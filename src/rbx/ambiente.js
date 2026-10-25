// O "Roblox" de mentirinha onde rodam os efeitos e as habilidades traduzidos do projeto original:
// game/workspace/serviços, os módulos (Effects, SkillArt, PackB/C/Skills, Skills_*), o relógio do agendador,
// a câmera e o chão (raycast) do jogo. O jogo chama rbx.fx(nome, params) e rbx.frame(dt) a cada quadro.
import * as THREE from 'three';
import { makeStdlib, stepScheduler, reportError, errors, resetScheduler, sched, callLua } from './lua.js';
import * as T from './tipos.js';
import { Instance, G as HOOK, ModuleScript, Camera, BasePart } from './instancias.js';
import { initCena, frameCena, cenaStats, clearParticles } from './cena.js';
import { DogModel, proxyFrame } from './proxies.js';
import { CONFIG, SHOT_STYLES, SKILLS, ELEMENTS } from '../data/jogo.js';

import mEffects from '../gerado/efeitos/Effects.js';
import mSkillArt from '../gerado/efeitos/SkillArt.js';
import mPackB from '../gerado/efeitos/PackB.js';
import mPackC from '../gerado/efeitos/PackC.js';
import mPackSkills from '../gerado/efeitos/PackSkills.js';
import sCommon from '../gerado/habilidades/Skills_Common.js';
import sUncommon from '../gerado/habilidades/Skills_Uncommon.js';
import sRare from '../gerado/habilidades/Skills_Rare.js';
import sEpic from '../gerado/habilidades/Skills_Epic.js';
import sLegendary from '../gerado/habilidades/Skills_Legendary.js';
import sMythic from '../gerado/habilidades/Skills_Mythic.js';
import sHalloween from '../gerado/habilidades/Skills_Halloween.js';
import sDivine from '../gerado/habilidades/Skills_Divine.js';
import sSignature from '../gerado/habilidades/Skills_Signature.js';

const SKILL_MODULES = { Skills_Common: sCommon, Skills_Uncommon: sUncommon, Skills_Rare: sRare, Skills_Epic: sEpic, Skills_Legendary: sLegendary, Skills_Mythic: sMythic, Skills_Halloween: sHalloween, Skills_Divine: sDivine, Skills_Signature: sSignature };

const QUALITY_NAME = { high: 'Alto', medium: 'Médio', low: 'Baixo' };

// efeito → som (igual ao client/Systems/Sfx.lua do jogo original)
const FX_SOUND = {
	Bite: 'Bite', BiteMark: 'Bite', SpectralBite: 'Bite', Hit: 'Punch', Roar: 'Roar', TitanGrow: 'Roar', Telegraph: 'Charge',
	ThunderCharge: 'Thunder', ThunderDash: 'Thunder', Lightning: 'Thunder', Smoke: 'Smoke', Cloud: 'Smoke', Streak: 'Whoosh',
	Trail: 'Whoosh', TailSwipe: 'Whoosh', Vortex: 'Whoosh', Cone: 'Whoosh', Impact: 'Slam', Shockwave: 'Slam', GroundSlam: 'Slam',
	SonicBoom: 'Explosion', Explosion: 'Explosion', Meteor: 'Explosion', EyeGlow: 'Magic', Circle: 'Magic', Clones: 'Magic',
	TitanAura: 'Magic', LevelUp: 'Magic', Burn: 'Burn', Lava: 'Fire', LavaCracks: 'Fire', FireSpot: 'Fire', FireRing: 'Fire',
	Ignite: 'Fire', PhoenixRise: 'Fire', IceField: 'Ice', IceWave: 'Ice', Freeze: 'Freeze', Slash: 'Slash', ShadowStrike: 'Slash',
	Spikes: 'Spikes', Projectile: 'Projectile', Glob: 'Water', Geyser: 'Water', Fin: 'Water', Laser: 'Laser', Tractor: 'Laser',
	SpecialName: 'Bark', Cash: 'Coin', XP: 'XP',
};
const SILENT_FX = { Shake: true, Damage: true };
const FX_VOLUME = { Click: 0.35, Open: 0.4, Close: 0.35, Notify: 0.45, Coin: 0.55, XP: 0.4, Bite: 0.7, Punch: 0.75, Whoosh: 0.5, Charge: 0.5, Eat: 0.6, Bark: 0.65 };

