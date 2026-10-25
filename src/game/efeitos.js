// Efeitos visuais: quadradinhos voando (poeira, faíscas, sangue de brinquedo), anéis de onda de choque,
// riscos de unha, números de dano e textos que sobem (+XP, SUPER!, MISS).
// Tudo de cubinhos, no estilo de blocos do jogo. Partículas usam UMA malha só (InstancedMesh) = leve.
import * as THREE from 'three';
import { R } from '../core/render.js';

const MAX = 2600;
const _m = new THREE.Matrix4();
const _q = new THREE.Quaternion();
const _s = new THREE.Vector3();
const _p = new THREE.Vector3();
const _e = new THREE.Euler();
const _c = new THREE.Color();
const _v = new THREE.Vector3();

export class Effects {
	constructor(scene, uiRoot) {
		this.scene = scene;
		const geo = new THREE.BoxGeometry(1, 1, 1);
		this.cubes = new THREE.InstancedMesh(geo, new THREE.MeshBasicMaterial({ toneMapped: false }), MAX);
		this.cubes.instanceMatrix.setUsage(THREE.DynamicDrawUsage);
		this.cubes.instanceColor = new THREE.InstancedBufferAttribute(new Float32Array(MAX * 3), 3);
		this.cubes.frustumCulled = false;
		this.cubes.count = 0;
		scene.add(this.cubes);
		this.litCubes = new THREE.InstancedMesh(geo, new THREE.MeshLambertMaterial(), MAX);
		this.litCubes.instanceMatrix.setUsage(THREE.DynamicDrawUsage);
		this.litCubes.instanceColor = new THREE.InstancedBufferAttribute(new Float32Array(MAX * 3), 3);
		this.litCubes.frustumCulled = false;
		this.litCubes.count = 0;
		scene.add(this.litCubes);
		this.parts = [];
		this.rings = [];
		this.meshes = [];
		this.texts = [];
		this.ringGeo = new THREE.RingGeometry(0.82, 1, 40, 1);
		this.ringGeo.rotateX(-Math.PI / 2);
		this.discGeo = new THREE.CircleGeometry(1, 32);
		this.discGeo.rotateX(-Math.PI / 2);
		this.boxGeo = geo;
		this.sphereGeo = new THREE.IcosahedronGeometry(1, 1);
		this.textLayer = document.createElement('div');
		this.textLayer.className = 'textos-mundo';
		(uiRoot || document.body).appendChild(this.textLayer);
		this.camera = R.camera;
		this.quality = 'high';
	}

	// ---------------------------------------------------------------- partículas (cubinhos)
	// opts: count, color (hex ou [hex...]), speed, up, size, life, gravity, spread (0..1), dir [x,y,z], lit (sombreado)
	burst(x, y, z, opts = {}) {
		let count = opts.count ?? 10;
		if (this.quality === 'low') count = Math.ceil(count * 0.4);
		else if (this.quality === 'medium') count = Math.ceil(count * 0.7);
		const colors = Array.isArray(opts.color) ? opts.color : [opts.color ?? 0xffffff];
		const speed = opts.speed ?? 10, up = opts.up ?? 6, size = opts.size ?? 0.35, life = opts.life ?? 0.6;
		const dir = opts.dir, spread = opts.spread ?? 1;
		for (let i = 0; i < count; i++) {
			if (this.parts.length >= MAX * 2 - 10) break;
			let vx = (Math.random() - 0.5) * 2, vy = Math.random(), vz = (Math.random() - 0.5) * 2;
			if (dir) {
				vx = dir[0] + vx * spread;
				vy = dir[1] + vy * spread * 0.5;
				vz = dir[2] + vz * spread;
			}
			const n = Math.hypot(vx, vy, vz) || 1;
			const sp = speed * (0.4 + Math.random() * 0.8);
			this.parts.push({
				x: x + (opts.radius ? (Math.random() - 0.5) * opts.radius * 2 : 0),
				y: y + (opts.radiusY ? Math.random() * opts.radiusY : 0),
				z: z + (opts.radius ? (Math.random() - 0.5) * opts.radius * 2 : 0),
				vx: (vx / n) * sp,
				vy: (vy / n) * sp + up * (0.5 + Math.random() * 0.7),
				vz: (vz / n) * sp,
				rx: Math.random() * 6, ry: Math.random() * 6, rs: (Math.random() - 0.5) * 12,
				size: size * (0.6 + Math.random() * 0.8),
				life: life * (0.7 + Math.random() * 0.6),
				age: 0,
				g: opts.gravity ?? 30,
				color: colors[Math.floor(Math.random() * colors.length)],
				lit: !!opts.lit,
				drag: opts.drag ?? 1.5,
				grow: opts.grow ?? 0,
			});
		}
	}

