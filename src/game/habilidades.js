// HABILIDADES (teclas 2, 3 e 4): as 210 habilidades do projeto Roblox (SpecialsPacks/Skills_*.lua, traduzidas
// para src/gerado/habilidades) rodam em cima deste KIT, que é o SkillKit.lua refeito em JavaScript para o
// nosso jogo: pose → aviso → movimento → efeito + dano → resíduo. Os desenhos são os do jogo original
// (Effects.lua e os pacotes, também traduzidos) e saem pelo rbx.fx(nome, params).
//
// Regras do dono (iguais ao Roblox): o poder do jogador sai na SETINHA (alvo invisível no chão), rápido
// (Config.SKILL_SPEED), sem prender o cachorro — só durante um movimento curto da habilidade (≤ SKILL_MOVE).
// Força pela raridade (Config.SKILL_TIER): o código só diz a fração de cada golpe.
import { $W, $M, sched, callLua, delayCall, reportError, spawnThread, isGen } from '../rbx/lua.js';
import { Vector3, CFrame, Color3, Random } from '../rbx/tipos.js';
import { Instance } from '../rbx/instancias.js';
import { CONFIG, SKILLS, SPECIES, RARITY, ELEMENTS, skillTier, hasSupreme, powerUnlockLevel, elementsOf } from '../data/jogo.js';
import { hostile } from './combate.js';
import { Fighter } from './lutador.js';
import { WATER_Y } from '../world/fisica.js';

const C = Color3.fromRGB;
const UP = new Vector3(0, 1, 0);
const GREEN = C(120, 255, 140);
const MARKER_HIT = 6;
const clamp = (x, a, b) => (x < a ? a : x > b ? b : x);
const flat = (v) => new Vector3(v.x, 0, v.z);
const flatDist = (a, b) => Math.hypot(a.x - b.x, a.z - b.z);

let GAME = null;
const SKILL_INFO = {};
for (const list of Object.values(SKILLS)) for (const s of list) SKILL_INFO[s.Id] = s;

// ------------------------------------------------------------------ o cachorro visto pelo Lua (f.Root, f.Model...)
function installLuaView() {
	if (Fighter.prototype.$luaView) return;
	Fighter.prototype.$luaView = true;
	Object.defineProperties(Fighter.prototype, {
		Model: {
			get() {
				return GAME.rbx.modelOf(this);
			},
		},
		Root: {
			get() {
				return GAME.rbx.modelOf(this).PrimaryPart;
			},
		},
		Humanoid: {
			get() {
				return GAME.rbx.modelOf(this).hum;
			},
		},
		Radius: {
			get() {
				return this.body.radius;
			},
			set(v) {},
		},
		Kind: {
			get() {
				return this.kind === 'champion' ? 'boss' : this.kind === 'wild' ? 'npc' : this.kind;
			},
		},
		SpeciesId: {
			get() {
				return this.speciesId;
			},
		},
		Species: {
			get() {
				return this.species;
			},
		},
		Stats: {
			get() {
				return { Atk: this.atk, Speed: this.species.Stats.Speed, MaxHP: this.maxHp, Power: this.stats.Power };
			},
		},
		Level: {
			get() {
				return this.level;
			},
		},
		Dead: {
			get() {
				return this.dead;
			},
		},
		HipHeight: {
			get() {
				return this.rig.asset.data.hip * (this.baseScale || this.scale);
			},
			set(v) {},
		},
	});
}

// ------------------------------------------------------------------ regras de luta (Fighters.lua)
function alive(f) {
	if (!f) return false;
	if (f.Dummy) return !f.Removed;
	return !f.dead && GAME.fighters.includes(f);
}
function isHostile(a, b) {
	if (!a || !b || a === b) return false;
	if (a.Dummy || b.Dummy) {
		const m = a.Dummy ? a : b, o = a.Dummy ? b : a;
		return m.Caster === o && !m.Removed && alive(o);
	}
	if (!alive(a) || !alive(b)) return false;
	return hostile(a, b);
}
// vivo e lutando (o do jogador: enquanto alguma habilidade dele roda)
function live(f) {
	return alive(f) && (f.kind !== 'player' || f.casting > 0);
}
function valid(f, t) {
	return live(f) && !!t && alive(t) && isHostile(f, t);
}
function rootPos(f) {
	if (f.Dummy) return f.Root.Position;
	return new Vector3(f.body.x, f.body.y + f.groundOffset, f.body.z);
}
function enemies(f, pos, radius) {
	const list = [];
	for (const o of GAME.fighters) {
		if (!isHostile(f, o)) continue;
		if (!pos || Math.hypot(o.body.x - pos.x, o.body.z - pos.z) - o.body.radius <= radius) list.push(o);
	}
	return list;
}
function now() {
	return GAME.time;
}

// chão embaixo de um ponto (sem chão: um pouco abaixo); na água, a superfície
function groundAt(p) {
	const ph = GAME.world.physics;
	if (ph) {
		const top = p.y + 6;
		const y = ph.topAt(p.x, p.z, top);
		if (y > -Infinity && top - y <= 96) return new Vector3(p.x, Math.max(y, WATER_Y), p.z);
		if (p.y < WATER_Y + 40) return new Vector3(p.x, WATER_Y, p.z);
	}
	return new Vector3(p.x, p.y - 3, p.z);
}
function turn(v, deg) {
	const r = (deg * Math.PI) / 180;
	const c = Math.cos(r), s = Math.sin(r);
	return new Vector3(v.x * c - v.z * s, v.y, v.x * s + v.z * c);
}

function fx(name, params) {
	GAME.rbx.fx(name, params);
}

// dano (Fighters.Damage): alvo invisível = quem está em volta do ponto
function damage(attacker, target, amount, opts = {}) {
	if (!target) return 0;
	if (target.Dummy) {
		if (!attacker || attacker !== target.Caster || target.Removed) return 0;
		let total = 0;
		for (const e of enemies(attacker, target.Root.Position, MARKER_HIT)) total += damage(attacker, e, amount, { ...opts });
		return total;
	}
	if (!alive(target)) return 0;
	if (attacker && attacker !== target && !isHostile(attacker, target)) return 0;
	let amt = amount * (attacker && typeof attacker.DamageDealt === 'number' ? attacker.DamageDealt : 1) * (typeof target.DamageTaken === 'number' ? target.DamageTaken : 1);
	if (opts.Crit) amt *= 2;
	amt *= 0.9 + Math.random() * 0.2;
	const kb = opts.Knockback;
	const c = opts.Color;
	const dealt = GAME.combat.damage(attacker, target, amt, {
		kind: 'skill',
		crit: !!opts.Crit,
		silent: !!opts.NoText,
		color: c && c.r !== undefined ? '#' + c.ToHex() : undefined,
		vel: kb && kb.x !== undefined ? [kb.x, kb.y, kb.z] : undefined,
	});
	if (dealt > 0 && target.$rbx) fx('Hit', { Model: target.$rbx });
	return dealt;
}
function damageArea(attacker, pos, radius, amount, opts = {}) {
	const hits = [];
	for (const e of enemies(attacker, pos, radius)) {
		const o = { ...opts };
		if (opts.KnockbackPower) {
			let ax = e.body.x - pos.x, az = e.body.z - pos.z;
			const l = Math.hypot(ax, az);
			if (l < 0.1) {
				ax = 1;
				az = 0;
			} else {
				ax /= l;
				az /= l;
			}
			o.Knockback = new Vector3(ax * opts.KnockbackPower, opts.Lift ?? 18, az * opts.KnockbackPower);
		}
		damage(attacker, e, amount, o);
		hits.push(e);
	}
	return hits;
}

