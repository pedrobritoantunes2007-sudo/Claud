// Luta: combo de patadas e mordida, tiros pela boca, dash, dano com vantagem de elemento, empurrão,
// estados (atordoado, congelado, lento, queimando...), números de dano e nocaute.
// Regras e números do Config.lua do projeto Roblox (MELEE_COMBO, SHOT_*, DASH_*, ELEMENT_*).
import * as THREE from 'three';
import { CONFIG, elementMultiplier } from '../data/jogo.js';
import { angleDiff } from '../core/util.js';
import { WATER_Y } from '../world/fisica.js';

const C = CONFIG;
const _v = new THREE.Vector3();
const _m = new THREE.Matrix4();

export function hostile(a, b) {
	if (!a || !b || a === b || a.dead || b.dead) return false;
	const sa = a.side || (a.kind === 'player' ? 'player' : 'wild');
	const sb = b.side || (b.kind === 'player' ? 'player' : 'wild');
	return sa !== sb;
}

// boca do cachorro no mundo (osso da mandíbula)
export function mouthPos(f, out = new THREE.Vector3()) {
	const i = f.rig.asset.byName.Jaw1 ?? f.rig.asset.byName.Neck1;
	if (i !== undefined) {
		f.mesh.updateMatrixWorld();
		const bone = f.rig.bones[i];
		bone.updateWorldMatrix(true, false);
		out.setFromMatrixPosition(bone.matrixWorld);
		const [fx, fz] = f.forward();
		out.x += fx * 0.4 * f.scale;
		out.z += fz * 0.4 * f.scale;
		return out;
	}
	const [fx, fz] = f.forward();
	return out.set(f.x + fx * f.body.radius * 1.5, f.y + f.body.height * 0.7, f.z + fz * f.body.radius * 1.5);
}

function hexOf(c) {
	return typeof c === 'string' ? parseInt(c.replace('#', ''), 16) : c;
}

export class Combat {
	constructor(game) {
		this.game = game;
		this.projectiles = [];
		this.timers = [];
		this.now = 0;
		this.projGeo = {
			ball: new THREE.IcosahedronGeometry(0.5, 1),
			shard: new THREE.OctahedronGeometry(0.5, 0),
			box: new THREE.BoxGeometry(1, 1, 1),
		};
	}

	get fx() {
		return this.game.fx;
	}

	after(seconds, fn) {
		this.timers.push({ at: this.now + seconds, fn });
	}

	// ---------------------------------------------------------------- dano
	// opts: knock (força), lift, from [x,z], kind ('melee'|'shot'|'skill'|'dash'|'dot'), crit, silent, color, label
	damage(attacker, target, amount, opts = {}) {
		if (!target || target.dead) return 0;
		const now = this.now;
		if (target.invulnUntil > now && opts.kind !== 'dot') {
			this.fx.text(target.x, target.y + target.body.height + 0.5, target.z, 'MISS', { cls: 'miss' });
			return 0;
		}
		let mult = 1;
		let label = null;
		if (attacker && attacker.speciesId && target.speciesId && opts.kind !== 'dot') {
			mult = elementMultiplier(attacker.speciesId, target.speciesId);
			if (mult > 1) label = 'SUPER!';
			else if (mult < 1) label = 'WEAK';
		}
		if (attacker) {
			const rage = attacker.statusOn && attacker.statusOn('rage', now);
			if (rage) mult *= rage.mult;
		}
		const curse = target.statusOn('curse', now);
		if (curse) mult *= curse.mult;
		const shield = target.statusOn('shield', now);
		if (shield) mult *= 1 - shield.reduce;
		let dmg = Math.max(1, Math.round(amount * mult));
		target.hp -= dmg;
		target.lastHurtAt = now;
		if (attacker) {
			target.lastHitBy = attacker;
			target.damageBy.set(attacker, (target.damageBy.get(attacker) || 0) + dmg);
			attacker.lastAttackAt = now;
			if (target.kind !== 'player' && hostile(attacker, target)) target.aggroOn = attacker;
		}
		// número de dano
		if (!opts.silent) {
			const big = opts.kind === 'skill' || dmg > target.maxHp * 0.2;
			const cls = target.kind === 'player' ? 'dano-meu' : big ? 'dano-grande' : 'dano';
			this.fx.text(target.x, target.y + target.body.height + 0.4, target.z, String(dmg), { cls, color: opts.color });
			if (label && (!target.lastLabelAt || now - target.lastLabelAt > 1.5)) {
				target.lastLabelAt = now;
				this.fx.text(target.x, target.y + target.body.height + 1.6, target.z, label, { cls: label === 'SUPER!' ? 'super' : 'fraco' });
			}
		}
		target.anim.playHit(Math.min(1, (dmg / target.maxHp) * 6));
		// empurrão
		if (opts.knock || opts.lift) {
			let dx = 0, dz = 0;
			if (opts.from) {
				dx = target.x - opts.from[0];
				dz = target.z - opts.from[1];
			} else if (attacker) {
				dx = target.x - attacker.x;
				dz = target.z - attacker.z;
			}
			const n = Math.hypot(dx, dz) || 1;
			const resist = target.kind === 'champion' ? 0.25 : 1;
			target.body.vx = (dx / n) * (opts.knock || 0) * resist;
			target.body.vz = (dz / n) * (opts.knock || 0) * resist;
			if (opts.lift) {
				target.body.vy = opts.lift * resist;
				target.body.grounded = false;
			}
			target.knockUntil = now + 0.35;
		}
		if (target.kind === 'player') {
			this.game.onPlayerHurt && this.game.onPlayerHurt(dmg, attacker);
		}
		if (target.hp <= 0) {
			target.hp = 0;
			this.kill(target, attacker);
		}
		return dmg;
	}

