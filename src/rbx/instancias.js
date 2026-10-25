// Objetos do Roblox (Instance): Part, Attachment, ParticleEmitter, Trail, PointLight, Highlight, BillboardGui,
// TextLabel, ColorCorrectionEffect, Folder, Model, ModuleScript, RemoteEvent e os serviços (Workspace, RunService,
// TweenService, Debris, Players, Lighting...). O desenho no three.js fica em cena.js (pelos "ganchos" G abaixo):
// aqui só os dados, a árvore (Parent/filhos) e os eventos.
import { $M, LuaError, callLua, delayCall, sched, tostring } from './lua.js';
import { Vector3, Vector2, CFrame, Color3, NumberSequence, ColorSequence, NumberRange, UDim2, Enum, TweenInfo } from './tipos.js';

// ganchos do desenho (cena.js preenche)
export const G = {
	enter: null, // (inst) entrou no mundo
	leave: null, // (inst) saiu do mundo
	dirty: null, // (inst, bits) mudou algo
	emit: null, // (emitter, n)
	world: null, // a Workspace
};

// ------------------------------------------------------------------ sinais (eventos)
export class Connection {
	constructor(sig, fn) {
		this.sig = sig;
		this.fn = fn;
		this.Connected = true;
	}
	get $type() {
		return 'RBXScriptConnection';
	}
	Disconnect() {
		if (!this.Connected) return;
		this.Connected = false;
		const i = this.sig.conns.indexOf(this);
		if (i >= 0) this.sig.conns.splice(i, 1);
	}
}

export class Signal {
	constructor() {
		this.conns = [];
		this.waiters = null;
	}
	get $type() {
		return 'RBXScriptSignal';
	}
	Connect(fn) {
		const c = new Connection(this, fn);
		this.conns.push(c);
		return c;
	}
	Once(fn) {
		const c = this.Connect((...a) => {
			c.Disconnect();
			return fn(...a);
		});
		return c;
	}
	ConnectParallel(fn) {
		return this.Connect(fn);
	}
	$addWaiter(th) {
		(this.waiters || (this.waiters = [])).push(th);
	}
	Fire(...args) {
		if (this.conns.length) {
			const list = this.conns.length === 1 ? this.conns : this.conns.slice();
			for (const c of list) if (c.Connected) callLua(c.fn, ...args);
		}
		if (this.waiters) {
			const w = this.waiters;
			this.waiters = null;
			for (const th of w) delayCall(0, th, ...args);
		}
	}
}

// ------------------------------------------------------------------ Instance
const CLASSES = {};
const ISA = {};

export class Instance {
	constructor(className) {
		this.ClassName = className;
		this._name = className;
		this._parent = undefined;
		this.$kids = [];
		this.$attrs = null;
		this.$sigs = null;
		this.$destroyed = false;
		this.$inWorld = false;
		this.Archivable = true;
	}
	static new(className, parent) {
		const C = CLASSES[className];
		if (!C) throw new LuaError(`Unable to create an Instance of type "${className}"`);
		const inst = new C(className);
		if (parent) inst.Parent = parent;
		return inst;
	}
	get $type() {
		return 'Instance';
	}
	toString() {
		return this._name;
	}
	$signal(name) {
		if (!this.$sigs) this.$sigs = {};
		return this.$sigs[name] || (this.$sigs[name] = new Signal());
	}
	$fire(name, ...args) {
		const s = this.$sigs && this.$sigs[name];
		if (s) s.Fire(...args);
	}
	get ChildAdded() {
		return this.$signal('ChildAdded');
	}
	get ChildRemoved() {
		return this.$signal('ChildRemoved');
	}
	get DescendantAdded() {
		return this.$signal('DescendantAdded');
	}
	get DescendantRemoving() {
		return this.$signal('DescendantRemoving');
	}
	get Destroying() {
		return this.$signal('Destroying');
	}
	get AncestryChanged() {
		return this.$signal('AncestryChanged');
	}
	get Changed() {
		return this.$signal('Changed');
	}
	GetPropertyChangedSignal(prop) {
		return this.$signal('prop:' + prop);
	}
	GetAttributeChangedSignal(name) {
		return this.$signal('attr:' + name);
	}
	get AttributeChanged() {
		return this.$signal('AttributeChanged');
	}

	get Name() {
		return this._name;
	}
	set Name(v) {
		v = tostring(v);
		if (v === this._name) return;
		const p = this._parent;
		if (p) p.$unlinkName(this);
		this._name = v;
		if (p) p.$linkName(this);
	}

	// filho acessível como campo (workspace.FX, script.Parent.Animator)
	$linkName(child) {
		const n = child._name;
		if (!(n in this) || (Object.prototype.hasOwnProperty.call(this, n) && this[n] instanceof Instance && this[n]._parent !== this)) {
			Object.defineProperty(this, n, { value: child, configurable: true, writable: true, enumerable: false });
		}
	}
	$unlinkName(child) {
		const n = child._name;
		if (Object.prototype.hasOwnProperty.call(this, n) && this[n] === child) {
			delete this[n];
			const other = this.$kids.find((k) => k !== child && k._name === n);
			if (other) this.$linkName(other);
		}
	}

	get Parent() {
		return this._parent;
	}
	set Parent(p) {
		if (p === null) p = undefined;
		if (p === this._parent) return;
		if (this.$destroyed) throw new LuaError(`The Parent property of ${this._name} is locked`);
		if (p !== undefined && !(p instanceof Instance)) throw new LuaError('Parent must be an Instance');
		const old = this._parent;
		if (old) {
			const i = old.$kids.indexOf(this);
			if (i >= 0) old.$kids.splice(i, 1);
			old.$unlinkName(this);
		}
		this._parent = p;
		if (p) {
			p.$kids.push(this);
			p.$linkName(this);
		}
		const world = !!(p && p.$inWorld);
		if (world !== this.$inWorld) this.$setWorld(world);
		else if (world) this.$reparented();
		if (old) old.$fire('ChildRemoved', this);
		if (p) {
			p.$fire('ChildAdded', this);
			for (let a = p; a; a = a._parent) if (a.$sigs && a.$sigs.DescendantAdded) a.$fire('DescendantAdded', this);
		}
		this.$fire('AncestryChanged', this, p);
	}
	// entrou/saiu do mundo (desenhado)
	$setWorld(flag) {
		this.$inWorld = flag;
		if (flag) G.enter && G.enter(this);
		else G.leave && G.leave(this);
		for (const k of this.$kids) if (k.$inWorld !== flag) k.$setWorld(flag);
	}
	// trocou de pai mas continua no mundo (anexos e emissores precisam saber)
	$reparented() {
		G.dirty && G.dirty(this, 1);
	}

