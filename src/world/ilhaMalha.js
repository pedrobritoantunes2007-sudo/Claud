// Desenha uma ilha carregada (ilhaDados.js): chão em blocos (grade de 4 studs, só as faces que aparecem),
// peças (árvores, casas, enfeites) em pedaços de 128 studs montados só quando o jogador chega perto,
// e detalhes pequenos (flores, pedrinhas) só bem perto. Peças grandes ficam sempre (aparecem de longe).
import * as THREE from 'three';
import { F_DETAIL, F_NEON, F_GLASS } from './ilhaDados.js';

export const WORLD_MATERIALS = {
	ground: new THREE.MeshLambertMaterial({ vertexColors: true }),
	opaque: new THREE.MeshLambertMaterial({ vertexColors: true }),
	neon: new THREE.MeshBasicMaterial({ vertexColors: true, toneMapped: false }),
	glass: new THREE.MeshLambertMaterial({ vertexColors: true, transparent: true, depthWrite: false }),
};

const HIDE_BELOW = -16; // faces abaixo disto nunca aparecem (fundo do mar)
const GROUND_CHUNK = 32; // células de 4 studs
const PART_CHUNK = 128; // studs
const BIG = 16; // peças maiores que isto ficam sempre montadas

// distâncias de montagem por qualidade
const LOD = {
	high: { parts: 460, detail: 190 },
	medium: { parts: 340, detail: 140 },
	low: { parts: 240, detail: 90 },
};

// ---------------------------------------------------------------- buffer de quadriláteros/triângulos
class Geo {
	constructor() {
		this.pos = [];
		this.nor = [];
		this.col = [];
		this.idx = [];
		this.n = 0;
	}

	quad(ax, ay, az, bx, by, bz, cx, cy, cz, dx, dy, dz, nx, ny, nz, r, g, b, a = 1) {
		const i = this.n;
		this.pos.push(ax, ay, az, bx, by, bz, cx, cy, cz, dx, dy, dz);
		for (let k = 0; k < 4; k++) {
			this.nor.push(nx, ny, nz);
			this.col.push(r, g, b, a);
		}
		this.idx.push(i, i + 1, i + 2, i, i + 2, i + 3);
		this.n += 4;
	}

	tri(ax, ay, az, bx, by, bz, cx, cy, cz, nx, ny, nz, r, g, b, a = 1) {
		const i = this.n;
		this.pos.push(ax, ay, az, bx, by, bz, cx, cy, cz);
		for (let k = 0; k < 3; k++) {
			this.nor.push(nx, ny, nz);
			this.col.push(r, g, b, a);
		}
		this.idx.push(i, i + 1, i + 2);
		this.n += 3;
	}

	empty() {
		return this.n === 0;
	}

	build() {
		const g = new THREE.BufferGeometry();
		g.setAttribute('position', new THREE.BufferAttribute(new Float32Array(this.pos), 3));
		const nor = new Int8Array(this.nor.length);
		for (let i = 0; i < nor.length; i++) nor[i] = Math.round(this.nor[i] * 127);
		g.setAttribute('normal', new THREE.BufferAttribute(nor, 3, true));
		g.setAttribute('color', new THREE.BufferAttribute(new Float32Array(this.col), 4));
		g.setIndex(this.n > 65535 ? new THREE.BufferAttribute(new Uint32Array(this.idx), 1) : new THREE.BufferAttribute(new Uint16Array(this.idx), 1));
		g.computeBoundingSphere();
		g.computeBoundingBox();
		return g;
	}
}

