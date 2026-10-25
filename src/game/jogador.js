// Controle do cachorro do jogador: andar (WASD/joystick, relativo à câmera), correr (Shift/RUN), pular (Espaço),
// dash (Q), atacar (clique/1: combo ou tiro na direção da setinha), poderes (2, 3, 4), voar (F) e olhar a setinha.
import { Input, down, pressed, moveAxis } from '../core/input.js';
import { CONFIG } from '../data/jogo.js';
import { angleDiff, clamp } from '../core/util.js';
import { WATER_Y } from '../world/fisica.js';

const C = CONFIG;
const JUMP = 44;
const RUN = 1.6;
const FLY = 3.2;

export class PlayerController {
	constructor(game, fighter) {
		this.game = game;
		this.f = fighter;
		this.aim = { x: 0, y: 0, z: 0, ok: false };
		this.nextAttack = 0;
		this.nextDash = 0;
		this.running = false;
		this.runToggle = false;
		this.attackHeld = false;
		this.lastMoveYaw = 0;
		this.faceAimUntil = 0;
		this.flyToggle = false;
		this.touchAttack = false;
	}

	setFighter(f) {
		this.f = f;
	}

	updateAim(camera) {
		const f = this.f;
		const I = Input;
		let sx = I.mouse.x, sy = I.mouse.y;
		if (I.locked || I.touch || !I.mouse.inside) {
			sx = window.innerWidth / 2;
			sy = window.innerHeight * 0.45;
		}
		const p = camera.screenToWorld(sx, sy, this.game.world.physics, f.y + 1);
		// mira longe demais: puxa para o alcance dos poderes
		this.aim.x = p.x;
		this.aim.y = p.y;
		this.aim.z = p.z;
		this.aim.ok = true;
		// no celular/trava: mira na frente do cachorro, ou no inimigo mais perto na frente
		if (I.touch && !I.locked) {
			const [fx, fz] = f.forward();
			let best = null, bestD = 30;
			for (const o of this.game.fighters) {
				if (o === f || o.dead || !o.ai) continue;
				const dx = o.x - f.x, dz = o.z - f.z;
				const d = Math.hypot(dx, dz);
				if (d < bestD && (dx * fx + dz * fz) / (d || 1) > 0.2) {
					best = o;
					bestD = d;
				}
			}
			if (best) {
				this.aim.x = best.x;
				this.aim.y = best.y + best.body.height * 0.5;
				this.aim.z = best.z;
			} else {
				this.aim.x = f.x + fx * 14;
				this.aim.y = f.y + 1;
				this.aim.z = f.z + fz * 14;
			}
		}
	}

