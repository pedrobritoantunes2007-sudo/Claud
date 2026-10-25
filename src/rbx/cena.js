// Desenho da mini-Roblox no three.js: peças (Part/WedgePart, bola, cilindro, elipsoide), partículas
// (ParticleEmitter com as texturas de partícula do Roblox desenhadas aqui), rastros (Trail), luzes (PointLight
// = brilho + algumas luzes de verdade), destaque (Highlight no cachorro), textos flutuantes (BillboardGui em
// HTML) e efeitos de tela (ColorCorrectionEffect = filtro CSS).
import * as THREE from 'three';
import {
	G as HOOK, Instance, BasePart, Attachment, ParticleEmitter, Trail, Light, Highlight, BillboardGui, GuiObject, UIComponent,
	PostEffect, SpecialMesh, Model,
} from './instancias.js';
import { reportError } from './lua.js';

const S = {
	scene: null,
	camera: null,
	renderer: null,
	ui: null,
	group: null,
	quality: 1,
	parts: new Set(),
	dirty: new Map(),
	emitters: new Set(),
	trails: new Set(),
	lights: new Set(),
	highlights: new Set(),
	guis: new Set(),
	post: new Set(),
	postKey: '',
	realLights: [],
	camPos: new THREE.Vector3(),
	time: 0,
};

// ------------------------------------------------------------------ formas (tamanho 1)
const GEO = {};
function faceGeometry(faces, center) {
	const pos = [];
	const nor = [];
	for (const face of faces) {
		const a = face[0], b = face[1], c = face[2];
		let nx = (b[1] - a[1]) * (c[2] - a[2]) - (b[2] - a[2]) * (c[1] - a[1]);
		let ny = (b[2] - a[2]) * (c[0] - a[0]) - (b[0] - a[0]) * (c[2] - a[2]);
		let nz = (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0]);
		let fx = 0, fy = 0, fz = 0;
		for (const p of face) {
			fx += p[0];
			fy += p[1];
			fz += p[2];
		}
		fx = fx / face.length - center[0];
		fy = fy / face.length - center[1];
		fz = fz / face.length - center[2];
		const flip = nx * fx + ny * fy + nz * fz < 0;
		if (flip) {
			nx = -nx;
			ny = -ny;
			nz = -nz;
		}
		const l = Math.hypot(nx, ny, nz) || 1;
		for (let i = 1; i < face.length - 1; i++) {
			const tri = flip ? [face[0], face[i + 1], face[i]] : [face[0], face[i], face[i + 1]];
			for (const p of tri) {
				pos.push(p[0], p[1], p[2]);
				nor.push(nx / l, ny / l, nz / l);
			}
		}
	}
	const g = new THREE.BufferGeometry();
	g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
	g.setAttribute('normal', new THREE.Float32BufferAttribute(nor, 3));
	g.computeBoundingSphere();
	return g;
}
function geo(kind) {
	if (GEO[kind]) return GEO[kind];
	let g;
	const h = 0.5;
	if (kind === 'box') g = new THREE.BoxGeometry(1, 1, 1);
	else if (kind === 'ball') g = new THREE.SphereGeometry(0.5, 18, 12);
	else if (kind === 'cyl') {
		g = new THREE.CylinderGeometry(0.5, 0.5, 1, 20);
		g.rotateZ(-Math.PI / 2); // eixo do cilindro = X (igual ao Roblox)
	} else if (kind === 'wedge') {
		// rampa sobe da frente (-Z, embaixo) para trás (+Z, em cima)
		const A = [-h, -h, -h], B = [h, -h, -h], C = [-h, -h, h], D = [h, -h, h], E = [-h, h, h], F = [h, h, h];
		g = faceGeometry([[A, B, D, C], [C, D, F, E], [A, E, F, B], [A, C, E], [B, F, D]], [0, -h / 3, h / 3]);
	} else if (kind === 'corner') {
		const P = [h, h, -h];
		g = faceGeometry(
			[
				[[-h, -h, -h], [h, -h, -h], [h, -h, h], [-h, -h, h]],
				[[-h, -h, -h], P, [h, -h, -h]],
				[[h, -h, -h], P, [h, -h, h]],
				[[h, -h, h], P, [-h, -h, h]],
				[[-h, -h, h], P, [-h, -h, -h]],
			],
			[h / 2, -h, -h / 2],
		);
	}
	GEO[kind] = g;
	return g;
}

function shapeOf(part) {
	const cls = part.ClassName;
	if (cls === 'WedgePart') return 'wedge';
	if (cls === 'CornerWedgePart') return 'corner';
	const sm = part.$mesh3;
	if (sm) {
		const t = sm._MeshType ? sm._MeshType.Name : 'Head';
		if (t === 'Sphere' || t === 'Head') return 'ellipsoid';
		if (t === 'Cylinder') return 'cyl';
		if (t === 'Wedge') return 'wedge';
		return 'box';
	}
	const sh = part._Shape ? part._Shape.Name : 'Block';
	if (sh === 'Ball') return 'ball';
	if (sh === 'Cylinder') return 'cyl';
	if (sh === 'Wedge') return 'wedge';
	if (sh === 'CornerWedge') return 'corner';
	return 'box';
}

// ------------------------------------------------------------------ materiais das peças
const _col = new THREE.Color();
function matKind(part) {
	const m = part._Material ? part._Material.Name : 'Plastic';
	if (m === 'Neon') return 'neon';
	if (m === 'ForceField') return 'ff';
	if (m === 'Glass') return 'glass';
	return 'std';
}
function makeMaterial(kind) {
	if (kind === 'neon') return new THREE.MeshBasicMaterial({ transparent: true, toneMapped: false });
	if (kind === 'ff') return new THREE.MeshBasicMaterial({ transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, toneMapped: false });
	return new THREE.MeshLambertMaterial({ transparent: true });
}
function applyLook(part, mesh) {
	const kind = matKind(part);
	if (mesh.userData.kind !== kind) {
		if (mesh.material) mesh.material.dispose();
		mesh.material = makeMaterial(kind);
		mesh.userData.kind = kind;
	}
	const mat = mesh.material;
	const c = part._Color;
	let alpha = (1 - clamp01(part._Transparency)) * (1 - clamp01(part._LocalTransparencyModifier));
	if (kind === 'neon') {
		// neon do Roblox brilha: cor mais forte
		_col.setRGB(Math.min(1, c.r * 1.25 + 0.04), Math.min(1, c.g * 1.25 + 0.04), Math.min(1, c.b * 1.25 + 0.04), THREE.SRGBColorSpace);
	} else _col.setRGB(c.r, c.g, c.b, THREE.SRGBColorSpace);
	mat.color.copy(_col);
	if (kind === 'ff') alpha *= 0.65;
	else if (kind === 'glass') alpha *= 0.82;
	mat.opacity = alpha;
	mat.depthWrite = kind !== 'ff' && alpha > 0.97;
	mesh.visible = alpha > 0.004;
}
const clamp01 = (x) => (x < 0 ? 0 : x > 1 ? 1 : x || 0);