// ---------------------------------------------------------------- chão
function buildGroundChunk(data, cx0, cz0) {
	const { grid, pal } = data;
	const { x0, z0, cell, w, d, start, y0, y1, col } = grid;
	const geo = new Geo();
	const runs = new Map(); // tampas em sequência na mesma linha: chave "iz|y|cor" → { ix0, ix1, y, c }
	const flushRuns = () => {
		for (const r of runs.values()) emitTop(r);
		runs.clear();
	};
	const emitTop = (r) => {
		const xa = x0 + r.ix0 * cell, xb = x0 + (r.ix1 + 1) * cell;
		const za = z0 + r.iz * cell, zb = za + cell;
		const c = r.c * 3;
		geo.quad(xa, r.y, za, xa, r.y, zb, xb, r.y, zb, xb, r.y, za, 0, 1, 0, pal[c], pal[c + 1], pal[c + 2]);
	};
	const ixEnd = Math.min(w, cx0 + GROUND_CHUNK), izEnd = Math.min(d, cz0 + GROUND_CHUNK);
	for (let iz = cz0; iz < izEnd; iz++) {
		for (let ix = cx0; ix < ixEnd; ix++) {
			const ci = iz * w + ix;
			const s0 = start[ci], s1 = start[ci + 1];
			if (s0 === s1) continue;
			const xa = x0 + ix * cell, xb = xa + cell, za = z0 + iz * cell, zb = za + cell;
			for (let s = s0; s < s1; s++) {
				const a = y0[s], b = y1[s];
				if (b < HIDE_BELOW) continue;
				const c = col[s] * 3;
				const R = pal[c], G = pal[c + 1], B = pal[c + 2];
				// tampa (se nada encosta em cima)
				let covered = false;
				for (let t = s0; t < s1; t++) if (t !== s && Math.abs(y0[t] - b) < 0.01) covered = true;
				if (!covered) {
					const key = iz + '|' + b + '|' + col[s];
					const run = runs.get(key);
					if (run && run.ix1 === ix - 1) run.ix1 = ix;
					else {
						if (run) emitTop(run);
						runs.set(key, { ix0: ix, ix1: ix, iz, y: b, c: col[s] });
					}
				}
				// laterais: o que o vizinho não cobre
				const lo = Math.max(a, HIDE_BELOW);
				sideFaces(grid, ix - 1, iz, lo, b, (ya, yb) => geo.quad(xa, ya, zb, xa, yb, zb, xa, yb, za, xa, ya, za, -1, 0, 0, R, G, B));
				sideFaces(grid, ix + 1, iz, lo, b, (ya, yb) => geo.quad(xb, ya, za, xb, yb, za, xb, yb, zb, xb, ya, zb, 1, 0, 0, R, G, B));
				sideFaces(grid, ix, iz - 1, lo, b, (ya, yb) => geo.quad(xa, ya, za, xa, yb, za, xb, yb, za, xb, ya, za, 0, 0, -1, R, G, B));
				sideFaces(grid, ix, iz + 1, lo, b, (ya, yb) => geo.quad(xb, ya, zb, xb, yb, zb, xa, yb, zb, xa, ya, zb, 0, 0, 1, R, G, B));
				// fundo (só chão flutuando)
				if (a > -9) {
					let below = false;
					for (let t = s0; t < s1; t++) if (t !== s && Math.abs(y1[t] - a) < 0.01) below = true;
					if (!below) geo.quad(xa, a, za, xb, a, za, xb, a, zb, xa, a, zb, 0, -1, 0, R * 0.8, G * 0.8, B * 0.8);
				}
			}
		}
		// fim da linha: as tampas desta linha não continuam na próxima
		flushRuns();
	}
	flushRuns();
	return geo.empty() ? null : geo.build();
}

// partes de [lo, hi] que a coluna vizinha (nx, nz) não cobre
function sideFaces(grid, nx, nz, lo, hi, emit) {
	if (hi - lo < 0.01) return;
	const { w, d, start, y0, y1 } = grid;
	if (nx < 0 || nz < 0 || nx >= w || nz >= d) {
		emit(lo, hi);
		return;
	}
	const ci = nz * w + nx;
	const s0 = start[ci], s1 = start[ci + 1];
	let cur = lo;
	// faixas do vizinho estão em ordem de altura
	for (let t = s0; t < s1 && cur < hi; t++) {
		const a = y0[t], b = y1[t];
		if (b <= cur) continue;
		if (a >= hi) break;
		if (a > cur) emit(cur, Math.min(a, hi));
		cur = Math.max(cur, b);
	}
	if (cur < hi) emit(cur, hi);
}

// ---------------------------------------------------------------- peças
const _q = new THREE.Quaternion();
const _m = new THREE.Matrix4();
const _v = new THREE.Vector3();
const _s = new THREE.Vector3();
const _p = new THREE.Vector3();
const _nm = new THREE.Matrix3();
const _c = new THREE.Vector3();

