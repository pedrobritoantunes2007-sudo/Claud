// Colisão do mundo: chão da ilha (grade de 4 studs com faixas) + peças que colidem (caixas giradas).
// Os cachorros são cilindros (raio, altura): andam por cima de degraus baixos, batem em paredes altas e
// ficam em cima de pontes, caixas e telhados.
import { F_COLLIDE } from './ilhaDados.js';

export const WATER_Y = -2;
const HASH = 16;

export class Physics {
	constructor(data) {
		this.grid = data.grid;
		this.parts = [];
		this.hash = new Map();
		const p = data.parts;
		for (let i = 0; i < p.count; i++) {
			if (!(p.flags[i] & F_COLLIDE)) continue;
			const qx = p.quat[i * 4], qy = p.quat[i * 4 + 1], qz = p.quat[i * 4 + 2], qw = p.quat[i * 4 + 3];
			// colunas da matriz de rotação (eixos X, Y, Z da peça no mundo)
			const r00 = 1 - 2 * (qy * qy + qz * qz), r10 = 2 * (qx * qy + qz * qw), r20 = 2 * (qx * qz - qy * qw);
			const r01 = 2 * (qx * qy - qz * qw), r11 = 1 - 2 * (qx * qx + qz * qz), r21 = 2 * (qy * qz + qx * qw);
			const r02 = 2 * (qx * qz + qy * qw), r12 = 2 * (qy * qz - qx * qw), r22 = 1 - 2 * (qx * qx + qy * qy);
			const hx = p.size[i * 3] / 2, hy = p.size[i * 3 + 1] / 2, hz = p.size[i * 3 + 2] / 2;
			const cx = p.pos[i * 3], cy = p.pos[i * 3 + 1], cz = p.pos[i * 3 + 2];
			const ex = Math.abs(r00) * hx + Math.abs(r01) * hy + Math.abs(r02) * hz;
			const ey = Math.abs(r10) * hx + Math.abs(r11) * hy + Math.abs(r12) * hz;
			const ez = Math.abs(r20) * hx + Math.abs(r21) * hy + Math.abs(r22) * hz;
			const upright = Math.abs(r11) > 0.995;
			const part = {
				cx, cy, cz, hx, hy, hz, r00, r01, r02, r10, r11, r12, r20, r21, r22,
				minX: cx - ex, maxX: cx + ex, minY: cy - ey, maxY: cy + ey, minZ: cz - ez, maxZ: cz + ez,
				upright, wedge: p.shape[i] === 1, shape: p.shape[i],
			};
			// peça muito fina e pequena (grama, flores) não atrapalha
			if (ex < 0.25 && ez < 0.25) continue;
			const id = this.parts.length;
			this.parts.push(part);
			const ix0 = Math.floor(part.minX / HASH), ix1 = Math.floor(part.maxX / HASH);
			const iz0 = Math.floor(part.minZ / HASH), iz1 = Math.floor(part.maxZ / HASH);
			for (let ix = ix0; ix <= ix1; ix++) {
				for (let iz = iz0; iz <= iz1; iz++) {
					const key = ix * 100003 + iz;
					let list = this.hash.get(key);
					if (!list) this.hash.set(key, (list = []));
					list.push(id);
				}
			}
		}
		const g = this.grid;
		this.minX = g.x0;
		this.minZ = g.z0;
		this.maxX = g.x0 + g.w * g.cell;
		this.maxZ = g.z0 + g.d * g.cell;
		this.stamp = 0;
		this.seen = new Uint32Array(this.parts.length);
	}

	partsNear(x, z, r, fn) {
		const ix0 = Math.floor((x - r) / HASH), ix1 = Math.floor((x + r) / HASH);
		const iz0 = Math.floor((z - r) / HASH), iz1 = Math.floor((z + r) / HASH);
		this.stamp++;
		for (let ix = ix0; ix <= ix1; ix++) {
			for (let iz = iz0; iz <= iz1; iz++) {
				const list = this.hash.get(ix * 100003 + iz);
				if (!list) continue;
				for (const id of list) {
					if (this.seen[id] === this.stamp) continue;
					this.seen[id] = this.stamp;
					const p = this.parts[id];
					if (x + r < p.minX || x - r > p.maxX || z + r < p.minZ || z - r > p.maxZ) continue;
					if (fn(p) === true) return true;
				}
			}
		}
		return false;
	}

	// ponto (x, z) visto no espaço da peça (só X e Z; para peças em pé)
	local(p, x, z, y) {
		const dx = x - p.cx, dy = y - p.cy, dz = z - p.cz;
		return [p.r00 * dx + p.r10 * dy + p.r20 * dz, p.r01 * dx + p.r11 * dy + p.r21 * dz, p.r02 * dx + p.r12 * dy + p.r22 * dz];
	}

