// O JOGO: junta mundo, cachorros, câmera, luta, efeitos e telas. Um quadro = ler controles → mexer todo mundo →
// física → luta → câmera → montar pedaços da ilha perto → desenhar.
import * as THREE from 'three';
import { R, render, followSun } from '../core/render.js';
import { Input, endInputFrame } from '../core/input.js';
import { World } from '../world/mundo.js';
import { WATER_Y } from '../world/fisica.js';
import { FollowCamera } from './camera.js';
import { Fighter } from './lutador.js';
import { Combat, hostile } from './combate.js';
import { Effects } from './efeitos.js';
import { PlayerController } from './jogador.js';
import { initAI, updateAI, separate } from './selvagem.js';
import { Plates } from '../ui/plaquinhas.js';
import { CONFIG, ISLANDS, SPECIES, speciesOfRarity, speciesWithElement, killReward, xpToNext } from '../data/jogo.js';
import { clamp } from '../core/util.js';

const C = CONFIG;
const FLY_RARITIES = ['Uncommon', 'Rare', 'Epic', 'Legendary', 'Mythic'];
const ACTIVE_DIST = 240; // selvagens mais longe que isso ficam "dormindo"
const SHOW_DIST = 320;

export class Game {
	constructor(uiRoot) {
		this.uiRoot = uiRoot;
		this.scene = R.scene;
		this.cam = new FollowCamera(R.camera);
		this.world = new World();
		this.fighters = [];
		this.player = null;
		this.ctrl = null;
		this.fx = new Effects(this.scene, uiRoot);
		this.combat = new Combat(this);
		this.plates = new Plates(uiRoot, R.camera);
		this.marks = this.plates;
		this.islandId = null;
		this.island = null; // definição (dados.json)
		this.local = null; // info da ilha exportada (pontos)
		this.wild = [];
		this.respawns = [];
		this.time = 0;
		this.paused = false;
		this.portals = [];
		this.travelling = false;
		this.listeners = {};
		this.hud = null;
		this.audio = null;
		this.skills = null;
		this.quality = 'high';
		this.koUntil = 0;
		this.portalCooldown = 0;
	}

	on(name, fn) {
		(this.listeners[name] ||= []).push(fn);
	}

	emit(name, ...args) {
		for (const fn of this.listeners[name] || []) fn(...args);
	}

	toast(msg, kind = '') {
		this.emit('toast', msg, kind);
	}

	camShake(power, time) {
		this.cam.shake(power, time);
	}

	// ---------------------------------------------------------------- jogador
	setPlayerDog(speciesId, level, opts = {}) {
		const old = this.player;
		const f = new Fighter({ speciesId, level, kind: 'player', name: opts.name });
		f.side = 'player';
		f.dogUid = opts.uid;
		f.xp = opts.xp || 0;
		this.scene.add(f.mesh);
		if (old) {
			f.place(old.x, old.y, old.z, old.yaw);
			this.removeFighter(old);
		}
		this.player = f;
		this.fighters.push(f);
		if (!this.ctrl) this.ctrl = new PlayerController(this, f);
		else this.ctrl.setFighter(f);
		const sz = clamp(f.body.height, 2, 12);
		this.cam.focusHeight = sz * 0.75;
		this.cam.wantDist = this.cam.dist = 9 + sz * 2.2;
		this.emit('player', f);
		return f;
	}

	removeFighter(f) {
		const i = this.fighters.indexOf(f);
		if (i >= 0) this.fighters.splice(i, 1);
		this.plates.detach(f);
		f.dispose();
	}

	// ---------------------------------------------------------------- ilhas
	async enterIsland(id, opts = {}) {
		this.travelling = true;
		this.emit('loading', id, 0);
		for (const f of [...this.wild]) this.removeFighter(f);
		this.wild = [];
		this.respawns = [];
		this.combat.clear();
		this.fx.clear();
		await this.world.load(id, (p) => this.emit('loading', id, p));
		this.world.setQuality(this.quality);
		this.islandId = id;
		this.island = ISLANDS.List[id] || null;
		this.local = this.world.data.info;
		this.buildPortals();
		// onde nasce
		const spawn = opts.spawn || this.arrivalPoint();
		const p = this.player;
		if (p) {
			const y = this.groundAt(spawn[0], spawn[1]);
			p.place(spawn[0], y + 0.2, spawn[1], spawn[2] ?? 0);
			p.hp = Math.max(p.hp, 1);
			p.body.flying = false;
			this.cam.snap(p.x, p.y, p.z, p.yaw);
			this.cam.yaw = p.yaw;
		}
		// monta logo o que está perto
		this.world.view.update(spawn[0], spawn[1], 1e9, true);
		if (this.island) {
			const n = Math.min(this.island.Wild || 12, this.maxWild());
			for (let i = 0; i < n; i++) this.spawnWild();
			if (this.island.Champion) this.spawnChampion();
		}
		this.portalCooldown = this.time + 2;
		this.travelling = false;
		this.emit('island', id);
	}