// empurrão com velocidade fixa por um instante (LinearVelocity do Roblox)
function push(f, v, duration) {
	if (!alive(f) || f.Dummy) return;
	const b = f.body;
	b.vx = v.x;
	b.vz = v.z;
	if (v.y) {
		b.vy = v.y;
		b.grounded = false;
	}
	f.pushVel = [v.x, v.y, v.z];
	f.pushUntil = now() + duration;
	f.knockUntil = Math.max(f.knockUntil || 0, now() + duration);
}
function face(f, pos) {
	if (!alive(f) || f.Dummy) return;
	const dx = pos.x - f.body.x, dz = pos.z - f.body.z;
	if (Math.hypot(dx, dz) > 0.1) f.yaw = Math.atan2(-dx, -dz);
}
function stop(f) {
	if (alive(f) && !f.Dummy) {
		f.body.vx = 0;
		f.body.vz = 0;
		if (f.ai) f.ai.holdUntil = now() + 0.2;
	}
}
// põe os pés num ponto do chão
function teleport(f, ground) {
	if (!alive(f) || f.Dummy) return;
	const b = f.body;
	b.x = ground.x;
	b.z = ground.z;
	b.y = ground.y + 0.2;
	b.vx = b.vy = b.vz = 0;
	f.visualY = b.y;
}
// põe o centro da raiz num ponto (olhando para look)
function placeRoot(f, p, look) {
	const b = f.body;
	b.x = p.x;
	b.z = p.z;
	b.y = p.y - f.groundOffset;
	f.visualY = b.y;
	b.vx = b.vy = b.vz = 0;
	if (look && Math.abs(look.x) + Math.abs(look.z) > 0.01) f.yaw = Math.atan2(-look.x, -look.z);
}
function standHeight(f) {
	return f.groundOffset + 0.2;
}
function isFrozen(f) {
	return !f.Dummy && f.stunned(now());
}
const ACTION_SOUND = { KO: 'KO', Eat: 'Eat', Howl: 'Roar', Roar: 'Roar', Spin: 'Whoosh', Dive: 'Whoosh' };
function setAction(f, action, duration, speed) {
	if (f.Dummy || !alive(f)) return;
	f.setAction(action, duration ?? 1, speed || 1);
	const s = ACTION_SOUND[action];
	if (s && GAME.audio) GAME.audio.sfx(s, f);
}
// tamanho (Titan Rage)
function scaleFighter(f, factor) {
	if (!alive(f) || f.Dummy) return;
	if (!f.baseScale) {
		f.baseScale = f.scale;
		f.baseGround = f.groundOffset;
		f.baseRadius = f.body.radius;
		f.baseHeight = f.body.height;
	}
	f.ScaleNow = factor;
	f.scale = f.baseScale * factor;
	f.mesh.scale.setScalar(f.scale);
	const dy = f.baseGround * factor - f.groundOffset;
	f.groundOffset = f.baseGround * factor;
	f.body.radius = f.baseRadius * Math.min(factor, 2);
	f.body.height = f.baseHeight * factor;
	f.body.step = Math.max(1.15, Math.min(3, f.groundOffset * 0.9));
	void dy;
}
function freezeFighter(f, seconds) {
	if (!alive(f) || f.Dummy) return;
	GAME.combat.freeze(f, seconds);
	fx('Freeze', { Model: f.Model, Duration: f.kind === 'champion' ? seconds * 0.35 : seconds, Kind: 'ice' });
}

// tabela "Fighters" que os Skills_*.lua recebem (só o que eles usam)
const FIGHTERS_SHIM = {
	Alive: alive,
	Hostile: isHostile,
	Fx: fx,
	Scale: scaleFighter,
	FlatDistance: (a, b) => flatDist(a, b),
	Enemies: enemies,
	Damage: damage,
	DamageArea: damageArea,
	Push: push,
	Face: face,
	Stop: stop,
	SetAction: setAction,
	Freeze: freezeFighter,
	IsFrozen: isFrozen,
	MARKER_HIT,
};

// ------------------------------------------------------------------ o kit
const FX_TIMES = {
	S_Ring: { Time: 0.6 },
	S_Orbit: { Duration: 1.5 },
	S_Prop: { Time: 0.6, Hold: 0.8 },
	S_Line: { Duration: 1.2 },
	S_Pillar: { Time: 0.25, Hold: 0.6 },
};
const DOT_COLOR = { Burn: C(255, 140, 40), Poison: C(150, 230, 70), Bleed: C(230, 50, 60), Shock: C(255, 235, 90), Curse: C(170, 90, 255) };

export class Kit {
	constructor(f, t, slot, id) {
		const rarity = (f.species && f.species.Rarity) || 'Rare';
		const tier = skillTier(rarity);
		const budget = tier.Budget[slot - 2] ?? tier.Budget[tier.Budget.length - 1];
		const info = SKILL_INFO[id];
		const el = ELEMENTS[elementsOf(f.speciesId)[0]];
		this.f = f;
		this.t = t;
		this.id = id;
		this.slot = slot;
		this.tier = tier;
		this.rarity = rarity;
		this.power = (f.atk || 10) * budget;
		this.A = tier.Area || 1;
		this.St = tier.Status || 1;
		this.color = info && info.Color ? Color3.fromHex(info.Color) : el && el.Color ? Color3.fromHex(el.Color) : Color3.new(1, 1, 1);
		this.size = clamp(f.Root.Size.z / 4, 0.6, 4);
		this.rng = new Random();
		this.aim = !!(t && t.Dummy && t.Caster === f);
		this.speed = this.aim ? CONFIG.SKILL_SPEED || 1 : 1;
		this.grabs = 0;
		this.risen = 0;
		this.air = this.aim && f.body.flying;
		this.airY = this.air ? rootPos(f).y : undefined;
		this.origin = null;
		this.anchored = false;
	}

	// ---- estado e espera
	alive() {
		return live(this.f);
	}
	ok() {
		return valid(this.f, this.t);
	}
	*wait(seconds) {
		yield $W((seconds || 0) * this.speed);
		return live(this.f);
	}
	*waitOk(seconds) {
		yield $W((seconds || 0) * this.speed);
		return valid(this.f, this.t);
	}
	R(r) {
		return r * this.A;
	}
	secs(s) {
		return s * this.St;
	}
	rand(a, b) {
		return this.rng.NextNumber(a, b);
	}
	later(seconds, fn) {
		delayCall((seconds || 0) * this.speed, () => {
			if (alive(this.f)) callLua(fn);
		});
	}
	real(target) {
		target = target || this.t;
		return !!target && !target.Dummy && alive(target);
	}

