// O cachorro do jogo visto pelo código do Roblox: um Model com HumanoidRootPart, Humanoid e as peças com os
// nomes do DogBuilder (Torso, Head1, Pata, AsaMembrana, CanhaoBoca...). As posições vêm ao vivo dos ossos do
// three.js, então efeitos presos numa peça (anexos, partículas, rastros, destaque) acompanham o cachorro.
import * as THREE from 'three';
import { Model, BasePart, Humanoid } from './instancias.js';
import { CFrame, Vector3, Color3, Enum } from './tipos.js';
import { $M } from './lua.js';
import { SPECIES_MODELS, speciesAsset } from '../dogs/rig.js';

const MATS = [Enum.Material.SmoothPlastic, Enum.Material.Neon, Enum.Material.Glass, Enum.Material.Metal, Enum.Material.ForceField];
let frame = 0;
export function proxyFrame() {
	frame++;
}

const _m = new THREE.Matrix4();
function cfFromElements(e) {
	const sx = Math.hypot(e[0], e[1], e[2]) || 1, sy = Math.hypot(e[4], e[5], e[6]) || 1, sz = Math.hypot(e[8], e[9], e[10]) || 1;
	return new CFrame(e[12], e[13], e[14], e[0] / sx, e[4] / sy, e[8] / sz, e[1] / sx, e[5] / sy, e[9] / sz, e[2] / sx, e[6] / sy, e[10] / sz);
}

// dados fixos por espécie (matriz local de cada peça, tamanhos, caixa)
const SPECIES_INFO = new Map();
function speciesInfo(id) {
	let info = SPECIES_INFO.get(id);
	if (info) return info;
	const d = SPECIES_MODELS[id];
	const asset = speciesAsset(id);
	const parts = d.parts.map((p) => {
		const [bone, wedge, sx, sy, sz, px, py, pz, qx, qy, qz, qw, hex, mat, tr, ni] = p;
		const m = new THREE.Matrix4().compose(new THREE.Vector3(px, py, pz), new THREE.Quaternion(qx, qy, qz, qw), new THREE.Vector3(1, 1, 1));
		return { bone, wedge, size: [sx, sy, sz], m, hex, mat, tr, name: (d.names && d.names[ni]) || 'Part' };
	});
	// caixa do modelo em repouso (para GetExtentsSize)
	const pos = asset.geometry.attributes.position.array;
	let lo = [Infinity, Infinity, Infinity], hi = [-Infinity, -Infinity, -Infinity];
	for (let i = 0; i < pos.length; i += 3) {
		for (let k = 0; k < 3; k++) {
			const v = pos[i + k];
			if (v < lo[k]) lo[k] = v;
			if (v > hi[k]) hi[k] = v;
		}
	}
	const root = d.root || [Math.max(1, d.rootY), d.rootY, Math.max(2, d.rootY * 1.8)];
	info = { parts, extents: [hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]], root, hip: d.hip, heads: d.heads || 1 };
	SPECIES_INFO.set(id, info);
	return info;
}

// garante que os ossos do cachorro estão com a posição deste quadro
function freshBones(dog) {
	if (dog.$upd === frame) return;
	dog.$upd = frame;
	const mesh = dog.$f.mesh;
	if (mesh) mesh.updateMatrixWorld(true);
}

class RootProxy extends BasePart {
	constructor(dog) {
		super('Part');
		this.$proxy = true;
		this.$dog = dog;
		this._name = 'HumanoidRootPart';
		this._Transparency = 1;
		this._CanCollide = false;
	}
	get CFrame() {
		const f = this.$dog.$f;
		const b = f.body;
		const rot = f.pitch || f.roll ? CFrame.fromEulerAnglesYXZ(f.pitch || 0, f.yaw, f.roll || 0) : CFrame.Angles(0, f.yaw, 0);
		return rot.__add(new Vector3(b.x, (f.visualY ?? b.y) + f.groundOffset, b.z));
	}
	set CFrame(cf) {
		const f = this.$dog.$f;
		f.body.x = cf.x;
		f.body.z = cf.z;
		f.body.y = cf.y - f.groundOffset;
		f.visualY = f.body.y;
		const lv = cf.LookVector;
		if (Math.abs(lv.x) + Math.abs(lv.z) > 1e-4) f.yaw = Math.atan2(-lv.x, -lv.z);
	}
	get Position() {
		const f = this.$dog.$f;
		const b = f.body;
		return new Vector3(b.x, (f.visualY ?? b.y) + f.groundOffset, b.z);
	}
	set Position(v) {
		const f = this.$dog.$f;
		f.body.x = v.x;
		f.body.z = v.z;
		f.body.y = v.y - f.groundOffset;
	}
	get Size() {
		const f = this.$dog.$f;
		const r = this.$dog.$info.root;
		const s = f.scale;
		return new Vector3(r[0] * s, r[1] * s, r[2] * s);
	}
	set Size(v) {}
	get Parent() {
		return this._parent;
	}
	set Parent(p) {
		super.Parent = p;
	}
	get AssemblyLinearVelocity() {
		const b = this.$dog.$f.body;
		return new Vector3(b.vx, b.vy, b.vz);
	}
	set AssemblyLinearVelocity(v) {}
}