	update(dt, now, camera) {
		const f = this.f;
		const game = this.game;
		const body = f.body;
		if (f.dead) {
			body.vx = body.vz = 0;
			return;
		}
		this.updateAim(camera);
		f.anim.lookPoint = [this.aim.x, this.aim.y, this.aim.z];
		const controlled = f.casting > 0 && f.castHold;
		const stunned = f.stunned(now);
		// ---- movimento
		const [ax, ay] = moveAxis();
		const [cfx, cfz] = camera.groundForward();
		// direita da câmera = (-fz, fx)
		let mx = cfx * ay + -cfz * ax;
		let mz = cfz * ay + cfx * ax;
		const moving = Math.hypot(mx, mz) > 0.05;
		if (pressed('shift')) this.runToggle = false;
		this.running = (down('shift') || this.runToggle || this.stickRun) && !body.inWater;
		let speed = f.species.Stats.Speed * C.PLAYER_SPEED_MULT * f.speedMult(now);
		if (this.running) speed *= RUN;
		if (body.inWater) speed *= 0.65;
		if (body.flying) speed = f.species.Stats.Speed * FLY * (this.running ? 1.4 : 1);
		const dashing = game.combat.updateDash(f);
		if (stunned) {
			body.vx *= 0.8;
			body.vz *= 0.8;
		} else if (dashing) {
			// o dash controla a velocidade
		} else if (f.knockUntil > now) {
			const k = Math.exp(-dt * 3);
			body.vx *= k;
			body.vz *= k;
		} else if (!controlled) {
			const accel = body.grounded || body.flying || body.inWater ? 14 : 4;
			const k = 1 - Math.exp(-dt * accel);
			body.vx += (mx * speed - body.vx) * k;
			body.vz += (mz * speed - body.vz) * k;
		}
		// virar: para onde anda; atacando, para a mira
		if (!stunned && !dashing && !controlled) {
			let want = null;
			if (f.faceAt && now < f.faceAt.until) want = Math.atan2(-(f.faceAt.x - f.x), -(f.faceAt.z - f.z));
			else if (now < this.faceAimUntil) want = Math.atan2(-(this.aim.x - f.x), -(this.aim.z - f.z));
			else if (moving) want = Math.atan2(-mx, -mz);
			if (want !== null) f.yaw += angleDiff(f.yaw, want) * Math.min(1, dt * (now < this.faceAimUntil ? 18 : 11));
		}
		// ---- pulo / voo
		if (!stunned) {
			if (body.flying) {
				let vy = 0;
				if (down('space')) vy += speed * 0.6;
				if (down('c') || down('ctrl')) vy -= speed * 0.6;
				body.vy += (vy - body.vy) * (1 - Math.exp(-dt * 6));
				// inclina o corpo como avião
				const fwd = (body.vx * -Math.sin(f.yaw) + body.vz * -Math.cos(f.yaw)) / Math.max(1, speed);
				f.pitch += (clamp(body.vy / Math.max(1, speed), -0.5, 0.5) * 0.8 - f.pitch) * dt * 4;
				f.roll += (clamp(this.turnRate || 0, -1, 1) * -0.5 - f.roll) * dt * 4;
				void fwd;
			} else {
				f.pitch += (0 - f.pitch) * Math.min(1, dt * 8);
				f.roll += (0 - f.roll) * Math.min(1, dt * 8);
				if (pressed('space') && (body.grounded || body.inWater)) {
					body.vy = body.inWater ? JUMP * 0.75 : JUMP;
					body.grounded = false;
					game.audio && game.audio.sfx('Jump', f);
				}
			}
			if (pressed('f') || this.flyToggle) {
				this.flyToggle = false;
				this.toggleFly();
			}
		}
		const lastYaw = this.prevYaw ?? f.yaw;
		this.turnRate = angleDiff(lastYaw, f.yaw) / Math.max(dt, 1e-3);
		this.prevYaw = f.yaw;
		if (stunned || controlled) return;
		// ---- dash
		if ((pressed('q') || this.dashPressed) && now >= this.nextDash) {
			this.dashPressed = false;
			let dx = mx, dz = mz;
			if (!moving) {
				dx = this.aim.x - f.x;
				dz = this.aim.z - f.z;
				if (Math.hypot(dx, dz) < 1) [dx, dz] = f.forward();
			}
			this.nextDash = now + game.combat.dash(f, dx, dz);
			game.hud && game.hud.cooldown('dash', this.nextDash - now);
		}
		this.dashPressed = false;
		// ---- ataque 1 (segurar = repete)
		const clicked = Input.clicks.length > 0 && !Input.touch;
		const wantAttack = clicked || (Input.mouse.left && !Input.touch) || down('1') || this.touchAttack;
		if (wantAttack && now >= this.nextAttack && f.casting <= 0) {
			this.faceAimUntil = now + 0.6;
			f.yaw = Math.atan2(-(this.aim.x - f.x), -(this.aim.z - f.z));
			let gap;
			if (f.shot) gap = game.combat.shoot(f, this.aim.x, this.aim.y + 0.5, this.aim.z);
			else gap = game.combat.melee(f, this.aim.x, this.aim.z);
			this.nextAttack = now + gap;
			game.hud && game.hud.cooldown('attack', gap);
		}
		// ---- poderes 2, 3, 4
		for (let k = 0; k < 3; k++) {
			if (pressed(String(k + 2)) || this.skillPressed === k) {
				this.skillPressed = null;
				if (game.skills) {
					const ok = game.skills.tryPlayer(f, k, this.aim);
					if (ok) this.faceAimUntil = now + 0.8;
				}
			}
		}
		this.skillPressed = null;
	}

	toggleFly() {
		const f = this.f;
		const body = f.body;
		if (!f.canFly) {
			this.game.toast && this.game.toast('This dog can\'t fly! (dogs with wings fly)', 'erro');
			return;
		}
		if (this.game.flyBlocked && this.game.flyBlocked(f)) return;
		body.flying = !body.flying;
		if (body.flying) {
			body.vy = 18;
			body.grounded = false;
			f.setAction(null, 0);
			this.game.audio && this.game.audio.sfx('Whoosh', f);
		}
	}

	// o cachorro caiu muito (nuvens) ou afundou: volta
	fellOff() {
		return this.f.y < WATER_Y - 60;
	}
}