function placePart(part, mesh) {
	const c = part._CFrame, s = part._Size;
	let sx = s.x, sy = s.y, sz = s.z;
	let ox = 0, oy = 0, oz = 0;
	const shape = mesh.userData.shape;
	if (shape === 'ball') sx = sy = sz = Math.min(sx, sy, sz);
	else if (shape === 'cyl' && !part.$mesh3) sy = sz = Math.min(sy, sz);
	const sm = part.$mesh3;
	if (sm) {
		const k = sm._Scale;
		if (k) {
			sx *= k.x;
			sy *= k.y;
			sz *= k.z;
		}
		const o = sm._Offset;
		if (o) {
			ox = o.x;
			oy = o.y;
			oz = o.z;
		}
	}
	const e = mesh.matrixWorld.elements;
	e[0] = c.m00 * sx;
	e[1] = c.m10 * sx;
	e[2] = c.m20 * sx;
	e[3] = 0;
	e[4] = c.m01 * sy;
	e[5] = c.m11 * sy;
	e[6] = c.m21 * sy;
	e[7] = 0;
	e[8] = c.m02 * sz;
	e[9] = c.m12 * sz;
	e[10] = c.m22 * sz;
	e[11] = 0;
	e[12] = c.x + c.m00 * ox + c.m01 * oy + c.m02 * oz;
	e[13] = c.y + c.m10 * ox + c.m11 * oy + c.m12 * oz;
	e[14] = c.z + c.m20 * ox + c.m21 * oy + c.m22 * oz;
	e[15] = 1;
}

function addPart(part) {
	const shape = shapeOf(part);
	const mesh = new THREE.Mesh(geo(shape === 'ellipsoid' ? 'ball' : shape));
	mesh.userData.shape = shape;
	mesh.matrixAutoUpdate = false;
	mesh.matrixWorldAutoUpdate = false;
	mesh.castShadow = false;
	mesh.receiveShadow = false;
	mesh.renderOrder = 2;
	applyLook(part, mesh);
	placePart(part, mesh);
	part.$m3 = mesh;
	S.group.add(mesh);
	S.parts.add(part);
}
function removePart(part) {
	const mesh = part.$m3;
	if (mesh) {
		S.group.remove(mesh);
		mesh.material.dispose();
		part.$m3 = null;
	}
	S.parts.delete(part);
}
function reshapePart(part) {
	const mesh = part.$m3;
	if (!mesh) return;
	const shape = shapeOf(part);
	if (shape !== mesh.userData.shape) {
		mesh.geometry = geo(shape === 'ellipsoid' ? 'ball' : shape);
		mesh.userData.shape = shape;
	}
	placePart(part, mesh);
}

// ------------------------------------------------------------------ texturas das partículas (desenhadas)
const TEXTURES = {};
function canvasTex(draw, size = 128) {
	const c = document.createElement('canvas');
	c.width = c.height = size;
	const g = c.getContext('2d');
	draw(g, size);
	const t = new THREE.CanvasTexture(c);
	t.colorSpace = THREE.NoColorSpace;
	t.generateMipmaps = true;
	t.minFilter = THREE.LinearMipmapLinearFilter;
	return t;
}
function radial(g, s, stops) {
	const r = g.createRadialGradient(s / 2, s / 2, 0, s / 2, s / 2, s / 2);
	for (const [o, c] of stops) r.addColorStop(o, c);
	g.fillStyle = r;
	g.fillRect(0, 0, s, s);
}
function texture(path) {
	const p = String(path || '').toLowerCase();
	let key = 'sparkle';
	if (p.includes('smoke')) key = 'smoke';
	else if (p.includes('fire_sparks') || p.includes('spark_')) key = 'spark';
	else if (p.includes('fire')) key = 'fire';
	else if (p.includes('vortex') || p.includes('swirl')) key = 'swirl';
	else if (p.includes('glow')) key = 'glow';
	if (TEXTURES[key]) return [key, TEXTURES[key]];
	let t;
	if (key === 'sparkle') {
		t = canvasTex((g, s) => {
			radial(g, s, [[0, 'rgba(255,255,255,1)'], [0.18, 'rgba(255,255,255,0.85)'], [0.45, 'rgba(255,255,255,0.18)'], [1, 'rgba(255,255,255,0)']]);
			g.globalCompositeOperation = 'lighter';
			for (const [w, a] of [[s * 0.5, 0], [s * 0.36, Math.PI / 4]]) {
				g.save();
				g.translate(s / 2, s / 2);
				g.rotate(a);
				const lg = g.createLinearGradient(-w, 0, w, 0);
				lg.addColorStop(0, 'rgba(255,255,255,0)');
				lg.addColorStop(0.5, 'rgba(255,255,255,0.9)');
				lg.addColorStop(1, 'rgba(255,255,255,0)');
				g.fillStyle = lg;
				g.fillRect(-w, -s * 0.022, w * 2, s * 0.044);
				g.rotate(Math.PI / 2);
				g.fillRect(-w, -s * 0.022, w * 2, s * 0.044);
				g.restore();
			}
		});
	} else if (key === 'smoke') {
		t = canvasTex((g, s) => {
			let seed = 7;
			const rnd = () => ((seed = (seed * 16807) % 2147483647) / 2147483647);
			for (let i = 0; i < 14; i++) {
				const x = s * (0.3 + rnd() * 0.4), y = s * (0.3 + rnd() * 0.4), r = s * (0.16 + rnd() * 0.2);
				const rg = g.createRadialGradient(x, y, 0, x, y, r);
				rg.addColorStop(0, 'rgba(255,255,255,0.32)');
				rg.addColorStop(1, 'rgba(255,255,255,0)');
				g.fillStyle = rg;
				g.fillRect(0, 0, s, s);
			}
		});
	} else if (key === 'fire') {
		t = canvasTex((g, s) => {
			radial(g, s, [[0, 'rgba(255,255,255,1)'], [0.25, 'rgba(255,255,255,0.8)'], [0.6, 'rgba(255,255,255,0.25)'], [1, 'rgba(255,255,255,0)']]);
		});
	} else if (key === 'spark') {
		t = canvasTex((g, s) => {
			radial(g, s, [[0, 'rgba(255,255,255,1)'], [0.12, 'rgba(255,255,255,0.95)'], [0.3, 'rgba(255,255,255,0.25)'], [0.55, 'rgba(255,255,255,0)'], [1, 'rgba(255,255,255,0)']]);
		}, 64);
	} else if (key === 'glow') {
		t = canvasTex((g, s) => {
			radial(g, s, [[0, 'rgba(255,255,255,0.9)'], [0.4, 'rgba(255,255,255,0.45)'], [0.8, 'rgba(255,255,255,0.1)'], [1, 'rgba(255,255,255,0)']]);
		});
	} else {
		t = canvasTex((g, s) => {
			g.translate(s / 2, s / 2);
			for (let arm = 0; arm < 3; arm++) {
				for (let i = 0; i < 60; i++) {
					const u = i / 60;
					const a = arm * ((Math.PI * 2) / 3) + u * 4.2;
					const r = u * s * 0.46;
					g.fillStyle = `rgba(255,255,255,${0.55 * (1 - u) * Math.min(1, u * 6)})`;
					g.beginPath();
					g.arc(Math.cos(a) * r, Math.sin(a) * r, s * 0.035 * (1.2 - u), 0, Math.PI * 2);
					g.fill();
				}
			}
		});
	}
	TEXTURES[key] = t;
	return [key, t];
}

