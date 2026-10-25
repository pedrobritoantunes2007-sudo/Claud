// Tipos de dados do Roblox: Vector3, Vector2, CFrame, Color3, NumberSequence, ColorSequence, NumberRange, UDim2,
// TweenInfo, Random, Enum. Imutáveis como no Roblox. Os operadores (+ - * /) vêm por __add/__sub/__mul... que o
// lua.js chama ($add, $mul...).
import { $M, LuaError, numStr } from './lua.js';

const clamp = (x, a, b) => (x < a ? a : x > b ? b : x);

// ------------------------------------------------------------------ Vector3
export class Vector3 {
	constructor(x = 0, y = 0, z = 0) {
		this.x = x;
		this.y = y;
		this.z = z;
	}
	static new(x = 0, y = 0, z = 0) {
		return new Vector3(x || 0, y || 0, z || 0);
	}
	static FromNormalId(id) {
		return NORMALS[id.Name] || V0;
	}
	static FromAxis(axis) {
		return NORMALS[axis.Name === 'X' ? 'Right' : axis.Name === 'Y' ? 'Top' : 'Back'];
	}
	get $type() {
		return 'Vector3';
	}
	get X() {
		return this.x;
	}
	get Y() {
		return this.y;
	}
	get Z() {
		return this.z;
	}
	get Magnitude() {
		return Math.sqrt(this.x * this.x + this.y * this.y + this.z * this.z);
	}
	get Unit() {
		const m = this.Magnitude;
		if (m === 0) return new Vector3(NaN, NaN, NaN);
		return new Vector3(this.x / m, this.y / m, this.z / m);
	}
	Lerp(b, t) {
		return new Vector3(this.x + (b.x - this.x) * t, this.y + (b.y - this.y) * t, this.z + (b.z - this.z) * t);
	}
	Dot(b) {
		return this.x * b.x + this.y * b.y + this.z * b.z;
	}
	Cross(b) {
		return new Vector3(this.y * b.z - this.z * b.y, this.z * b.x - this.x * b.z, this.x * b.y - this.y * b.x);
	}
	Abs() {
		return new Vector3(Math.abs(this.x), Math.abs(this.y), Math.abs(this.z));
	}
	Floor() {
		return new Vector3(Math.floor(this.x), Math.floor(this.y), Math.floor(this.z));
	}
	Ceil() {
		return new Vector3(Math.ceil(this.x), Math.ceil(this.y), Math.ceil(this.z));
	}
	Sign() {
		return new Vector3(Math.sign(this.x), Math.sign(this.y), Math.sign(this.z));
	}
	Min(b) {
		return new Vector3(Math.min(this.x, b.x), Math.min(this.y, b.y), Math.min(this.z, b.z));
	}
	Max(b) {
		return new Vector3(Math.max(this.x, b.x), Math.max(this.y, b.y), Math.max(this.z, b.z));
	}
	Angle(b, axis) {
		const a = Math.acos(clamp(this.Dot(b) / (this.Magnitude * b.Magnitude || 1), -1, 1));
		if (axis && this.Cross(b).Dot(axis) < 0) return -a;
		return a;
	}
	FuzzyEq(b, eps = 1e-5) {
		return Math.abs(this.x - b.x) <= eps && Math.abs(this.y - b.y) <= eps && Math.abs(this.z - b.z) <= eps;
	}
	__add(b) {
		if (!(b instanceof Vector3)) throw new LuaError('attempt to perform arithmetic (add) on Vector3 and ' + (b === undefined ? 'nil' : typeof b));
		return new Vector3(this.x + b.x, this.y + b.y, this.z + b.z);
	}
	__sub(b) {
		if (!(b instanceof Vector3)) throw new LuaError('attempt to perform arithmetic (sub) on Vector3 and ' + (b === undefined ? 'nil' : typeof b));
		return new Vector3(this.x - b.x, this.y - b.y, this.z - b.z);
	}
	__mul(b) {
		if (typeof b === 'number') return new Vector3(this.x * b, this.y * b, this.z * b);
		if (b instanceof Vector3) return new Vector3(this.x * b.x, this.y * b.y, this.z * b.z);
		throw new LuaError('attempt to perform arithmetic (mul) on Vector3 and ' + (b === undefined ? 'nil' : typeof b));
	}
	__mulNum(n) {
		return new Vector3(this.x * n, this.y * n, this.z * n);
	}
	__div(b) {
		if (typeof b === 'number') return new Vector3(this.x / b, this.y / b, this.z / b);
		if (b instanceof Vector3) return new Vector3(this.x / b.x, this.y / b.y, this.z / b.z);
		throw new LuaError('attempt to perform arithmetic (div) on Vector3');
	}
	__divNum(n) {
		return new Vector3(n / this.x, n / this.y, n / this.z);
	}
	__idiv(b) {
		return this.__div(b).Floor();
	}
	__unm() {
		return new Vector3(-this.x, -this.y, -this.z);
	}
	__eq(b) {
		return b instanceof Vector3 && b.x === this.x && b.y === this.y && b.z === this.z;
	}
	toString() {
		return `${numStr(this.x)}, ${numStr(this.y)}, ${numStr(this.z)}`;
	}
}
const V0 = new Vector3(0, 0, 0);
Vector3.zero = V0;
Vector3.one = new Vector3(1, 1, 1);
Vector3.xAxis = new Vector3(1, 0, 0);
Vector3.yAxis = new Vector3(0, 1, 0);
Vector3.zAxis = new Vector3(0, 0, 1);
const NORMALS = {
	Top: new Vector3(0, 1, 0),
	Bottom: new Vector3(0, -1, 0),
	Front: new Vector3(0, 0, -1),
	Back: new Vector3(0, 0, 1),
	Right: new Vector3(1, 0, 0),
	Left: new Vector3(-1, 0, 0),
};