	maxWild() {
		return this.quality === 'low' ? 10 : this.quality === 'medium' ? 16 : 22;
	}

	// ponto de chegada [x, z, giro]
	arrivalPoint() {
		const L = this.local;
		if (L.def && L.def.Arrival) return [L.def.Arrival[0], L.def.Arrival[2], 0];
		if (this.islandId === 'village') return [0, 56, 0];
		if (this.islandId === 'main') return [0, 480, 0];
		return [0, 0, 0];
	}

	groundAt(x, z, fromY = 2000) {
		const ph = this.world.physics;
		if (!ph) return 0;
		const y = ph.topAt(x, z, fromY);
		return y === -Infinity ? WATER_Y : Math.max(y, WATER_Y - 1);
	}

	// portais da ilha atual: { x, z, r, to, label }
	buildPortals() {
		const id = this.islandId;
		const L = this.local;
		this.portals = [];
		if (id === 'village') {
			this.portals.push({ x: 0, z: 304, r: 10, to: 'main', spawn: 'pawville', label: '⚔️ ARENA' });
			this.portals.push({ x: -74, z: 254, r: 10, to: 'common', label: '🌻 PUPPY MEADOWS' });
		} else if (id === 'main') {
			for (const [isl, cf] of Object.entries(L.plazaPortals || {})) {
				this.portals.push({ x: cf[0], z: cf[2], r: 9, to: isl, label: ISLANDS.List[isl] ? ISLANDS.List[isl].Name : isl });
			}
			const pv = (L.layout && L.layout.PAWVILLE_PORTAL) || [0, 0, 604];
			this.portals.push({ x: pv[0], z: pv[2], r: 9, to: 'village', label: '🏡 PAWVILLE' });
		} else if (L.def && L.def.Portal) {
			this.portals.push({ x: L.def.Portal[0], z: L.def.Portal[2], r: 9, to: 'main', spawn: id, label: '🏠 HOME' });
		}
	}

	// ---------------------------------------------------------------- selvagens
	speciesPool() {
		const def = this.island;
		if (!def) return [];
		if (def.Flyers) {
			const list = [];
			for (const r of FLY_RARITIES) list.push(...speciesWithElement(r, 'Fly'));
			return list;
		}
		return speciesOfRarity(def.Golden ? 'Mythic' : def.Rarity);
	}

	randomIslandPoint(margin = 30) {
		const def = this.local.def;
		if (!def || !def.Shape) return null;
		let total = 0;
		for (const c of def.Shape) total += c[2] * c[2];
		for (let k = 0; k < 30; k++) {
			let pick = Math.random() * total;
			let ch = def.Shape[0];
			for (const c of def.Shape) {
				pick -= c[2] * c[2];
				if (pick <= 0) {
					ch = c;
					break;
				}
			}
			const a = Math.random() * Math.PI * 2;
			const r = Math.sqrt(Math.random()) * Math.max(5, ch[2] - margin);
			const x = ch[0] + Math.cos(a) * r, z = ch[1] + Math.sin(a) * r;
			if (def.Holes && def.Holes.some((h) => Math.hypot(x - h[0], z - h[1]) < h[2] + 6)) continue;
			const y = this.groundAt(x, z);
			if (y <= WATER_Y + 0.3) continue;
			return [x, y, z];
		}
		return null;
	}

	spawnPoint() {
		let best = null, bestGap = -1;
		const avoid = [];
		if (this.player) avoid.push([this.player.x, this.player.z, 1]);
		const arr = this.arrivalPoint();
		avoid.push([arr[0], arr[1], 0.6]);
		for (const w of this.wild) if (!w.dead) avoid.push([w.x, w.z, 2.5]);
		for (let i = 0; i < 8; i++) {
			const p = this.randomIslandPoint(28);
			if (!p) continue;
			let gap = Infinity;
			for (const [ax, az, wgt] of avoid) gap = Math.min(gap, Math.hypot(p[0] - ax, p[2] - az) * wgt);
			if (gap > bestGap) {
				best = p;
				bestGap = gap;
			}
			if (gap > 90) break;
		}
		return best;
	}