// ------------------------------------------------------------------ partículas
const PVS = `
attribute vec3 iPos;
attribute vec2 iSR;
attribute vec4 iCol;
varying vec2 vUv;
varying vec4 vCol;
#include <fog_pars_vertex>
void main() {
	vUv = uv;
	vCol = iCol;
	vec4 mvPosition = modelViewMatrix * vec4(iPos, 1.0);
	float c = cos(iSR.y), s = sin(iSR.y);
	vec2 p = position.xy * iSR.x;
	mvPosition.xy += vec2(p.x * c - p.y * s, p.x * s + p.y * c);
	gl_Position = projectionMatrix * mvPosition;
	#include <fog_vertex>
}`;
const PFS = `
uniform sampler2D map;
varying vec2 vUv;
varying vec4 vCol;
#include <fog_pars_fragment>
void main() {
	vec4 t = texture2D(map, vUv);
	gl_FragColor = vec4(vCol.rgb * t.rgb, vCol.a * t.a);
	if (gl_FragColor.a < 0.003) discard;
	#include <fog_fragment>
}`;

const MAXP = 5000;
const particles = [];
class Batch {
	constructor(tex, additive, cap = 2048) {
		this.cap = cap;
		const g = new THREE.InstancedBufferGeometry();
		g.setAttribute('position', new THREE.Float32BufferAttribute([-0.5, -0.5, 0, 0.5, -0.5, 0, 0.5, 0.5, 0, -0.5, 0.5, 0], 3));
		g.setAttribute('uv', new THREE.Float32BufferAttribute([0, 0, 1, 0, 1, 1, 0, 1], 2));
		g.setIndex([0, 1, 2, 0, 2, 3]);
		this.pos = new Float32Array(cap * 3);
		this.sr = new Float32Array(cap * 2);
		this.col = new Float32Array(cap * 4);
		this.aPos = new THREE.InstancedBufferAttribute(this.pos, 3).setUsage(THREE.DynamicDrawUsage);
		this.aSR = new THREE.InstancedBufferAttribute(this.sr, 2).setUsage(THREE.DynamicDrawUsage);
		this.aCol = new THREE.InstancedBufferAttribute(this.col, 4).setUsage(THREE.DynamicDrawUsage);
		g.setAttribute('iPos', this.aPos);
		g.setAttribute('iSR', this.aSR);
		g.setAttribute('iCol', this.aCol);
		g.instanceCount = 0;
		this.geo = g;
		this.mat = new THREE.ShaderMaterial({
			uniforms: THREE.UniformsUtils.merge([THREE.UniformsLib.fog, { map: { value: tex } }]),
			vertexShader: PVS,
			fragmentShader: PFS,
			transparent: true,
			depthWrite: false,
			fog: true,
			blending: additive ? THREE.AdditiveBlending : THREE.NormalBlending,
		});
		this.mat.uniforms.map.value = tex;
		this.mesh = new THREE.Mesh(g, this.mat);
		this.mesh.frustumCulled = false;
		this.mesh.renderOrder = additive ? 12 : 11;
		this.n = 0;
	}
}
const batches = new Map();
function batchFor(texPath, lightEmission) {
	const [key, tex] = texture(texPath);
	const additive = lightEmission >= 0.5;
	const id = key + (additive ? '+' : '');
	let b = batches.get(id);
	if (!b) {
		b = new Batch(tex, additive);
		batches.set(id, b);
		S.group.add(b.mesh);
	}
	return b;
}

const _v = new THREE.Vector3();
const _d = new THREE.Vector3();
const _a1 = new THREE.Vector3();
const _a2 = new THREE.Vector3();
const DIRS = { Top: [0, 1, 0], Bottom: [0, -1, 0], Front: [0, 0, -1], Back: [0, 0, 1], Right: [1, 0, 0], Left: [-1, 0, 0] };

function emitterFrame(e) {
	// CFrame e tamanho de onde as partículas saem
	const p = e._parent;
	if (!p) return null;
	if (p instanceof Attachment) return { cf: p.WorldCFrame, size: null };
	if (p instanceof BasePart) return { cf: p.CFrame, size: p.Size };
	return null;
}

function rotateAround(v, axis, ang) {
	return v.applyAxisAngle(axis, ang);
}