// ------------------------------------------------------------------ Vector2
export class Vector2 {
	constructor(x = 0, y = 0) {
		this.x = x;
		this.y = y;
	}
	static new(x = 0, y = 0) {
		return new Vector2(x || 0, y || 0);
	}
	get $type() {
		return 'Vector2';
	}
	get X() {
		return this.x;
	}
	get Y() {
		return this.y;
	}
	get Magnitude() {
		return Math.hypot(this.x, this.y);
	}
	get Unit() {
		const m = this.Magnitude;
		return new Vector2(this.x / m, this.y / m);
	}
	Lerp(b, t) {
		return new Vector2(this.x + (b.x - this.x) * t, this.y + (b.y - this.y) * t);
	}
	Dot(b) {
		return this.x * b.x + this.y * b.y;
	}
	Cross(b) {
		return this.x * b.y - this.y * b.x;
	}
	__add(b) {
		return new Vector2(this.x + b.x, this.y + b.y);
	}
	__sub(b) {
		return new Vector2(this.x - b.x, this.y - b.y);
	}
	__mul(b) {
		return typeof b === 'number' ? new Vector2(this.x * b, this.y * b) : new Vector2(this.x * b.x, this.y * b.y);
	}
	__mulNum(n) {
		return new Vector2(this.x * n, this.y * n);
	}
	__div(b) {
		return typeof b === 'number' ? new Vector2(this.x / b, this.y / b) : new Vector2(this.x / b.x, this.y / b.y);
	}
	__unm() {
		return new Vector2(-this.x, -this.y);
	}
	__eq(b) {
		return b instanceof Vector2 && b.x === this.x && b.y === this.y;
	}
	toString() {
		return `${numStr(this.x)}, ${numStr(this.y)}`;
	}
}
Vector2.zero = new Vector2(0, 0);
Vector2.one = new Vector2(1, 1);