	// ---- 🎯 mira do jogador: o corpo só fica com a habilidade durante um movimento
	grab() {
		if (!this.aim) return;
		this.origin = this.origin || rootPos(this.f);
		this.grabs++;
		this.f.castHold = (this.f.castHold || 0) + 1;
	}
	release(all) {
		if (!this.aim || this.grabs <= 0) return;
		const n = all ? this.grabs : 1;
		this.grabs -= n;
		this.f.castHold = Math.max(0, (this.f.castHold || 0) - n);
	}
	held() {
		return !this.aim || this.grabs > 0;
	}
	hold() {
		if (!this.anchored) {
			this.anchored = true;
			this.f.body.kinematic = true;
		}
	}
	unhold() {
		if (this.anchored) {
			this.anchored = false;
			this.f.body.kinematic = false;
			this.f.body.vx = this.f.body.vy = this.f.body.vz = 0;
		}
	}
	cap(toPos, margin) {
		if (!this.aim) return toPos;
		const from = this.origin || rootPos(this.f);
		const d = flat(toPos.__sub(from));
		const max = Math.max(4, (CONFIG.SKILL_MOVE || 26) * this.A - (margin || 0));
		const m = d.Magnitude;
		if (m <= max) return toPos;
		const u = d.__div(m);
		const p = new Vector3(from.x + u.x * max, toPos.y, from.z + u.z * max);
		const t = this.t;
		if (t && t.Dummy && t.Root) t.Root.CFrame = CFrame.new(groundAt(p).__add(UP));
		return p;
	}
	dur(seconds) {
		return seconds === undefined || seconds === null ? undefined : seconds * this.speed;
	}

	// ---- posições
	me() {
		return rootPos(this.f);
	}
	feet() {
		return groundAt(rootPos(this.f));
	}
	tpos() {
		return this.t.Root.Position;
	}
	tground() {
		return groundAt(this.t.Root.Position);
	}
	dir(pos) {
		const me = rootPos(this.f);
		const to = pos || this.t.Root.Position;
		let d = flat(to.__sub(me));
		if (d.Magnitude < 0.05) {
			const [fx, fz] = this.f.forward();
			d = new Vector3(fx, 0, fz);
		}
		return d.Magnitude > 0.01 ? d.Unit : new Vector3(0, 0, -1);
	}
	dist(pos) {
		return flatDist(rootPos(this.f), pos || this.t.Root.Position);
	}
	mouth() {
		const f = this.f;
		const [fx, fz] = f.forward();
		const p = rootPos(f);
		const sy = f.Root.Size.y;
		return new Vector3(p.x + fx * f.body.radius, p.y + sy * 0.4, p.z + fz * f.body.radius);
	}
	clamp(pos) {
		const b = GAME.bounds();
		const m = 5;
		return new Vector3(clamp(pos.x, b.minX + m, b.maxX - m), pos.y, clamp(pos.z, b.minZ + m, b.maxZ - m));
	}
	around(center, radius, n, a0, jitter) {
		const list = [];
		for (let i = 1; i <= n; i++) {
			const a = (((a0 || 0) + ((i - 1) * 360) / n) * Math.PI) / 180;
			const r = radius * (jitter ? this.rng.NextNumber(1 - jitter, 1) : 1);
			list.push(groundAt(center.__add(new Vector3(Math.cos(a) * r, 0, Math.sin(a) * r))));
		}
		return list;
	}
	scatter(center, radius, n, firstCenter) {
		const list = [];
		for (let i = 1; i <= n; i++) {
			if (i === 1 && firstCenter) list.push(groundAt(center));
			else {
				const a = this.rng.NextNumber(0, Math.PI * 2);
				const r = Math.sqrt(this.rng.NextNumber()) * radius;
				list.push(groundAt(center.__add(new Vector3(Math.cos(a) * r, 0, Math.sin(a) * r))));
			}
		}
		return list;
	}
	lineOf(from, to, n) {
		const list = [];
		for (let i = 1; i <= n; i++) list.push(groundAt(from.Lerp(to, n === 1 ? 1 : i / n)));
		return list;
	}
	enemies(pos, radius) {
		return enemies(this.f, pos, radius);
	}
	victims(target) {
		target = target || this.t;
		if (!target) return [];
		if (target.Dummy) return enemies(this.f, target.Root.Position, MARKER_HIT);
		if (alive(target) && isHostile(this.f, target)) return [target];
		return [];
	}

	// ---- pose e efeitos
	pose(action, duration) {
		setAction(this.f, action, this.dur(duration), this.aim ? 1 / this.speed : undefined);
	}
	fx(name, params) {
		if (this.speed !== 1 && params && typeof params === 'object') {
			for (const key of ['Duration', 'Time']) if (typeof params[key] === 'number') params[key] *= this.speed;
		}
		fx(name, params);
	}
	paced(name, p) {
		const keys = FX_TIMES[name];
		if (keys && this.speed !== 1) for (const [key, def] of Object.entries(keys)) p[key] = (p[key] ?? def) * this.speed;
		return p;
	}
	face(pos) {
		pos = pos || this.t.Root.Position;
		if (this.held()) face(this.f, pos);
		else this.f.faceAt = { x: pos.x, z: pos.z, until: now() + 0.5 };
	}
	stop() {
		if (this.held()) stop(this.f);
	}
	tele(pos, radius, duration, color) {
		fx('Telegraph', { Position: pos, Radius: this.R(radius), Duration: this.dur(duration), Color: color || this.color });
	}
	impact(pos, radius, color, heavy) {
		fx('Impact', { Position: pos, Radius: this.R(radius), Color: color || this.color, Heavy: heavy });
	}
	shock(pos, radius, color, thick) {
		fx('Shockwave', { Position: pos, Radius: this.R(radius), Color: color || this.color, Thick: thick });
	}
	shake(pos, intensity, radius, duration) {
		fx('Shake', { Position: pos, Intensity: intensity, Radius: radius ?? 50, Duration: duration ?? 0.3 });
	}
	pop(text, pos, color, size) {
		const f = this.f;
		fx('S_Pop', { Position: pos || rootPos(f).__add(new Vector3(0, f.Root.Size.y + 3, 0)), Text: text, Color: color || this.color, Size: size });
	}
	burst(kind, pos, opts) {
		const p = { Kind: kind, Position: pos, Color: this.color, ...(opts || {}) };
		if (p.Radius) p.Radius = this.R(p.Radius);
		fx('S_Burst', p);
	}
	charge(duration, color, kind) {
		fx('S_Charge', { Model: this.f.Model, Duration: this.dur(duration), Color: color || this.color, Kind: kind });
	}
	prop(motif, opts) {
		fx('S_Prop', this.paced('S_Prop', { Motif: motif, Color: this.color, ...(opts || {}) }));
	}
	path(kind, from, to, opts) {
		fx('S_Line', this.paced('S_Line', { Kind: kind, From: from, To: to, Color: this.color, ...(opts || {}) }));
	}
	pillar(kind, pos, radius, opts) {
		fx('S_Pillar', this.paced('S_Pillar', { Kind: kind, Position: pos, Radius: this.R(radius), ...(opts || {}) }));
	}
	orbit(motif, opts) {
		fx('S_Orbit', this.paced('S_Orbit', { Model: this.f.Model, Motif: motif, Color: this.color, ...(opts || {}) }));
	}
	ringOut(motif, pos, r0, r1, opts) {
		fx('S_Ring', this.paced('S_Ring', { Motif: motif, Position: pos, R0: this.R(r0), R1: this.R(r1), Color: this.color, ...(opts || {}) }));
	}
	sky(kind, duration) {
		fx('S_Sky', { Kind: kind, Position: rootPos(this.f), Duration: this.dur(duration) });
	}
	aura(kind, duration, color) {
		fx('S_Aura', { Model: this.f.Model, Kind: kind, Duration: duration, Color: color || this.color });
	}
	mark(target, kind, duration, color) {
		if (target && target.Model) fx('S_Mark', { Model: target.Model, Kind: kind, Duration: duration, Color: color });
	}