function emit(e, n) {
	if (n <= 0 || !e._parent) return;
	const fr = emitterFrame(e);
	if (!fr) return;
	const cf = fr.cf;
	const room = MAXP - particles.length;
	if (room <= 0) return;
	n = Math.min(n, room);
	const b = batchFor(e._Texture, e._LightEmission);
	const dirName = e._EmissionDirection ? e._EmissionDirection.Name : 'Top';
	const base = DIRS[dirName] || DIRS.Top;
	const shape = e._Shape ? e._Shape.Name : 'Box';
	const surface = e._ShapeStyle && e._ShapeStyle.Name === 'Surface';
	const inout = e._ShapeInOut ? e._ShapeInOut.Name : 'Outward';
	const spread = e._SpreadAngle;
	const sx = spread ? (spread.x * Math.PI) / 180 : 0, sy = spread ? (spread.y * Math.PI) / 180 : 0;
	const life = e._Lifetime, speed = e._Speed, rot = e._Rotation, rs = e._RotSpeed;
	const acc = e._Acceleration;
	const parent = e._parent;
	for (let i = 0; i < n; i++) {
		// ponto de saída (no espaço do pai)
		let lx = 0, ly = 0, lz = 0;
		let nx = base[0], ny = base[1], nz = base[2];
		if (fr.size) {
			const hx = fr.size.x / 2, hy = fr.size.y / 2, hz = fr.size.z / 2;
			if (shape === 'Sphere') {
				let x, y, z, l;
				do {
					x = Math.random() * 2 - 1;
					y = Math.random() * 2 - 1;
					z = Math.random() * 2 - 1;
					l = x * x + y * y + z * z;
				} while (l > 1 || l < 1e-6);
				l = Math.sqrt(l);
				const k = surface ? 1 / l : 1;
				lx = x * k * hx;
				ly = y * k * hy;
				lz = z * k * hz;
				nx = x / l;
				ny = y / l;
				nz = z / l;
				if (inout === 'Inward' || (inout === 'InAndOut' && Math.random() < 0.5)) {
					nx = -nx;
					ny = -ny;
					nz = -nz;
				}
			} else if (shape === 'Cylinder' || shape === 'Disc') {
				const a = Math.random() * Math.PI * 2;
				const r = surface ? 1 : Math.sqrt(Math.random());
				const cx = Math.cos(a), cz = Math.sin(a);
				lx = cx * r * hx;
				lz = cz * r * hz;
				ly = shape === 'Disc' ? 0 : (Math.random() * 2 - 1) * hy;
				nx = cx;
				ny = 0;
				nz = cz;
				if (inout === 'Inward') {
					nx = -nx;
					nz = -nz;
				}
			} else {
				lx = (Math.random() * 2 - 1) * hx;
				ly = (Math.random() * 2 - 1) * hy;
				lz = (Math.random() * 2 - 1) * hz;
				if (surface) {
					const axis = Math.floor(Math.random() * 3);
					const sg = Math.random() < 0.5 ? -1 : 1;
					if (axis === 0) lx = sg * hx;
					else if (axis === 1) ly = sg * hy;
					else lz = sg * hz;
				}
			}
		}
		// direção com o espalhamento (SpreadAngle)
		_d.set(nx, ny, nz);
		if (sx || sy) {
			_a1.set(ny, nz, nx);
			if (Math.abs(_a1.dot(_d)) > 0.9) _a1.set(nz, nx, ny);
			_a1.cross(_d).normalize();
			_a2.copy(_d).cross(_a1).normalize();
			if (sx) rotateAround(_d, _a1, (Math.random() * 2 - 1) * sx);
			if (sy) rotateAround(_d, _a2, (Math.random() * 2 - 1) * sy);
		}
		// para o mundo
		const wx = cf.x + cf.m00 * lx + cf.m01 * ly + cf.m02 * lz;
		const wy = cf.y + cf.m10 * lx + cf.m11 * ly + cf.m12 * lz;
		const wz = cf.z + cf.m20 * lx + cf.m21 * ly + cf.m22 * lz;
		const dx = cf.m00 * _d.x + cf.m01 * _d.y + cf.m02 * _d.z;
		const dy = cf.m10 * _d.x + cf.m11 * _d.y + cf.m12 * _d.z;
		const dz = cf.m20 * _d.x + cf.m21 * _d.y + cf.m22 * _d.z;
		const sp = speed.Min + Math.random() * (speed.Max - speed.Min);
		const lf = Math.max(0.02, life.Min + Math.random() * (life.Max - life.Min));
		particles.push({
			e,
			b,
			x: wx,
			y: wy,
			z: wz,
			vx: dx * sp,
			vy: dy * sp,
			vz: dz * sp,
			ax: acc.x,
			ay: acc.y,
			az: acc.z,
			drag: e._Drag || 0,
			age: 0,
			life: lf,
			rot: ((rot.Min + Math.random() * (rot.Max - rot.Min)) * Math.PI) / 180,
			rs: ((rs.Min + Math.random() * (rs.Max - rs.Min)) * Math.PI) / 180,
			size: e._Size,
			tr: e._Transparency,
			col: e._Color,
			lock: e._LockedToPart ? parent : null,
			lx: e._LockedToPart ? cf.x : 0,
			ly: e._LockedToPart ? cf.y : 0,
			lz: e._LockedToPart ? cf.z : 0,
		});
	}
}

const _rgb = [1, 1, 1];
function stepParticles(dt) {
	// emissores ligados (Rate)
	for (const e of S.emitters) {
		if (!e._Enabled || !(e._Rate > 0) || !e.$inWorld) continue;
		e.$acc += e._Rate * dt;
		const n = Math.floor(e.$acc);
		if (n > 0) {
			e.$acc -= n;
			emit(e, Math.min(n, 60));
		}
	}
	for (const b of batches.values()) b.n = 0;
	let w = 0;
	for (let i = 0; i < particles.length; i++) {
		const p = particles[i];
		p.age += dt;
		if (p.age >= p.life || !p.e.$inWorld) continue;
		p.vx += p.ax * dt;
		p.vy += p.ay * dt;
		p.vz += p.az * dt;
		if (p.drag) {
			const k = Math.pow(2, -p.drag * dt);
			p.vx *= k;
			p.vy *= k;
			p.vz *= k;
		}
		p.x += p.vx * dt;
		p.y += p.vy * dt;
		p.z += p.vz * dt;
		p.rot += p.rs * dt;
		let ox = 0, oy = 0, oz = 0;
		if (p.lock) {
			const fr = p.lock instanceof Attachment ? p.lock.WorldCFrame : p.lock.CFrame;
			if (fr) {
				ox = fr.x - p.lx;
				oy = fr.y - p.ly;
				oz = fr.z - p.lz;
			}
		}
		particles[w++] = p;
		const b = p.b;
		if (b.n >= b.cap) continue;
		const u = p.age / p.life;
		const j = b.n++;
		b.pos[j * 3] = p.x + ox;
		b.pos[j * 3 + 1] = p.y + oy;
		b.pos[j * 3 + 2] = p.z + oz;
		b.sr[j * 2] = Math.max(0, p.size.at(u));
		b.sr[j * 2 + 1] = p.rot;
		p.col.at(u, _rgb);
		b.col[j * 4] = _rgb[0];
		b.col[j * 4 + 1] = _rgb[1];
		b.col[j * 4 + 2] = _rgb[2];
		b.col[j * 4 + 3] = Math.max(0, Math.min(1, 1 - p.tr.at(u)));
	}
	particles.length = w;
	for (const b of batches.values()) {
		b.geo.instanceCount = b.n;
		if (b.n) {
			b.aPos.needsUpdate = true;
			b.aSR.needsUpdate = true;
			b.aCol.needsUpdate = true;
			b.aPos.addUpdateRange(0, b.n * 3);
			b.aSR.addUpdateRange(0, b.n * 2);
			b.aCol.addUpdateRange(0, b.n * 4);
		}
		b.mesh.visible = b.n > 0;
	}
}