// ------------------------------------------------------------------ CFrame
// posição (x, y, z) + matriz 3x3 (linhas): colunas = RightVector, UpVector, -LookVector (igual ao Roblox)
export class CFrame {
	constructor(x, y, z, m00, m01, m02, m10, m11, m12, m20, m21, m22) {
		this.x = x;
		this.y = y;
		this.z = z;
		this.m00 = m00;
		this.m01 = m01;
		this.m02 = m02;
		this.m10 = m10;
		this.m11 = m11;
		this.m12 = m12;
		this.m20 = m20;
		this.m21 = m21;
		this.m22 = m22;
	}
	static new(a, b, c, d, e, f, g, h, i, j, k, l) {
		if (a === undefined) return CF_IDENTITY;
		if (a instanceof Vector3) {
			if (b instanceof Vector3) return CFrame.lookAt(a, b);
			return new CFrame(a.x, a.y, a.z, 1, 0, 0, 0, 1, 0, 0, 0, 1);
		}
		if (l !== undefined) return new CFrame(a, b, c, d, e, f, g, h, i, j, k, l);
		if (g !== undefined) return fromQuat(a, b, c, d, e, f, g);
		return new CFrame(a, b || 0, c || 0, 1, 0, 0, 0, 1, 0, 0, 0, 1);
	}
	// rotação: Rx * Ry * Rz (igual CFrame.Angles / fromEulerAnglesXYZ)
	static Angles(rx = 0, ry = 0, rz = 0) {
		const cx = Math.cos(rx), sx = Math.sin(rx), cy = Math.cos(ry), sy = Math.sin(ry), cz = Math.cos(rz), sz = Math.sin(rz);
		return new CFrame(
			0, 0, 0,
			cy * cz, -cy * sz, sy,
			cx * sz + sx * sy * cz, cx * cz - sx * sy * sz, -sx * cy,
			sx * sz - cx * sy * cz, sx * cz + cx * sy * sz, cx * cy,
		);
	}
	static fromEulerAnglesXYZ(rx, ry, rz) {
		return CFrame.Angles(rx, ry, rz);
	}
	// Ry * Rx * Rz
	static fromEulerAnglesYXZ(rx = 0, ry = 0, rz = 0) {
		return CFrame.Angles(0, ry, 0).__mul(CFrame.Angles(rx, 0, 0)).__mul(CFrame.Angles(0, 0, rz));
	}
	static fromOrientation(rx, ry, rz) {
		return CFrame.fromEulerAnglesYXZ(rx, ry, rz);
	}
	static fromAxisAngle(axis, angle) {
		const u = axis.Unit;
		const c = Math.cos(angle), s = Math.sin(angle), t = 1 - c;
		const { x, y, z } = u;
		return new CFrame(
			0, 0, 0,
			t * x * x + c, t * x * y - s * z, t * x * z + s * y,
			t * x * y + s * z, t * y * y + c, t * y * z - s * x,
			t * x * z - s * y, t * y * z + s * x, t * z * z + c,
		);
	}
	static lookAt(at, target, up) {
		let fx = target.x - at.x, fy = target.y - at.y, fz = target.z - at.z;
		let fl = Math.hypot(fx, fy, fz);
		if (fl < 1e-9) return new CFrame(at.x, at.y, at.z, 1, 0, 0, 0, 1, 0, 0, 0, 1);
		fx /= fl;
		fy /= fl;
		fz /= fl;
		let ux = up ? up.x : 0, uy = up ? up.y : 1, uz = up ? up.z : 0;
		// direita = olhar × cima
		let rx = fy * uz - fz * uy, ry = fz * ux - fx * uz, rz = fx * uy - fy * ux;
		let rl = Math.hypot(rx, ry, rz);
		if (rl < 1e-6) {
			// olhando reto para cima/baixo
			ux = 0;
			uy = 0;
			uz = fy > 0 ? 1 : -1;
			rx = fy * uz - fz * uy;
			ry = fz * ux - fx * uz;
			rz = fx * uy - fy * ux;
			rl = Math.hypot(rx, ry, rz) || 1;
		}
		rx /= rl;
		ry /= rl;
		rz /= rl;
		// cima de verdade = direita × olhar
		const vx = ry * fz - rz * fy, vy = rz * fx - rx * fz, vz = rx * fy - ry * fx;
		// colunas: direita, cima, -olhar
		return new CFrame(at.x, at.y, at.z, rx, vx, -fx, ry, vy, -fy, rz, vz, -fz);
	}
	static fromMatrix(pos, vX, vY, vZ) {
		if (!vZ) vZ = vX.Cross(vY).Unit;
		return new CFrame(pos.x, pos.y, pos.z, vX.x, vY.x, vZ.x, vX.y, vY.y, vZ.y, vX.z, vY.z, vZ.z);
	}
	get $type() {
		return 'CFrame';
	}
	get Position() {
		return new Vector3(this.x, this.y, this.z);
	}
	get p() {
		return this.Position;
	}
	get X() {
		return this.x;
	}
	get Y() {
		return this.y;
	}
	get Z() {
		return this.z;
	}
	get LookVector() {
		return new Vector3(-this.m02, -this.m12, -this.m22);
	}
	get RightVector() {
		return new Vector3(this.m00, this.m10, this.m20);
	}
	get UpVector() {
		return new Vector3(this.m01, this.m11, this.m21);
	}
	get XVector() {
		return this.RightVector;
	}
	get YVector() {
		return this.UpVector;
	}
	get ZVector() {
		return new Vector3(this.m02, this.m12, this.m22);
	}
	get Rotation() {
		return new CFrame(0, 0, 0, this.m00, this.m01, this.m02, this.m10, this.m11, this.m12, this.m20, this.m21, this.m22);
	}
	Inverse() {
		// rotação ortonormal: inversa = transposta
		const { m00, m01, m02, m10, m11, m12, m20, m21, m22, x, y, z } = this;
		return new CFrame(
			-(m00 * x + m10 * y + m20 * z), -(m01 * x + m11 * y + m21 * z), -(m02 * x + m12 * y + m22 * z),
			m00, m10, m20, m01, m11, m21, m02, m12, m22,
		);
	}
	__mul(b) {
		if (b instanceof CFrame) {
			const a = this;
			return new CFrame(
				a.m00 * b.x + a.m01 * b.y + a.m02 * b.z + a.x,
				a.m10 * b.x + a.m11 * b.y + a.m12 * b.z + a.y,
				a.m20 * b.x + a.m21 * b.y + a.m22 * b.z + a.z,
				a.m00 * b.m00 + a.m01 * b.m10 + a.m02 * b.m20, a.m00 * b.m01 + a.m01 * b.m11 + a.m02 * b.m21, a.m00 * b.m02 + a.m01 * b.m12 + a.m02 * b.m22,
				a.m10 * b.m00 + a.m11 * b.m10 + a.m12 * b.m20, a.m10 * b.m01 + a.m11 * b.m11 + a.m12 * b.m21, a.m10 * b.m02 + a.m11 * b.m12 + a.m12 * b.m22,
				a.m20 * b.m00 + a.m21 * b.m10 + a.m22 * b.m20, a.m20 * b.m01 + a.m21 * b.m11 + a.m22 * b.m21, a.m20 * b.m02 + a.m21 * b.m12 + a.m22 * b.m22,
			);
		}
		if (b instanceof Vector3) return this.PointToWorldSpace(b);
		throw new LuaError('attempt to multiply a CFrame with ' + (b === undefined ? 'nil' : typeof b));
	}
	__add(v) {
		return new CFrame(this.x + v.x, this.y + v.y, this.z + v.z, this.m00, this.m01, this.m02, this.m10, this.m11, this.m12, this.m20, this.m21, this.m22);
	}
	__sub(v) {
		return new CFrame(this.x - v.x, this.y - v.y, this.z - v.z, this.m00, this.m01, this.m02, this.m10, this.m11, this.m12, this.m20, this.m21, this.m22);
	}
	__eq(b) {
		if (!(b instanceof CFrame)) return false;
		for (const k of ['x', 'y', 'z', 'm00', 'm01', 'm02', 'm10', 'm11', 'm12', 'm20', 'm21', 'm22']) if (this[k] !== b[k]) return false;
		return true;
	}
	PointToWorldSpace(v) {
		return new Vector3(
			this.m00 * v.x + this.m01 * v.y + this.m02 * v.z + this.x,
			this.m10 * v.x + this.m11 * v.y + this.m12 * v.z + this.y,
			this.m20 * v.x + this.m21 * v.y + this.m22 * v.z + this.z,
		);
	}
	PointToObjectSpace(v) {
		const dx = v.x - this.x, dy = v.y - this.y, dz = v.z - this.z;
		return new Vector3(
			this.m00 * dx + this.m10 * dy + this.m20 * dz,
			this.m01 * dx + this.m11 * dy + this.m21 * dz,
			this.m02 * dx + this.m12 * dy + this.m22 * dz,
		);
	}
	VectorToWorldSpace(v) {
		return new Vector3(
			this.m00 * v.x + this.m01 * v.y + this.m02 * v.z,
			this.m10 * v.x + this.m11 * v.y + this.m12 * v.z,
			this.m20 * v.x + this.m21 * v.y + this.m22 * v.z,
		);
	}
	VectorToObjectSpace(v) {
		return new Vector3(
			this.m00 * v.x + this.m10 * v.y + this.m20 * v.z,
			this.m01 * v.x + this.m11 * v.y + this.m21 * v.z,
			this.m02 * v.x + this.m12 * v.y + this.m22 * v.z,
		);
	}
	ToWorldSpace(cf) {
		return this.__mul(cf);
	}
	ToObjectSpace(cf) {
		return this.Inverse().__mul(cf);
	}
	Lerp(b, t) {
		const qa = toQuat(this), qb = toQuat(b);
		let dot = qa[0] * qb[0] + qa[1] * qb[1] + qa[2] * qb[2] + qa[3] * qb[3];
		if (dot < 0) {
			for (let i = 0; i < 4; i++) qb[i] = -qb[i];
			dot = -dot;
		}
		let k0, k1;
		if (dot > 0.9995) {
			k0 = 1 - t;
			k1 = t;
		} else {
			const th = Math.acos(dot), s = Math.sin(th);
			k0 = Math.sin((1 - t) * th) / s;
			k1 = Math.sin(t * th) / s;
		}
		const q = [0, 1, 2, 3].map((i) => qa[i] * k0 + qb[i] * k1);
		const l = Math.hypot(q[0], q[1], q[2], q[3]) || 1;
		return fromQuat(this.x + (b.x - this.x) * t, this.y + (b.y - this.y) * t, this.z + (b.z - this.z) * t, q[0] / l, q[1] / l, q[2] / l, q[3] / l);
	}
	GetComponents() {
		return $M(this.x, this.y, this.z, this.m00, this.m01, this.m02, this.m10, this.m11, this.m12, this.m20, this.m21, this.m22);
	}
	components() {
		return this.GetComponents();
	}
	ToEulerAnglesXYZ() {
		// R = Rx * Ry * Rz
		const ry = Math.asin(clamp(this.m02, -1, 1));
		let rx, rz;
		if (Math.abs(this.m02) < 0.99999) {
			rx = Math.atan2(-this.m12, this.m22);
			rz = Math.atan2(-this.m01, this.m00);
		} else {
			rx = Math.atan2(this.m21, this.m11);
			rz = 0;
		}
		return $M(rx, ry, rz);
	}
	ToEulerAnglesYXZ() {
		// R = Ry * Rx * Rz
		const rx = Math.asin(clamp(-this.m12, -1, 1));
		let ry, rz;
		if (Math.abs(this.m12) < 0.99999) {
			ry = Math.atan2(this.m02, this.m22);
			rz = Math.atan2(this.m10, this.m11);
		} else {
			ry = Math.atan2(-this.m20, this.m00);
			rz = 0;
		}
		return $M(rx, ry, rz);
	}
	ToOrientation() {
		return this.ToEulerAnglesYXZ();
	}
	ToAxisAngle() {
		const q = toQuat(this);
		const angle = 2 * Math.acos(clamp(q[3], -1, 1));
		const s = Math.sqrt(1 - q[3] * q[3]) || 1;
		return $M(new Vector3(q[0] / s, q[1] / s, q[2] / s), angle);
	}
	Orthonormalize() {
		return CFrame.fromMatrix(this.Position, this.RightVector.Unit, this.UpVector.Unit);
	}
	FuzzyEq(b, eps = 1e-5) {
		for (const k of ['x', 'y', 'z', 'm00', 'm01', 'm02', 'm10', 'm11', 'm12', 'm20', 'm21', 'm22']) if (Math.abs(this[k] - b[k]) > eps) return false;
		return true;
	}
	toString() {
		return [this.x, this.y, this.z, this.m00, this.m01, this.m02, this.m10, this.m11, this.m12, this.m20, this.m21, this.m22].map(numStr).join(', ');
	}
}
const CF_IDENTITY = new CFrame(0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1);
CFrame.identity = CF_IDENTITY;