	// ---- dano
	dmg(target, frac, opts) {
		if (!target || !alive(this.f)) return 0;
		return damage(this.f, target, this.power * frac, opts || { Color: this.color });
	}
	hit(frac, opts) {
		return this.dmg(this.t, frac, opts);
	}
	area(pos, radius, frac, opts) {
		if (!alive(this.f)) return [];
		let o = opts || {};
		if (!o.Color) o = { ...o, Color: this.color };
		return damageArea(this.f, pos, this.R(radius), this.power * frac, o);
	}
	inLine(origin, dir, length, width, frac, opts, onHit) {
		const list = [];
		dir = flat(dir);
		if (dir.Magnitude < 0.01) return list;
		dir = dir.Unit;
		width = this.R(width);
		for (const e of enemies(this.f)) {
			const rel = flat(rootPos(e).__sub(origin));
			const along = rel.Dot(dir);
			const side = rel.__sub(dir.__mul(along)).Magnitude;
			if (along > -2 && along < length + e.body.radius && side < width / 2 + e.body.radius) {
				list.push(e);
				if (frac && frac > 0) this.dmg(e, frac, opts ? { ...opts } : undefined);
				if (onHit) callLua(onHit, e);
			}
		}
		return list;
	}
	inCone(origin, dir, length, angle, frac, opts, onHit) {
		const list = [];
		dir = flat(dir);
		if (dir.Magnitude < 0.01) return list;
		dir = dir.Unit;
		length = this.R(length);
		const cosA = Math.cos((angle * Math.PI) / 180);
		for (const e of enemies(this.f)) {
			const rel = flat(rootPos(e).__sub(origin));
			const m = rel.Magnitude;
			if (m < length + e.body.radius && (m < 2 + e.body.radius || rel.__div(m).Dot(dir) > cosA)) {
				list.push(e);
				if (frac && frac > 0) this.dmg(e, frac, opts ? { ...opts } : undefined);
				if (onHit) callLua(onHit, e);
			}
		}
		return list;
	}
	knock(target, from, power, lift) {
		if (alive(target) && !target.Dummy) {
			let d = flat(rootPos(target).__sub(from));
			if (d.Magnitude > 0.1) d = d.Unit;
			else {
				const [fx, fz] = this.f.forward();
				d = new Vector3(fx, 0, fz);
			}
			push(target, d.__mul(power).__add(UP.__mul(lift ?? 15)), 0.2);
		}
	}
	pull(target, to, speed, duration) {
		if (alive(target) && !target.Dummy && target.kind !== 'champion') {
			const d = flat(to.__sub(rootPos(target)));
			if (d.Magnitude > 1.5) push(target, d.Unit.__mul(speed), duration ?? 0.2);
		}
	}
	launch(target, up) {
		if (alive(target) && !target.Dummy) push(target, UP.__mul(target.kind === 'champion' ? up * 0.15 : up), 0.22);
	}

	// ---- estados no alvo
	stun(target, seconds, mark, color) {
		seconds = this.secs(seconds);
		for (const v of this.victims(target)) {
			const s = v.kind === 'champion' ? seconds * 0.35 : seconds;
			GAME.combat.stun(v, s / (v.kind === 'champion' ? 0.4 : 1), mark || 'Dizzy');
			fx('S_Mark', { Model: v.Model, Kind: mark || 'Dizzy', Duration: s, Color: color });
		}
	}
	force(target, action, seconds) {
		for (const v of this.victims(target)) if (v.kind !== 'champion') setAction(v, action, seconds);
	}
	freeze(target, seconds) {
		for (const v of this.victims(target)) freezeFighter(v, this.secs(seconds));
	}
	slow(target, seconds, mult, mark) {
		seconds = this.secs(seconds);
		for (const v of this.victims(target)) {
			GAME.combat.slow(v, seconds, mult);
			fx('S_Mark', { Model: v.Model, Kind: mark || 'Slow', Duration: seconds });
		}
	}
	dot(target, seconds, frac, kind) {
		seconds = this.secs(seconds);
		const ticks = Math.max(1, Math.floor(seconds / 0.5));
		const per = (this.power * frac) / ticks;
		const f = this.f;
		const color = DOT_COLOR[kind || 'Burn'] || this.color;
		for (const v of this.victims(target)) {
			fx('S_Mark', { Model: v.Model, Kind: kind || 'Burn', Duration: seconds });
			spawnThread(
				(function* () {
					for (let i = 0; i < ticks; i++) {
						yield $W(0.5);
						if (!(alive(f) && alive(v))) return;
						damage(f, v, per, { Color: color });
					}
				})(),
			);
		}
	}
	curse(target, seconds, mult, mark) {
		seconds = this.secs(seconds);
		for (const v of this.victims(target)) {
			if (v.statusOn('curse', now())) continue;
			GAME.combat.curse(v, seconds, mult);
			fx('S_Mark', { Model: v.Model, Kind: mark || 'Curse', Duration: seconds });
		}
	}

	// ---- estados no próprio cachorro
	shield(seconds, reduce, kind, color) {
		const f = this.f;
		if (f.statusOn('shield', now())) return;
		GAME.combat.buff(f, 'shield', seconds, { reduce });
		fx('S_Aura', { Model: f.Model, Kind: kind || 'Shield', Duration: seconds, Color: color || this.color });
	}
	rage(seconds, mult, kind, color) {
		const f = this.f;
		if (f.statusOn('rage', now())) return;
		GAME.combat.buff(f, 'rage', seconds, { mult });
		fx('S_Aura', { Model: f.Model, Kind: kind || 'Rage', Duration: seconds, Color: color || this.color });
	}
	haste(seconds, mult, kind, color) {
		const f = this.f;
		if (f.statusOn('haste', now())) return;
		GAME.combat.buff(f, 'haste', seconds, { mult });
		fx('S_Aura', { Model: f.Model, Kind: kind || 'Haste', Duration: seconds, Color: color || this.color });
	}
	heal(frac) {
		const f = this.f;
		if (!alive(f)) return 0;
		const amount = Math.floor(f.maxHp * frac);
		GAME.combat.heal(f, amount);
		fx('S_Aura', { Model: f.Model, Kind: 'Heal', Duration: 1, Color: GREEN });
		return amount;
	}