	Destroy() {
		if (this.$destroyed) return;
		this.$fire('Destroying');
		for (const k of this.$kids.slice()) k.Destroy();
		this.Parent = undefined;
		this.$destroyed = true;
		if (this.$sigs) for (const s of Object.values(this.$sigs)) s.conns.length = 0;
	}
	Remove() {
		this.Parent = undefined;
	}
	ClearAllChildren() {
		for (const k of this.$kids.slice()) k.Destroy();
	}
	Clone() {
		if (!this.Archivable) return undefined;
		const C = CLASSES[this.ClassName] || this.constructor;
		const c = new C(this.ClassName);
		for (const key of this.$cloneKeys()) {
			const v = this[key];
			if (v !== undefined) c[key] = v;
		}
		c._name = this._name;
		if (this.$attrs) c.$attrs = new Map(this.$attrs);
		for (const k of this.$kids) {
			const kc = k.Clone();
			if (kc) kc.Parent = c;
		}
		return c;
	}
	$cloneKeys() {
		return [];
	}
	GetChildren() {
		return this.$kids.slice();
	}
	GetDescendants() {
		const out = [];
		const walk = (n) => {
			for (const k of n.$kids) {
				out.push(k);
				walk(k);
			}
		};
		walk(this);
		return out;
	}
	FindFirstChild(name, recursive) {
		for (const k of this.$kids) if (k._name === name) return k;
		if (recursive) for (const k of this.$kids) {
			const r = k.FindFirstChild(name, true);
			if (r) return r;
		}
		return undefined;
	}
	FindFirstChildOfClass(cls) {
		for (const k of this.$kids) if (k.ClassName === cls) return k;
		return undefined;
	}
	FindFirstChildWhichIsA(cls, recursive) {
		for (const k of this.$kids) if (k.IsA(cls)) return k;
		if (recursive) for (const k of this.$kids) {
			const r = k.FindFirstChildWhichIsA(cls, true);
			if (r) return r;
		}
		return undefined;
	}
	FindFirstAncestor(name) {
		for (let a = this._parent; a; a = a._parent) if (a._name === name) return a;
		return undefined;
	}
	FindFirstAncestorOfClass(cls) {
		for (let a = this._parent; a; a = a._parent) if (a.ClassName === cls) return a;
		return undefined;
	}
	FindFirstAncestorWhichIsA(cls) {
		for (let a = this._parent; a; a = a._parent) if (a.IsA(cls)) return a;
		return undefined;
	}
	WaitForChild(name) {
		return this.FindFirstChild(name);
	}
	IsA(cls) {
		if (cls === 'Instance') return true;
		const set = ISA[this.ClassName];
		return set ? set.has(cls) : cls === this.ClassName;
	}
	IsDescendantOf(anc) {
		for (let a = this._parent; a; a = a._parent) if (a === anc) return true;
		return false;
	}
	IsAncestorOf(d) {
		return d && d.IsDescendantOf(this);
	}
	GetFullName() {
		const names = [];
		for (let a = this; a && a.ClassName !== 'DataModel'; a = a._parent) names.unshift(a._name);
		return names.join('.');
	}
	GetAttribute(name) {
		return this.$attrs ? this.$attrs.get(name) : undefined;
	}
	SetAttribute(name, v) {
		if (!this.$attrs) this.$attrs = new Map();
		if (v === undefined || v === null) this.$attrs.delete(name);
		else this.$attrs.set(name, v);
		this.$fire('attr:' + name);
		this.$fire('AttributeChanged', name);
	}
	GetAttributes() {
		return this.$attrs ? Object.fromEntries(this.$attrs) : {};
	}
	GetTags() {
		return this.$tags ? [...this.$tags] : [];
	}
	HasTag(t) {
		return !!(this.$tags && this.$tags.has(t));
	}
	AddTag(t) {
		(this.$tags || (this.$tags = new Set())).add(t);
	}
	RemoveTag(t) {
		this.$tags && this.$tags.delete(t);
	}
}

function define(name, C, parents = []) {
	CLASSES[name] = C;
	ISA[name] = new Set([name, ...parents]);
}

// propriedade simples que avisa o desenho quando muda (bits = o que mudou)
function props(C, list) {
	for (const [key, def, bits] of list) {
		const slot = '_' + key;
		C.prototype[slot] = def;
		Object.defineProperty(C.prototype, key, {
			get() {
				return this[slot];
			},
			set(v) {
				if (v === null) v = undefined;
				if (this[slot] === v) return;
				this[slot] = v;
				if (bits && this.$inWorld) G.dirty(this, bits);
			},
			configurable: true,
		});
	}
	const keys = list.map((l) => l[0]);
	const base = C.prototype.$cloneKeys;
	C.prototype.$cloneKeys = function () {
		return [...base.call(this), ...keys];
	};
}

// ------------------------------------------------------------------ pastas, modelos, scripts
export class Folder extends Instance {}
define('Folder', Folder);
define('Configuration', Folder);

export class ModuleScript extends Instance {
	constructor(cls) {
		super(cls);
		this.$factory = null;
		this.$value = undefined;
		this.$loaded = false;
	}
	$require() {
		if (!this.$loaded) {
			this.$loaded = true;
			this.$value = this.$factory ? this.$factory(this) : undefined;
		}
		return this.$value;
	}
}
define('ModuleScript', ModuleScript, ['LuaSourceContainer']);

export class RemoteEvent extends Instance {
	get OnClientEvent() {
		return this.$signal('OnClientEvent');
	}
	get OnServerEvent() {
		return this.$signal('OnServerEvent');
	}
	FireServer() {}
	FireClient() {}
	FireAllClients(...a) {
		this.$fire('OnClientEvent', ...a);
	}
}
define('RemoteEvent', RemoteEvent);
define('UnreliableRemoteEvent', RemoteEvent);