	spawnWild() {
		const def = this.island;
		const list = this.speciesPool();
		if (!list.length) return null;
		const pos = this.spawnPoint();
		if (!pos) return null;
		const speciesId = list[Math.floor(Math.random() * list.length)];
		const level = def.Levels[0] + Math.floor(Math.random() * (def.Levels[1] - def.Levels[0] + 1));
		const golden = !!def.Golden;
		const f = new Fighter({
			speciesId,
			level,
			kind: 'wild',
			name: (golden ? '☀️ Sun Guardian ' : 'Wild ') + SPECIES[speciesId].Name,
			statMult: golden ? { HP: 1.1, Atk: 1 } : { HP: 0.75, Atk: 0.75 },
			island: this.islandId,
		});
		f.side = 'wild';
		if (def.Flyers) {
			f.body.flying = true;
			pos[1] += 5;
		}
		f.place(pos[0], pos[1], pos[2], Math.random() * Math.PI * 2);
		initAI(f, pos[0], pos[2]);
		this.scene.add(f.mesh);
		this.fighters.push(f);
		this.wild.push(f);
		this.plates.attach(f);
		return f;
	}

	spawnChampion() {
		const def = this.island;
		const c = def.Champion;
		const at = this.local.def.ChampionAt;
		let y = this.groundAt(at[0], at[2], (this.local.def.ChampionY || at[1]) + 40);
		const f = new Fighter({
			speciesId: c.Species,
			level: c.Level,
			kind: 'champion',
			name: '👑 ' + c.Name,
			scale: c.Scale * 0.6,
			statMult: { HP: 4, Atk: 1.15 },
			island: this.islandId,
		});
		f.side = 'wild';
		f.place(at[0], y + 0.2, at[2], Math.random() * 6.28);
		initAI(f, at[0], at[2], { champion: true, homeR: 14 });
		this.scene.add(f.mesh);
		this.fighters.push(f);
		this.wild.push(f);
		this.plates.attach(f);
		this.champion = f;
		return f;
	}

	isSafe(f) {
		if (!f || f.kind !== 'player') return false;
		if (this.islandId === 'village' || this.islandId === 'main') return true;
		const a = this.arrivalPoint();
		return Math.hypot(f.x - a[0], f.z - a[1]) < 22;
	}

	// ---------------------------------------------------------------- eventos de luta
	onKill(target, attacker) {
		if (target.kind === 'player') {
			this.koUntil = this.time + C.KO_RESPAWN;
			this.emit('ko', target, attacker);
			return;
		}
		// selvagem caiu: renasce depois
		this.respawns.push({ at: this.time + (target.kind === 'champion' ? 45 : 5), champion: target.kind === 'champion' });
		const p = this.player;
		if (!p) return;
		// quem ganha: quem deu o último golpe ou tirou >= 20% da vida
		const share = (target.damageBy.get(p) || 0) / target.maxHp;
		const credited = attacker === p || share >= C.QUEST_HELP_SHARE;
		if (!credited) return;
		const [, xp] = killReward(target.level, target.stats.Power, p.level);
		const gain = Math.max(1, Math.floor(xp * (target.kind === 'champion' ? 1 : C.WILD_XP_MULT)));
		this.giveXP(gain);
		this.emit('kill', target);
	}

	giveXP(amount) {
		const p = this.player;
		if (!p) return;
		p.xp = (p.xp || 0) + amount;
		this.fx.text(p.x, p.y + p.body.height + 1.2, p.z, `+${amount} XP`, { cls: 'xp' });
		let ups = 0;
		while (p.level < C.MAX_LEVEL && p.xp >= xpToNext(p.level)) {
			p.xp -= xpToNext(p.level);
			p.level++;
			ups++;
		}
		if (ups) {
			p.refreshStats();
			p.hp = p.maxHp;
			this.fx.burst(p.x, p.y + 1, p.z, { count: 30, color: [0xffe066, 0xffffff, 0x8cf0ff], speed: 10, up: 14, size: 0.45, life: 1.1 });
			this.fx.ring(p.x, p.y, p.z, 8, 0xffe066, 0.6);
			this.plates.setName(p);
			this.emit('levelup', p, ups);
		}
		this.emit('xp', p, amount);
	}

	onPlayerHurt(dmg) {
		this.camShake(Math.min(0.6, 0.15 + dmg / (this.player.maxHp * 0.5)), 0.15);
		this.emit('hurt', dmg);
	}

	flyBlocked() {
		return false;
	}