function fromQuat(x, y, z, qx, qy, qz, qw) {
	const xx = qx * qx, yy = qy * qy, zz = qz * qz, xy = qx * qy, xz = qx * qz, yz = qy * qz, wx = qw * qx, wy = qw * qy, wz = qw * qz;
	return new CFrame(
		x, y, z,
		1 - 2 * (yy + zz), 2 * (xy - wz), 2 * (xz + wy),
		2 * (xy + wz), 1 - 2 * (xx + zz), 2 * (yz - wx),
		2 * (xz - wy), 2 * (yz + wx), 1 - 2 * (xx + yy),
	);
}
export function toQuat(c) {
	const tr = c.m00 + c.m11 + c.m22;
	let qx, qy, qz, qw;
	if (tr > 0) {
		const s = Math.sqrt(tr + 1) * 2;
		qw = 0.25 * s;
		qx = (c.m21 - c.m12) / s;
		qy = (c.m02 - c.m20) / s;
		qz = (c.m10 - c.m01) / s;
	} else if (c.m00 > c.m11 && c.m00 > c.m22) {
		const s = Math.sqrt(1 + c.m00 - c.m11 - c.m22) * 2;
		qw = (c.m21 - c.m12) / s;
		qx = 0.25 * s;
		qy = (c.m01 + c.m10) / s;
		qz = (c.m02 + c.m20) / s;
	} else if (c.m11 > c.m22) {
		const s = Math.sqrt(1 + c.m11 - c.m00 - c.m22) * 2;
		qw = (c.m02 - c.m20) / s;
		qx = (c.m01 + c.m10) / s;
		qy = 0.25 * s;
		qz = (c.m12 + c.m21) / s;
	} else {
		const s = Math.sqrt(1 + c.m22 - c.m00 - c.m11) * 2;
		qw = (c.m10 - c.m01) / s;
		qx = (c.m02 + c.m20) / s;
		qy = (c.m12 + c.m21) / s;
		qz = 0.25 * s;
	}
	return [qx, qy, qz, qw];
}