// "#ff8800" → Color3 (tabelas do jogo usadas pelo código Lua)
function toLua(v) {
	if (typeof v === 'string' && /^#[0-9a-fA-F]{6}$/.test(v)) return T.Color3.fromHex(v);
	if (Array.isArray(v)) return v.map(toLua);
	if (v && typeof v === 'object') {
		const o = {};
		for (const [k, x] of Object.entries(v)) o[k] = toLua(x);
		return o;
	}
	return v;
}

function formatNumber(n) {
	n = Math.floor(n);
	const suf = ['', 'K', 'M', 'B', 'T', 'Qa'];
	let i = 0, v = n;
	while (Math.abs(v) >= 1000 && i < suf.length - 1) {
		v /= 1000;
		i++;
	}
	if (i === 0) return String(n);
	return v.toFixed(1).replace(/\.0$/, '') + suf[i];
}

export class Roblox {
	// opts: { scene, camera, renderer, ui, quality ('high'|'medium'|'low'), raycast(origin, dir) → hit | null }
	constructor(opts) {
		this.opts = opts;
		this.camera3 = opts.camera;
		initCena({ scene: opts.scene, camera: opts.camera, renderer: opts.renderer, ui: opts.ui, realLights: opts.quality === 'low' ? 0 : 4 });

		// ---- árvore do jogo
		const game = Instance.new('DataModel');
		game._name = 'Game';
		this.game = game;
		const workspace = game.GetService('Workspace');
		workspace._name = 'Workspace';
		HOOK.world = workspace;
		this.workspace = workspace;
		const terrain = Instance.new('Terrain');
		terrain._name = 'Terrain';
		terrain.Parent = workspace;
		const cam = Instance.new('Camera');
		cam._name = 'Camera';
		cam.Parent = workspace;
		workspace.CurrentCamera = cam;
		this.cam = cam;
		cam.$project = (x, y, z) => this.project(x, y, z);
		workspace.$raycast = (o, d) => this.raycast(o, d);

		const players = game.GetService('Players');
		const me = Instance.new('Player');
		me._name = 'Player';
		me.UserId = 1;
		me.Parent = players;
		players.$local = me;
		this.player = me;
		this.setQuality(opts.quality || 'high');
		this.run = game.GetService('RunService');
		this.tweens = game.GetService('TweenService');
		game.GetService('Debris');
		game.GetService('Lighting');
		game.GetService('CollectionService');

		// ---- ReplicatedStorage: Shared (Config, DogData) e Remotes (Effect)
		const rs = game.GetService('ReplicatedStorage');
		const shared = Instance.new('Folder');
		shared._name = 'Shared';
		shared.Parent = rs;
		const config = Object.assign(toLua(CONFIG), { Format: formatNumber });
		this.module(shared, 'Config', () => config);
		const specials = {};
		for (const list of Object.values(SKILLS)) for (const s of list) specials[s.Id] = toLua(s);
		const dogData = { SHOT_STYLES: toLua(SHOT_STYLES), Specials: specials, DOG_ELEMENTS: toLua(ELEMENTS) };
		this.module(shared, 'DogData', () => dogData);
		const remotes = Instance.new('Folder');
		remotes._name = 'Remotes';
		remotes.Parent = rs;
		const effect = Instance.new('RemoteEvent');
		effect._name = 'Effect';
		effect.Parent = remotes;
		this.effectRemote = effect;

		// ---- cliente: Effects (+ pacotes), SkillArt, Animator
		const client = Instance.new('Folder');
		client._name = 'Client';
		client.Parent = game.GetService('StarterPlayer');
		this.module(client, 'Animator', () => ({
			PlayBite: (model, head) => {
				const f = model && model.$fighter;
				if (f && f.anim) f.anim.playBite(head);
				return true;
			},
			PlayMelee: (model, step) => {
				const f = model && model.$fighter;
				if (f && f.anim) f.anim.playMelee(step);
				return true;
			},
		}));
		this.module(client, 'SkillArt', (ms) => mSkillArt(this.G, ms));
		const packs = Instance.new('Folder');
		packs._name = 'EffectsPacks';
		packs.Parent = client;
		this.module(packs, 'PackB', (ms) => mPackB(this.G, ms));
		this.module(packs, 'PackC', (ms) => mPackC(this.G, ms));
		this.module(packs, 'PackSkills', (ms) => mPackSkills(this.G, ms));
		const effectsMs = this.module(client, 'Effects', (ms) => mEffects(this.G, ms));

		// ---- servidor: SkillKit (o kit em JS entra depois, setSkillKit) e as habilidades
		const services = Instance.new('Folder');
		services._name = 'Services';
		services.Parent = game.GetService('ServerStorage');
		this.services = services;
		this.kitModule = this.module(services, 'SkillKit', () => this.skillKit);
		const sp = Instance.new('Folder');
		sp._name = 'SpecialsPacks';
		sp.Parent = services;
		this.skillModules = [];
		for (const [name, fn] of Object.entries(SKILL_MODULES)) this.skillModules.push(this.module(sp, name, (ms) => fn(this.G, ms)));

		// ---- globais do Lua
		this.G = makeStdlib({
			Vector3: T.Vector3,
			Vector2: T.Vector2,
			CFrame: T.CFrame,
			Color3: T.Color3,
			BrickColor: T.BrickColor,
			NumberSequence: T.NumberSequence,
			NumberSequenceKeypoint: T.NumberSequenceKeypoint,
			ColorSequence: T.ColorSequence,
			ColorSequenceKeypoint: T.ColorSequenceKeypoint,
			NumberRange: T.NumberRange,
			UDim: T.UDim,
			UDim2: T.UDim2,
			TweenInfo: T.TweenInfo,
			Random: T.Random,
			Enum: T.Enum,
			Font: T.Font,
			Ray: { new: (o, d) => ({ Origin: o, Direction: d, $type: 'Ray' }) },
			RaycastParams: { new: () => ({ FilterDescendantsInstances: [], FilterType: T.Enum.RaycastFilterType.Exclude, $type: 'RaycastParams' }) },
			OverlapParams: { new: () => ({ $type: 'OverlapParams' }) },
			PhysicalProperties: { new: () => ({ $type: 'PhysicalProperties' }) },
			Instance: { new: (cls, parent) => Instance.new(cls, parent) },
			game,
			workspace,
			Workspace: workspace,
			require: (m) => {
				if (m instanceof ModuleScript) return m.$require();
				throw new Error('require: módulo desconhecido');
			},
		});

		// ---- liga os efeitos (carrega os pacotes e escuta Remotes.Effect)
		this.Effects = null;
		try {
			this.Effects = effectsMs.$require();
			callLua(this.Effects.Start);
		} catch (e) {
			reportError(e, 'Effects.Start');
		}
	}

	module(parent, name, factory) {
		const ms = Instance.new('ModuleScript');
		ms._name = name;
		ms.$factory = factory;
		ms.Parent = parent;
		return ms;
	}

	setQuality(q) {
		this.player.SetAttribute('GraphicsQuality', QUALITY_NAME[q] || 'Alto');
	}

	// o kit das habilidades (JS) que os Skills_*.lua usam com require(SkillKit)
	setSkillKit(kit) {
		this.skillKit = kit;
	}

	// registra todas as habilidades: Specials[id] = function(f, t) (feito pelo SkillKit.def)
	loadSkills(specials, fightersShim) {
		for (const ms of this.skillModules) {
			try {
				const fn = ms.$require();
				fn(specials, fightersShim);
			} catch (e) {
				reportError(e, ms.Name);
			}
		}
	}

	// efeito do jogo (igual ao Remotes.Effect:FireAllClients do servidor do Roblox)
	fx(name, params) {
		if (this.onSound) this.soundFor(name, params);
		try {
			this.effectRemote.FireAllClients(name, params);
		} catch (e) {
			reportError(e, 'fx ' + name);
		}
	}

	soundFor(name, p) {
		if (!p || typeof p !== 'object') return;
		const at = this.whereOf(p);
		if (name === 'Damage') {
			if (p.Crit) this.onSound('Crit', at, 0.6);
			return;
		}
		if (SILENT_FX[name]) return;
		if (name === 'Freeze' && p.Kind && p.Kind !== 'ice') return this.onSound('Magic', at, 0.6);
		const s = FX_SOUND[name];
		if (s) this.onSound(s, at, FX_VOLUME[s] ?? 0.6);
		else this.onSound('Whoosh', at, 0.3);
	}

	whereOf(p) {
		const v = p.Position || p.From || p.Center || p.At || (Array.isArray(p.Positions) && p.Positions[0]);
		if (v && v.x !== undefined) return { x: v.x, y: v.y, z: v.z };
		const m = p.Model;
		if (m && m.PrimaryPart) {
			const q = m.PrimaryPart.Position;
			return { x: q.x, y: q.y, z: q.z };
		}
		return null;
	}

	// Model do Roblox para um cachorro do jogo (criado na primeira vez)
	modelOf(f) {
		if (!f) return undefined;
		if (!f.$rbx || f.$rbx.$destroyed) f.$rbx = new DogModel(f, this.workspace, f.kind === 'player' ? this.player.UserId : 0);
		return f.$rbx;
	}

	dropModel(f) {
		if (f && f.$rbx) {
			try {
				f.$rbx.Destroy();
			} catch (e) {
				reportError(e, 'dropModel');
			}
			f.$rbx = null;
		}
	}

	project(x, y, z) {
		const v = new THREE.Vector3(x, y, z).project(this.camera3);
		const w = this.opts.renderer.domElement.clientWidth || window.innerWidth;
		const h = this.opts.renderer.domElement.clientHeight || window.innerHeight;
		const camPos = new THREE.Vector3().setFromMatrixPosition(this.camera3.matrixWorld);
		const depth = camPos.distanceTo(new THREE.Vector3(x, y, z));
		return [(v.x * 0.5 + 0.5) * w, (-v.y * 0.5 + 0.5) * h, depth, v.z > -1 && v.z < 1 && Math.abs(v.x) <= 1 && Math.abs(v.y) <= 1];
	}

	raycast(o, d) {
		const fn = this.opts.raycast;
		if (!fn) return null;
		const len = Math.hypot(d.x, d.y, d.z);
		if (len < 1e-6) return null;
		const hit = fn(o.x, o.y, o.z, d.x / len, d.y / len, d.z / len, len);
		if (!hit) return null;
		return { Position: new T.Vector3(hit.x, hit.y, hit.z), Distance: hit.t, Normal: T.Vector3.yAxis };
	}

	// câmera do three.js → workspace.CurrentCamera
	syncCamera() {
		const c = this.camera3;
		c.updateMatrixWorld();
		const e = c.matrixWorld.elements;
		const sx = Math.hypot(e[0], e[1], e[2]) || 1, sy = Math.hypot(e[4], e[5], e[6]) || 1, sz = Math.hypot(e[8], e[9], e[10]) || 1;
		this.cam._CFrame = new T.CFrame(e[12], e[13], e[14], e[0] / sx, e[4] / sy, e[8] / sz, e[1] / sx, e[5] / sy, e[9] / sz, e[2] / sx, e[6] / sy, e[10] / sz);
		this.cam.$set = null;
		this.cam.FieldOfView = c.fov;
		const el = this.opts.renderer.domElement;
		this.cam.ViewportSize = new T.Vector2(el.clientWidth || window.innerWidth, el.clientHeight || window.innerHeight);
	}

	// o Lua mexeu na câmera (tremor): aplica a diferença na câmera deste quadro
	applyCamera() {
		const cf = this.cam.$set;
		if (!cf) return;
		this.cam.$set = null;
		const base = this.camBase;
		if (!base) return;
		const d = base.Inverse().__mul(cf);
		const c = this.camera3;
		c.updateMatrixWorld();
		const delta = new THREE.Matrix4().set(d.m00, d.m01, d.m02, d.x, d.m10, d.m11, d.m12, d.y, d.m20, d.m21, d.m22, d.z, 0, 0, 0, 1);
		const m = c.matrixWorld.clone().multiply(delta);
		c.matrixWorld.copy(m);
		c.matrixWorldInverse.copy(m).invert();
		m.decompose(c.position, c.quaternion, c.scale);
		c.matrix.copy(m);
	}

	// parte 1 do quadro (antes da física): agendador (esperas, task.delay), tweens e RunService (animações dos efeitos)
	step(dt) {
		dt = Math.min(dt, 0.1);
		proxyFrame();
		this.syncCamera();
		this.camBase = this.cam._CFrame;
		try {
			stepScheduler(dt);
		} catch (e) {
			reportError(e, 'scheduler');
		}
		try {
			this.tweens.$step(dt);
		} catch (e) {
			reportError(e, 'tweens');
		}
		try {
			this.run.$frame(dt);
		} catch (e) {
			reportError(e, 'RunService');
		}
	}

	// parte 2 (depois da câmera do jogo): tremor do Lua e o desenho das peças/partículas/textos
	post(dt) {
		this.applyCamera();
		frameCena(Math.min(dt, 0.1));
	}

	frame(dt) {
		this.step(dt);
		this.post(dt);
	}

	// troca de ilha: apaga tudo que é efeito (peças, partículas, textos)
	clear() {
		const ws = this.workspace;
		for (const k of ws.GetChildren()) {
			if (k.ClassName === 'Terrain' || k.ClassName === 'Camera') {
				for (const c of k.GetChildren()) c.Destroy();
				continue;
			}
			if (k.$fighter) continue;
			if (k._name === 'FX' || k.ClassName === 'Folder') {
				for (const c of k.GetChildren()) c.Destroy();
				continue;
			}
			k.Destroy();
		}
		for (const k of this.game.GetService('Lighting').GetChildren()) k.Destroy();
		this.tweens.$clear();
		clearParticles();
	}

	stats() {
		return Object.assign(cenaStats(), { threads: sched.queue.length, errors: errors.length });
	}

	get errors() {
		return errors;
	}
}
