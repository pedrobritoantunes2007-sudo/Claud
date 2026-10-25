// Carrega o arquivo de uma ilha (assets/ilhas/<id>.js, feito pelo tools/exportar) e lê o binário.
// O arquivo é um <script> que chama window.__ilha(id, base64) — funciona até abrindo o jogo direto do disco.
import { gunzipSync } from 'fflate';

const pending = new Map();
const cache = new Map();

window.__ilha = (id, b64) => {
	const p = pending.get(id);
	if (p) {
		pending.delete(id);
		p.resolve(b64);
	}
};

function loadScript(id) {
	return new Promise((resolve, reject) => {
		pending.set(id, { resolve, reject });
		const s = document.createElement('script');
		s.src = `ilhas/${id}.js`;
		s.onerror = () => {
			pending.delete(id);
			reject(new Error('não consegui carregar a ilha ' + id));
		};
		document.head.appendChild(s);
	});
}

function base64ToBytes(b64) {
	const bin = atob(b64);
	const out = new Uint8Array(bin.length);
	for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
	return out;
}

export async function loadIsland(id) {
	if (cache.has(id)) return cache.get(id);
	const b64 = await loadScript(id);
	const blob = gunzipSync(base64ToBytes(b64));
	const data = parseIsland(blob);
	cache.set(id, data);
	return data;
}

export function forgetIsland(id) {
	cache.delete(id);
}

function parseIsland(bytes) {
	const dv = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
	const magic = String.fromCharCode(bytes[0], bytes[1], bytes[2], bytes[3]);
	if (magic !== 'DFI1') throw new Error('arquivo de ilha inválido');
	const jsonLen = dv.getUint32(4, true);
	const info = JSON.parse(new TextDecoder().decode(bytes.subarray(8, 8 + jsonLen)));
	let off = 8 + jsonLen;
	// ---- chão: faixas por célula
	const g = info.grid;
	const cells = g.w * g.d;
	const start = new Uint32Array(cells + 1);
	// primeira passada: contar
	let o = off, total = 0;
	for (let i = 0; i < cells; i++) {
		start[i] = total;
		const n = bytes[o];
		total += n;
		o += 1 + n * 6;
	}
	start[cells] = total;
	const y0 = new Float32Array(total), y1 = new Float32Array(total);
	const col = new Uint16Array(total);
	let k = 0;
	for (let i = 0; i < cells; i++) {
		const n = bytes[off];
		off += 1;
		for (let j = 0; j < n; j++) {
			y0[k] = dv.getInt16(off, true) / 8;
			y1[k] = dv.getInt16(off + 2, true) / 8;
			col[k] = dv.getUint16(off + 4, true);
			k++;
			off += 6;
		}
	}
	// ---- peças
	const np = dv.getUint32(off, true);
	off += 4;
	const shape = new Uint8Array(np), flags = new Uint8Array(np), alpha = new Uint8Array(np), tag = new Uint8Array(np);
	const color = new Uint16Array(np);
	const pos = new Float32Array(np * 3), size = new Float32Array(np * 3), quat = new Float32Array(np * 4);
	for (let i = 0; i < np; i++, off += 32) {
		shape[i] = bytes[off];
		flags[i] = bytes[off + 1];
		color[i] = dv.getUint16(off + 2, true);
		alpha[i] = bytes[off + 4];
		tag[i] = bytes[off + 5];
		pos[i * 3] = dv.getFloat32(off + 6, true);
		pos[i * 3 + 1] = dv.getFloat32(off + 10, true);
		pos[i * 3 + 2] = dv.getFloat32(off + 14, true);
		size[i * 3] = dv.getUint16(off + 18, true) / 32;
		size[i * 3 + 1] = dv.getUint16(off + 20, true) / 32;
		size[i * 3 + 2] = dv.getUint16(off + 22, true) / 32;
		let qx = dv.getInt16(off + 24, true) / 32767, qy = dv.getInt16(off + 26, true) / 32767;
		let qz = dv.getInt16(off + 28, true) / 32767, qw = dv.getInt16(off + 30, true) / 32767;
		const n = Math.hypot(qx, qy, qz, qw) || 1;
		quat[i * 4] = qx / n;
		quat[i * 4 + 1] = qy / n;
		quat[i * 4 + 2] = qz / n;
		quat[i * 4 + 3] = qw / n;
	}
	// paleta em cores lineares (o three.js trabalha em linear)
	const pal = new Float32Array(info.palette.length * 3);
	info.palette.forEach((c, i) => {
		pal[i * 3] = srgbToLinear(c[0] / 255);
		pal[i * 3 + 1] = srgbToLinear(c[1] / 255);
		pal[i * 3 + 2] = srgbToLinear(c[2] / 255);
	});
	return {
		id: info.id,
		info,
		grid: { x0: g.x0, z0: g.z0, cell: g.cell, w: g.w, d: g.d, start, y0, y1, col },
		parts: { count: np, shape, flags, alpha, tag, color, pos, size, quat },
		pal,
	};
}

export function srgbToLinear(c) {
	return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
}

// bandeiras das peças
export const F_COLLIDE = 1, F_DETAIL = 2, F_NEON = 4, F_LOOSE_GROUND = 8, F_GLASS = 16;