export class BindableEvent extends Instance {
	get Event() {
		return this.$signal('Event');
	}
	Fire(...a) {
		this.$fire('Event', ...a);
	}
}
define('BindableEvent', BindableEvent);

// valores (IntValue, StringValue...)
export class ValueBase extends Instance {
	constructor(cls) {
		super(cls);
		this._Value = undefined;
	}
	get Value() {
		return this._Value;
	}
	set Value(v) {
		this._Value = v;
		this.$fire('Changed', v);
	}
}
for (const n of ['IntValue', 'NumberValue', 'StringValue', 'BoolValue', 'ObjectValue', 'Vector3Value', 'CFrameValue', 'Color3Value']) define(n, ValueBase, ['ValueBase']);

// ------------------------------------------------------------------ peças (BasePart)
// bits: 1 = posição/tamanho, 2 = cor/material/transparência, 4 = forma
export class BasePart extends Instance {
	constructor(cls) {
		super(cls);
		this._Size = cls === 'Part' ? new Vector3(4, 1, 2) : new Vector3(4, 1, 2);
		this._CFrame = CFrame.identity;
		this.AssemblyLinearVelocity = Vector3.zero;
		this.AssemblyAngularVelocity = Vector3.zero;
	}
	get Size() {
		return this._Size;
	}
	set Size(v) {
		if (!(v instanceof Vector3)) throw new LuaError('Size must be a Vector3');
		this._Size = new Vector3(Math.max(0.001, v.x), Math.max(0.001, v.y), Math.max(0.001, v.z));
		if (this.$inWorld) G.dirty(this, 1);
	}
	get CFrame() {
		return this._CFrame;
	}
	set CFrame(cf) {
		if (!(cf instanceof CFrame)) throw new LuaError('CFrame must be a CFrame');
		this._CFrame = cf;
		if (this.$inWorld) G.dirty(this, 1);
	}
	get Position() {
		return this._CFrame.Position;
	}
	set Position(v) {
		const c = this._CFrame;
		this.CFrame = new CFrame(v.x, v.y, v.z, c.m00, c.m01, c.m02, c.m10, c.m11, c.m12, c.m20, c.m21, c.m22);
	}
	get Orientation() {
		const [rx, ry, rz] = this._CFrame.ToEulerAnglesYXZ().v;
		const d = 180 / Math.PI;
		return new Vector3(rx * d, ry * d, rz * d);
	}
	set Orientation(v) {
		const r = Math.PI / 180;
		const p = this._CFrame;
		this.CFrame = CFrame.fromEulerAnglesYXZ(v.x * r, v.y * r, v.z * r).__add(p.Position);
	}
	get Rotation() {
		const [rx, ry, rz] = this._CFrame.ToEulerAnglesXYZ().v;
		const d = 180 / Math.PI;
		return new Vector3(rx * d, ry * d, rz * d);
	}
	set Rotation(v) {
		const r = Math.PI / 180;
		this.CFrame = CFrame.Angles(v.x * r, v.y * r, v.z * r).__add(this._CFrame.Position);
	}
	get BrickColor() {
		return { Color: this._Color, Name: 'Custom', $type: 'BrickColor' };
	}
	set BrickColor(b) {
		this.Color = b.Color;
	}
	get Velocity() {
		return this.AssemblyLinearVelocity;
	}
	set Velocity(v) {
		this.AssemblyLinearVelocity = v;
	}
	get Touched() {
		return this.$signal('Touched');
	}
	get TouchEnded() {
		return this.$signal('TouchEnded');
	}
	GetMass() {
		return this._Size.x * this._Size.y * this._Size.z * 0.7;
	}
	GetTouchingParts() {
		return [];
	}
	GetConnectedParts() {
		return [];
	}
	GetRootPart() {
		return this;
	}
	BreakJoints() {}
	MakeJoints() {}
	PivotTo(cf) {
		this.CFrame = cf;
	}
	GetPivot() {
		return this._CFrame;
	}
	$cloneKeys() {
		return ['Size', 'CFrame', ...super.$cloneKeys()];
	}
}
props(BasePart, [
	['Color', Color3.fromRGB(163, 162, 165), 2],
	['Transparency', 0, 2],
	['LocalTransparencyModifier', 0, 2],
	['Reflectance', 0, 2],
	['Material', Enum.Material.Plastic, 2],
	['Anchored', false, 0],
	['CanCollide', true, 0],
	['CanQuery', true, 0],
	['CanTouch', true, 0],
	['CastShadow', true, 0],
	['Massless', false, 0],
	['Locked', false, 0],
	['TopSurface', Enum.SurfaceType.Smooth, 0],
	['BottomSurface', Enum.SurfaceType.Smooth, 0],
	['CollisionGroup', 'Default', 0],
]);

export class Part extends BasePart {}
props(Part, [['Shape', Enum.PartType.Block, 4]]);
define('Part', Part, ['BasePart', 'FormFactorPart', 'PVInstance']);
export class WedgePart extends BasePart {}
define('WedgePart', WedgePart, ['BasePart', 'FormFactorPart', 'PVInstance']);
export class CornerWedgePart extends BasePart {}
define('CornerWedgePart', CornerWedgePart, ['BasePart', 'PVInstance']);
export class TrussPart extends BasePart {}
define('TrussPart', TrussPart, ['BasePart', 'PVInstance']);
export class MeshPart extends BasePart {}
props(MeshPart, [['MeshId', '', 4], ['TextureID', '', 2]]);
define('MeshPart', MeshPart, ['BasePart', 'TriangleMeshPart', 'PVInstance']);

// malha especial (bola achatada = elipsoide)
export class SpecialMesh extends Instance {}
props(SpecialMesh, [
	['MeshType', Enum.MeshType.Head, 4],
	['Scale', new Vector3(1, 1, 1), 4],
	['Offset', Vector3.zero, 4],
	['VertexColor', new Vector3(1, 1, 1), 2],
	['MeshId', '', 4],
	['TextureId', '', 2],
]);
SpecialMesh.prototype.$reparented = function () {
	G.dirty(this, 4);
};
define('SpecialMesh', SpecialMesh, ['FileMesh', 'DataModelMesh']);
export class BlockMesh extends Instance {}
props(BlockMesh, [['Scale', new Vector3(1, 1, 1), 4], ['Offset', Vector3.zero, 4]]);
define('BlockMesh', BlockMesh, ['BevelMesh', 'DataModelMesh']);
define('CylinderMesh', BlockMesh, ['BevelMesh', 'DataModelMesh']);