class PartProxy extends BasePart {
	constructor(dog, def) {
		super(def.wedge ? 'WedgePart' : 'Part');
		this.$proxy = true;
		this.$dog = dog;
		this.$def = def;
		this._name = def.name;
		const hex = def.hex;
		this._Color = Color3.fromRGB((hex >> 16) & 255, (hex >> 8) & 255, hex & 255);
		this._Material = MATS[def.mat] || Enum.Material.SmoothPlastic;
		this._Transparency = def.tr || 0;
		this._CanCollide = false;
	}
	get CFrame() {
		const dog = this.$dog;
		freshBones(dog);
		const bone = dog.$f.rig.bones[this.$def.bone];
		if (!bone) return dog.root.CFrame;
		_m.multiplyMatrices(bone.matrixWorld, this.$def.m);
		return cfFromElements(_m.elements);
	}
	set CFrame(cf) {}
	get Position() {
		return this.CFrame.Position;
	}
	set Position(v) {}
	get Size() {
		const s = this.$dog.$f.scale;
		const z = this.$def.size;
		return new Vector3(z[0] * s, z[1] * s, z[2] * s);
	}
	set Size(v) {}
	get LocalTransparencyModifier() {
		return this._ltm || 0;
	}
	set LocalTransparencyModifier(v) {
		this._ltm = v;
		// esconder o tronco = esconder o cachorro (sumiço)
		if (this._name === 'Torso') this.$dog.$f.mesh.visible = !(v >= 0.99);
	}
}

class DogHumanoid extends Humanoid {
	constructor(dog) {
		super('Humanoid');
		this.$dog = dog;
	}
	get HipHeight() {
		const f = this.$dog.$f;
		return this.$dog.$info.hip * f.scale;
	}
	set HipHeight(v) {}
	get Health() {
		return this.$dog.$f.hp;
	}
	set Health(v) {
		if (!this.$dog) return;
		const f = this.$dog.$f;
		f.hp = Math.max(0, Math.min(f.maxHp, v));
	}
	get MaxHealth() {
		return this.$dog.$f.maxHp;
	}
	set MaxHealth(v) {}
	get WalkSpeed() {
		return this.$dog.$f.species.Stats.Speed;
	}
	set WalkSpeed(v) {}
	get MoveDirection() {
		const b = this.$dog.$f.body;
		const l = Math.hypot(b.vx, b.vz);
		return l > 0.5 ? new Vector3(b.vx / l, 0, b.vz / l) : Vector3.zero;
	}
	set MoveDirection(v) {}
}

export class DogModel extends Model {
	constructor(fighter, workspace, localUserId) {
		super('Model');
		this.$f = fighter;
		this.$fighter = fighter;
		this.$info = speciesInfo(fighter.speciesId);
		this.$upd = -1;
		this.$parts = null;
		this._name = fighter.species ? fighter.species.Name : 'Dog';
		this.root = new RootProxy(this);
		this.root.Parent = this;
		this.PrimaryPart = this.root;
		this.hum = new DogHumanoid(this);
		this.hum.Parent = this;
		this.SetAttribute('HipHeight', this.$info.hip * fighter.scale);
		this.SetAttribute('Heads', this.$info.heads);
		this.SetAttribute('Species', fighter.speciesId);
		if (fighter.kind === 'player' && localUserId) this.SetAttribute('Owner', localUserId);
		this.AddTag('Dog');
		this.Parent = workspace;
	}
	$ensureParts() {
		if (this.$parts) return;
		this.$parts = this.$info.parts.map((def) => {
			const p = new PartProxy(this, def);
			p.Parent = this;
			return p;
		});
	}
	GetChildren() {
		this.$ensureParts();
		return super.GetChildren();
	}
	GetDescendants() {
		this.$ensureParts();
		return super.GetDescendants();
	}
	FindFirstChild(name, rec) {
		if (name !== 'HumanoidRootPart' && name !== 'Humanoid') this.$ensureParts();
		return super.FindFirstChild(name, rec);
	}
	FindFirstChildWhichIsA(cls, rec) {
		if (cls !== 'Humanoid') this.$ensureParts();
		return super.FindFirstChildWhichIsA(cls, rec);
	}
	GetPivot() {
		return this.root.CFrame;
	}
	PivotTo(cf) {
		this.root.CFrame = cf;
	}
	GetBoundingBox() {
		const s = this.$f.scale;
		const e = this.$info.extents;
		return $M(this.root.CFrame, new Vector3(e[0] * s, e[1] * s, e[2] * s));
	}
	GetExtentsSize() {
		const s = this.$f.scale;
		const e = this.$info.extents;
		return new Vector3(e[0] * s, e[1] * s, e[2] * s);
	}
}

// "Head1", "Torso"... devolve o proxy da peça (para o código JS do kit)
export function dogPart(model, name) {
	if (!model) return null;
	return model.FindFirstChild(name) || null;
}