	// ---- movimento
	*lunge(within) {
		const t = this.t;
		const gap = this.dist() - (t.Radius || 1) - this.f.body.radius - (within ?? 2);
		if (gap > 1.5) {
			const d = this.dir();
			const was = t.Dummy ? t.Root.Position : null;
			const real = clamp(gap / 100, 0.1, 0.3);
			yield* this.dash(this.me().__add(d.__mul(gap)), real / this.speed);
			if (was && t.Root.Position.__sub(was).Magnitude > 0.5 && (within ?? 2) > 3) {
				t.Root.CFrame = CFrame.new(groundAt(this.me().__add(d.__mul(within + this.f.body.radius))).__add(UP));
			}
		}
		return this.ok();
	}
	*approach(within, maxTime) {
		if (this.aim) return yield* this.lunge(within);
		const f = this.f, t = this.t;
		const start = sched.clock;
		while (valid(f, t) && sched.clock - start < maxTime) {
			const tp = rootPos(t);
			if (flatDist(rootPos(f), tp) - f.body.radius - (t.Radius || 1) <= within) break;
			if (!isFrozen(f)) {
				const d = flat(tp.__sub(rootPos(f)));
				const m = d.Magnitude || 1;
				const sp = f.species.Stats.Speed * f.speedMult(now()) * 1.7;
				f.body.vx = (d.x / m) * sp;
				f.body.vz = (d.z / m) * sp;
				face(f, tp);
			}
			yield $W(0.1);
		}
		stop(f);
		return valid(f, t);
	}
	*reach(range, maxTime) {
		if (this.aim) return yield* this.lunge(range);
		const t = this.t;
		if (t && this.dist() - (t.Radius || 1) - this.f.body.radius > range) return yield* this.approach(range, maxTime ?? 1);
		return this.ok();
	}
	sweep(hit, done) {
		if (!hit) return;
		const f = this.f;
		for (const e of enemies(f, rootPos(f), (hit.radius ?? 4) + f.body.radius)) {
			if (done.has(e)) continue;
			done.add(e);
			if (hit.frac && hit.frac > 0) this.dmg(e, hit.frac, hit.opts ? { ...hit.opts } : undefined);
			if (hit.on) callLua(hit.on, e);
		}
	}
	*dash(toPos, time, hit) {
		this.grab();
		const r = yield* this._dash(toPos, time * this.speed, hit);
		this.release();
		return r;
	}
	*_dash(toPos, time, hit) {
		if (this.air) return yield* this._swoop(toPos, 0, time, hit);
		const f = this.f;
		toPos = this.clamp(this.cap(toPos));
		const from = rootPos(f);
		const d = flat(toPos.__sub(from));
		const done = new Set();
		if (d.Magnitude < 0.5) return $M(live(f), done);
		face(f, from.__add(d));
		const v = d.__mul(1 / time);
		const t0 = sched.clock;
		while (sched.clock - t0 < time) {
			f.body.vx = v.x;
			f.body.vz = v.z;
			f.knockUntil = Math.max(f.knockUntil || 0, now() + 0.06);
			yield $W(0.04);
			if (!live(f)) return $M(false, done);
			this.sweep(hit, done);
		}
		stop(f);
		return $M(live(f), done);
	}
	*blink(toPos, steps, stepTime, hit) {
		this.grab();
		const r = yield* this._blink(toPos, steps, stepTime * this.speed, hit);
		this.release();
		return r;
	}
	*_blink(toPos, steps, stepTime, hit) {
		const f = this.f;
		toPos = this.clamp(this.cap(toPos));
		const from = rootPos(f);
		const d = flat(toPos.__sub(from));
		const done = new Set();
		for (let i = 1; i <= steps; i++) {
			if (!live(f)) return $M(false, done);
			const step = from.Lerp(toPos, i / steps);
			if (this.air) placeRoot(f, new Vector3(step.x, this.airY, step.z), d.Magnitude > 0.1 ? d : null);
			else teleport(f, groundAt(step));
			if (d.Magnitude > 0.1) face(f, rootPos(f).__add(d));
			this.sweep(hit, done);
			yield $W(stepTime);
		}
		return $M(live(f), done);
	}
	*leap(toPos, height, time, hit) {
		this.grab();
		const r = yield* this._leap(toPos, height, time * this.speed, hit);
		this.release();
		return r;
	}
	*_leap(toPos, height, time, hit) {
		if (this.air) return yield* this._swoop(toPos, height * 0.5, time, hit);
		const f = this.f;
		toPos = this.clamp(this.cap(toPos));
		const start = groundAt(rootPos(f));
		const land = groundAt(toPos);
		const stand = standHeight(f);
		const look = flat(land.__sub(start));
		const done = new Set();
		const t0 = sched.clock;
		const wasKin = f.body.kinematic;
		f.body.kinematic = true;
		try {
			while (true) {
				const u = Math.min(1, (sched.clock - t0) / time);
				const p = start.Lerp(land, u).__add(new Vector3(0, stand + 4 * height * u * (1 - u), 0));
				placeRoot(f, p, look.Magnitude > 0.1 ? look : null);
				this.sweep(hit, done);
				if (u >= 1) break;
				yield $W(0);
				if (!live(f)) return $M(false, done);
			}
		} finally {
			f.body.kinematic = wasKin || this.anchored;
			if (!f.body.kinematic) f.body.grounded = true;
		}
		return $M(live(f), done);
	}
	*_swoop(toPos, dip, time, hit) {
		const f = this.f;
		const p = this.clamp(this.cap(toPos));
		const from = rootPos(f);
		const to = new Vector3(p.x, this.airY ?? from.y, p.z);
		const floor = groundAt(from).y + standHeight(f) + 1;
		dip = clamp(dip || 0, 0, Math.max(0, Math.min(from.y, to.y) - floor));
		const look = flat(to.__sub(from));
		const done = new Set();
		const t0 = sched.clock;
		const wasKin = f.body.kinematic;
		f.body.kinematic = true;
		try {
			while (true) {
				const u = Math.min(1, (sched.clock - t0) / time);
				const e = u * u * (3 - 2 * u);
				placeRoot(f, from.Lerp(to, e).__sub(UP.__mul(4 * dip * u * (1 - u))), look.Magnitude > 0.1 ? look : null);
				this.sweep(hit, done);
				if (u >= 1) break;
				yield $W(0);
				if (!live(f)) return $M(false, done);
			}
		} finally {
			f.body.kinematic = wasKin || this.anchored;
		}
		return $M(live(f), done);
	}
	*glide(toRootPos, time, hit, look) {
		this.grab();
		const r = yield* this._glide(this.cap(toRootPos), time * this.speed, hit, look);
		this.release();
		return r;
	}
	*_glide(toRootPos, time, hit, look) {
		const f = this.f;
		const from = rootPos(f);
		const done = new Set();
		const dir = look || flat(toRootPos.__sub(from));
		const t0 = sched.clock;
		const wasKin = f.body.kinematic;
		f.body.kinematic = true;
		try {
			while (true) {
				const u = Math.min(1, (sched.clock - t0) / time);
				const e = u * u * (3 - 2 * u);
				placeRoot(f, from.Lerp(toRootPos, e), dir.Magnitude > 0.1 ? dir : null);
				this.sweep(hit, done);
				if (u >= 1) break;
				yield $W(0);
				if (!live(f)) return $M(false, done);
			}
		} finally {
			f.body.kinematic = wasKin || this.anchored;
		}
		return $M(live(f), done);
	}
	*rise(height, time) {
		this.grab();
		this.risen++;
		let goal;
		if (this.air) goal = rootPos(this.f).__add(new Vector3(0, Math.min(height, 8), 0));
		else goal = groundAt(rootPos(this.f)).__add(new Vector3(0, standHeight(this.f) + height, 0));
		const r = yield* this.glide(goal, time);
		this.hold();
		return r;
	}
	*land(pos, time, hit) {
		const f = this.f;
		const p = this.clamp(this.cap(pos || rootPos(f)));
		const goal = this.air ? new Vector3(p.x, this.airY, p.z) : groundAt(p).__add(new Vector3(0, standHeight(f), 0));
		const r = yield* this.glide(goal, time ?? 0.25, hit);
		if (this.risen > 0) {
			this.risen--;
			if (this.risen === 0) this.unhold();
			this.release();
		}
		return r;
	}
	*circle(center, radius, laps, time, hit) {
		this.grab();
		const r = yield* this._circle(this.cap(center, radius), radius, laps, time * this.speed, hit);
		this.release();
		return r;
	}
	*_circle(center, radius, laps, time, hit) {
		const f = this.f;
		const rel = flat(rootPos(f).__sub(center));
		const a0 = rel.Magnitude > 0.1 ? Math.atan2(rel.z, rel.x) : 0;
		const steps = Math.max(8, Math.floor(time / 0.04));
		const perLap = Math.max(1, Math.floor(steps / Math.max(laps, 0.01)));
		let done = new Set();
		const wasKin = f.body.kinematic;
		f.body.kinematic = true;
		try {
			for (let i = 1; i <= steps; i++) {
				if (!live(f)) return $M(false, done);
				const a = a0 + (i / steps) * laps * Math.PI * 2;
				const tangent = new Vector3(-Math.sin(a), 0, Math.cos(a));
				const q = this.clamp(center.__add(new Vector3(Math.cos(a) * radius, 0, Math.sin(a) * radius)));
				if (this.air) placeRoot(f, new Vector3(q.x, this.airY, q.z), tangent);
				else placeRoot(f, groundAt(q).__add(new Vector3(0, standHeight(f), 0)), tangent);
				if (hit) {
					if (hit.every && i % perLap === 0) done = new Set();
					this.sweep(hit, done);
				}
				yield $W(time / steps);
			}
		} finally {
			f.body.kinematic = wasKin || this.anchored;
		}
		return $M(live(f), done);
	}
	tp(pos) {
		const f = this.f;
		if (!live(f)) return false;
		this.grab();
		const p = this.clamp(this.cap(pos));
		if (this.air) placeRoot(f, new Vector3(p.x, this.airY, p.z), this.t ? flat(this.t.Root.Position.__sub(p)) : null);
		else {
			teleport(f, groundAt(p));
			if (this.t) face(f, this.t.Root.Position);
		}
		this.release();
		return true;
	}
	behind(dist) {
		const f = this.f, t = this.t;
		const d = this.dir();
		this.grab();
		const p = this.clamp(this.cap(t.Root.Position.__add(d.__mul((t.Radius || 1) + f.body.radius + (dist ?? 2)))));
		if (this.air) placeRoot(f, new Vector3(p.x, this.airY, p.z), flat(t.Root.Position.__sub(p)));
		else {
			teleport(f, groundAt(p));
			face(f, t.Root.Position);
		}
		this.release();
		return live(f);
	}