	// altura do topo da peça no ponto (x, z), ou null se o ponto não está em cima dela (margem r)
	partTop(p, x, z, r = 0) {
		if (!p.upright) {
			if (x < p.minX - r || x > p.maxX + r || z < p.minZ - r || z > p.maxZ + r) return null;
			return p.maxY;
		}
		const l = this.local(p, x, z, p.cy);
		if (Math.abs(l[0]) > p.hx + r || Math.abs(l[2]) > p.hz + r) return null;
		const sgn = p.r11 >= 0 ? 1 : -1;
		if (p.wedge) {
			// rampa: sobe da frente (-Z local) para trás (+Z local)
			const t = Math.min(1, Math.max(0, (l[2] + p.hz) / (2 * p.hz)));
			return sgn > 0 ? p.cy - p.hy + 2 * p.hy * t : p.cy + p.hy;
		}
		return p.cy + p.hy;
	}

	partBottom(p) {
		return p.upright ? p.cy - p.hy : p.minY;
	}

	// faixas de chão da célula (x, z)
	cellRange(x, z) {
		const g = this.grid;
		const ix = Math.floor((x - g.x0) / g.cell), iz = Math.floor((z - g.z0) / g.cell);
		if (ix < 0 || iz < 0 || ix >= g.w || iz >= g.d) return null;
		const ci = iz * g.w + ix;
		return [g.start[ci], g.start[ci + 1]];
	}

	// chão onde um corpo com pés em footY consegue ficar em pé em (x, z): o topo mais alto até footY + step
	groundAt(x, z, footY, step = 1.6) {
		const g = this.grid;
		let best = -Infinity;
		const range = this.cellRange(x, z);
		if (range) {
			for (let s = range[0]; s < range[1]; s++) {
				const top = g.y1[s];
				if (top <= footY + step && top > best) best = top;
			}
		}
		this.partsNear(x, z, 0.3, (p) => {
			const top = this.partTop(p, x, z, 0.3);
			if (top !== null && top <= footY + step && top > best && this.partBottom(p) < top) best = top;
		});
		return best;
	}

	// topo mais alto de tudo (para pôr coisas no chão: ovos, NPCs, selvagens). maxY limita (debaixo de pontes)
	topAt(x, z, maxY = 1e9) {
		const g = this.grid;
		let best = -Infinity;
		const range = this.cellRange(x, z);
		if (range) for (let s = range[0]; s < range[1]; s++) if (g.y1[s] <= maxY && g.y1[s] > best) best = g.y1[s];
		this.partsNear(x, z, 0.3, (p) => {
			const top = this.partTop(p, x, z, 0);
			if (top !== null && top <= maxY && top > best) best = top;
		});
		return best;
	}

	// tem parede (algo mais alto que o degrau) no círculo (x, z, r) para um corpo de pés em footY e altura h?
	blocked(x, z, footY, h, r, step = 1.6) {
		const g = this.grid;
		const lo = footY + step, hi = footY + h;
		// chão: confere a célula do centro e as vizinhas que o círculo encosta
		const cells = [[x, z], [x + r, z], [x - r, z], [x, z + r], [x, z - r]];
		for (const [px, pz] of cells) {
			const range = this.cellRange(px, pz);
			if (!range) continue;
			for (let s = range[0]; s < range[1]; s++) {
				if (g.y1[s] > lo && g.y0[s] < hi) return true;
			}
		}
		return this.partsNear(x, z, r, (p) => {
			const top = this.partTop(p, x, z, r);
			if (top === null) return false;
			const bottom = this.partBottom(p);
			if (top > lo && bottom < hi) {
				// rampa: só bloqueia se a parte alta está bem acima
				return true;
			}
			return false;
		});
	}

	// raio para baixo/frente (mira, câmera): primeiro ponto sólido na linha (passos de 1 stud)
	raycast(ox, oy, oz, dx, dy, dz, maxDist, stepLen = 1) {
		const len = Math.hypot(dx, dy, dz) || 1;
		dx /= len;
		dy /= len;
		dz /= len;
		for (let t = 0; t <= maxDist; t += stepLen) {
			const x = ox + dx * t, y = oy + dy * t, z = oz + dz * t;
			if (this.solidAt(x, y, z)) return { x, y, z, t };
			if (y < WATER_Y && dy < 0) return { x, y: WATER_Y, z, t, water: true };
		}
		return null;
	}

	solidAt(x, y, z) {
		const g = this.grid;
		const range = this.cellRange(x, z);
		if (range) for (let s = range[0]; s < range[1]; s++) if (y >= g.y0[s] && y <= g.y1[s]) return true;
		return this.partsNear(x, z, 0, (p) => {
			if (y < p.minY || y > p.maxY) return false;
			if (!p.upright) return true;
			const l = this.local(p, x, z, y);
			return Math.abs(l[0]) <= p.hx && Math.abs(l[1]) <= p.hy && Math.abs(l[2]) <= p.hz;
		});
	}
}