// junta (só os dados)
export class JointInstance extends Instance {
	constructor(cls) {
		super(cls);
		this.C0 = CFrame.identity;
		this.C1 = CFrame.identity;
		this.Part0 = undefined;
		this.Part1 = undefined;
		this.Enabled = true;
	}
}
for (const n of ['Weld', 'WeldConstraint', 'Motor6D', 'ManualWeld', 'Snap']) define(n, JointInstance, ['JointInstance']);

// ------------------------------------------------------------------ Model
export class Model extends Instance {
	constructor(cls) {
		super(cls);
		this.PrimaryPart = undefined;
		this.$pivot = undefined;
	}
	get WorldPivot() {
		return this.GetPivot();
	}
	set WorldPivot(cf) {
		this.$pivot = cf;
	}
	GetPivot() {
		if (this.PrimaryPart) return this.PrimaryPart.CFrame;
		if (this.$pivot) return this.$pivot;
		const parts = this.GetDescendants().filter((d) => d instanceof BasePart);
		if (!parts.length) return CFrame.identity;
		let x = 0, y = 0, z = 0;
		for (const p of parts) {
			x += p.CFrame.x;
			y += p.CFrame.y;
			z += p.CFrame.z;
		}
		return CFrame.new(x / parts.length, y / parts.length, z / parts.length);
	}
	PivotTo(cf) {
		const cur = this.GetPivot();
		const delta = cf.__mul(cur.Inverse());
		for (const d of this.GetDescendants()) if (d instanceof BasePart) d.CFrame = delta.__mul(d.CFrame);
		if (this.$pivot) this.$pivot = cf;
	}
	SetPrimaryPartCFrame(cf) {
		this.PivotTo(cf);
	}
	GetPrimaryPartCFrame() {
		return this.GetPivot();
	}
	GetBoundingBox() {
		const parts = this.GetDescendants().filter((d) => d instanceof BasePart);
		if (!parts.length) return $M(CFrame.identity, Vector3.zero);
		let lo = [Infinity, Infinity, Infinity], hi = [-Infinity, -Infinity, -Infinity];
		for (const p of parts) {
			const c = p.CFrame, s = p.Size;
			const ex = Math.abs(c.m00) * s.x / 2 + Math.abs(c.m01) * s.y / 2 + Math.abs(c.m02) * s.z / 2;
			const ey = Math.abs(c.m10) * s.x / 2 + Math.abs(c.m11) * s.y / 2 + Math.abs(c.m12) * s.z / 2;
			const ez = Math.abs(c.m20) * s.x / 2 + Math.abs(c.m21) * s.y / 2 + Math.abs(c.m22) * s.z / 2;
			lo = [Math.min(lo[0], c.x - ex), Math.min(lo[1], c.y - ey), Math.min(lo[2], c.z - ez)];
			hi = [Math.max(hi[0], c.x + ex), Math.max(hi[1], c.y + ey), Math.max(hi[2], c.z + ez)];
		}
		return $M(CFrame.new((lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2), new Vector3(hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]));
	}
	GetExtentsSize() {
		return this.GetBoundingBox().v[1];
	}
	ScaleTo() {}
	GetScale() {
		return 1;
	}
}
define('Model', Model, ['PVInstance']);

// ------------------------------------------------------------------ Attachment
export class Attachment extends Instance {
	constructor(cls) {
		super(cls);
		this._CFrame = CFrame.identity;
		this.Visible = false;
	}
	get CFrame() {
		return this._CFrame;
	}
	set CFrame(cf) {
		this._CFrame = cf;
		if (this.$inWorld) G.dirty(this, 1);
	}
	get Position() {
		return this._CFrame.Position;
	}
	set Position(v) {
		const c = this._CFrame;
		this.CFrame = new CFrame(v.x, v.y, v.z, c.m00, c.m01, c.m02, c.m10, c.m11, c.m12, c.m20, c.m21, c.m22);
	}
	get Orientation() {
		const [rx, ry, rz] = this._CFrame.ToEulerAnglesYXZ().v;
		const d = 180 / Math.PI;
		return new Vector3(rx * d, ry * d, rz * d);
	}
	set Orientation(v) {
		const r = Math.PI / 180;
		this.CFrame = CFrame.fromEulerAnglesYXZ(v.x * r, v.y * r, v.z * r).__add(this._CFrame.Position);
	}
	get Axis() {
		return this._CFrame.RightVector;
	}
	get SecondaryAxis() {
		return this._CFrame.UpVector;
	}
	// CFrame no mundo: o pai é uma peça (ou o Terrain = mundo)
	get WorldCFrame() {
		const p = this._parent;
		if (p && p.$partCFrame) return p.$partCFrame().__mul(this._CFrame);
		if (p instanceof BasePart && p.ClassName !== 'Terrain') return p.CFrame.__mul(this._CFrame);
		return this._CFrame;
	}
	set WorldCFrame(cf) {
		const p = this._parent;
		if (p instanceof BasePart && p.ClassName !== 'Terrain') this.CFrame = p.CFrame.Inverse().__mul(cf);
		else this.CFrame = cf;
	}
	get WorldPosition() {
		return this.WorldCFrame.Position;
	}
	set WorldPosition(v) {
		const p = this._parent;
		if (p instanceof BasePart && p.ClassName !== 'Terrain') this.Position = p.CFrame.PointToObjectSpace(v);
		else this.Position = v;
	}
	get WorldAxis() {
		return this.WorldCFrame.RightVector;
	}
	get WorldOrientation() {
		return this.Orientation;
	}
	$cloneKeys() {
		return ['CFrame', ...super.$cloneKeys()];
	}
}
define('Attachment', Attachment);
define('Bone', Attachment, ['Attachment']);

