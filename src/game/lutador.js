// Um cachorro no mundo (jogador, selvagem ou campeão): modelo 3D + animação + corpo + vida e golpes.
import * as THREE from 'three';
import { createDogModel, setRigPose, disposeDogModel, SPECIES_MODELS } from '../dogs/rig.js';
import { DogAnimator } from '../dogs/animator.js';
import { makeBody, stepBody } from './corpo.js';
import { SPECIES, stats as calcStats, gameScale, shotOf, elementsOf } from '../data/jogo.js';

let nextId = 1;
const _e = new THREE.Euler(0, 0, 0, 'YXZ');

export class Fighter {
	constructor(opts) {
		this.id = nextId++;
		this.kind = opts.kind || 'wild'; // 'player' | 'wild' | 'champion' | 'clone'
		this.speciesId = opts.speciesId;
		this.species = SPECIES[opts.speciesId];
		this.level = opts.level || 1;
		this.statMult = opts.statMult || null;
		this.extraScale = opts.scale || 1;
		this.name = opts.name || this.species.Name;
		this.shot = shotOf(this.speciesId);
		this.elements = elementsOf(this.speciesId);
		const model = SPECIES_MODELS[this.speciesId];
		this.canFly = !!(model && (model.wings || model.float));
		this.scale = gameScale(this.speciesId) * this.extraScale;
		this.rig = createDogModel(this.speciesId, this.scale);
		this.mesh = this.rig.mesh;
		this.mesh.userData.fighter = this;
		this.anim = new DogAnimator(this.rig, { baseSpeed: this.species.Stats.Speed, showcase: !!opts.showcase });
		const a = this.rig.asset;
		this.groundOffset = a.groundOffset * this.scale;
		// corpo: raio pela largura da raiz, altura até o alto da cabeça
		const radius = Math.max(0.7, (model.rootY * 0.55 + 0.25) * this.scale);
		const height = Math.max(2, a.height * this.scale + this.groundOffset);
		const step = Math.max(1.15, Math.min(3, this.groundOffset * 0.9));
		this.body = makeBody(radius, height, step);
		this.body.swimDepth = this.groundOffset * 0.75;
		this.yaw = 0;
		this.visualY = 0;
		this.pitch = 0;
		this.roll = 0;
		this.refreshStats(true);
		// estado de luta
		this.dead = false;
		this.deadAt = 0;
		this.action = null;
		this.actionUntil = 0;
		this.actionSpeed = 1;
		this.cool = {};
		this.combo = 0;
		this.comboAt = -10;
		this.invulnUntil = 0;
		this.status = {};
		this.lastHitBy = null;
		this.damageBy = new Map();
		this.lastHurtAt = -100;
		this.lastAttackAt = -100;
		this.target = null;
		this.casting = 0;
		this.home = null;
		this.island = opts.island || null;
		this.plate = null;
	}

	refreshStats(full = false) {
		const old = this.maxHp || 0;
		this.stats = calcStats(this.speciesId, this.level, this.statMult);
		this.maxHp = this.stats.MaxHP;
		this.atk = this.stats.Atk;
		if (full || this.hp === undefined) this.hp = this.maxHp;
		else this.hp = Math.min(this.maxHp, this.hp + Math.max(0, this.maxHp - old));
	}

	get x() {
		return this.body.x;
	}
	get z() {
		return this.body.z;
	}
	get y() {
		return this.body.y;
	}

	// posição da raiz (centro do corpo) no mundo
	rootPos(out = new THREE.Vector3()) {
		return out.set(this.body.x, this.body.y + this.groundOffset, this.body.z);
	}

	headPos(out = new THREE.Vector3()) {
		return out.set(this.body.x, this.body.y + this.body.height, this.body.z);
	}

	forward() {
		return [-Math.sin(this.yaw), -Math.cos(this.yaw)];
	}

	place(x, y, z, yaw = 0) {
		this.body.x = x;
		this.body.y = y;
		this.body.z = z;
		this.body.vx = this.body.vy = this.body.vz = 0;
		this.body.grounded = true;
		this.yaw = yaw;
		this.visualY = y;
		this.syncMesh(0, true);
	}

	setAction(name, duration, speed = 1) {
		this.action = name;
		this.actionUntil = performance.now() / 1000 + duration;
		this.actionSpeed = speed;
	}

	statusOn(name, now) {
		const s = this.status[name];
		return s && s.until > now ? s : null;
	}

	speedMult(now) {
		let m = 1;
		const slow = this.statusOn('slow', now);
		if (slow) m *= slow.mult;
		const haste = this.statusOn('haste', now);
		if (haste) m *= haste.mult;
		return m;
	}

	stunned(now) {
		return !!(this.statusOn('stun', now) || this.statusOn('freeze', now));
	}

	// física + animação de um quadro
	update(dt, now, world, extra) {
		if (!this.dead) stepBody(this.body, world && world.physics, dt, extra);
		if (this.action && now > this.actionUntil) this.action = null;
		this.syncMesh(dt, false);
		const a = this.anim;
		const m = this.mesh;
		a.pos = [m.position.x, m.position.y, m.position.z];
		a.quat = [m.quaternion.x, m.quaternion.y, m.quaternion.z, m.quaternion.w];
		a.vel = [this.body.vx, this.body.vy, this.body.vz];
		a.grounded = this.body.grounded;
		a.inWater = this.body.inWater;
		a.flying = this.body.flying;
		a.action = this.dead ? 'KO' : this.action;
		a.actionSpeed = this.actionSpeed;
		a.setHealth(this.hp / this.maxHp);
		a.raging = !!this.statusOn('rage', now);
		a.update(dt);
		setRigPose(this.rig);
	}

	syncMesh(dt, snap) {
		const m = this.mesh;
		// sobe degrau suave (o corpo pula na hora, o desenho vai junto rapidinho)
		if (snap || Math.abs(this.body.y - this.visualY) > 6) this.visualY = this.body.y;
		else this.visualY += (this.body.y - this.visualY) * (1 - Math.exp(-dt * 22));
		m.position.set(this.body.x, this.visualY + this.groundOffset, this.body.z);
		_e.set(this.pitch, this.yaw, this.roll, 'YXZ');
		m.quaternion.setFromEuler(_e);
	}

	dispose() {
		disposeDogModel(this.rig);
		if (this.plate) this.plate.remove();
		this.plate = null;
	}
}