	heal(target, amount) {
		if (!target || target.dead) return;
		const before = target.hp;
		target.hp = Math.min(target.maxHp, target.hp + amount);
		const got = Math.round(target.hp - before);
		if (got > 0) this.fx.text(target.x, target.y + target.body.height + 0.4, target.z, '+' + got, { cls: 'cura' });
	}

	kill(target, attacker) {
		if (target.dead) return;
		target.dead = true;
		target.deadAt = this.now;
		target.action = null;
		target.body.vx = target.body.vz = 0;
		target.status = {};
		this.fx.burst(target.x, target.y + target.body.height * 0.5, target.z, { count: 14, color: [0xffffff, 0xffe9a0, 0xdddddd], speed: 8, up: 6, size: 0.4, life: 0.7 });
		this.game.audio && this.game.audio.sfx('KO', target);
		this.game.onKill && this.game.onKill(target, attacker);
	}

	// ---------------------------------------------------------------- estados
	stun(target, seconds, mark = 'Dizzy') {
		if (!target || target.dead) return;
		const res = target.kind === 'champion' ? 0.4 : 1;
		target.status.stun = { until: this.now + seconds * res, mark };
		target.body.vx = target.body.vz = 0;
		this.game.marks && this.game.marks.add(target, mark, seconds * res);
	}

	freeze(target, seconds) {
		if (!target || target.dead) return;
		const res = target.kind === 'champion' ? 0.4 : 1;
		target.status.freeze = { until: this.now + seconds * res };
		target.body.vx = target.body.vz = 0;
		this.game.marks && this.game.marks.add(target, 'Ice', seconds * res);
	}

	slow(target, seconds, mult = 0.6) {
		if (!target || target.dead) return;
		target.status.slow = { until: this.now + seconds, mult };
		this.game.marks && this.game.marks.add(target, 'Slow', seconds);
	}

	dot(attacker, target, seconds, total, kind = 'Burn') {
		if (!target || target.dead) return;
		const ticks = Math.max(1, Math.round(seconds / 0.5));
		target.status.dot = { until: this.now + seconds, per: total / ticks, next: this.now + 0.5, by: attacker, kind };
		this.game.marks && this.game.marks.add(target, kind, seconds);
	}

	curse(target, seconds, mult = 1.25) {
		if (!target || target.dead) return;
		target.status.curse = { until: this.now + seconds, mult };
		this.game.marks && this.game.marks.add(target, 'Curse', seconds);
	}

	buff(target, name, seconds, values) {
		target.status[name] = Object.assign({ until: this.now + seconds }, values);
		this.game.marks && this.game.marks.add(target, name, seconds);
	}

