// Inteligência dos cachorros selvagens (igual ao jogo do Roblox): passeiam perto de casa, ficam BRAVOS e atacam
// quem chega perto (vários ao mesmo tempo, até AGGRO_MAX), perseguem até AGGRO_LEASH e voltam para casa.
// Quem morde chega perto e faz o combo (patada, patada, mordida); quem atira fica a meia distância rodeando.
import { CONFIG } from '../data/jogo.js';
import { hostile } from './combate.js';
import { angleDiff, clamp } from '../core/util.js';
import { WATER_Y } from '../world/fisica.js';

const C = CONFIG;

export function initAI(f, homeX, homeZ, opts = {}) {
	f.ai = {
		mode: 'idle',
		homeX,
		homeZ,
		homeR: opts.homeR || 28,
		goal: null,
		until: 0,
		nextAttack: 0,
		nextSkill: 4 + Math.random() * 6,
		strafe: Math.random() < 0.5 ? -1 : 1,
		strafeUntil: 0,
		detour: 0,
		detourUntil: 0,
		champion: !!opts.champion,
		aggroRange: opts.champion ? C.AGGRO_CHAMPION_RANGE : C.AGGRO_RANGE,
	};
}

function attackersOn(game, target) {
	let n = 0;
	for (const o of game.fighters) if (o.ai && o.target === target && !o.dead) n++;
	return n;
}

function moveToward(f, tx, tz, speed, dt, stopAt = 0) {
	let dx = tx - f.x, dz = tz - f.z;
	const dist = Math.hypot(dx, dz);
	if (dist <= stopAt || dist < 0.05) {
		f.body.vx *= 0.7;
		f.body.vz *= 0.7;
		return dist;
	}
	dx /= dist;
	dz /= dist;
	// desvia se bateu na parede há pouco
	const ai = f.ai;
	if (ai.detourUntil > f._now) {
		const a = ai.detour;
		const c = Math.cos(a), s = Math.sin(a);
		const rx = dx * c - dz * s, rz = dx * s + dz * c;
		dx = rx;
		dz = rz;
	}
	const k = 1 - Math.exp(-dt * 8);
	f.body.vx += (dx * speed - f.body.vx) * k;
	f.body.vz += (dz * speed - f.body.vz) * k;
	const want = Math.atan2(-dx, -dz);
	f.yaw += angleDiff(f.yaw, want) * Math.min(1, dt * 10);
	return dist;
}

function face(f, tx, tz, dt, rate = 12) {
	const want = Math.atan2(-(tx - f.x), -(tz - f.z));
	f.yaw += angleDiff(f.yaw, want) * Math.min(1, dt * rate);
	return Math.abs(angleDiff(f.yaw, want));
}