// ------------------------------------------------------------------ rastros (Trail)
const MAXT = 48;
const toLinear = (c) => (c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4));
function addTrail(t) {
	const g = new THREE.BufferGeometry();
	const pos = new Float32Array(MAXT * 2 * 3);
	const col = new Float32Array(MAXT * 2 * 4);
	g.setAttribute('position', new THREE.BufferAttribute(pos, 3).setUsage(THREE.DynamicDrawUsage));
	g.setAttribute('color', new THREE.BufferAttribute(col, 4).setUsage(THREE.DynamicDrawUsage));
	const idx = [];
	for (let i = 0; i < MAXT - 1; i++) {
		const a = i * 2;
		idx.push(a, a + 1, a + 2, a + 1, a + 3, a + 2);
	}
	g.setIndex(idx);
	g.setDrawRange(0, 0);
	const mat = new THREE.MeshBasicMaterial({ vertexColors: true, transparent: true, depthWrite: false, side: THREE.DoubleSide, toneMapped: false });
	const mesh = new THREE.Mesh(g, mat);
	mesh.frustumCulled = false;
	mesh.renderOrder = 10;
	S.group.add(mesh);
	t.$tr = { mesh, pos, col, pts: [], last: null };
	S.trails.add(t);
}
function removeTrail(t) {
	if (t.$tr) {
		S.group.remove(t.$tr.mesh);
		t.$tr.mesh.geometry.dispose();
		t.$tr.mesh.material.dispose();
		t.$tr = null;
	}
	S.trails.delete(t);
}
const _p0 = new THREE.Vector3();
const _p1 = new THREE.Vector3();
function stepTrails() {
	const now = S.time;
	for (const t of S.trails) {
		const tr = t.$tr;
		if (!tr) continue;
		const a0 = t._Attachment0, a1 = t._Attachment1;
		const life = Math.max(0.02, t._Lifetime || 0.5);
		const ok = a0 && a1 && a0.$inWorld && a1.$inWorld;
		if (ok && t._Enabled) {
			const w0 = a0.WorldPosition, w1 = a1.WorldPosition;
			const cx = (w0.x + w1.x) / 2, cy = (w0.y + w1.y) / 2, cz = (w0.z + w1.z) / 2;
			const last = tr.pts[tr.pts.length - 1];
			const moved = !last || Math.hypot(cx - last.cx, cy - last.cy, cz - last.cz) >= Math.max(0.05, t._MinLength || 0.1);
			const head = { cx, cy, cz, hx: (w1.x - w0.x) / 2, hy: (w1.y - w0.y) / 2, hz: (w1.z - w0.z) / 2, t: now };
			if (moved || !last) tr.pts.push(head);
			else Object.assign(last, head);
			if (tr.pts.length > MAXT) tr.pts.shift();
		}
		while (tr.pts.length && now - tr.pts[0].t > life) tr.pts.shift();
		const n = tr.pts.length;
		const mat = tr.mesh.material;
		mat.blending = t._LightEmission >= 0.5 ? THREE.AdditiveBlending : THREE.NormalBlending;
		if (n < 2) {
			tr.mesh.geometry.setDrawRange(0, 0);
			continue;
		}
		const cam = S.camPos;
		for (let i = 0; i < n; i++) {
			const p = tr.pts[i];
			const u = Math.min(1, (now - p.t) / life);
			const ws = t._WidthScale ? t._WidthScale.at(u) : 1;
			let ox = p.hx * ws, oy = p.hy * ws, oz = p.hz * ws;
			if (t._FaceCamera) {
				const q = tr.pts[Math.min(n - 1, i + 1)], r = tr.pts[Math.max(0, i - 1)];
				_d.set(q.cx - r.cx, q.cy - r.cy, q.cz - r.cz);
				_v.set(cam.x - p.cx, cam.y - p.cy, cam.z - p.cz);
				_d.cross(_v);
				const l = _d.length() || 1;
				const half = Math.hypot(p.hx, p.hy, p.hz) * ws;
				ox = (_d.x / l) * half;
				oy = (_d.y / l) * half;
				oz = (_d.z / l) * half;
			}
			tr.pos.set([p.cx - ox, p.cy - oy, p.cz - oz, p.cx + ox, p.cy + oy, p.cz + oz], i * 6);
			t._Color.at(u, _rgb);
			const r = toLinear(_rgb[0]), g = toLinear(_rgb[1]), b = toLinear(_rgb[2]);
			const a = Math.max(0, Math.min(1, 1 - (t._Transparency ? t._Transparency.at(u) : 0)));
			tr.col.set([r, g, b, a, r, g, b, a], i * 8);
		}
		const gg = tr.mesh.geometry;
		gg.attributes.position.needsUpdate = true;
		gg.attributes.color.needsUpdate = true;
		gg.setDrawRange(0, (n - 1) * 6);
	}
}