// ------------------------------------------------------------------ partículas
export class ParticleEmitter extends Instance {
	constructor(cls) {
		super(cls);
		this.$acc = 0;
	}
	Emit(n = 16) {
		if (this.$inWorld && G.emit) G.emit(this, Math.floor(n));
	}
	Clear() {
		G.dirty && G.dirty(this, 8);
	}
	FastForward() {}
}
props(ParticleEmitter, [
	['Enabled', true, 1],
	['Rate', 5, 0],
	['Texture', 'rbxasset://textures/particles/sparkles_main.dds', 0],
	['Color', ColorSequence.new(Color3.new(1, 1, 1)), 0],
	['Size', NumberSequence.new(1), 0],
	['Transparency', NumberSequence.new(0), 0],
	['Lifetime', NumberRange.new(5, 10), 0],
	['Speed', NumberRange.new(5, 5), 0],
	['SpreadAngle', Vector2.new(0, 0), 0],
	['Rotation', NumberRange.new(0, 0), 0],
	['RotSpeed', NumberRange.new(0, 0), 0],
	['Acceleration', Vector3.zero, 0],
	['Drag', 0, 0],
	['LightEmission', 0, 0],
	['LightInfluence', 0, 0],
	['Brightness', 1, 0],
	['ZOffset', 0, 0],
	['EmissionDirection', Enum.NormalId.Top, 0],
	['LockedToPart', false, 0],
	['VelocityInheritance', 0, 0],
	['Shape', Enum.ParticleEmitterShape.Box, 0],
	['ShapeStyle', Enum.ParticleEmitterShapeStyle.Volume, 0],
	['ShapeInOut', Enum.ParticleEmitterShapeInOut.Outward, 0],
	['ShapePartial', 1, 0],
	['Squash', NumberSequence.new(0), 0],
	['Orientation', Enum.ParticleOrientation.FacingCamera, 0],
	['TimeScale', 1, 0],
	['WindAffectsDrag', false, 0],
	['FlipbookLayout', undefined, 0],
]);
define('ParticleEmitter', ParticleEmitter);

// ------------------------------------------------------------------ rastro, luz, destaque
export class Trail extends Instance {
	Clear() {
		G.dirty && G.dirty(this, 8);
	}
}
props(Trail, [
	['Attachment0', undefined, 1],
	['Attachment1', undefined, 1],
	['Enabled', true, 1],
	['Color', ColorSequence.new(Color3.new(1, 1, 1)), 0],
	['Transparency', NumberSequence.new(0.5), 0],
	['WidthScale', NumberSequence.new(1), 0],
	['Lifetime', 2, 0],
	['MinLength', 0.1, 0],
	['MaxLength', 0, 0],
	['FaceCamera', false, 0],
	['LightEmission', 0, 0],
	['LightInfluence', 1, 0],
	['Brightness', 1, 0],
	['Texture', '', 0],
	['TextureLength', 1, 0],
	['TextureMode', Enum.TrailTextureMode.Stretch, 0],
]);
define('Trail', Trail);

export class Beam extends Instance {}
props(Beam, [
	['Attachment0', undefined, 1],
	['Attachment1', undefined, 1],
	['Enabled', true, 1],
	['Color', ColorSequence.new(Color3.new(1, 1, 1)), 0],
	['Transparency', NumberSequence.new(0.5), 0],
	['Width0', 1, 0],
	['Width1', 1, 0],
	['LightEmission', 0, 0],
	['FaceCamera', false, 0],
	['Segments', 10, 0],
	['CurveSize0', 0, 0],
	['CurveSize1', 0, 0],
	['Texture', '', 0],
]);
define('Beam', Beam);

export class Light extends Instance {}
props(Light, [
	['Brightness', 1, 2],
	['Range', 8, 2],
	['Color', Color3.new(1, 1, 1), 2],
	['Enabled', true, 2],
	['Shadows', false, 0],
	['Angle', 90, 0],
	['Face', Enum.NormalId.Front, 0],
]);
define('PointLight', Light, ['Light']);
define('SpotLight', Light, ['Light']);
define('SurfaceLight', Light, ['Light']);

export class Highlight extends Instance {}
props(Highlight, [
	['Adornee', undefined, 1],
	['Enabled', true, 2],
	['FillColor', Color3.fromRGB(255, 0, 0), 2],
	['FillTransparency', 0.5, 2],
	['OutlineColor', Color3.new(1, 1, 1), 2],
	['OutlineTransparency', 0, 2],
	['DepthMode', Enum.HighlightDepthMode.AlwaysOnTop, 2],
]);
define('Highlight', Highlight);

export class Decal extends Instance {}
props(Decal, [['Texture', '', 0], ['Transparency', 0, 0], ['Color3', Color3.new(1, 1, 1), 0], ['Face', Enum.NormalId.Front, 0]]);
define('Decal', Decal, ['FaceInstance']);
define('Texture', Decal, ['Decal', 'FaceInstance']);

export class Sound extends Instance {
	Play() {}
	Stop() {}
	Pause() {}
	Resume() {}
	get Ended() {
		return this.$signal('Ended');
	}
}
props(Sound, [['SoundId', '', 0], ['Volume', 0.5, 0], ['PlaybackSpeed', 1, 0], ['Looped', false, 0], ['Playing', false, 0], ['TimePosition', 0, 0]]);
define('Sound', Sound);

// efeitos de tela (no Lighting ou na câmera)
export class PostEffect extends Instance {}
props(PostEffect, [
	['Enabled', true, 2],
	['TintColor', Color3.new(1, 1, 1), 2],
	['Brightness', 0, 2],
	['Contrast', 0, 2],
	['Saturation', 0, 2],
	['Size', 24, 2],
	['Intensity', 0.4, 2],
	['Threshold', 0.95, 2],
	['Spread', 1, 2],
]);
define('ColorCorrectionEffect', PostEffect, ['PostEffect']);
define('BlurEffect', PostEffect, ['PostEffect']);
define('BloomEffect', PostEffect, ['PostEffect']);
define('SunRaysEffect', PostEffect, ['PostEffect']);
define('DepthOfFieldEffect', PostEffect, ['PostEffect']);
export class Atmosphere extends Instance {}
props(Atmosphere, [['Density', 0.3, 0], ['Offset', 0, 0], ['Color', Color3.new(1, 1, 1), 0], ['Decay', Color3.new(1, 1, 1), 0], ['Glare', 0, 0], ['Haze', 0, 0]]);
define('Atmosphere', Atmosphere);
define('Sky', Folder);
define('Clouds', Folder);