	// ---------------------------------------------------------------- combo de perto (patada direita, esquerda, mordida)
	// devolve o tempo até poder golpear de novo
	melee(f, aimX, aimZ) {
		const now = this.now;
		if (now - f.comboAt > C.MELEE_COMBO_WINDOW || f.combo >= 3) f.combo = 0;
		f.combo++;
		f.comboAt = now;
		const step = f.combo;
		const power = C.MELEE_COMBO[step - 1];
		const gap = C.MELEE_GAP[step - 1];
		// vira para a mira
		if (aimX !== undefined) f.yaw = Math.atan2(-(aimX - f.x), -(aimZ - f.z));
		f.anim.playMelee(step);
		this.game.audio && this.game.audio.sfx(step === 3 ? 'Bite' : 'Slash', f);
		const hitAt = step === 3 ? 0.17 : 0.13;
		this.after(hitAt, () => {
			if (f.dead) return;
			const [fx, fz] = f.forward();
			const reach = C.MELEE_REACH + f.body.radius;
			const cone = (C.MELEE_AIM_CONE * Math.PI) / 180;
			let hits = 0;
			for (const t of this.game.fighters) {
				if (!hostile(f, t)) continue;
				const dx = t.x - f.x, dz = t.z - f.z;
				const dist = Math.hypot(dx, dz) - t.body.radius;
				if (dist > reach || Math.abs(t.y - f.y) > Math.max(4, f.body.height + t.body.height)) continue;
				const ang = Math.abs(angleDiff(Math.atan2(-dx, -dz), f.yaw));
				if (dist > 1 && ang > cone) continue;
				const dmg = this.damage(f, t, f.atk * power, { kind: 'melee', knock: step === 3 ? 26 : 8, lift: step === 3 ? 14 : 0 });
				if (dmg > 0) hits++;
				const p = t.rootPos(_v);
				this.fx.sparks(p.x, p.y, p.z, step === 3 ? 0xffffff : 0xfff0c0, step === 3 ? 14 : 8);
			}
			const mp = mouthPos(f, _v);
			if (step < 3) this.fx.slash(mp.x + fx * 0.8, mp.y - 0.3 * f.scale, mp.z + fz * 0.8, f.yaw, 0xffffff, f.scale * 0.9);
			if (hits && f.kind === 'player') this.game.camShake(step === 3 ? 0.5 : 0.18, step === 3 ? 0.18 : 0.08);
			if (hits && f.kind === 'player') this.game.audio && this.game.audio.sfx(step === 3 ? 'Crit' : 'Hit', f);
		});
		return gap;
	}

	// ---------------------------------------------------------------- tiro pela boca
	shoot(f, aimX, aimY, aimZ, opts = {}) {
		const shot = f.shot;
		if (!shot) return 0;
		const st = shot.style;
		const now = this.now;
		f.shotCount = now - (f.lastShotAt || -10) < 2.2 ? (f.shotCount || 0) + 1 : 1;
		f.lastShotAt = now;
		const big = f.shotCount % 3 === 0;
		const isPlayer = f.kind === 'player';
		f.yaw = Math.atan2(-(aimX - f.x), -(aimZ - f.z));
		f.setAction('Spit', 0.3);
		f.anim.playBite(1);
		const from = mouthPos(f, new THREE.Vector3());
		let dx = aimX - from.x, dy = aimY - from.y, dz = aimZ - from.z;
		const flat = Math.hypot(dx, dz);
		const range = isPlayer ? C.SHOT_RANGE : Math.max(30, C.SHOT_AI_RANGE * 2);
		// tiro do jogador vai reto (com subida/descida só se mirou bem em cima/baixo)
		if (flat > 0.1) {
			dy = Math.max(-flat * 0.6, Math.min(flat * 0.6, dy));
		}
		const n = Math.hypot(dx, dy, dz) || 1;
		dx /= n;
		dy /= n;
		dz /= n;
		const color = hexOf(st.Color || '#ffffff'), color2 = hexOf(st.Color2 || '#ffffff');
		const dmg = f.atk * C.SHOT_DAMAGE * (big ? 1.6 : 1) * (opts.mult || 1);
		const count = st.Count || 1;
		this.game.audio && this.game.audio.sfx(st.Shape === 'Beam' || st.Shape === 'Bolt' ? 'Laser' : 'Projectile', f);
		for (let k = 0; k < count; k++) {
			const spread = count > 1 ? (k - (count - 1) / 2) * 0.12 : 0;
			const cs = Math.cos(spread), sn = Math.sin(spread);
			const ddx = dx * cs - dz * sn, ddz = dx * sn + dz * cs;
			if (st.Shape === 'Beam' || st.Shape === 'Bolt') {
				this.instantRay(f, from, ddx, dy, ddz, range, dmg, color, color2, st, big);
			} else {
				this.spawnProjectile(f, from, ddx, dy, ddz, range, dmg, color, color2, st, big);
			}
		}
		return isPlayer ? C.SHOT_COOLDOWN : C.SHOT_AI_COOLDOWN * (0.85 + Math.random() * 0.3);
	}