export function updateAI(game, f, dt, now) {
	const ai = f.ai;
	if (!ai || f.dead) return;
	f._now = now;
	const body = f.body;
	// atordoado/congelado/empurrado: sem controle
	if (f.stunned(now)) {
		body.vx *= 0.8;
		body.vz *= 0.8;
		return;
	}
	if (f.knockUntil > now) {
		const k = Math.exp(-dt * 3);
		body.vx *= k;
		body.vz *= k;
		return;
	}
	if (f.casting > 0) return;
	if (body.hitWall) {
		body.hitWall = false;
		if (ai.detourUntil < now) {
			ai.detour = (Math.random() < 0.5 ? -1 : 1) * (0.9 + Math.random() * 0.6);
			ai.detourUntil = now + 0.6;
		}
	}
	const speedBase = f.species.Stats.Speed * f.speedMult(now);
	// ---- escolhe alvo
	let t = f.target;
	if (t && (t.dead || !hostile(f, t))) t = f.target = null;
	const homeDist = Math.hypot(f.x - ai.homeX, f.z - ai.homeZ);
	if (t) {
		const leash = ai.champion ? 70 : C.AGGRO_LEASH;
		if (homeDist > leash || Math.hypot(t.x - ai.homeX, t.z - ai.homeZ) > leash + 20 || game.isSafe(t)) {
			f.target = t = null;
			f.aggroOn = null;
			ai.mode = 'return';
		}
	}
	if (!t) {
		// alguém bateu nele: revida
		if (f.aggroOn && !f.aggroOn.dead && hostile(f, f.aggroOn) && !game.isSafe(f.aggroOn)) t = f.target = f.aggroOn;
		else if (now > (ai.nextLook || 0)) {
			ai.nextLook = now + 0.3 + Math.random() * 0.2;
			let best = null, bestD = ai.aggroRange;
			for (const o of game.fighters) {
				if (!hostile(f, o) || o.ai) continue;
				if (game.isSafe(o)) continue;
				const d = Math.hypot(o.x - f.x, o.z - f.z);
				if (d < bestD && Math.abs(o.y - f.y) < 25 && attackersOn(game, o) < C.AGGRO_MAX) {
					best = o;
					bestD = d;
				}
			}
			if (best) {
				t = f.target = best;
				// "❗" + rosnado ao ver o jogador
				game.marks && game.marks.add(f, 'Alert', 1.1);
				f.setAction('Roar', 0.5);
				ai.nextAttack = now + 0.6;
			}
		}
	}
	// ---- luta
	if (t) {
		ai.mode = 'fight';
		const dist = Math.hypot(t.x - f.x, t.z - f.z);
		const reach = C.MELEE_REACH + f.body.radius + t.body.radius - 0.5;
		// habilidade de vez em quando
		if (now > ai.nextSkill && dist < 26 && game.skills) {
			const k = game.skills.pick(f);
			if (k >= 0) {
				ai.nextSkill = now + 7 + Math.random() * 6;
				face(f, t.x, t.z, 1, 1);
				game.skills.use(f, k, t.x, t.y, t.z, t);
				return;
			}
			ai.nextSkill = now + 1;
		}
		if (f.shot) {
			// atirador: fica a meia distância, rodeando, e atira
			const want = C.SHOT_AI_RANGE * 0.8;
			if (now > ai.strafeUntil) {
				ai.strafe = -ai.strafe;
				ai.strafeUntil = now + 1.5 + Math.random() * 2;
			}
			const dx = (t.x - f.x) / (dist || 1), dz = (t.z - f.z) / (dist || 1);
			let mx = 0, mz = 0;
			if (dist > want + 4) {
				mx = dx;
				mz = dz;
			} else if (dist < want - 6) {
				mx = -dx;
				mz = -dz;
			}
			mx += -dz * ai.strafe * 0.7;
			mz += dx * ai.strafe * 0.7;
			const n = Math.hypot(mx, mz) || 1;
			const k = 1 - Math.exp(-dt * 6);
			body.vx += ((mx / n) * speedBase * 0.75 - body.vx) * k;
			body.vz += ((mz / n) * speedBase * 0.75 - body.vz) * k;
			face(f, t.x, t.z, dt, 10);
			if (now > ai.nextAttack && dist < C.SHOT_AI_RANGE + 6) {
				const cd = game.combat.shoot(f, t.x, t.y + t.body.height * 0.5, t.z);
				ai.nextAttack = now + cd;
			}
		} else {
			if (dist > reach) {
				moveToward(f, t.x, t.z, speedBase, dt, reach * 0.8);
			} else {
				body.vx *= 0.6;
				body.vz *= 0.6;
				const off = face(f, t.x, t.z, dt, 12);
				if (now > ai.nextAttack && off < 0.6) {
					const gap = game.combat.melee(f, t.x, t.z);
					// selvagem um pouco mais devagar que o jogador (dá tempo de reagir)
					ai.nextAttack = now + gap + 0.25 + Math.random() * 0.35 + (f.combo === 3 ? 0.6 : 0);
				}
			}
		}
		return;
	}
	// ---- sem alvo: volta para casa ou passeia
	if (ai.mode === 'return') {
		if (moveToward(f, ai.homeX, ai.homeZ, speedBase * 0.8, dt, 4) <= 4) ai.mode = 'idle';
		return;
	}
	if (ai.mode === 'walk' && ai.goal) {
		const d = moveToward(f, ai.goal[0], ai.goal[1], speedBase * 0.42, dt, 1.5);
		if (d <= 1.5 || now > ai.until) {
			ai.mode = 'idle';
			ai.until = now + 2 + Math.random() * 5;
		}
		return;
	}
	// parado
	body.vx *= 0.8;
	body.vz *= 0.8;
	if (now > ai.until) {
		const ph = game.world.physics;
		for (let i = 0; i < 6; i++) {
			const a = Math.random() * Math.PI * 2, r = Math.random() * ai.homeR;
			const gx = ai.homeX + Math.cos(a) * r, gz = ai.homeZ + Math.sin(a) * r;
			const gy = ph ? ph.topAt(gx, gz, f.y + 6) : 0;
			if (gy > WATER_Y + 0.2 && Math.abs(gy - f.y) < 8) {
				ai.goal = [gx, gz];
				ai.mode = 'walk';
				ai.until = now + 8;
				break;
			}
		}
		if (ai.mode !== 'walk') ai.until = now + 2;
	}
}

// empurra cachorros que ficaram um em cima do outro
export function separate(fighters, dt) {
	for (let i = 0; i < fighters.length; i++) {
		const a = fighters[i];
		if (a.dead) continue;
		for (let j = i + 1; j < fighters.length; j++) {
			const b = fighters[j];
			if (b.dead) continue;
			const dx = b.x - a.x, dz = b.z - a.z;
			const min = (a.body.radius + b.body.radius) * 0.9;
			const d2 = dx * dx + dz * dz;
			if (d2 < min * min && d2 > 1e-6 && Math.abs(a.y - b.y) < 3) {
				const d = Math.sqrt(d2);
				const push = clamp((min - d) * 6, 0, 30) * dt;
				const nx = dx / d, nz = dz / d;
				const wa = a.kind === 'player' ? 0.3 : 0.5, wb = b.kind === 'player' ? 0.3 : 0.5;
				a.body.x -= nx * push * wa;
				a.body.z -= nz * push * wa;
				b.body.x += nx * push * wb;
				b.body.z += nz * push * wb;
			}
		}
	}
}