// ------------------------------------------------------------------ interface (BillboardGui, TextLabel...)
export class GuiBase extends Instance {
	$reparented() {
		G.dirty(this, 2);
	}
}
export class BillboardGui extends GuiBase {}
props(BillboardGui, [
	['Adornee', undefined, 1],
	['Enabled', true, 2],
	['Size', UDim2.new(0, 0, 0, 0), 2],
	['SizeOffset', Vector2.zero, 2],
	['StudsOffset', Vector3.zero, 1],
	['StudsOffsetWorldSpace', Vector3.zero, 1],
	['ExtentsOffset', Vector3.zero, 1],
	['ExtentsOffsetWorldSpace', Vector3.zero, 1],
	['AlwaysOnTop', false, 0],
	['MaxDistance', Infinity, 0],
	['LightInfluence', 1, 0],
	['Brightness', 1, 0],
	['ClipsDescendants', false, 0],
	['ResetOnSpawn', true, 0],
	['ZIndexBehavior', Enum.ZIndexBehavior.Sibling, 0],
	['Active', false, 0],
	['DistanceLowerLimit', 0, 0],
	['DistanceUpperLimit', -1, 0],
]);
define('BillboardGui', BillboardGui, ['LayerCollector', 'GuiBase2d', 'GuiBase']);
define('SurfaceGui', BillboardGui, ['LayerCollector', 'GuiBase2d', 'GuiBase']);
define('ScreenGui', BillboardGui, ['LayerCollector', 'GuiBase2d', 'GuiBase']);

export class GuiObject extends GuiBase {}
props(GuiObject, [
	['Size', UDim2.new(0, 100, 0, 100), 2],
	['Position', UDim2.new(0, 0, 0, 0), 2],
	['AnchorPoint', Vector2.zero, 2],
	['Rotation', 0, 2],
	['BackgroundColor3', Color3.fromRGB(163, 162, 165), 2],
	['BackgroundTransparency', 0, 2],
	['BorderSizePixel', 1, 2],
	['BorderColor3', Color3.fromRGB(27, 42, 53), 2],
	['Visible', true, 2],
	['ZIndex', 1, 2],
	['LayoutOrder', 0, 0],
	['ClipsDescendants', false, 2],
	['Text', 'Label', 2],
	['TextColor3', Color3.fromRGB(27, 42, 53), 2],
	['TextTransparency', 0, 2],
	['TextScaled', false, 2],
	['TextSize', 14, 2],
	['TextWrapped', false, 2],
	['Font', Enum.Font.SourceSans, 2],
	['FontFace', undefined, 2],
	['TextStrokeColor3', Color3.new(0, 0, 0), 2],
	['TextStrokeTransparency', 1, 2],
	['TextXAlignment', Enum.TextXAlignment.Center, 2],
	['TextYAlignment', Enum.TextYAlignment.Center, 2],
	['RichText', false, 2],
	['LineHeight', 1, 2],
	['Image', '', 2],
	['ImageColor3', Color3.new(1, 1, 1), 2],
	['ImageTransparency', 0, 2],
	['AutomaticSize', Enum.AutomaticSize.None, 0],
	['SizeConstraint', Enum.SizeConstraint.RelativeXY, 0],
	['Active', false, 0],
	['Selectable', false, 0],
]);
for (const n of ['TextLabel', 'TextButton', 'TextBox', 'Frame', 'ImageLabel', 'ImageButton', 'CanvasGroup', 'ScrollingFrame']) define(n, GuiObject, ['GuiObject', 'GuiBase2d', 'GuiBase']);

export class UIComponent extends GuiBase {}
props(UIComponent, [
	['Color', Color3.new(0, 0, 0), 2],
	['Thickness', 1, 2],
	['Transparency', 0, 2],
	['Enabled', true, 2],
	['ApplyStrokeMode', Enum.ApplyStrokeMode.Contextual, 2],
	['LineJoinMode', undefined, 0],
	['Scale', 1, 2],
	['Rotation', 0, 2],
	['Offset', Vector2.zero, 2],
	['CornerRadius', { Scale: 0, Offset: 8, $type: 'UDim' }, 2],
]);
for (const n of ['UIStroke', 'UIScale', 'UIGradient', 'UICorner', 'UIPadding', 'UIListLayout', 'UIAspectRatioConstraint', 'UISizeConstraint', 'UITextSizeConstraint']) define(n, UIComponent, ['UIComponent', 'UIBase']);

// ------------------------------------------------------------------ Humanoid (só dados, para quem pergunta)
export class Humanoid extends Instance {
	constructor(cls) {
		super(cls);
		this.HipHeight = 2;
		this.Health = 100;
		this.MaxHealth = 100;
		this.WalkSpeed = 16;
		this.JumpPower = 50;
		this.MoveDirection = Vector3.zero;
		this.PlatformStand = false;
		this.AutoRotate = true;
	}
	get Died() {
		return this.$signal('Died');
	}
	get HealthChanged() {
		return this.$signal('HealthChanged');
	}
	MoveTo() {}
	Move() {}
	ChangeState() {}
	GetState() {
		return Enum.HumanoidStateType.Running;
	}
	LoadAnimation() {
		return { Play() {}, Stop() {}, AdjustSpeed() {}, Stopped: new Signal(), $type: 'Instance' };
	}
}
define('Humanoid', Humanoid);
define('Animator', Folder);
define('AnimationController', Folder);

// ------------------------------------------------------------------ câmera e mundo
export class Camera extends Instance {
	constructor(cls) {
		super(cls);
		this._CFrame = CFrame.new(0, 10, 20);
		this.$set = null; // CFrame escolhido pelo Lua neste quadro (tremor)
		this.FieldOfView = 55;
		this.ViewportSize = new Vector2(1280, 720);
		this.Focus = CFrame.identity;
		this.CameraType = { Name: 'Custom' };
		this.$project = null; // (x, y, z) → [sx, sy, depth, onScreen]
	}
	get CFrame() {
		return this._CFrame;
	}
	set CFrame(cf) {
		this._CFrame = cf;
		this.$set = cf;
	}
	WorldToViewportPoint(v) {
		const r = this.$project ? this.$project(v.x, v.y, v.z) : [0, 0, 0, false];
		return $M(new Vector3(r[0], r[1], r[2]), r[3]);
	}
	WorldToScreenPoint(v) {
		return this.WorldToViewportPoint(v);
	}
	ScreenPointToRay(x, y) {
		return { Origin: this._CFrame.Position, Direction: this._CFrame.LookVector, $type: 'Ray' };
	}
	ViewportPointToRay(x, y) {
		return this.ScreenPointToRay(x, y);
	}
}
define('Camera', Camera);