// ------------------------------------------------------------------ Color3
export class Color3 {
	constructor(r = 0, g = 0, b = 0) {
		this.r = r;
		this.g = g;
		this.b = b;
	}
	static new(r = 0, g = 0, b = 0) {
		return new Color3(r, g, b);
	}
	static fromRGB(r = 0, g = 0, b = 0) {
		return new Color3(r / 255, g / 255, b / 255);
	}
	static fromHSV(h, s, v) {
		h = ((h % 1) + 1) % 1;
		const i = Math.floor(h * 6), f = h * 6 - i;
		const p = v * (1 - s), q = v * (1 - f * s), t = v * (1 - (1 - f) * s);
		const [r, g, b] = [[v, t, p], [q, v, p], [p, v, t], [p, q, v], [t, p, v], [v, p, q]][i % 6];
		return new Color3(r, g, b);
	}
	static fromHex(hex) {
		const h = String(hex).replace('#', '');
		const n = parseInt(h.length === 3 ? h.split('').map((c) => c + c).join('') : h, 16);
		return new Color3(((n >> 16) & 255) / 255, ((n >> 8) & 255) / 255, (n & 255) / 255);
	}
	get $type() {
		return 'Color3';
	}
	get R() {
		return this.r;
	}
	get G() {
		return this.g;
	}
	get B() {
		return this.b;
	}
	Lerp(o, t) {
		return new Color3(this.r + (o.r - this.r) * t, this.g + (o.g - this.g) * t, this.b + (o.b - this.b) * t);
	}
	ToHSV() {
		const { r, g, b } = this;
		const max = Math.max(r, g, b), min = Math.min(r, g, b), d = max - min;
		let h = 0;
		if (d > 0) {
			if (max === r) h = ((g - b) / d) % 6;
			else if (max === g) h = (b - r) / d + 2;
			else h = (r - g) / d + 4;
			h /= 6;
			if (h < 0) h += 1;
		}
		return $M(h, max === 0 ? 0 : d / max, max);
	}
	ToHex() {
		return [this.r, this.g, this.b].map((c) => Math.round(clamp(c, 0, 1) * 255).toString(16).padStart(2, '0')).join('');
	}
	__eq(o) {
		return o instanceof Color3 && o.r === this.r && o.g === this.g && o.b === this.b;
	}
	toString() {
		return `${numStr(this.r)}, ${numStr(this.g)}, ${numStr(this.b)}`;
	}
}

