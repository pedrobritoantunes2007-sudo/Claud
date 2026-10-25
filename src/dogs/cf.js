// "CFrame" leve para as poses dos cachorros: posição + rotação (quaternion), igual ao CFrame do Roblox.
// As poses do Animator usam muito A() (ângulos), T() (deslocamento) e mul (multiplicar dois CFrames).
// Convenção igual ao Roblox: o cachorro olha para -Z, Y para cima.

export class CF {
	constructor(x = 0, y = 0, z = 0, qx = 0, qy = 0, qz = 0, qw = 1) {
		this.x = x;
		this.y = y;
		this.z = z;
		this.qx = qx;
		this.qy = qy;
		this.qz = qz;
		this.qw = qw;
	}

	// this * b
	mul(b) {
		const ax = this.qx, ay = this.qy, az = this.qz, aw = this.qw;
		// gira b.posição pela rotação de this
		const vx = b.x, vy = b.y, vz = b.z;
		const tx = 2 * (ay * vz - az * vy);
		const ty = 2 * (az * vx - ax * vz);
		const tz = 2 * (ax * vy - ay * vx);
		const px = vx + aw * tx + (ay * tz - az * ty);
		const py = vy + aw * ty + (az * tx - ax * tz);
		const pz = vz + aw * tz + (ax * ty - ay * tx);
		const bx = b.qx, by = b.qy, bz = b.qz, bw = b.qw;
		return new CF(
			this.x + px,
			this.y + py,
			this.z + pz,
			ax * bw + aw * bx + ay * bz - az * by,
			ay * bw + aw * by + az * bx - ax * bz,
			az * bw + aw * bz + ax * by - ay * bx,
			aw * bw - ax * bx - ay * by - az * bz,
		);
	}

	// interpolação (posição linear, rotação esférica pelo caminho curto)
	lerp(b, t) {
		if (t <= 0) return this;
		if (t >= 1) return b;
		let bx = b.qx, by = b.qy, bz = b.qz, bw = b.qw;
		let cos = this.qx * bx + this.qy * by + this.qz * bz + this.qw * bw;
		if (cos < 0) {
			cos = -cos;
			bx = -bx;
			by = -by;
			bz = -bz;
			bw = -bw;
		}
		let k0, k1;
		if (cos > 0.9995) {
			k0 = 1 - t;
			k1 = t;
		} else {
			const ang = Math.acos(cos);
			const sin = Math.sin(ang);
			k0 = Math.sin((1 - t) * ang) / sin;
			k1 = Math.sin(t * ang) / sin;
		}
		let qx = this.qx * k0 + bx * k1;
		let qy = this.qy * k0 + by * k1;
		let qz = this.qz * k0 + bz * k1;
		let qw = this.qw * k0 + bw * k1;
		const n = Math.hypot(qx, qy, qz, qw) || 1;
		return new CF(
			this.x + (b.x - this.x) * t,
			this.y + (b.y - this.y) * t,
			this.z + (b.z - this.z) * t,
			qx / n,
			qy / n,
			qz / n,
			qw / n,
		);
	}

	inverse() {
		const qx = -this.qx, qy = -this.qy, qz = -this.qz, qw = this.qw;
		const r = new CF(0, 0, 0, qx, qy, qz, qw);
		const p = r.rotate(-this.x, -this.y, -this.z);
		r.x = p[0];
		r.y = p[1];
		r.z = p[2];
		return r;
	}

	// gira um vetor (devolve [x, y, z])
	rotate(vx, vy, vz) {
		const ax = this.qx, ay = this.qy, az = this.qz, aw = this.qw;
		const tx = 2 * (ay * vz - az * vy);
		const ty = 2 * (az * vx - ax * vz);
		const tz = 2 * (ax * vy - ay * vx);
		return [vx + aw * tx + (ay * tz - az * ty), vy + aw * ty + (az * tx - ax * tz), vz + aw * tz + (ax * ty - ay * tx)];
	}

	isIdentity() {
		return this.x === 0 && this.y === 0 && this.z === 0 && this.qx === 0 && this.qy === 0 && this.qz === 0;
	}

	// escreve num THREE.Matrix4 (sem escala)
	toMatrix(m) {
		const x = this.qx, y = this.qy, z = this.qz, w = this.qw;
		const x2 = x + x, y2 = y + y, z2 = z + z;
		const xx = x * x2, xy = x * y2, xz = x * z2;
		const yy = y * y2, yz = y * z2, zz = z * z2;
		const wx = w * x2, wy = w * y2, wz = w * z2;
		const e = m.elements;
		e[0] = 1 - (yy + zz);
		e[1] = xy + wz;
		e[2] = xz - wy;
		e[3] = 0;
		e[4] = xy - wz;
		e[5] = 1 - (xx + zz);
		e[6] = yz + wx;
		e[7] = 0;
		e[8] = xz + wy;
		e[9] = yz - wx;
		e[10] = 1 - (xx + yy);
		e[11] = 0;
		e[12] = this.x;
		e[13] = this.y;
		e[14] = this.z;
		e[15] = 1;
		return m;
	}
}

export const IDENT = new CF();

export function fromArray(a) {
	return new CF(a[0], a[1], a[2], a[3], a[4], a[5], a[6]);
}

// CFrame.Angles(x, y, z) do Roblox = Rx * Ry * Rz (ordem XYZ do three.js)
export function A(x = 0, y = 0, z = 0) {
	if (x === 0 && y === 0 && z === 0) return IDENT;
	const c1 = Math.cos(x / 2), c2 = Math.cos(y / 2), c3 = Math.cos(z / 2);
	const s1 = Math.sin(x / 2), s2 = Math.sin(y / 2), s3 = Math.sin(z / 2);
	return new CF(0, 0, 0, s1 * c2 * c3 + c1 * s2 * s3, c1 * s2 * c3 - s1 * c2 * s3, c1 * c2 * s3 + s1 * s2 * c3, c1 * c2 * c3 - s1 * s2 * s3);
}

// CFrame.fromEulerAnglesYXZ(pitch, yaw, tilt): vira para o lado, depois levanta o nariz e inclina
export function HEAD(pitch = 0, yaw = 0, tilt = 0) {
	const c1 = Math.cos(pitch / 2), c2 = Math.cos(yaw / 2), c3 = Math.cos(tilt / 2);
	const s1 = Math.sin(pitch / 2), s2 = Math.sin(yaw / 2), s3 = Math.sin(tilt / 2);
	return new CF(0, 0, 0, s1 * c2 * c3 + c1 * s2 * s3, c1 * s2 * c3 - s1 * c2 * s3, c1 * c2 * s3 - s1 * s2 * c3, c1 * c2 * c3 + s1 * s2 * s3);
}

export function T(x = 0, y = 0, z = 0) {
	return new CF(x, y, z);
}

export function axisAngle(ax, ay, az, angle) {
	const n = Math.hypot(ax, ay, az) || 1;
	const s = Math.sin(angle / 2) / n;
	return new CF(0, 0, 0, ax * s, ay * s, az * s, Math.cos(angle / 2));
}