export class Terrain extends BasePart {}
define('Terrain', Terrain, ['BasePart']);

export class Workspace extends Model {
	constructor(cls) {
		super(cls);
		this.$inWorld = true;
		this.Gravity = 196.2;
		this.DistributedGameTime = 0;
		this.$raycast = null; // (origin, dir) → {Position, Normal, Distance} | null
	}
	get CurrentCamera() {
		return this.$camera;
	}
	set CurrentCamera(c) {
		this.$camera = c;
	}
	BulkMoveTo(parts, cframes) {
		const n = Math.min(parts.length, cframes.length);
		for (let i = 0; i < n; i++) if (parts[i]) parts[i].CFrame = cframes[i];
	}
	Raycast(origin, dir, params) {
		if (!this.$raycast) return undefined;
		const r = this.$raycast(origin, dir, params);
		if (!r) return undefined;
		return { Position: r.Position, Normal: r.Normal || Vector3.yAxis, Distance: r.Distance, Instance: this.Terrain, Material: Enum.Material.Grass, $type: 'RaycastResult' };
	}
	FindPartOnRay(ray) {
		const r = this.Raycast(ray.Origin, ray.Direction);
		return r ? $M(r.Instance, r.Position, r.Normal, r.Material) : $M(undefined, ray.Origin.__add(ray.Direction), Vector3.yAxis);
	}
	FindPartOnRayWithIgnoreList(ray) {
		return this.FindPartOnRay(ray);
	}
	GetServerTimeNow() {
		return sched.clock;
	}
	GetPartBoundsInRadius() {
		return [];
	}
	GetPartBoundsInBox() {
		return [];
	}
	GetPartsInPart() {
		return [];
	}
}
define('Workspace', Workspace, ['WorldRoot', 'Model', 'PVInstance']);

// ------------------------------------------------------------------ serviços
export class RunService extends Instance {
	constructor(cls) {
		super(cls);
		this.$bound = [];
	}
	get RenderStepped() {
		return this.$signal('RenderStepped');
	}
	get Heartbeat() {
		return this.$signal('Heartbeat');
	}
	get Stepped() {
		return this.$signal('Stepped');
	}
	get PreRender() {
		return this.$signal('PreRender');
	}
	get PreSimulation() {
		return this.$signal('PreSimulation');
	}
	get PostSimulation() {
		return this.$signal('PostSimulation');
	}
	get PreAnimation() {
		return this.$signal('PreAnimation');
	}
	BindToRenderStep(name, priority, fn) {
		this.UnbindFromRenderStep(name);
		this.$bound.push({ name, priority, fn });
		this.$bound.sort((a, b) => a.priority - b.priority);
	}
	UnbindFromRenderStep(name) {
		this.$bound = this.$bound.filter((b) => b.name !== name);
	}
	IsClient() {
		return true;
	}
	IsServer() {
		return false;
	}
	IsStudio() {
		return false;
	}
	IsRunning() {
		return true;
	}
	IsRunMode() {
		return true;
	}
	// um quadro do jogo
	$frame(dt) {
		this.$fire('Stepped', sched.clock, dt);
		this.$fire('PreSimulation', dt);
		this.$fire('Heartbeat', dt);
		this.$fire('PostSimulation', dt);
		this.$fire('PreRender', dt);
		this.$fire('RenderStepped', dt);
		for (const b of this.$bound) callLua(b.fn, dt);
	}
}
define('RunService', RunService);

export class Debris extends Instance {
	AddItem(inst, life = 10) {
		if (!inst) return;
		delayCall(life, () => {
			if (inst instanceof Instance) inst.Destroy();
		});
	}
}
define('Debris', Debris);

// ---- TweenService (curvas de animação iguais às do Roblox)
const PI = Math.PI;
function easeIn(style, t) {
	switch (style) {
		case 'Linear':
			return t;
		case 'Sine':
			return 1 - Math.cos((t * PI) / 2);
		case 'Back':
			return t * t * (2.70158 * t - 1.70158);
		case 'Quad':
			return t * t;
		case 'Cubic':
			return t * t * t;
		case 'Quart':
			return t ** 4;
		case 'Quint':
			return t ** 5;
		case 'Exponential':
			return t === 0 ? 0 : 2 ** (10 * t - 10);
		case 'Circular':
			return 1 - Math.sqrt(1 - t * t);
		case 'Elastic':
			return t === 0 || t === 1 ? t : -(2 ** (10 * t - 10)) * Math.sin((t * 10 - 10.75) * ((2 * PI) / 3));
		case 'Bounce':
			return 1 - bounceOut(1 - t);
		default:
			return t * t;
	}
}
function bounceOut(t) {
	const n = 7.5625, d = 2.75;
	if (t < 1 / d) return n * t * t;
	if (t < 2 / d) return n * (t -= 1.5 / d) * t + 0.75;
	if (t < 2.5 / d) return n * (t -= 2.25 / d) * t + 0.9375;
	return n * (t -= 2.625 / d) * t + 0.984375;
}
export function ease(style, dir, t) {
	t = Math.max(0, Math.min(1, t));
	const s = style ? style.Name : 'Quad';
	const d = dir ? dir.Name : 'Out';
	if (d === 'In') return easeIn(s, t);
	if (d === 'Out') return 1 - easeIn(s, 1 - t);
	return t < 0.5 ? easeIn(s, t * 2) / 2 : 1 - easeIn(s, (1 - t) * 2) / 2;
}
function lerpValue(a, b, k) {
	if (typeof a === 'number' && typeof b === 'number') return a + (b - a) * k;
	if (a && typeof a.Lerp === 'function' && b && b.constructor === a.constructor) return a.Lerp(b, k);
	if (a instanceof NumberRange && b instanceof NumberRange) return NumberRange.new(a.Min + (b.Min - a.Min) * k, a.Max + (b.Max - a.Max) * k);
	return k >= 1 ? b : a;
}