	// ---------------------------------------------------------------- quadro
	update(dt) {
		if (this.paused || this.travelling) {
			endInputFrame();
			return;
		}
		dt = Math.min(dt, 0.05);
		this.time += dt;
		const now = this.time;
		const p = this.player;
		this.combat.now = now;
		if (p && this.ctrl) this.ctrl.update(dt, now, this.cam);
		// selvagens perto acordam
		for (const f of this.wild) {
			if (f.dead) continue;
			const d = p ? Math.hypot(f.x - p.x, f.z - p.z) : 0;
			f.sleeping = d > ACTIVE_DIST && !f.target;
			if (!f.sleeping) updateAI(this, f, dt, now);
		}
		separate(this.fighters, dt);
		const bounds = this.bounds();
		for (const f of this.fighters) {
			const d = p ? Math.hypot(f.x - p.x, f.z - p.z) : 0;
			f.mesh.visible = d < SHOW_DIST && !(f.dead && now - f.deadAt > 1.6);
			if (f.sleeping && f !== p) continue;
			// animação mais leve de longe
			if (f !== p && d > 120) {
				f.animSkip = (f.animSkip || 0) + 1;
				if (f.animSkip % 3 !== 0) {
					f.syncMesh(dt, false);
					continue;
				}
				f.update(dt * 3, now, this.world, { bounds });
				continue;
			}
			f.update(dt, now, this.world, { bounds });
		}
		this.combat.update(dt, now);
		// selvagens mortos somem e renascem
		for (const f of [...this.wild]) {
			if (f.dead && now - f.deadAt > 2.2) {
				this.wild.splice(this.wild.indexOf(f), 1);
				this.removeFighter(f);
			}
		}
		this.respawns = this.respawns.filter((r) => {
			if (now < r.at) return true;
			if (r.champion) this.spawnChampion();
			else if (this.wild.filter((w) => !w.dead).length < this.maxWild()) this.spawnWild();
			return false;
		});
		this.regen(dt, now);
		// jogador caiu (nuvens) ou nocaute
		if (p) {
			if (p.y < WATER_Y - 60 && !p.dead) {
				const a = this.arrivalPoint();
				p.place(a[0], this.groundAt(a[0], a[1]) + 0.5, a[1], p.yaw);
				p.hp = Math.max(1, Math.floor(p.hp * 0.9));
				this.toast('You fell! Back to the portal.');
			}
			if (p.dead && now >= this.koUntil) this.respawnPlayer();
			this.checkPortals(now);
		}
		// câmera, mundo, efeitos
		if (p) this.cam.update(dt, p.x, p.visualY, p.z, this.world.physics);
		const cx = R.camera.position.x, cz = R.camera.position.z;
		if (p) {
			this.world.update(dt, now, p.x, p.z, cx, cz);
			followSun(p.x, p.y, p.z);
		}
		this.fx.update(dt);
		this.plates.update(dt);
		this.emit('frame', dt, now);
		endInputFrame();
	}

	bounds() {
		const g = this.world.data && this.world.data.grid;
		if (!g || !g.w) return { minX: -800, maxX: 800, minZ: -800, maxZ: 800 };
		const m = 60;
		return { minX: g.x0 - m, maxX: g.x0 + g.w * g.cell + m, minZ: g.z0 - m, maxZ: g.z0 + g.d * g.cell + m };
	}

	regen(dt, now) {
		const safe = this.islandId === 'village' || this.islandId === 'main';
		for (const f of this.fighters) {
			if (f.dead || f.hp >= f.maxHp) continue;
			if (f.ai && f.target) continue;
			if (now - f.lastHurtAt < C.REGEN_DELAY) continue;
			const rate = safe ? C.REGEN_SAFE : f.ai ? 0.06 : C.REGEN_FIELD;
			f.hp = Math.min(f.maxHp, f.hp + f.maxHp * rate * dt);
		}
	}

	respawnPlayer() {
		const p = this.player;
		const a = this.arrivalPoint();
		p.dead = false;
		p.hp = Math.max(1, Math.floor(p.maxHp * C.KO_RESPAWN_HP));
		p.status = {};
		p.place(a[0], this.groundAt(a[0], a[1]) + 0.3, a[1], a[2] || 0);
		for (const w of this.wild) if (w.target === p) w.target = null;
		this.cam.snap(p.x, p.y, p.z);
		this.emit('respawn', p);
	}

	checkPortals(now) {
		if (now < this.portalCooldown || this.travelling) return;
		const p = this.player;
		for (const portal of this.portals) {
			if (Math.hypot(p.x - portal.x, p.z - portal.z) < portal.r) {
				this.portalCooldown = now + 3;
				this.emit('portal', portal);
				return;
			}
		}
	}

	frame(dt) {
		this.update(dt);
		render();
	}

	render() {
		render();
	}
}

void THREE;
void hostile;
void Input;