// ------------------------------------------------------------------ luzes (brilho + algumas luzes de verdade)
let glowTex = null;
function addLight(l) {
	if (!glowTex) glowTex = texture('glow')[1];
	const s = new THREE.Sprite(new THREE.SpriteMaterial({ map: glowTex, blending: THREE.AdditiveBlending, depthWrite: false, transparent: true, toneMapped: false }));
	s.renderOrder = 13;
	S.group.add(s);
	l.$sp = s;
	S.lights.add(l);
}
function removeLight(l) {
	if (l.$sp) {
		S.group.remove(l.$sp);
		l.$sp.material.dispose();
		l.$sp = null;
	}
	S.lights.delete(l);
}
function lightPos(l) {
	const p = l._parent;
	if (!p) return null;
	if (p instanceof Attachment) return p.WorldPosition;
	if (p instanceof BasePart) return p.Position;
	return null;
}
const _lightList = [];
function stepLights() {
	_lightList.length = 0;
	for (const l of S.lights) {
		const sp = l.$sp;
		const pos = lightPos(l);
		if (!pos || !l._Enabled || !(l._Brightness > 0.01)) {
			sp.visible = false;
			continue;
		}
		sp.visible = true;
		sp.position.set(pos.x, pos.y, pos.z);
		const range = Math.min(l._Range || 8, 40);
		sp.scale.setScalar(range * 0.75);
		const c = l._Color;
		sp.material.color.setRGB(c.r, c.g, c.b, THREE.SRGBColorSpace);
		sp.material.opacity = Math.min(0.42, l._Brightness * 0.07);
		_lightList.push({ l, pos, d: pos.distanceToSquared ? 0 : (pos.x - S.camPos.x) ** 2 + (pos.y - S.camPos.y) ** 2 + (pos.z - S.camPos.z) ** 2 });
	}
	// as mais fortes e perto da câmera viram luz de verdade
	if (S.realLights.length) {
		_lightList.sort((a, b) => b.l._Brightness * b.l._Range / (1 + b.d * 0.002) - a.l._Brightness * a.l._Range / (1 + a.d * 0.002));
		for (let i = 0; i < S.realLights.length; i++) {
			const rl = S.realLights[i];
			const it = _lightList[i];
			if (!it) {
				rl.intensity = 0;
				continue;
			}
			const c = it.l._Color;
			rl.color.setRGB(c.r, c.g, c.b, THREE.SRGBColorSpace);
			rl.position.set(it.pos.x, it.pos.y, it.pos.z);
			rl.distance = Math.min(60, it.l._Range || 8);
			rl.intensity = Math.min(40, it.l._Brightness * 9);
		}
	}
}

// ------------------------------------------------------------------ destaque (Highlight) no cachorro
function highlightTarget(h) {
	const a = h._Adornee || h._parent;
	if (a && a.$fighter) return a;
	return null;
}
function addHighlight(h) {
	S.highlights.add(h);
	refreshHighlight(h);
}
function removeHighlight(h) {
	if (h.$ov) {
		h.$ov.removeFromParent();
		h.$ov.material.dispose();
		h.$ov = null;
	}
	S.highlights.delete(h);
}
function refreshHighlight(h) {
	const target = highlightTarget(h);
	const rig = target && target.$fighter && target.$fighter.rig;
	if (!rig) {
		if (h.$ov) h.$ov.visible = false;
		return;
	}
	if (!h.$ov || h.$ov.userData.rig !== rig) {
		if (h.$ov) {
			h.$ov.removeFromParent();
			h.$ov.material.dispose();
		}
		const mat = new THREE.MeshBasicMaterial({ transparent: true, depthWrite: false, polygonOffset: true, polygonOffsetFactor: -2, polygonOffsetUnits: -2, toneMapped: false });
		const ov = new THREE.SkinnedMesh(rig.mesh.geometry, mat);
		ov.bind(rig.mesh.skeleton, new THREE.Matrix4());
		ov.userData.rig = rig;
		ov.renderOrder = 3;
		ov.frustumCulled = false;
		rig.mesh.add(ov);
		h.$ov = ov;
	}
	const c = h._FillColor;
	h.$ov.material.color.setRGB(c.r, c.g, c.b, THREE.SRGBColorSpace);
	const a = h._Enabled ? 1 - clamp01(h._FillTransparency) : 0;
	h.$ov.material.opacity = a * 0.85;
	h.$ov.material.depthTest = !(h._DepthMode && h._DepthMode.Name === 'AlwaysOnTop');
	h.$ov.visible = a > 0.01;
}

