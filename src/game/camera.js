// Câmera de terceira pessoa: gira com o botão direito do mouse (ou arrastando o dedo), zoom com a rodinha,
// não atravessa o chão e treme nos golpes fortes. Também acha o ponto do chão embaixo da setinha (mira).
import * as THREE from 'three';
import { Input } from '../core/input.js';
import { clamp, damp } from '../core/util.js';

const _ray = new THREE.Raycaster();
const _ndc = new THREE.Vector2();
const _v = new THREE.Vector3();

export class FollowCamera {
	constructor(camera) {
		this.camera = camera;
		this.yaw = 0; // 0 = câmera atrás olhando para -Z
		this.pitch = 0.38;
		this.dist = 16;
		this.wantDist = 16;
		this.minDist = 5;
		this.maxDist = 70;
		this.target = new THREE.Vector3();
		this.focusHeight = 2;
		this.shakeT = 0;
		this.shakePower = 0;
		this.locked = false; // trava (mira no meio da tela)
		this.sensitivity = 1;
	}

	snap(x, y, z, yaw) {
		this.target.set(x, y + this.focusHeight, z);
		if (yaw !== undefined) this.yaw = yaw;
		this.place(null);
	}

	shake(power = 0.5, time = 0.25) {
		this.shakePower = Math.max(this.shakePower, power);
		this.shakeT = Math.max(this.shakeT, time);
	}

	update(dt, fx, fy, fz, physics) {
		const I = Input;
		const sens = 0.005 * this.sensitivity;
		if (I.locked) {
			this.yaw -= I.mouse.dx * sens * 0.6;
			this.pitch += I.mouse.dy * sens * 0.6;
		} else if (I.mouse.right) {
			this.yaw -= I.mouse.dx * sens;
			this.pitch += I.mouse.dy * sens;
		}
		if (I.look.dx || I.look.dy) {
			this.yaw -= I.look.dx * sens * 1.1;
			this.pitch += I.look.dy * sens * 0.9;
		}
		// teclas de girar a câmera (setas laterais ficam para andar): Q/E não; usamos , e .
		this.pitch = clamp(this.pitch, -0.35, 1.35);
		if (I.mouse.wheel) this.wantDist = clamp(this.wantDist * (I.mouse.wheel > 0 ? 1.15 : 0.87), this.minDist, this.maxDist);
		this.dist += (this.wantDist - this.dist) * damp(dt, 10);
		const k = damp(dt, 14);
		this.target.x += (fx - this.target.x) * k;
		this.target.y += (fy + this.focusHeight - this.target.y) * damp(dt, 9);
		this.target.z += (fz - this.target.z) * k;
		this.place(physics, dt);
	}

	place(physics, dt = 0) {
		const cp = Math.cos(this.pitch), sp = Math.sin(this.pitch);
		const dx = Math.sin(this.yaw) * cp, dz = Math.cos(this.yaw) * cp, dy = sp;
		let d = this.dist;
		// não deixa a câmera entrar no chão/paredes
		if (physics) {
			const hit = physics.raycast(this.target.x, this.target.y, this.target.z, dx, dy, dz, d, 1.2);
			if (hit && !hit.water) d = Math.max(2.5, hit.t - 1.2);
		}
		let x = this.target.x + dx * d, y = this.target.y + dy * d, z = this.target.z + dz * d;
		if (physics) {
			const floor = physics.topAt(x, z, y + 2);
			if (y < floor + 1.2) y = floor + 1.2;
		}
		if (this.shakeT > 0) {
			this.shakeT -= dt;
			const p = this.shakePower * Math.min(1, this.shakeT * 4);
			x += (Math.random() - 0.5) * p;
			y += (Math.random() - 0.5) * p;
			z += (Math.random() - 0.5) * p;
			if (this.shakeT <= 0) this.shakePower = 0;
		}
		this.camera.position.set(x, y, z);
		this.camera.lookAt(this.target);
	}

	// direção "para frente" da câmera no chão (para andar com WASD)
	groundForward() {
		return [-Math.sin(this.yaw), -Math.cos(this.yaw)];
	}

	// ponto do mundo embaixo da posição de tela (sx, sy): chão, água ou plano na altura planeY
	screenToWorld(sx, sy, physics, planeY, maxDist = 260) {
		_ndc.set((sx / window.innerWidth) * 2 - 1, -(sy / window.innerHeight) * 2 + 1);
		_ray.setFromCamera(_ndc, this.camera);
		const o = _ray.ray.origin, d = _ray.ray.direction;
		if (physics) {
			const hit = physics.raycast(o.x, o.y, o.z, d.x, d.y, d.z, maxDist, 1.5);
			if (hit) return _v.set(hit.x, hit.y, hit.z).clone();
		}
		if (Math.abs(d.y) > 1e-4) {
			const t = (planeY - o.y) / d.y;
			if (t > 0 && t < maxDist * 2) return new THREE.Vector3(o.x + d.x * t, planeY, o.z + d.z * t);
		}
		return new THREE.Vector3(o.x + d.x * 60, o.y + d.y * 60, o.z + d.z * 60);
	}
}