const tweens = new Set();
export class Tween extends Instance {
	constructor(cls) {
		super(cls);
		this.PlaybackState = Enum.PlaybackState.Begin;
	}
	get Completed() {
		return this.$signal('Completed');
	}
	Play() {
		if (this.PlaybackState === Enum.PlaybackState.Playing) return;
		this.$from = {};
		for (const k of Object.keys(this.$goal)) this.$from[k] = this.Instance[k];
		this.$t = -(this.TweenInfo.DelayTime || 0);
		this.$loops = 0;
		this.PlaybackState = Enum.PlaybackState.Playing;
		tweens.add(this);
	}
	Pause() {
		this.PlaybackState = Enum.PlaybackState.Paused;
		tweens.delete(this);
	}
	Cancel() {
		this.PlaybackState = Enum.PlaybackState.Cancelled;
		tweens.delete(this);
		this.$fire('Completed', Enum.PlaybackState.Cancelled);
	}
	$step(dt) {
		const inst = this.Instance;
		if (!inst || inst.$destroyed) {
			tweens.delete(this);
			return;
		}
		this.$t += dt;
		const info = this.TweenInfo;
		const time = Math.max(info.Time, 1e-4);
		if (this.$t < 0) return;
		let u = Math.min(1, this.$t / time);
		const back = info.Reverses && this.$loops % 2 === 1;
		const k = ease(info.EasingStyle, info.EasingDirection, back ? 1 - u : u);
		for (const key of Object.keys(this.$goal)) inst[key] = lerpValue(this.$from[key], this.$goal[key], k);
		if (u >= 1) {
			const total = (info.RepeatCount || 0) * (info.Reverses ? 2 : 1) + (info.Reverses ? 1 : 0);
			if (info.RepeatCount < 0 || this.$loops < total) {
				this.$loops++;
				this.$t = 0;
				return;
			}
			tweens.delete(this);
			this.PlaybackState = Enum.PlaybackState.Completed;
			this.$fire('Completed', Enum.PlaybackState.Completed);
		}
	}
}
define('Tween', Tween, ['TweenBase']);

export class TweenService extends Instance {
	Create(inst, info, goal) {
		const t = new Tween('Tween');
		t.Instance = inst;
		t.TweenInfo = info || TweenInfo.new();
		t.$goal = {};
		for (const k of Object.keys(goal)) t.$goal[k] = goal[k];
		return t;
	}
	GetValue(alpha, style, dir) {
		return ease(style, dir, alpha);
	}
	$step(dt) {
		for (const t of [...tweens]) t.$step(dt);
	}
	$clear() {
		tweens.clear();
	}
}
define('TweenService', TweenService);

export class Player extends Instance {
	constructor(cls) {
		super(cls);
		this.UserId = 1;
		this.DisplayName = 'Player';
		this.Character = undefined;
	}
	GetMouse() {
		return { Hit: CFrame.identity, Target: undefined, X: 0, Y: 0, $type: 'Instance' };
	}
	Kick() {}
}
define('Player', Player);

export class Players extends Instance {
	get LocalPlayer() {
		return this.$local;
	}
	GetPlayers() {
		return this.$local ? [this.$local] : [];
	}
	GetPlayerFromCharacter() {
		return undefined;
	}
	GetPlayerByUserId(id) {
		return this.$local && this.$local.UserId === id ? this.$local : undefined;
	}
	get PlayerAdded() {
		return this.$signal('PlayerAdded');
	}
	get PlayerRemoving() {
		return this.$signal('PlayerRemoving');
	}
}
define('Players', Players);

export class CollectionService extends Instance {
	GetTagged() {
		return [];
	}
	GetInstanceAddedSignal(tag) {
		return this.$signal('add:' + tag);
	}
	GetInstanceRemovedSignal(tag) {
		return this.$signal('rem:' + tag);
	}
	HasTag(inst, tag) {
		return !!(inst && inst.HasTag && inst.HasTag(tag));
	}
	AddTag(inst, tag) {
		inst && inst.AddTag && inst.AddTag(tag);
	}
	RemoveTag(inst, tag) {
		inst && inst.RemoveTag && inst.RemoveTag(tag);
	}
	GetTags(inst) {
		return inst && inst.GetTags ? inst.GetTags() : [];
	}
}
define('CollectionService', CollectionService);

export class Lighting extends Instance {
	constructor(cls) {
		super(cls);
		this.$inWorld = true;
		this.ClockTime = 14;
		this.Brightness = 2;
		this.Ambient = Color3.fromRGB(70, 70, 70);
		this.OutdoorAmbient = Color3.fromRGB(128, 128, 128);
		this.FogColor = Color3.fromRGB(192, 192, 192);
		this.FogStart = 0;
		this.FogEnd = 100000;
		this.ExposureCompensation = 0;
		this.GeographicLatitude = 41.7;
		this.EnvironmentDiffuseScale = 1;
		this.EnvironmentSpecularScale = 1;
		this.GlobalShadows = true;
	}
	get TimeOfDay() {
		return '14:00:00';
	}
	GetMinutesAfterMidnight() {
		return this.ClockTime * 60;
	}
}
define('Lighting', Lighting);

export class GenericService extends Instance {}
for (const n of ['ReplicatedStorage', 'ReplicatedFirst', 'ServerStorage', 'StarterGui', 'StarterPlayer', 'SoundService', 'Teams', 'HttpService', 'UserInputService', 'ContextActionService', 'GuiService', 'TextService', 'MarketplaceService', 'StarterPack', 'Chat', 'PhysicsService', 'ContentProvider'])
	define(n, GenericService);

export class DataModel extends Instance {
	constructor(cls) {
		super(cls);
		this.$services = new Map();
		this.$inWorld = true;
		this.PlaceId = 0;
		this.GameId = 0;
		this.JobId = 'web';
	}
	GetService(name) {
		let s = this.$services.get(name);
		if (!s) {
			s = Instance.new(CLASSES[name] ? name : 'Folder');
			s._name = name;
			this.$services.set(name, s);
			s.Parent = this;
		}
		return s;
	}
	FindService(name) {
		return this.$services.get(name);
	}
	IsLoaded() {
		return true;
	}
	BindToClose() {}
	get Loaded() {
		return this.$signal('Loaded');
	}
}
define('DataModel', DataModel, ['ServiceProvider']);

export { CLASSES };