// ------------------------------------------------------------------ BrickColor (só o básico)
export class BrickColor {
	constructor(color, name = 'Custom') {
		this.Color = color;
		this.Name = name;
	}
	static new(x) {
		if (x instanceof Color3) return new BrickColor(x);
		return new BrickColor(Color3.fromRGB(163, 162, 165), String(x));
	}
	static White() {
		return new BrickColor(Color3.new(1, 1, 1), 'White');
	}
	static Black() {
		return new BrickColor(Color3.fromRGB(27, 42, 53), 'Black');
	}
	get $type() {
		return 'BrickColor';
	}
}

// ------------------------------------------------------------------ sequências e faixas
export class NumberSequenceKeypoint {
	constructor(t, v, e = 0) {
		this.Time = t;
		this.Value = v;
		this.Envelope = e;
	}
	static new(t, v, e) {
		return new NumberSequenceKeypoint(t, v, e);
	}
	get $type() {
		return 'NumberSequenceKeypoint';
	}
}
export class NumberSequence {
	constructor(kps) {
		this.Keypoints = kps;
	}
	static new(a, b) {
		if (typeof a === 'number') {
			const v1 = typeof b === 'number' ? b : a;
			return new NumberSequence([new NumberSequenceKeypoint(0, a), new NumberSequenceKeypoint(1, v1)]);
		}
		const list = Array.isArray(a) ? a.slice() : [];
		list.sort((x, y) => x.Time - y.Time);
		return new NumberSequence(list);
	}
	get $type() {
		return 'NumberSequence';
	}
	// valor no tempo t (0..1)
	at(t) {
		const k = this.Keypoints;
		if (!k.length) return 0;
		if (t <= k[0].Time) return k[0].Value;
		for (let i = 1; i < k.length; i++) {
			if (t <= k[i].Time) {
				const a = k[i - 1], b = k[i];
				const u = (t - a.Time) / (b.Time - a.Time || 1);
				return a.Value + (b.Value - a.Value) * u;
			}
		}
		return k[k.length - 1].Value;
	}
}
export class ColorSequenceKeypoint {
	constructor(t, c) {
		this.Time = t;
		this.Value = c;
	}
	static new(t, c) {
		return new ColorSequenceKeypoint(t, c);
	}
	get $type() {
		return 'ColorSequenceKeypoint';
	}
}
export class ColorSequence {
	constructor(kps) {
		this.Keypoints = kps;
	}
	static new(a, b) {
		if (a instanceof Color3) {
			return new ColorSequence([new ColorSequenceKeypoint(0, a), new ColorSequenceKeypoint(1, b instanceof Color3 ? b : a)]);
		}
		const list = Array.isArray(a) ? a.slice() : [];
		list.sort((x, y) => x.Time - y.Time);
		return new ColorSequence(list);
	}
	get $type() {
		return 'ColorSequence';
	}
	// cor no tempo t → escreve em out [r, g, b]
	at(t, out) {
		const k = this.Keypoints;
		if (!k.length) {
			out[0] = out[1] = out[2] = 1;
			return out;
		}
		let a = k[0], b = k[0], u = 0;
		if (t <= k[0].Time) a = b = k[0];
		else if (t >= k[k.length - 1].Time) a = b = k[k.length - 1];
		else {
			for (let i = 1; i < k.length; i++) {
				if (t <= k[i].Time) {
					a = k[i - 1];
					b = k[i];
					u = (t - a.Time) / (b.Time - a.Time || 1);
					break;
				}
			}
		}
		out[0] = a.Value.r + (b.Value.r - a.Value.r) * u;
		out[1] = a.Value.g + (b.Value.g - a.Value.g) * u;
		out[2] = a.Value.b + (b.Value.b - a.Value.b) * u;
		return out;
	}
}
export class NumberRange {
	constructor(a, b) {
		this.Min = a;
		this.Max = b;
	}
	static new(a, b) {
		return new NumberRange(a, b === undefined ? a : b);
	}
	get $type() {
		return 'NumberRange';
	}
	pick() {
		return this.Min + Math.random() * (this.Max - this.Min);
	}
}