	// ---- tiros, chuva, áreas, criaturas
	landHit(p, o, target) {
		if (!alive(this.f)) return;
		const opts = o.opts ? { ...o.opts } : { Color: o.color || this.color };
		if (o.radius) {
			const hits = damageArea(this.f, p, this.R(o.radius), this.power * (o.frac ?? 0.2), opts);
			if (o.on) for (const e of hits) callLua(o.on, e);
			return;
		}
		let best = null, bestD = 3;
		if (target && alive(target) && !target.Dummy && isHostile(this.f, target)) {
			const d = flatDist(rootPos(target), p) - target.body.radius;
			if (d < 4) {
				best = target;
				bestD = d;
			}
		}
		if (!best) {
			for (const e of enemies(this.f, p, 3)) {
				const d = flatDist(rootPos(e), p) - e.body.radius;
				if (d < bestD) {
					best = e;
					bestD = d;
				}
			}
		}
		if (best) {
			this.dmg(best, o.frac ?? 0.2, opts);
			if (o.on) callLua(o.on, best);
		}
	}
	shoot(motif, o) {
		o = o || {};
		const f = this.f, t = this.t;
		const count = o.count || (o.points && o.points.length) || 1;
		const from = o.from || this.mouth();
		const [lx, lz] = f.forward();
		const aim = t ? t.Root.Position : from.__add(new Vector3(lx * 30, 0, lz * 30));
		let base = flat(aim.__sub(from));
		const dist = Math.max(4, base.Magnitude);
		base = base.Magnitude > 0.01 ? base.Unit : new Vector3(lx, 0, lz);
		const speed = (o.speed || 70) / this.speed;
		const gap = (o.gap || 0) * this.speed;
		const points = [], times = [], delays = [];
		let last = 0;
		for (let i = 1; i <= count; i++) {
			let p;
			if (o.points) p = o.points[i - 1];
			else {
				const ang = count > 1 ? (o.spread || 0) * ((i - 1) / (count - 1) - 0.5) : 0;
				p = groundAt(from.__add(turn(base, ang).__mul(dist)));
				if (o.homing && t && !t.Dummy && i === 1 && count === 1) p = t.Root.Position;
			}
			points.push(p);
			times.push(clamp(p.__sub(from).Magnitude / speed, 0.08, 2.5));
			delays.push((i - 1) * gap);
			last = Math.max(last, delays[i - 1] + times[i - 1] * (o.back ? 2 : 1));
		}
		fx('S_Shot', {
			Model: f.Model,
			From: from,
			Points: points,
			Times: times,
			Delays: delays,
			Motif: motif,
			Size: (o.size || 1) * Math.sqrt(this.size),
			Color: o.color || this.color,
			Color2: o.color2,
			Arc: o.arc,
			Spin: o.spin,
			Trail: o.trail,
			Impact: o.impact,
			Target: o.homing && t && !t.Dummy ? t.Model : undefined,
			Back: o.back,
			Radius: o.radius ? this.R(o.radius) : undefined,
		});
		for (let i = 0; i < count; i++) {
			delayCall(delays[i] + times[i], () => {
				let p = points[i];
				if (o.homing && t && alive(t) && !t.Dummy) p = t.Root.Position;
				this.landHit(p, o, t);
			});
			if (o.back) {
				delayCall(delays[i] + times[i] * 1.6, () => {
					const mid = points[i].Lerp(rootPos(f), 0.4);
					const o2 = { ...o, frac: o.backFrac ?? o.frac ?? 0.2, radius: o.radius || 4, on: undefined };
					this.landHit(mid, o2, null);
				});
			}
		}
		return last;
	}
	rain(motif, points, o) {
		o = o || {};
		const fall = (o.fall ?? 0.6) * this.speed;
		const gap = (o.gap ?? 0.12) * this.speed;
		const radius = o.radius || 5;
		fx('S_Rain', {
			Motif: motif,
			Points: points,
			Fall: fall,
			Gap: gap,
			Height: o.height || 40,
			Size: (o.size || 1) * Math.sqrt(this.size),
			Color: o.color || this.color,
			Color2: o.color2,
			Impact: o.impact,
			Radius: this.R(radius),
			Tele: o.tele !== false,
			Spin: o.spin,
		});
		points.forEach((p, i) => {
			delayCall(i * gap + fall, () => this.landHit(p, { radius, frac: o.frac ?? 0.15, opts: o.opts, on: o.on, color: o.color }, null));
		});
		return (points.length - 1) * gap + fall;
	}
	zone(kind, center, radius, duration, frac, o) {
		o = o || {};
		const f = this.f;
		duration *= this.speed;
		const every = (o.every || 0.5) * this.speed;
		const ticks = Math.max(1, Math.floor(duration / every));
		const r = this.R(radius);
		fx('S_Zone', { Kind: kind, Position: center, Radius: r, Duration: duration, Color: o.color || this.color });
		const self = this;
		spawnThread(
			(function* () {
				for (let i = 0; i < ticks; i++) {
					yield $W(every);
					if (!alive(f)) return;
					if (frac && frac > 0) {
						const opts = o.opts ? { ...o.opts } : { Color: o.color || self.color };
						const hits = damageArea(f, center, r, (self.power * frac) / ticks, opts);
						if (o.on) for (const e of hits) callLua(o.on, e);
					} else if (o.on) {
						for (const e of enemies(f, center, r)) callLua(o.on, e);
					}
				}
			})(),
		);
	}
	summon(kind, o) {
		o = o || {};
		const f = this.f, t = this.t;
		const count = o.count || 3;
		let points = o.points;
		if (!points) {
			points = [];
			const [lx, lz] = f.forward();
			const center = t ? t.Root.Position : rootPos(f).__add(new Vector3(lx * 20, 0, lz * 20));
			for (let i = 1; i <= count; i++) {
				const a = (((i - 1) * 360) / count + this.rng.NextNumber(-20, 20)) * (Math.PI / 180);
				const r = count > 1 ? this.rng.NextNumber(1, 4) : 0;
				points.push(groundAt(center.__add(new Vector3(Math.cos(a) * r, 0, Math.sin(a) * r))));
			}
		}
		const time = (o.time ?? 0.8) * this.speed;
		const gap = (o.gap ?? 0.15) * this.speed;
		fx('S_Summon', {
			Kind: kind,
			Model: f.Model,
			From: o.from || rootPos(f),
			Points: points,
			Time: time,
			Gap: gap,
			Color: o.color || this.color,
			Size: (o.size || 1) * Math.sqrt(this.size),
			Path: o.path,
			Target: t && !t.Dummy ? t.Model : undefined,
		});
		points.forEach((p, i) => {
			delayCall(i * gap + time, () => this.landHit(p, { radius: o.radius || 4, frac: o.frac ?? 0.15, opts: o.opts, on: o.on, color: o.color }, null));
		});
		return (points.length - 1) * gap + time;
	}
	*beam(kind, o) {
		o = o || {};
		const f = this.f;
		const length = o.length || 30;
		const width = o.width || 4;
		const time = (o.time ?? 0.8) * this.speed;
		const ticks = o.ticks || 3;
		const from = o.from || this.mouth();
		const dir = o.dir || this.dir();
		fx('S_Beam', { Kind: kind, Model: f.Model, From: from, To: from.__add(dir.__mul(length)), Width: this.R(width), Duration: time, Color: o.color || this.color, Color2: o.color2, Sweep: o.sweep });
		for (let i = 1; i <= ticks; i++) {
			if (!live(f)) return false;
			yield $W(time / ticks);
			let d = dir;
			if (o.sweep) d = turn(dir, o.sweep * (i / ticks - 0.5) * 2);
			this.inLine(flat(rootPos(f)), d, length, width, (o.frac ?? 0.3) / ticks, o.opts, o.on);
		}
		return live(f);
	}
	*breath(kind, o) {
		o = o || {};
		const f = this.f, t = this.t;
		const length = o.length || 16;
		const angle = o.angle || 30;
		const time = (o.time ?? 1) * this.speed;
		const ticks = o.ticks || 4;
		fx('S_Cone', { Kind: kind, Model: f.Model, Length: this.R(length), Angle: angle, Duration: time, Color: o.color || this.color });
		for (let i = 0; i < ticks; i++) {
			yield $W(time / ticks);
			if (!live(f)) return false;
			if (t && valid(f, t) && !this.aim) face(f, rootPos(t));
			const [lx, lz] = f.forward();
			const look = this.aim ? this.dir() : new Vector3(lx, 0, lz);
			this.inCone(flat(rootPos(f)), look, length, angle, (o.frac ?? 0.3) / ticks, o.opts, o.on);
		}
		return live(f);
	}
	wave(kind, o) {
		o = o || {};
		const f = this.f;
		const from = o.from || this.feet();
		const dir = o.dir || this.dir();
		const length = o.length || 30;
		const width = o.width || 8;
		const speed = (o.speed || 50) / this.speed;
		if (!o.silent) fx('S_Wave', { Kind: kind, Position: from, Dir: dir, Length: length, Width: this.R(width), Speed: speed, Color: o.color || this.color });
		const list = this.inLine(flat(from), dir, length, width, 0);
		for (const e of list) {
			const along = flat(rootPos(e).__sub(from)).Dot(dir);
			delayCall(Math.max(0, along) / speed, () => {
				if (alive(f) && alive(e)) {
					this.dmg(e, o.frac ?? 0.3, o.opts ? { ...o.opts } : undefined);
					if (o.on) callLua(o.on, e);
				}
			});
		}
		return length / speed;
	}
}