	dust(x, y, z, power = 1) {
		this.burst(x, y + 0.2, z, {
			count: Math.round(6 + power * 10), color: [0xc8b490, 0xa89070, 0xe0d4b8], speed: 5 * power + 2, up: 2 + power * 2,
			size: 0.35 + power * 0.25, life: 0.6 + power * 0.3, gravity: 6, lit: true, radius: 0.6 * power, drag: 3,
		});
	}

	sparks(x, y, z, color = 0xffe080, n = 10, power = 1) {
		this.burst(x, y, z, { count: n, color: [color, 0xffffff], speed: 14 * power, up: 4, size: 0.22, life: 0.35, gravity: 18 });
	}

	// ---------------------------------------------------------------- anéis e discos no chão
	ring(x, y, z, radius, color = 0xffffff, life = 0.45, opts = {}) {
		const mat = new THREE.MeshBasicMaterial({ color, transparent: true, opacity: opts.opacity ?? 0.85, depthWrite: false, side: THREE.DoubleSide, toneMapped: false });
		const mesh = new THREE.Mesh(opts.disc ? this.discGeo : this.ringGeo, mat);
		mesh.position.set(x, y + 0.15, z);
		mesh.renderOrder = 5;
		this.scene.add(mesh);
		this.rings.push({ mesh, age: 0, life, r0: opts.from ?? radius * 0.2, r1: radius, op: opts.opacity ?? 0.85, keep: !!opts.keep });
		return mesh;
	}

	// aviso no chão (círculo que enche) antes de um golpe de área
	tele(x, y, z, radius, time, color = 0xff4040) {
		this.ring(x, y, z, radius, color, time, { from: radius, opacity: 0.7, keep: true });
		this.ring(x, y, z, radius, color, time, { disc: true, from: 0.05, opacity: 0.32, keep: true });
	}

	// ---------------------------------------------------------------- malhas soltas (tiros grandes, objetos)
	addMesh(mesh, life, update) {
		this.scene.add(mesh);
		const item = { mesh, age: 0, life, update };
		this.meshes.push(item);
		return item;
	}