const SHAPE_FACES = (() => {
	// faces em espaço unitário (meia medida 0.5); cada face = lista de vértices
	const box = [
		[[-1, -1, -1], [-1, 1, -1], [1, 1, -1], [1, -1, -1]],
		[[1, -1, 1], [1, 1, 1], [-1, 1, 1], [-1, -1, 1]],
		[[-1, -1, 1], [-1, 1, 1], [-1, 1, -1], [-1, -1, -1]],
		[[1, -1, -1], [1, 1, -1], [1, 1, 1], [1, -1, 1]],
		[[-1, 1, -1], [-1, 1, 1], [1, 1, 1], [1, 1, -1]],
		[[-1, -1, 1], [-1, -1, -1], [1, -1, -1], [1, -1, 1]],
	];
	const A = [-1, -1, -1], B = [1, -1, -1], C = [-1, -1, 1], D = [1, -1, 1], E = [-1, 1, 1], F = [1, 1, 1];
	const wedge = [
		[A, B, D, C],
		[C, D, F, E],
		[A, E, F, B],
		[A, C, E],
		[B, F, D],
	];
	// quina (CornerWedgePart): pirâmide com a ponta em cima no canto (+x, +y, -z)
	const P = [1, 1, -1];
	const corner = [
		[[-1, -1, -1], [1, -1, -1], [1, -1, 1], [-1, -1, 1]],
		[[-1, -1, -1], P, [1, -1, -1]],
		[[1, -1, -1], P, [1, -1, 1]],
		[[1, -1, 1], P, [-1, -1, 1]],
		[[-1, -1, 1], P, [-1, -1, -1]],
	];
	const cyl = [];
	const N = 10;
	for (let i = 0; i < N; i++) {
		const a0 = (i / N) * Math.PI * 2, a1 = ((i + 1) / N) * Math.PI * 2;
		const y0 = Math.cos(a0), z0 = Math.sin(a0), y1 = Math.cos(a1), z1 = Math.sin(a1);
		cyl.push([[-1, y0, z0], [-1, y1, z1], [1, y1, z1], [1, y0, z0]]);
	}
	const capA = [], capB = [];
	for (let i = 0; i < N; i++) {
		const a = (i / N) * Math.PI * 2;
		capA.push([-1, Math.cos(a), Math.sin(a)]);
		capB.unshift([1, Math.cos(a), Math.sin(a)]);
	}
	cyl.push(capA, capB);
	const sph = [];
	const LAT = 6, LON = 10;
	for (let i = 0; i < LAT; i++) {
		const t0 = (i / LAT) * Math.PI, t1 = ((i + 1) / LAT) * Math.PI;
		for (let j = 0; j < LON; j++) {
			const p0 = (j / LON) * Math.PI * 2, p1 = ((j + 1) / LON) * Math.PI * 2;
			const v = (t, p) => [Math.sin(t) * Math.cos(p), Math.cos(t), Math.sin(t) * Math.sin(p)];
			sph.push([v(t0, p0), v(t0, p1), v(t1, p1), v(t1, p0)]);
		}
	}
	return { 0: box, 1: wedge, 2: corner, 3: cyl, 4: sph };
})();
// centro do sólido (unidades de meia medida) para virar as faces para fora
const SHAPE_CENTER = { 1: [0, -1 / 3, 1 / 3], 2: [0.25, -0.5, -0.25] };

