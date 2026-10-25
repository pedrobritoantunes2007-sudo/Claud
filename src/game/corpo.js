// Física simples do corpo de um cachorro (cilindro): anda, sobe degraus, bate em paredes, cai, pula e nada.
import { WATER_Y } from '../world/fisica.js';

export const GRAVITY = 150;

// body: { x, y (pés), z, vx, vy, vz, radius, height, step, grounded, inWater, flying, swimDepth }
export function stepBody(body, physics, dt, opts = {}) {
	if (!physics) return;
	const r = body.radius, h = body.height, step = body.step;
	// ---- movimento na horizontal (com escorregar na parede)
	let nx = body.x + body.vx * dt, nz = body.z + body.vz * dt;
	const lim = opts.bounds;
	if (lim) {
		nx = Math.min(lim.maxX, Math.max(lim.minX, nx));
		nz = Math.min(lim.maxZ, Math.max(lim.minZ, nz));
	}
	const foot = body.y;
	if (body.noclip) {
		body.x = nx;
		body.z = nz;
	} else if (!physics.blocked(nx, nz, foot, h, r, step)) {
		body.x = nx;
		body.z = nz;
	} else if (!physics.blocked(nx, body.z, foot, h, r, step)) {
		body.x = nx;
		body.vz *= 0.5;
		body.hitWall = true;
	} else if (!physics.blocked(body.x, nz, foot, h, r, step)) {
		body.z = nz;
		body.vx *= 0.5;
		body.hitWall = true;
	} else {
		body.vx = 0;
		body.vz = 0;
		body.hitWall = true;
	}
	// ---- vertical
	let ground = physics.groundAt(body.x, body.z, body.y, step);
	const swimFloor = WATER_Y - body.swimDepth;
	body.inWater = false;
	if (ground < swimFloor && !body.flying) {
		// água funda: boia na superfície
		if (body.y <= swimFloor + 0.3) body.inWater = true;
		ground = Math.max(ground, swimFloor);
	}
	body.groundY = ground;
	if (body.flying) {
		body.y += body.vy * dt;
		if (body.y < ground) {
			body.y = ground;
			if (body.vy < 0) body.vy = 0;
		}
		body.grounded = body.y <= ground + 0.05;
		return;
	}
	if (body.grounded && body.vy <= 0 && body.y - ground <= step + 0.2 && body.y - ground >= -step - 0.2) {
		// no chão: acompanha degraus para cima e para baixo
		body.y = ground;
		body.vy = 0;
	} else {
		body.vy -= GRAVITY * (opts.gravityMult || 1) * dt;
		body.y += body.vy * dt;
		if (body.y <= ground) {
			if (!body.grounded) body.landedSpeed = -body.vy;
			body.y = ground;
			body.vy = 0;
			body.grounded = true;
		} else {
			body.grounded = false;
		}
	}
	if (body.inWater) body.grounded = true;
}

export function makeBody(radius, height, step = 1.6) {
	return {
		x: 0,
		y: 0,
		z: 0,
		vx: 0,
		vy: 0,
		vz: 0,
		radius,
		height,
		step,
		grounded: true,
		inWater: false,
		flying: false,
		swimDepth: 1.2,
		groundY: 0,
		hitWall: false,
		landedSpeed: 0,
		noclip: false,
	};
}