// ------------------------------------------------------------------ UDim / UDim2
export class UDim {
	constructor(s = 0, o = 0) {
		this.Scale = s;
		this.Offset = o;
	}
	static new(s, o) {
		return new UDim(s || 0, o || 0);
	}
	get $type() {
		return 'UDim';
	}
	__add(b) {
		return new UDim(this.Scale + b.Scale, this.Offset + b.Offset);
	}
}
export class UDim2 {
	constructor(xs = 0, xo = 0, ys = 0, yo = 0) {
		this.X = new UDim(xs, xo);
		this.Y = new UDim(ys, yo);
	}
	static new(xs, xo, ys, yo) {
		if (xs instanceof UDim) return new UDim2(xs.Scale, xs.Offset, xo.Scale, xo.Offset);
		return new UDim2(xs || 0, xo || 0, ys || 0, yo || 0);
	}
	static fromOffset(x = 0, y = 0) {
		return new UDim2(0, x, 0, y);
	}
	static fromScale(x = 0, y = 0) {
		return new UDim2(x, 0, y, 0);
	}
	get $type() {
		return 'UDim2';
	}
	get Width() {
		return this.X;
	}
	get Height() {
		return this.Y;
	}
	Lerp(b, t) {
		return new UDim2(
			this.X.Scale + (b.X.Scale - this.X.Scale) * t,
			this.X.Offset + (b.X.Offset - this.X.Offset) * t,
			this.Y.Scale + (b.Y.Scale - this.Y.Scale) * t,
			this.Y.Offset + (b.Y.Offset - this.Y.Offset) * t,
		);
	}
	__add(b) {
		return new UDim2(this.X.Scale + b.X.Scale, this.X.Offset + b.X.Offset, this.Y.Scale + b.Y.Scale, this.Y.Offset + b.Y.Offset);
	}
	__sub(b) {
		return new UDim2(this.X.Scale - b.X.Scale, this.X.Offset - b.X.Offset, this.Y.Scale - b.Y.Scale, this.Y.Offset - b.Y.Offset);
	}
	__eq(b) {
		return b instanceof UDim2 && b.X.Scale === this.X.Scale && b.X.Offset === this.X.Offset && b.Y.Scale === this.Y.Scale && b.Y.Offset === this.Y.Offset;
	}
}

// ------------------------------------------------------------------ Random
export class Random {
	constructor(seed) {
		this.s = (seed === undefined ? (Math.random() * 2 ** 32) >>> 0 : Math.floor(seed)) >>> 0 || 1;
	}
	static new(seed) {
		return new Random(seed);
	}
	get $type() {
		return 'Random';
	}
	next() {
		// mulberry32
		let t = (this.s += 0x6d2b79f5);
		t = Math.imul(t ^ (t >>> 15), t | 1);
		t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
		return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
	}
	NextNumber(a = 0, b = 1) {
		return a + this.next() * (b - a);
	}
	NextInteger(a, b) {
		return Math.floor(a + this.next() * (b - a + 1));
	}
	NextUnitVector() {
		const z = this.next() * 2 - 1, a = this.next() * Math.PI * 2, r = Math.sqrt(1 - z * z);
		return new Vector3(r * Math.cos(a), r * Math.sin(a), z);
	}
	Clone() {
		const r = new Random(1);
		r.s = this.s;
		return r;
	}
}

// ------------------------------------------------------------------ TweenInfo
export class TweenInfo {
	constructor(time, style, dir, repeat, reverses, delay) {
		this.Time = time;
		this.EasingStyle = style;
		this.EasingDirection = dir;
		this.RepeatCount = repeat;
		this.Reverses = reverses;
		this.DelayTime = delay;
	}
	static new(time = 1, style, dir, repeat = 0, reverses = false, delay = 0) {
		return new TweenInfo(time, style || Enum.EasingStyle.Quad, dir || Enum.EasingDirection.Out, repeat, reverses, delay);
	}
	get $type() {
		return 'TweenInfo';
	}
}