function addPart(geo, parts, pal, i) {
	const sh = parts.shape[i];
	const faces = SHAPE_FACES[sh] || SHAPE_FACES[0];
	let sx = parts.size[i * 3] / 2, sy = parts.size[i * 3 + 1] / 2, sz = parts.size[i * 3 + 2] / 2;
	if (sh === 3) {
		const r = Math.min(sy, sz);
		sy = sz = r;
	}
	_q.set(parts.quat[i * 4], parts.quat[i * 4 + 1], parts.quat[i * 4 + 2], parts.quat[i * 4 + 3]);
	_p.set(parts.pos[i * 3], parts.pos[i * 3 + 1], parts.pos[i * 3 + 2]);
	_s.set(sx, sy, sz);
	_m.compose(_p, _q, _s);
	_nm.getNormalMatrix(_m);
	const c = parts.color[i] * 3;
	const neon = parts.flags[i] & F_NEON;
	let R = pal[c], G = pal[c + 1], B = pal[c + 2];
	if (neon) {
		R = Math.min(1, R * 1.15 + 0.05);
		G = Math.min(1, G * 1.15 + 0.05);
		B = Math.min(1, B * 1.15 + 0.05);
	}
	let alpha = parts.alpha[i] / 255;
	if (parts.flags[i] & F_GLASS) alpha = Math.min(alpha, 0.75);
	const curved = sh === 4;
	for (const f of faces) {
		const pts = f.map((p) => _v.set(p[0], p[1], p[2]).applyMatrix4(_m).toArray());
		let nx, ny, nz;
		if (curved) {
			// esfera: normal de cada face pelo meio dela
			let mx = 0, my = 0, mz = 0;
			for (const p of f) {
				mx += p[0];
				my += p[1];
				mz += p[2];
			}
			_v.set(mx / sx, my / sy, mz / sz).applyMatrix3(_nm).normalize();
		} else {
			const a = f[0], b = f[1], cc = f[2];
			const ux = (b[0] - a[0]) * sx, uy = (b[1] - a[1]) * sy, uz = (b[2] - a[2]) * sz;
			const vx = (cc[0] - a[0]) * sx, vy = (cc[1] - a[1]) * sy, vz = (cc[2] - a[2]) * sz;
			_v.set(uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx);
			if (_v.lengthSq() < 1e-12) continue;
			_v.applyQuaternion(_q).normalize();
		}
		nx = _v.x;
		ny = _v.y;
		nz = _v.z;
		// garante a face virada para fora (comparando com o centro do sólido)
		const sc = SHAPE_CENTER[sh];
		if (sc) _c.set(sc[0], sc[1], sc[2]).applyMatrix4(_m);
		else _c.copy(_p);
		let fx = 0, fy = 0, fz = 0;
		for (const p of pts) {
			fx += p[0];
			fy += p[1];
			fz += p[2];
		}
		fx = fx / pts.length - _c.x;
		fy = fy / pts.length - _c.y;
		fz = fz / pts.length - _c.z;
		const flip = nx * fx + ny * fy + nz * fz < 0 && !curved;
		if (flip) {
			nx = -nx;
			ny = -ny;
			nz = -nz;
			pts.reverse();
		}
		if (pts.length === 4) geo.quad(...pts[0], ...pts[1], ...pts[2], ...pts[3], nx, ny, nz, R, G, B, alpha);
		else if (pts.length === 3) geo.tri(...pts[0], ...pts[1], ...pts[2], nx, ny, nz, R, G, B, alpha);
		else for (let k = 1; k < pts.length - 1; k++) geo.tri(...pts[0], ...pts[k], ...pts[k + 1], nx, ny, nz, R, G, B, alpha);
	}
}

// monta uma malha com até 3 materiais (normal, neon, vidro) para uma lista de peças
function buildPartsMesh(data, list) {
	const { parts, pal } = data;
	const geos = { opaque: new Geo(), neon: new Geo(), glass: new Geo() };
	for (const i of list) {
		const fl = parts.flags[i];
		const kind = fl & F_NEON ? 'neon' : fl & F_GLASS || parts.alpha[i] < 250 ? 'glass' : 'opaque';
		addPart(geos[kind], parts, pal, i);
	}
	const group = new THREE.Group();
	for (const [kind, geo] of Object.entries(geos)) {
		if (geo.empty()) continue;
		const mesh = new THREE.Mesh(geo.build(), WORLD_MATERIALS[kind]);
		mesh.castShadow = kind === 'opaque';
		mesh.receiveShadow = kind !== 'neon';
		mesh.matrixAutoUpdate = false;
		group.add(mesh);
	}
	group.matrixAutoUpdate = false;
	return group;
}

function disposeGroup(group) {
	group.traverse((o) => {
		if (o.geometry) o.geometry.dispose();
	});
	if (group.parent) group.parent.remove(group);
}