	// riscos de unha na frente do golpe
	slash(x, y, z, yaw, color = 0xffffff, size = 1) {
		const group = new THREE.Group();
		const mat = new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 1, toneMapped: false, depthWrite: false });
		for (let i = -1; i <= 1; i++) {
			const m = new THREE.Mesh(this.boxGeo, mat);
			m.scale.set(0.12 * size, 1.8 * size, 0.12 * size);
			m.position.set(i * 0.45 * size, 0, 0);
			m.rotation.z = 0.55;
			group.add(m);
		}
		group.position.set(x, y, z);
		group.rotation.y = yaw;
		this.addMesh(group, 0.22, (it, t) => {
			mat.opacity = 1 - t;
			group.scale.setScalar(1 + t * 0.5);
		});
	}

	// ---------------------------------------------------------------- textos (dano, +XP...)
	text(x, y, z, str, opts = {}) {
		const el = document.createElement('div');
		el.className = 'texto-mundo ' + (opts.cls || '');
		el.textContent = str;
		if (opts.color) el.style.color = opts.color;
		if (opts.size) el.style.fontSize = opts.size + 'px';
		this.textLayer.appendChild(el);
		this.texts.push({ el, x, y, z, age: 0, life: opts.life ?? 0.9, rise: opts.rise ?? 3, dx: (Math.random() - 0.5) * 1.2 });
		if (this.texts.length > 40) {
			const old = this.texts.shift();
			old.el.remove();
		}
	}

	// ---------------------------------------------------------------- quadro
	update(dt) {
		// partículas
		let nB = 0, nL = 0;
		const alive = [];
		for (const p of this.parts) {
			p.age += dt;
			if (p.age >= p.life) continue;
			p.vy -= p.g * dt;
			const dr = Math.exp(-p.drag * dt);
			p.vx *= dr;
			p.vz *= dr;
			p.x += p.vx * dt;
			p.y += p.vy * dt;
			p.z += p.vz * dt;
			p.rx += p.rs * dt;
			const k = 1 - p.age / p.life;
			const s = p.size * (p.grow ? 1 + (p.age / p.life) * p.grow : Math.min(1, k * 2.2));
			_e.set(p.rx, p.ry + p.rx * 0.5, 0);
			_q.setFromEuler(_e);
			_m.compose(_p.set(p.x, p.y, p.z), _q, _s.set(s, s, s));
			_c.setHex(p.color);
			if (p.lit) {
				if (nL < MAX) {
					this.litCubes.setMatrixAt(nL, _m);
					this.litCubes.setColorAt(nL, _c);
					nL++;
				}
			} else if (nB < MAX) {
				this.cubes.setMatrixAt(nB, _m);
				this.cubes.setColorAt(nB, _c);
				nB++;
			}
			alive.push(p);
		}
		this.parts = alive;
		this.cubes.count = nB;
		this.litCubes.count = nL;
		this.cubes.instanceMatrix.needsUpdate = true;
		this.litCubes.instanceMatrix.needsUpdate = true;
		if (this.cubes.instanceColor) this.cubes.instanceColor.needsUpdate = true;
		if (this.litCubes.instanceColor) this.litCubes.instanceColor.needsUpdate = true;
		// anéis
		this.rings = this.rings.filter((r) => {
			r.age += dt;
			const t = Math.min(1, r.age / r.life);
			if (t >= 1) {
				this.scene.remove(r.mesh);
				r.mesh.material.dispose();
				return false;
			}
			const e = 1 - Math.pow(1 - t, 3);
			const rad = r.r0 + (r.r1 - r.r0) * e;
			r.mesh.scale.set(rad, 1, rad);
			r.mesh.material.opacity = r.keep ? r.op * (t > 0.85 ? (1 - t) / 0.15 : 1) : r.op * (1 - t);
			return true;
		});
		// malhas
		this.meshes = this.meshes.filter((it) => {
			it.age += dt;
			const t = it.age / it.life;
			if (t >= 1 || it.dead) {
				this.scene.remove(it.mesh);
				it.mesh.traverse((o) => {
					if (o.material && o.material.dispose && !o.material.shared) o.material.dispose();
				});
				return false;
			}
			if (it.update) it.update(it, t, dt);
			return true;
		});
		// textos
		const cam = this.camera;
		const w = window.innerWidth, h = window.innerHeight;
		this.texts = this.texts.filter((t) => {
			t.age += dt;
			const k = t.age / t.life;
			if (k >= 1) {
				t.el.remove();
				return false;
			}
			_v.set(t.x + t.dx * k, t.y + t.rise * Math.sqrt(k), t.z).project(cam);
			if (_v.z > 1) {
				t.el.style.display = 'none';
				return true;
			}
			t.el.style.display = '';
			const sx = (_v.x * 0.5 + 0.5) * w, sy = (-_v.y * 0.5 + 0.5) * h;
			const pop = k < 0.15 ? 0.6 + (k / 0.15) * 0.6 : 1.2 - Math.min(0.2, (k - 0.15) * 0.4);
			t.el.style.transform = `translate(${sx}px, ${sy}px) translate(-50%, -50%) scale(${pop})`;
			t.el.style.opacity = k > 0.7 ? String(1 - (k - 0.7) / 0.3) : '1';
			return true;
		});
	}

	clear() {
		this.parts = [];
		for (const r of this.rings) this.scene.remove(r.mesh);
		this.rings = [];
		for (const it of this.meshes) this.scene.remove(it.mesh);
		this.meshes = [];
		for (const t of this.texts) t.el.remove();
		this.texts = [];
	}
}