// ------------------------------------------------------------------ alvo invisível (a setinha do jogador)
class Marker {
	constructor(caster, pos, workspace) {
		this.Dummy = true;
		this.Caster = caster;
		this.Kind = 'dummy';
		this.Radius = 1;
		this.Removed = false;
		this.Dead = false;
		this.DamageTaken = 1;
		this.DamageDealt = 1;
		this.Stats = { Speed: 0, Atk: 0, MaxHP: 1, Power: 0 };
		const model = Instance.new('Model');
		model.Name = 'AlvoDoPoder';
		const root = Instance.new('Part');
		root.Name = 'HumanoidRootPart';
		root.Size = new Vector3(2, 2, 2);
		root.Transparency = 1;
		root.Anchored = true;
		root.CanCollide = false;
		root.CFrame = CFrame.new(pos.__add(UP));
		root.Parent = model;
		model.PrimaryPart = root;
		model.Parent = workspace;
		this.Model = model;
		this.Root = root;
		this.Humanoid = { Health: 1, MaxHealth: 1, HipHeight: 0, WalkSpeed: 0 };
	}
	remove() {
		if (this.Removed) return;
		this.Removed = true;
		this.Dead = true;
		try {
			this.Model.Destroy();
		} catch (e) {
			reportError(e, 'marker');
		}
	}
}