// ---------------------------------------------------------------- a ilha na cena
export class IslandView {
	constructor(data, scene) {
		this.data = data;
		this.root = new THREE.Group();
		this.root.name = 'ilha-' + data.id;
		scene.add(this.root);
		this.quality = 'high';
		this.buildGround();
		this.indexParts();
		this.queue = [];
	}

	buildGround() {
		const g = this.data.grid;
		this.ground = [];
		for (let cz = 0; cz < g.d; cz += GROUND_CHUNK) {
			for (let cx = 0; cx < g.w; cx += GROUND_CHUNK) {
				const geo = buildGroundChunk(this.data, cx, cz);
				if (!geo) continue;
				const mesh = new THREE.Mesh(geo, WORLD_MATERIALS.ground);
				mesh.receiveShadow = true;
				mesh.castShadow = true;
				mesh.matrixAutoUpdate = false;
				this.root.add(mesh);
				this.ground.push(mesh);
			}
		}
	}

	// separa as peças em pedaços de 128 studs (normais e detalhes) + as grandes (sempre)
	indexParts() {
		const { parts } = this.data;
		const big = [];
		const chunks = new Map();
		for (let i = 0; i < parts.count; i++) {
			const sx = parts.size[i * 3], sy = parts.size[i * 3 + 1], sz = parts.size[i * 3 + 2];
			if (Math.max(sx, sy, sz) >= BIG && !(parts.flags[i] & F_DETAIL)) {
				big.push(i);
				continue;
			}
			const x = parts.pos[i * 3], z = parts.pos[i * 3 + 2];
			const kx = Math.floor(x / PART_CHUNK), kz = Math.floor(z / PART_CHUNK);
			const detail = (parts.flags[i] & F_DETAIL) !== 0;
			const key = kx + ',' + kz + (detail ? 'd' : '');
			let ch = chunks.get(key);
			if (!ch) {
				ch = { key, detail, cx: (kx + 0.5) * PART_CHUNK, cz: (kz + 0.5) * PART_CHUNK, list: [], group: null };
				chunks.set(key, ch);
			}
			ch.list.push(i);
		}
		this.chunks = [...chunks.values()];
		// as grandes em pedaços de 512 para o corte de visão funcionar
		const bigChunks = new Map();
		for (const i of big) {
			const key = Math.floor(parts.pos[i * 3] / 512) + ',' + Math.floor(parts.pos[i * 3 + 2] / 512);
			if (!bigChunks.has(key)) bigChunks.set(key, []);
			bigChunks.get(key).push(i);
		}
		this.big = [];
		for (const list of bigChunks.values()) {
			const g = buildPartsMesh(this.data, list);
			this.root.add(g);
			this.big.push(g);
		}
	}

	// monta/desmonta pedaços conforme a distância do ponto (jogador ou câmera). budgetMs = tempo por quadro
	update(x, z, budgetMs = 4, all = false) {
		const lod = LOD[this.quality] || LOD.high;
		const t0 = performance.now();
		const want = [];
		for (const ch of this.chunks) {
			const r = ch.detail ? lod.detail : lod.parts;
			const dist = Math.hypot(ch.cx - x, ch.cz - z) - PART_CHUNK * 0.71;
			if (dist < r) {
				if (!ch.group) want.push({ ch, dist });
				else ch.group.visible = true;
			} else if (ch.group && dist > r + 120) {
				disposeGroup(ch.group);
				ch.group = null;
			} else if (ch.group) {
				ch.group.visible = dist < r + 40;
			}
		}
		want.sort((a, b) => a.dist - b.dist);
		for (const { ch } of want) {
			ch.group = buildPartsMesh(this.data, ch.list);
			this.root.add(ch.group);
			if (!all && performance.now() - t0 > budgetMs) break;
		}
		return want.length;
	}

	setQuality(q) {
		this.quality = q;
	}

	dispose() {
		for (const ch of this.chunks) if (ch.group) disposeGroup(ch.group);
		for (const g of this.big) disposeGroup(g);
		for (const m of this.ground) {
			m.geometry.dispose();
		}
		if (this.root.parent) this.root.parent.remove(this.root);
	}
}