// ------------------------------------------------------------------ textos flutuantes (BillboardGui → HTML)
const FONTS = {
	LuckiestGuy: '"Luckiest Guy", "Fredoka One", sans-serif',
	FredokaOne: '"Fredoka One", sans-serif',
	Cartoon: '"Fredoka One", sans-serif',
	Bangers: '"Luckiest Guy", sans-serif',
};
const css = (c, a = 1) => `rgba(${Math.round(c.r * 255)},${Math.round(c.g * 255)},${Math.round(c.b * 255)},${a})`;
function addGui(g) {
	const root = document.createElement('div');
	root.className = 'rbx-bb';
	root.style.cssText = 'position:absolute;left:0;top:0;pointer-events:none;will-change:transform;';
	S.ui.appendChild(root);
	g.$dom = root;
	g.$domDirty = true;
	S.guis.add(g);
}
function removeGui(g) {
	if (g.$dom) g.$dom.remove();
	g.$dom = null;
	S.guis.delete(g);
}
function guiOf(inst) {
	for (let a = inst; a; a = a._parent) if (a instanceof BillboardGui) return a;
	return null;
}
function udim(u, size) {
	return u.Offset + u.Scale * size;
}
function buildGuiDom(g, w, h) {
	const root = g.$dom;
	root.innerHTML = '';
	root.style.width = w + 'px';
	root.style.height = h + 'px';
	const make = (inst, parentEl, pw, ph) => {
		for (const k of inst.$kids) {
			if (!(k instanceof GuiObject) || !k._Visible) continue;
			const el = document.createElement('div');
			const kw = udim(k._Size.X, pw), kh = udim(k._Size.Y, ph);
			const kx = udim(k._Position.X, pw), ky = udim(k._Position.Y, ph);
			let scale = 1;
			let stroke = null, gradient = null, corner = null;
			for (const c of k.$kids) {
				if (!(c instanceof UIComponent) || c._Enabled === false) continue;
				if (c.ClassName === 'UIScale') scale *= c._Scale;
				else if (c.ClassName === 'UIStroke') stroke = c;
				else if (c.ClassName === 'UIGradient') gradient = c;
				else if (c.ClassName === 'UICorner') corner = c;
			}
			const ap = k._AnchorPoint;
			const st = el.style;
			st.position = 'absolute';
			st.left = kx + 'px';
			st.top = ky + 'px';
			st.width = kw + 'px';
			st.height = kh + 'px';
			st.transform = `translate(${-ap.x * 100}%, ${-ap.y * 100}%) rotate(${k._Rotation || 0}deg) scale(${scale})`;
			st.transformOrigin = '50% 50%';
			st.boxSizing = 'border-box';
			if (k._BackgroundTransparency < 1) st.background = css(k._BackgroundColor3, 1 - k._BackgroundTransparency);
			if (corner) st.borderRadius = `${udim(corner._CornerRadius, Math.min(kw, kh))}px`;
			if (k.ClassName === 'TextLabel' || k.ClassName === 'TextButton' || k.ClassName === 'TextBox') {
				const text = k._Text || '';
				const font = FONTS[k._Font && k._Font.Name] || '"Fredoka One", sans-serif';
				let fs = k._TextSize || 14;
				if (k._TextScaled) {
					const lines = String(text).split('\n');
					const longest = Math.max(1, ...lines.map((l) => [...l].length));
					fs = Math.max(4, Math.min((kh / lines.length) * 0.92, kw / (longest * 0.6)));
				}
				st.display = 'flex';
				st.alignItems = 'center';
				st.justifyContent = 'center';
				st.fontFamily = font;
				st.fontSize = fs + 'px';
				st.lineHeight = '1';
				st.whiteSpace = 'pre';
				st.textAlign = 'center';
				const ta = 1 - clamp01(k._TextTransparency);
				st.color = css(k._TextColor3, ta);
				const shadows = [];
				if (stroke && stroke._Transparency < 1) {
					const t = Math.max(1, stroke._Thickness || 1);
					const sc = css(stroke._Color, (1 - clamp01(stroke._Transparency)) * ta);
					for (let i = 0; i < 12; i++) {
						const a = (i / 12) * Math.PI * 2;
						shadows.push(`${(Math.cos(a) * t).toFixed(1)}px ${(Math.sin(a) * t).toFixed(1)}px 0 ${sc}`);
					}
				} else if (k._TextStrokeTransparency < 1) {
					const sc = css(k._TextStrokeColor3, (1 - k._TextStrokeTransparency) * ta);
					for (const [x, y] of [[1, 1], [-1, 1], [1, -1], [-1, -1]]) shadows.push(`${x}px ${y}px 0 ${sc}`);
				}
				if (shadows.length) st.textShadow = shadows.join(',');
				if (gradient && gradient._Color) {
					const kp = gradient._Color.Keypoints || [];
					const stops = kp.map((p) => `${css(p.Value)} ${(p.Time * 100).toFixed(0)}%`).join(',');
					st.backgroundImage = `linear-gradient(${90 + (gradient._Rotation || 0)}deg, ${stops})`;
					st.webkitBackgroundClip = 'text';
					st.backgroundClip = 'text';
					st.color = 'transparent';
					if (shadows.length) st.filter = `drop-shadow(0 0 ${Math.max(1, (stroke && stroke._Thickness) || 1)}px ${css(stroke ? stroke._Color : k._TextStrokeColor3)})`, (st.textShadow = '');
				}
				el.textContent = text;
			} else if (gradient && gradient._Color && k._BackgroundTransparency < 1) {
				const kp = gradient._Color.Keypoints || [];
				st.background = `linear-gradient(${90 + (gradient._Rotation || 0)}deg, ${kp.map((p) => `${css(p.Value, 1 - k._BackgroundTransparency)} ${(p.Time * 100).toFixed(0)}%`).join(',')})`;
			}
			if (stroke && k.ClassName === 'Frame') st.border = `${stroke._Thickness}px solid ${css(stroke._Color, 1 - stroke._Transparency)}`;
			parentEl.appendChild(el);
			make(k, el, kw, kh);
		}
	};
	make(g, root, w, h);
}
const _proj = new THREE.Vector3();
function guiAnchor(g) {
	const a = g._Adornee || g._parent;
	if (!a) return null;
	if (a instanceof Attachment) return a.WorldPosition;
	if (a instanceof BasePart) return a.Position;
	if (a instanceof Model) {
		const pp = a.PrimaryPart;
		return pp ? pp.Position : null;
	}
	return null;
}
function stepGuis() {
	const cam = S.camera;
	const W = S.renderer.domElement.clientWidth || window.innerWidth;
	const H = S.renderer.domElement.clientHeight || window.innerHeight;
	const tanHalf = Math.tan((cam.fov * Math.PI) / 360);
	for (const g of S.guis) {
		const el = g.$dom;
		if (!el) continue;
		const pos = g._Enabled ? guiAnchor(g) : null;
		if (!pos) {
			el.style.display = 'none';
			continue;
		}
		const off = g._StudsOffsetWorldSpace;
		_proj.set(pos.x + off.x, pos.y + off.y, pos.z + off.z);
		const so = g._StudsOffset;
		if (so && (so.x || so.y || so.z)) {
			// deslocamento no espaço da câmera
			const e = cam.matrixWorld.elements;
			_proj.x += e[0] * so.x + e[4] * so.y + e[8] * so.z;
			_proj.y += e[1] * so.x + e[5] * so.y + e[9] * so.z;
			_proj.z += e[2] * so.x + e[6] * so.y + e[10] * so.z;
		}
		const dist = _proj.distanceTo(S.camPos);
		if (dist > (g._MaxDistance || Infinity)) {
			el.style.display = 'none';
			continue;
		}
		_proj.project(cam);
		if (_proj.z > 1 || _proj.z < -1) {
			el.style.display = 'none';
			continue;
		}
		const pxPerStud = H / (2 * Math.max(0.1, dist) * tanHalf);
		const w = udim(g._Size.X, pxPerStud), h = udim(g._Size.Y, pxPerStud);
		if (g.$domDirty || Math.abs(w - (g.$w || 0)) > 0.5 || Math.abs(h - (g.$h || 0)) > 0.5) {
			g.$domDirty = false;
			g.$w = w;
			g.$h = h;
			try {
				buildGuiDom(g, w, h);
			} catch (e) {
				reportError(e, 'BillboardGui');
			}
		}
		const sx = (_proj.x * 0.5 + 0.5) * W, sy = (-_proj.y * 0.5 + 0.5) * H;
		const so2 = g._SizeOffset;
		el.style.display = '';
		el.style.transform = `translate(${(sx - w / 2 + (so2 ? so2.x * w : 0)).toFixed(1)}px, ${(sy - h / 2 - (so2 ? so2.y * h : 0)).toFixed(1)}px)`;
	}
}