// ------------------------------------------------------------------ o gerenciador (recargas, desbloqueio, IA)
export class Skills {
	constructor(game) {
		GAME = game;
		this.game = game;
		installLuaView();
		this.specials = {};
		const kit = {
			Ids: {},
			Ground: groundAt,
			Turn: turn,
			def: (specials, id, slot, fn) => {
				kit.Ids[id] = slot;
				specials[id] = { slot, fn };
			},
		};
		game.rbx.setSkillKit(kit);
		game.rbx.loadSkills(this.specials, FIGHTERS_SHIM);
		this.count = Object.keys(this.specials).length;
		this.runs = new Set();
	}

	idsOf(f) {
		return (SKILLS[f.speciesId] || []).map((s) => s.Id);
	}

	// k = 0 (tecla 2), 1 (tecla 3), 2 (tecla 4 = Especial)
	cooldownFor(f, k) {
		const tier = skillTier(f.species.Rarity);
		if (k >= 2) return (tier.Cooldown[1] ?? tier.Cooldown[0] ?? 12) * (CONFIG.SPECIAL_COOLDOWN_MULT || 1.5);
		return tier.Cooldown[k] ?? tier.Cooldown[0];
	}

	cooldownOf(f, k) {
		const c = f.skillCd && f.skillCd[k];
		if (!c) return { left: 0, dur: 0 };
		return { left: Math.max(0, c.until - this.game.time), dur: c.dur };
	}

	// motivo de não poder usar (ou null)
	lockReason(f, k) {
		const id = this.idsOf(f)[k];
		if (!id || !this.specials[id]) return 'none';
		if (f.kind === 'player') {
			const need = powerUnlockLevel(k);
			if ((f.level || 1) < need) return `🔒 This power unlocks at Lv.${need}!`;
			if (k >= 2 && !hasSupreme(f.species.Rarity)) return '👑 The SPECIAL power unlocks at EPIC dogs and above!';
		}
		return null;
	}

	canUse(f, k) {
		if (!f || f.dead || f.stunned(this.game.time)) return false;
		if (this.lockReason(f, k)) return false;
		if (this.cooldownOf(f, k).left > 0) return false;
		if ((f.nextCast || 0) > this.game.time) return false;
		if (f.kind !== 'player' && f.casting > 0) return false;
		return true;
	}

	// ponto da setinha: até POWER_REACH do cachorro, no chão
	powerPoint(f, x, y, z) {
		const ox = f.x, oz = f.z;
		let px = x, pz = z;
		const dx = px - ox, dz = pz - oz;
		const d = Math.hypot(dx, dz);
		const reach = CONFIG.POWER_REACH || 55;
		if (d > reach) {
			px = ox + (dx / d) * reach;
			pz = oz + (dz / d) * reach;
		}
		if (d < 0.5) {
			const [fx, fz] = f.forward();
			px = ox + fx * 18;
			pz = oz + fz * 18;
		}
		const b = this.game.bounds();
		px = clamp(px, b.minX + 5, b.maxX - 5);
		pz = clamp(pz, b.minZ + 5, b.maxZ - 5);
		return groundAt(new Vector3(px, Math.max(y, f.y + 1) + 30, pz));
	}

	// solta a habilidade k; alvo = um cachorro (IA) ou o ponto (x, y, z) (jogador)
	use(f, k, x, y, z, target) {
		const id = this.idsOf(f)[k];
		const def = id && this.specials[id];
		if (!def) return false;
		const game = this.game;
		const dur = this.cooldownFor(f, k) * (f.kind === 'player' ? 1 : 0.85 + Math.random() * 0.35);
		f.skillCd = f.skillCd || {};
		f.skillCd[k] = { until: game.time + dur, dur };
		f.nextCast = game.time + (CONFIG.SKILL_GAP || 0.25);
		let marker = null;
		let t = target && !target.dead ? target : null;
		if (!t) {
			marker = new Marker(f, this.powerPoint(f, x, y, z), game.rbx.workspace);
			t = marker;
		}
		// ✨ brilho na cor da raridade (o poder sai na hora)
		const rc = RARITY[f.species.Rarity] && RARITY[f.species.Rarity].Color;
		const color = rc ? Color3.fromHex(rc) : Color3.new(1, 1, 1);
		const feet = new Vector3(f.body.x, f.body.y, f.body.z);
		fx('Shockwave', { Position: feet, Radius: k >= 2 ? 12 : 7, Color: color, Thick: k >= 2 });
		if (k >= 2) fx('Shake', { Position: rootPos(f), Intensity: 0.5, Radius: 40, Duration: 0.3 });
		fx('SpecialName', { Model: f.Model, Name: id });
		f.casting = (f.casting || 0) + 1;
		const kit = new Kit(f, t, def.slot, id);
		const run = { f, kit, marker, id };
		this.runs.add(run);
		const self = this;
		spawnThread(
			(function* () {
				try {
					const r = def.fn(kit);
					if (isGen(r)) yield* r;
				} catch (e) {
					reportError(e, id);
				} finally {
					self.finish(run);
				}
			})(),
		);
		return true;
	}

	finish(run) {
		if (!this.runs.has(run)) return;
		this.runs.delete(run);
		const { f, kit, marker } = run;
		try {
			kit.unhold();
			kit.release(true);
		} catch (e) {
			reportError(e, 'finish');
		}
		f.casting = Math.max(0, (f.casting || 1) - 1);
		if (f.casting === 0) f.castHold = 0;
		if (marker) marker.remove();
	}

	// jogador apertou 2/3/4: mira = ponto da setinha
	tryPlayer(f, k, aim) {
		const reason = this.lockReason(f, k);
		if (reason) {
			if (reason !== 'none') this.game.toast(reason, 'erro');
			return false;
		}
		if (!this.canUse(f, k)) return false;
		return this.use(f, k, aim.x, aim.y, aim.z, null);
	}

	// IA: qual habilidade usar agora (ou -1)
	pick(f) {
		const ids = this.idsOf(f);
		const list = [];
		for (let k = 0; k < ids.length; k++) if (this.canUse(f, k)) list.push(k);
		if (!list.length) return -1;
		return list[Math.floor(Math.random() * list.length)];
	}

	// troca de ilha: para tudo
	clear() {
		for (const run of [...this.runs]) {
			run.kit.f.casting = 0;
			this.finish(run);
		}
	}
}

void SPECIES;