// ------------------------------------------------------------------ Enum
export class EnumItem {
	constructor(type, name, value) {
		this.EnumType = type;
		this.Name = name;
		this.Value = value;
	}
	get $type() {
		return 'EnumItem';
	}
	IsA(name) {
		return this.EnumType.$name === name;
	}
	toString() {
		return `Enum.${this.EnumType.$name}.${this.Name}`;
	}
}
const ENUMS = {
	Material: ['Plastic', 'SmoothPlastic', 'Neon', 'Glass', 'Metal', 'Wood', 'WoodPlanks', 'Slate', 'Ice', 'Glacier', 'ForceField', 'Foil', 'Snow', 'Marble', 'Sandstone', 'Fabric', 'Basalt', 'CrackedLava', 'Grass', 'LeafyGrass', 'Sand', 'Mud', 'Concrete', 'Brick', 'Granite', 'Pebble', 'Cobblestone', 'DiamondPlate', 'CorrodedMetal', 'Rock', 'Asphalt', 'Salt', 'Limestone', 'Pavement', 'Ground', 'Water', 'Air', 'Cardboard', 'Carpet', 'CeramicTiles', 'ClayRoofTiles', 'RoofShingles', 'Leather', 'Plaster', 'Rubber'],
	PartType: ['Ball', 'Block', 'Cylinder', 'Wedge', 'CornerWedge'],
	NormalId: ['Right', 'Top', 'Back', 'Left', 'Bottom', 'Front'],
	SurfaceType: ['Smooth', 'Glue', 'Weld', 'Studs', 'Inlet', 'Universal', 'Hinge', 'Motor', 'SteppingMotor', 'SmoothNoOutlines'],
	ParticleEmitterShape: ['Box', 'Sphere', 'Cylinder', 'Disc'],
	ParticleEmitterShapeStyle: ['Volume', 'Surface'],
	ParticleEmitterShapeInOut: ['Outward', 'Inward', 'InAndOut'],
	ParticleOrientation: ['FacingCamera', 'FacingCameraWorldUp', 'VelocityParallel', 'VelocityPerpendicular'],
	HighlightDepthMode: ['AlwaysOnTop', 'Occluded'],
	MeshType: ['Head', 'Torso', 'Wedge', 'Prism', 'Pyramid', 'ParallelRamp', 'RightAngleRamp', 'CornerWedge', 'Brick', 'Sphere', 'Cylinder', 'FileMesh'],
	EasingStyle: ['Linear', 'Sine', 'Back', 'Quad', 'Quart', 'Quint', 'Bounce', 'Elastic', 'Exponential', 'Circular', 'Cubic'],
	EasingDirection: ['In', 'Out', 'InOut'],
	Font: ['Legacy', 'Arial', 'ArialBold', 'SourceSans', 'SourceSansBold', 'SourceSansLight', 'SourceSansItalic', 'Bodoni', 'Garamond', 'Cartoon', 'Code', 'Highway', 'SciFi', 'Arcade', 'Fantasy', 'Antique', 'SourceSansSemibold', 'Gotham', 'GothamMedium', 'GothamBold', 'GothamBlack', 'AmaticSC', 'Bangers', 'Creepster', 'DenkOne', 'Fondamento', 'FredokaOne', 'GrenzeGotisch', 'IndieFlower', 'JosefinSans', 'Jura', 'Kalam', 'LuckiestGuy', 'Merriweather', 'Michroma', 'Nunito', 'Oswald', 'PatrickHand', 'PermanentMarker', 'Roboto', 'RobotoCondensed', 'RobotoMono', 'Sarpanch', 'SpecialElite', 'TitilliumWeb', 'Ubuntu', 'BuilderSans', 'BuilderSansBold'],
	BulkMoveMode: ['FireAllEvents', 'FireCFrameChanged'],
	RenderPriority: [['First', 0], ['Input', 100], ['Camera', 200], ['Character', 300], ['Last', 2000]],
	TextXAlignment: ['Left', 'Center', 'Right'],
	TextYAlignment: ['Top', 'Center', 'Bottom'],
	ZIndexBehavior: ['Global', 'Sibling'],
	ApplyStrokeMode: ['Contextual', 'Border'],
	SizeConstraint: ['RelativeXY', 'RelativeXX', 'RelativeYY'],
	AutomaticSize: ['None', 'X', 'Y', 'XY'],
	PlaybackState: ['Begin', 'Delayed', 'Playing', 'Paused', 'Completed', 'Cancelled'],
	TrailTextureMode: ['Stretch', 'Wrap', 'Static'],
	Axis: ['X', 'Y', 'Z'],
	HumanoidStateType: ['Running', 'Jumping', 'Freefall', 'Landed', 'Physics', 'Dead', 'Seated', 'Swimming', 'Climbing', 'GettingUp', 'FallingDown', 'Ragdoll', 'PlatformStanding', 'None'],
	RaycastFilterType: ['Exclude', 'Include', 'Blacklist', 'Whitelist'],
	KeyCode: [],
	UserInputType: [],
};
function makeEnumType(name, items) {
	const type = { $name: name };
	const list = [];
	items.forEach((it, i) => {
		const [n, v] = Array.isArray(it) ? it : [it, i];
		const item = new EnumItem(type, n, v);
		type[n] = item;
		list.push(item);
	});
	type.GetEnumItems = () => list.slice();
	// item que não está na lista: cria na hora (o código do Roblox pode usar outros nomes)
	return new Proxy(type, {
		get(t, k) {
			if (k in t || typeof k !== 'string') return t[k];
			const item = new EnumItem(type, k, list.length);
			t[k] = item;
			list.push(item);
			return item;
		},
	});
}
export const Enum = new Proxy(
	Object.fromEntries(Object.entries(ENUMS).map(([n, items]) => [n, makeEnumType(n, items)])),
	{
		get(t, k) {
			if (k in t || typeof k !== 'string') return t[k];
			t[k] = makeEnumType(k, []);
			return t[k];
		},
	},
);

// Font.new / Font.fromEnum (só o nome importa)
export const Font = {
	new: (family) => ({ Family: family, $type: 'Font' }),
	fromEnum: (e) => ({ Family: e.Name, $type: 'Font' }),
	fromName: (n) => ({ Family: n, $type: 'Font' }),
};