	// raio/laser: acerta na hora o primeiro na linha
	instantRay(f, from, dx, dy, dz, range, dmg, color, color2, st, big) {
		const hit = this.firstOnLine(f, from, dx, dy, dz, range, (st.Size || 1) * 1.2);
		const len = hit ? hit.t : this.wallDistance(from, dx, dy, dz, range);
		const end = new THREE.Vector3(from.x + dx * len, from.y + dy * len, from.z + dz * len);
		const thick = (big ? 0.7 : 0.4) * (st.Size || 1);
		const mat = new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 0.95, toneMapped: false });
		const core = new THREE.MeshBasicMaterial({ color: color2, transparent: true, opacity: 1, toneMapped: false });
		const group = new THREE.Group();
		if (st.Shape === 'Bolt') {
			// raio em zigue-zague
			let px = from.x, py = from.y, pz = from.z;
			const segs = Math.max(3, Math.floor(len / 4));
			for (let i = 1; i <= segs; i++) {
				const t = (i / segs) * len;
				const jx = i === segs ? 0 : (Math.random() - 0.5) * 1.6, jy = i === segs ? 0 : (Math.random() - 0.5) * 1.6;
				const nx = from.x + dx * t + jx, ny = from.y + dy * t + jy, nz = from.z + dz * t;
				group.add(this.segment(px, py, pz, nx, ny, nz, thick, mat));
				px = nx;
				py = ny;
				pz = nz;
			}
		} else {
			group.add(this.segment(from.x, from.y, from.z, end.x, end.y, end.z, thick * 1.6, mat));
			group.add(this.segment(from.x, from.y, from.z, end.x, end.y, end.z, thick * 0.6, core));
		}
		this.fx.addMesh(group, 0.18, (it, t) => {
			mat.opacity = 0.95 * (1 - t);
			core.opacity = 1 - t;
		});
		this.impact(end.x, end.y, end.z, st.Impact || 'Burst', color, color2, big);
		if (hit) this.damage(f, hit.f, dmg, { kind: 'shot', knock: big ? 22 : 4, lift: big ? 10 : 0, from: [from.x, from.z] });
	}

	segment(ax, ay, az, bx, by, bz, thick, mat) {
		const len = Math.hypot(bx - ax, by - ay, bz - az);
		const m = new THREE.Mesh(this.projGeo.box, mat);
		m.scale.set(thick, thick, len);
		m.position.set((ax + bx) / 2, (ay + by) / 2, (az + bz) / 2);
		m.lookAt(bx, by, bz);
		return m;
	}

	spawnProjectile(f, from, dx, dy, dz, range, dmg, color, color2, st, big) {
		const size = (st.Size || 1) * (big ? 1.5 : 1) * Math.max(0.8, Math.min(1.6, f.scale));
		const mat = new THREE.MeshBasicMaterial({ color, toneMapped: false });
		let mesh;
		if (st.Shape === 'Shard') {
			mesh = new THREE.Mesh(this.projGeo.shard, mat);
			mesh.scale.set(size * 0.6, size * 0.6, size * 1.6);
		} else if (st.Shape === 'Bone') {
			mesh = new THREE.Group();
			const m1 = new THREE.Mesh(this.projGeo.box, mat);
			m1.scale.set(size * 1.6, size * 0.35, size * 0.35);
			const m2 = new THREE.Mesh(this.projGeo.box, mat);
			m2.scale.set(size * 0.5, size * 0.7, size * 0.5);
			m2.position.x = size * 0.8;
			const m3 = m2.clone();
			m3.position.x = -size * 0.8;
			mesh.add(m1, m2, m3);
		} else if (st.Shape === 'Wave') {
			mesh = new THREE.Mesh(new THREE.TorusGeometry(size * 1.1, size * 0.18, 6, 16, Math.PI), new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 0.85, toneMapped: false }));
		} else {
			mesh = new THREE.Mesh(this.projGeo.ball, mat);
			mesh.scale.setScalar(size);
			const glow = new THREE.Mesh(this.projGeo.ball, new THREE.MeshBasicMaterial({ color: color2, transparent: true, opacity: 0.45, toneMapped: false, depthWrite: false }));
			glow.scale.setScalar(1.45);
			mesh.add(glow);
		}
		mesh.position.copy(from);
		this.game.scene.add(mesh);
		const speed = st.Speed || 100;
		this.projectiles.push({
			f, mesh, x: from.x, y: from.y, z: from.z, dx, dy, dz, speed, traveled: 0, range,
			maxTime: C.SHOT_MAX_TIME, age: 0, dmg, color, color2, st, big, size,
			arc: st.Arc ? st.Arc * Math.min(1, range / 60) : 0, vy: st.Arc ? st.Arc * 3 : 0,
			width: 0.6 * size + C.SHOT_AIM_WIDTH * 0.35,
		});
	}

	wallDistance(from, dx, dy, dz, range) {
		const ph = this.game.world.physics;
		if (!ph) return range;
		const hit = ph.raycast(from.x, from.y, from.z, dx, dy, dz, range, 1.5);
		return hit ? hit.t : range;
	}

	// primeiro inimigo perto da linha (from + dir * t), até `range`
	firstOnLine(f, from, dx, dy, dz, range, width) {
		let best = null;
		for (const t of this.game.fighters) {
			if (!hostile(f, t)) continue;
			const c = t.rootPos(_v);
			const rx = c.x - from.x, ry = c.y - from.y, rz = c.z - from.z;
			const proj = rx * dx + ry * dy + rz * dz;
			if (proj < 0 || proj > range) continue;
			const px = rx - dx * proj, py = ry - dy * proj, pz = rz - dz * proj;
			const off = Math.hypot(px, py * 0.6, pz);
			if (off <= t.body.radius + width && (!best || proj < best.t)) best = { f: t, t: proj };
		}
		if (best) {
			const wall = this.wallDistance(from, dx, dy, dz, best.t);
			if (wall < best.t - 1) return null;
		}
		return best;
	}

	impact(x, y, z, kind, color, color2, big) {
		const p = big ? 1.5 : 1;
		if (kind === 'Explode') {
			this.fx.burst(x, y, z, { count: 18 * p, color: [color, color2, 0xffffff], speed: 14 * p, up: 6, size: 0.45, life: 0.5 });
			this.fx.ring(x, y - 0.5, z, 5 * p, color, 0.4);
			this.game.audio && this.game.audio.sfxAt('Explosion', x, y, z, 0.6);
		} else if (kind === 'Splash') {
			this.fx.burst(x, y, z, { count: 14 * p, color: [color, color2], speed: 10, up: 10, size: 0.35, life: 0.55, gravity: 40 });
		} else if (kind === 'Shatter') {
			this.fx.burst(x, y, z, { count: 12 * p, color: [color, color2, 0xffffff], speed: 12, up: 5, size: 0.3, life: 0.45 });
		} else if (kind === 'Pop') {
			this.fx.burst(x, y, z, { count: 20, color: [0xff6fb5, 0x6fd3ff, 0xffe066, 0x8cff7a], speed: 12, up: 8, size: 0.3, life: 0.7 });
		} else {
			this.fx.burst(x, y, z, { count: 10 * p, color: [color, color2], speed: 11, up: 4, size: 0.3, life: 0.35 });
		}
	}

	// ---------------------------------------------------------------- dash (Q)
	dash(f, dirX, dirZ) {
		const n = Math.hypot(dirX, dirZ) || 1;
		dirX /= n;
		dirZ /= n;
		f.dashUntil = this.now + C.DASH_TIME;
		f.dashDir = [dirX, dirZ];
		f.dashHit = new Set();
		f.invulnUntil = this.now + 0.3;
		f.yaw = Math.atan2(-dirX, -dirZ);
		f.anim.playDodge(dirX, dirZ, true);
		f.setAction('Dash', 0.35);
		this.fx.dust(f.x, f.y, f.z, 0.8);
		this.game.audio && this.game.audio.sfx('Whoosh', f);
		return C.DASH_COOLDOWN;
	}

	updateDash(f) {
		if (!f.dashUntil || this.now > f.dashUntil) return false;
		f.body.vx = f.dashDir[0] * C.DASH_SPEED;
		f.body.vz = f.dashDir[1] * C.DASH_SPEED;
		for (const t of this.game.fighters) {
			if (!hostile(f, t) || f.dashHit.has(t)) continue;
			if (Math.hypot(t.x - f.x, t.z - f.z) < t.body.radius + f.body.radius + C.DASH_HIT_WIDTH && Math.abs(t.y - f.y) < 5) {
				f.dashHit.add(t);
				this.damage(f, t, f.atk * C.DASH_DAMAGE, { kind: 'dash', knock: 18, lift: 6 });
				this.fx.sparks(t.x, t.y + t.body.height * 0.5, t.z, 0xffffff, 8);
			}
		}
		if (Math.random() < 0.5) this.fx.burst(f.x, f.y + 0.3, f.z, { count: 1, color: 0xffffff, speed: 1, up: 1, size: 0.4, life: 0.25, gravity: 0 });
		return true;
	}

	// ---------------------------------------------------------------- área (para habilidades e chefões)
	area(f, x, y, z, radius, amount, opts = {}) {
		const hits = [];
		for (const t of this.game.fighters) {
			if (!hostile(f, t)) continue;
			const d = Math.hypot(t.x - x, t.z - z) - t.body.radius;
			if (d <= radius && Math.abs(t.y - y) < radius + 6) {
				this.damage(f, t, amount, Object.assign({ kind: 'skill', from: [x, z] }, opts));
				hits.push(t);
			}
		}
		return hits;
	}

	// ---------------------------------------------------------------- quadro
	update(dt, now) {
		this.now = now;
		// timers
		if (this.timers.length) {
			const due = this.timers.filter((t) => t.at <= now);
			this.timers = this.timers.filter((t) => t.at > now);
			for (const t of due) t.fn();
		}
		// estados que fazem efeito com o tempo (queimar, veneno)
		for (const f of this.game.fighters) {
			const d = f.status.dot;
			if (d && !f.dead) {
				if (d.until < now) delete f.status.dot;
				else if (now >= d.next) {
					d.next += 0.5;
					this.damage(d.by, f, d.per, { kind: 'dot', color: d.kind === 'Poison' ? '#9dff6a' : '#ffae4a' });
				}
			}
		}
		// tiros
		const ph = this.game.world.physics;
		this.projectiles = this.projectiles.filter((p) => {
			p.age += dt;
			const step = p.speed * dt;
			let nx = p.x + p.dx * step, ny = p.y + p.dy * step, nz = p.z + p.dz * step;
			if (p.arc) {
				p.vy -= 25 * dt;
				ny += p.vy * dt * 0.4;
			}
			p.traveled += step;
			// acerta alguém no caminho?
			let hit = null;
			for (const t of this.game.fighters) {
				if (!hostile(p.f, t)) continue;
				const c = t.rootPos(_v);
				const dd = Math.hypot(c.x - nx, (c.y - ny) * 0.7, c.z - nz);
				if (dd < t.body.radius + p.width) {
					hit = t;
					break;
				}
			}
			const wall = ph && (ph.solidAt(nx, ny, nz) || ny < WATER_Y - 0.5);
			if (hit || wall || p.traveled > p.range || p.age > p.maxTime) {
				this.impact(nx, ny, nz, p.st.Impact || 'Burst', p.color, p.color2, p.big);
				if (hit) this.damage(p.f, hit, p.dmg, { kind: 'shot', knock: p.big ? 22 : 4, lift: p.big ? 10 : 0, from: [p.x, p.z] });
				this.game.scene.remove(p.mesh);
				p.mesh.traverse((o) => o.material && o.material.dispose());
				return false;
			}
			p.x = nx;
			p.y = ny;
			p.z = nz;
			p.mesh.position.set(nx, ny, nz);
			p.mesh.lookAt(nx + p.dx, ny + p.dy, nz + p.dz);
			if (p.st.Shape === 'Bone') p.mesh.rotateZ(p.age * 18);
			// rastro
			const trail = p.st.Trail;
			if (trail && Math.random() < 0.8) {
				const col = trail === 'Fire' ? [0xffa040, 0xffe080, 0xff5020] : trail === 'Smoke' ? [0x888888, p.color] : [p.color2, 0xffffff];
				this.fx.burst(nx, ny, nz, { count: 1, color: col, speed: 1.5, up: trail === 'Smoke' ? 1 : 0.5, size: 0.35 * p.size, life: 0.3, gravity: trail === 'Fire' ? -6 : 0 });
			}
			return true;
		});
	}

	clear() {
		for (const p of this.projectiles) this.game.scene.remove(p.mesh);
		this.projectiles = [];
		this.timers = [];
	}
}

void _m;
