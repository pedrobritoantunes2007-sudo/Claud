// Utilidades de matemática, sorteio e ruído usadas pelo jogo todo.

export const TAU = Math.PI * 2;

export function clamp(x, a, b) {
	return x < a ? a : x > b ? b : x;
}

export function lerp(a, b, t) {
	return a + (b - a) * t;
}

export function damp(dt, k) {
	return 1 - Math.exp(-k * dt);
}

export function smooth01(x) {
	x = clamp(x, 0, 1);
	return x * x * (3 - 2 * x);
}

// menor diferença entre dois ângulos (rad)
export function angleDiff(a, b) {
	let d = (b - a) % TAU;
	if (d > Math.PI) d -= TAU;
	if (d < -Math.PI) d += TAU;
	return d;
}

export function dist2D(ax, az, bx, bz) {
	return Math.hypot(ax - bx, az - bz);
}

// sorteio com semente (mulberry32)
export function rng(seed) {
	let a = seed >>> 0;
	const next = () => {
		a = (a + 0x6d2b79f5) >>> 0;
		let t = a;
		t = Math.imul(t ^ (t >>> 15), t | 1);
		t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
		return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
	};
	next.range = (lo, hi) => lo + (hi - lo) * next();
	next.int = (lo, hi) => lo + Math.floor(next() * (hi - lo + 1));
	next.pick = (list) => list[Math.floor(next() * list.length)];
	next.chance = (p) => next() < p;
	return next;
}

export function hashString(s) {
	let h = 2166136261;
	for (let i = 0; i < s.length; i++) {
		h ^= s.charCodeAt(i);
		h = Math.imul(h, 16777619);
	}
	return h >>> 0;
}

// número inteiro → 0..1 (sempre igual para a mesma entrada)
export function hash2(x, z, seed = 0) {
	let h = Math.imul(x | 0, 374761393) + Math.imul(z | 0, 668265263) + Math.imul(seed | 0, 2246822519);
	h = Math.imul(h ^ (h >>> 13), 1274126177);
	h ^= h >>> 16;
	return (h >>> 0) / 4294967296;
}

// ruído suave 2D (value noise com interpolação suave)
export function noise2(x, z, seed = 0) {
	const xi = Math.floor(x), zi = Math.floor(z);
	const xf = x - xi, zf = z - zi;
	const u = xf * xf * (3 - 2 * xf), v = zf * zf * (3 - 2 * zf);
	const a = hash2(xi, zi, seed), b = hash2(xi + 1, zi, seed);
	const c = hash2(xi, zi + 1, seed), d = hash2(xi + 1, zi + 1, seed);
	return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v;
}

// ruído em camadas (0..1)
export function fbm(x, z, seed = 0, octaves = 4) {
	let sum = 0, amp = 0.5, freq = 1, norm = 0;
	for (let i = 0; i < octaves; i++) {
		sum += noise2(x * freq, z * freq, seed + i * 101) * amp;
		norm += amp;
		amp *= 0.5;
		freq *= 2.03;
	}
	return sum / norm;
}

export function formatNumber(n) {
	n = Math.floor(n);
	if (n >= 1e9) return (n / 1e9).toFixed(n >= 1e10 ? 0 : 1).replace(/\.0$/, '') + 'B';
	if (n >= 1e6) return (n / 1e6).toFixed(n >= 1e7 ? 0 : 1).replace(/\.0$/, '') + 'M';
	if (n >= 1e4) return (n / 1e3).toFixed(n >= 1e5 ? 0 : 1).replace(/\.0$/, '') + 'K';
	return n.toLocaleString('en-US');
}

export function formatCash(n) {
	return '$' + formatNumber(n);
}

export function hexToRgb(hex) {
	const v = parseInt(hex.replace('#', ''), 16);
	return [(v >> 16) & 255, (v >> 8) & 255, v & 255];
}