// ------------------------------------------------------------------ efeitos de tela (ColorCorrectionEffect)
function stepPost() {
	let br = 0, ct = 0, sat = 0, blur = 0;
	let tr = 1, tg = 1, tb = 1;
	for (const p of S.post) {
		if (!p._Enabled || !p.$inWorld) continue;
		if (p.ClassName === 'ColorCorrectionEffect') {
			br += p._Brightness || 0;
			ct += p._Contrast || 0;
			sat += p._Saturation || 0;
			const t = p._TintColor;
			if (t) {
				tr *= t.r;
				tg *= t.g;
				tb *= t.b;
			}
		} else if (p.ClassName === 'BlurEffect') blur += p._Size || 0;
	}
	const filter = `${br ? `brightness(${(1 + br).toFixed(3)}) ` : ''}${ct ? `contrast(${(1 + ct).toFixed(3)}) ` : ''}${sat ? `saturate(${Math.max(0, 1 + sat).toFixed(3)}) ` : ''}${blur ? `blur(${(blur / 10).toFixed(1)}px)` : ''}`;
	const tint = tr < 0.995 || tg < 0.995 || tb < 0.995 ? `rgb(${Math.round(tr * 255)},${Math.round(tg * 255)},${Math.round(tb * 255)})` : '';
	const key = filter + '|' + tint;
	if (key === S.postKey) return;
	S.postKey = key;
	S.renderer.domElement.style.filter = filter.trim();
	if (!S.tintEl) {
		const d = document.createElement('div');
		d.style.cssText = 'position:absolute;inset:0;pointer-events:none;mix-blend-mode:multiply;z-index:0;';
		S.renderer.domElement.parentElement.appendChild(d);
		S.tintEl = d;
	}
	S.tintEl.style.background = tint || 'transparent';
	S.tintEl.style.display = tint ? '' : 'none';
}

// ------------------------------------------------------------------ ganchos
HOOK.enter = (inst) => {
	try {
		if (inst instanceof BasePart) {
			if (!inst.$proxy && inst.ClassName !== 'Terrain') {
				// malha especial (SpecialMesh) já dentro da peça
				for (const k of inst.$kids) if (k instanceof SpecialMesh) inst.$mesh3 = k;
				addPart(inst);
			}
		} else if (inst instanceof ParticleEmitter) S.emitters.add(inst);
		else if (inst instanceof Trail) addTrail(inst);
		else if (inst instanceof Light) addLight(inst);
		else if (inst instanceof Highlight) addHighlight(inst);
		else if (inst instanceof BillboardGui) addGui(inst);
		else if (inst instanceof PostEffect) S.post.add(inst);
		else if (inst instanceof SpecialMesh) {
			const p = inst._parent;
			if (p instanceof BasePart) {
				p.$mesh3 = inst;
				reshapePart(p);
			}
		} else if (inst instanceof GuiObject || inst instanceof UIComponent) {
			const g = guiOf(inst);
			if (g) g.$domDirty = true;
		}
	} catch (e) {
		reportError(e, 'enter ' + inst.ClassName);
	}
};
HOOK.leave = (inst) => {
	try {
		if (inst instanceof BasePart) removePart(inst);
		else if (inst instanceof ParticleEmitter) S.emitters.delete(inst);
		else if (inst instanceof Trail) removeTrail(inst);
		else if (inst instanceof Light) removeLight(inst);
		else if (inst instanceof Highlight) removeHighlight(inst);
		else if (inst instanceof BillboardGui) removeGui(inst);
		else if (inst instanceof PostEffect) S.post.delete(inst);
		else if (inst instanceof SpecialMesh) {
			const p = inst._parent;
			if (p && p.$mesh3 === inst) {
				p.$mesh3 = null;
				reshapePart(p);
			}
		} else if (inst instanceof GuiObject || inst instanceof UIComponent) {
			const g = guiOf(inst);
			if (g) g.$domDirty = true;
		}
	} catch (e) {
		reportError(e, 'leave ' + inst.ClassName);
	}
};
HOOK.dirty = (inst, bits) => {
	if (inst instanceof BasePart) {
		if (inst.$m3) S.dirty.set(inst, (S.dirty.get(inst) || 0) | bits);
	} else if (inst instanceof SpecialMesh) {
		const p = inst._parent;
		if (p instanceof BasePart && p.$m3) S.dirty.set(p, (S.dirty.get(p) || 0) | 4);
	} else if (inst instanceof Highlight) refreshHighlight(inst);
	else if (inst instanceof GuiObject || inst instanceof UIComponent || inst instanceof BillboardGui) {
		const g = guiOf(inst);
		if (g) g.$domDirty = true;
	} else if ((inst instanceof Trail) && bits & 8 && inst.$tr) inst.$tr.pts.length = 0;
	else if (inst instanceof ParticleEmitter && bits & 8) {
		for (const p of particles) if (p.e === inst) p.age = p.life;
	}
};
HOOK.emit = (e, n) => {
	try {
		emit(e, n);
	} catch (err) {
		reportError(err, 'Emit');
	}
};

// ------------------------------------------------------------------ início, quadro e limpeza
export function initCena({ scene, camera, renderer, ui, quality = 1, realLights = 4 }) {
	S.scene = scene;
	S.camera = camera;
	S.renderer = renderer;
	S.ui = document.createElement('div');
	S.ui.className = 'rbx-gui';
	S.ui.style.cssText = 'position:absolute;inset:0;overflow:hidden;pointer-events:none;';
	ui.prepend(S.ui);
	S.group = new THREE.Group();
	S.group.name = 'rbx';
	S.group.matrixAutoUpdate = false;
	scene.add(S.group);
	S.quality = quality;
	for (let i = 0; i < realLights; i++) {
		const l = new THREE.PointLight('#ffffff', 0, 20, 1.6);
		l.castShadow = false;
		scene.add(l);
		S.realLights.push(l);
	}
}

export function setCenaQuality(q) {
	S.quality = q;
}

// depois do Lua rodar (RenderStepped/Heartbeat): atualiza o desenho
export function frameCena(dt) {
	S.time += dt;
	S.camPos.setFromMatrixPosition(S.camera.matrixWorld);
	for (const [part, bits] of S.dirty) {
		const mesh = part.$m3;
		if (!mesh) continue;
		if (bits & 4) reshapePart(part);
		else if (bits & 1) placePart(part, mesh);
		if (bits & 2) applyLook(part, mesh);
	}
	S.dirty.clear();
	stepParticles(dt);
	stepTrails();
	stepLights();
	for (const h of S.highlights) if (h.$ov) {
		const t = highlightTarget(h);
		if (!t || !t.$fighter || t.$fighter.rig.mesh !== h.$ov.parent) refreshHighlight(h);
	}
	stepGuis();
	stepPost();
}

export function cenaStats() {
	return { parts: S.parts.size, particles: particles.length, trails: S.trails.size, lights: S.lights.size, guis: S.guis.size };
}

export function clearParticles() {
	particles.length = 0;
}
