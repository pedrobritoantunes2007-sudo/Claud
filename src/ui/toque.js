// Controles de celular: joystick à esquerda, botões redondos à direita (atacar, pular, dash, poderes 2/3/4,
// correr e voar), como o TouchPad do projeto Roblox.
import { Input } from '../core/input.js';
import { h } from './janela.js';

export class TouchControls {
	constructor(app, root) {
		this.app = app;
		this.root = h('div', 'toque');
		root.appendChild(this.root);
		this.buildStick();
		this.buildButtons();
		this.setVisible(Input.touch);
	}

	setVisible(on) {
		this.root.classList.toggle('ativo', on);
	}

	buildStick() {
		const stick = h('div', 'joystick');
		const knob = h('div', 'pino');
		stick.appendChild(knob);
		this.root.appendChild(stick);
		let id = null, cx = 0, cy = 0;
		const R = 60;
		const move = (x, y) => {
			let dx = x - cx, dy = y - cy;
			const m = Math.hypot(dx, dy);
			if (m > R) {
				dx = (dx / m) * R;
				dy = (dy / m) * R;
			}
			knob.style.transform = `translate(${dx}px, ${dy}px)`;
			Input.joy.x = dx / R;
			Input.joy.y = -dy / R;
			Input.joy.active = true;
			// empurrou até a borda = corre
			this.app.game.ctrl && (this.app.game.ctrl.stickRun = Math.hypot(dx, dy) > R * 0.95);
		};
		stick.addEventListener('pointerdown', (e) => {
			id = e.pointerId;
			const r = stick.getBoundingClientRect();
			cx = r.left + r.width / 2;
			cy = r.top + r.height / 2;
			stick.setPointerCapture(id);
			move(e.clientX, e.clientY);
			e.preventDefault();
		});
		stick.addEventListener('pointermove', (e) => {
			if (e.pointerId === id) move(e.clientX, e.clientY);
		});
		const end = (e) => {
			if (e.pointerId !== id) return;
			id = null;
			knob.style.transform = '';
			Input.joy.x = Input.joy.y = 0;
			Input.joy.active = false;
		};
		stick.addEventListener('pointerup', end);
		stick.addEventListener('pointercancel', end);
	}

	buildButtons() {
		const box = h('div', 'botoes-toque');
		this.root.appendChild(box);
		const make = (key, icon, label, size, right, bottom, bg) => {
			const b = h('div', 'bt', `<span class="ic">${icon}</span><div class="pizza"></div><small>${label}</small>`);
			b.style.width = b.style.height = size + 'px';
			b.style.right = right + 'px';
			b.style.bottom = bottom + 'px';
			b.style.background = bg;
			b.style.fontSize = Math.round(size * 0.42) + 'px';
			b.addEventListener('pointerdown', (e) => {
				e.preventDefault();
				b.classList.add('apertado');
				this.press(key, true);
			});
			const up = () => {
				b.classList.remove('apertado');
				this.press(key, false);
			};
			b.addEventListener('pointerup', up);
			b.addEventListener('pointercancel', up);
			b.addEventListener('pointerleave', up);
			box.appendChild(b);
			return b;
		};
		this.btn = {
			attack: make('attack', '🐾', '', 100, 6, 6, 'radial-gradient(circle at 50% 30%, #ffffff55, transparent 60%), #e0445a'),
			jump: make('jump', '⬆️', 'JUMP', 70, 118, 4, 'linear-gradient(#64b5ff, #2d6fd6)'),
			dash: make('dash', '💨', 'DASH', 64, 14, 118, 'linear-gradient(#7fe8ff, #2fa8d8)'),
			s0: make('s0', '✨', '2', 58, 92, 96, 'linear-gradient(#c58bff, #8a3fe0)'),
			s1: make('s1', '✨', '3', 58, 152, 74, 'linear-gradient(#c58bff, #8a3fe0)'),
			s2: make('s2', '✨', '4', 58, 186, 134, 'linear-gradient(#ffe066, #ffb81c)'),
			run: make('run', '🏃', 'RUN', 50, 196, 10, 'linear-gradient(#7ef06a, #38b544)'),
			fly: make('fly', '🕊️', 'FLY', 50, 70, 176, 'linear-gradient(#ffffff, #b8d8ff)'),
		};
	}

	press(key, down) {
		const ctrl = this.app.game.ctrl;
		if (!ctrl) return;
		if (key === 'attack') ctrl.touchAttack = down;
		else if (key === 'jump') {
			if (down) {
				Input.keys.add('space');
				Input.pressed.add('space');
			} else Input.keys.delete('space');
		} else if (down && key === 'dash') ctrl.dashPressed = true;
		else if (down && key[0] === 's') ctrl.skillPressed = Number(key.slice(1));
		else if (down && key === 'run') {
			ctrl.runToggle = !ctrl.runToggle;
			this.btn.run.classList.toggle('on', ctrl.runToggle);
		} else if (down && key === 'fly') ctrl.flyToggle = true;
	}

	// ícones e cadeados iguais à barra de golpes do PC
	sync(hud) {
		if (!this.root.classList.contains('ativo')) return;
		const f = this.app.game.player;
		if (!f) return;
		for (const key of ['attack', 's0', 's1', 's2', 'dash']) {
			const s = hud.slots[key];
			const b = this.btn[key];
			b.style.display = s.el.style.display;
			b.querySelector('.ic').textContent = s.ic.textContent;
			b.classList.toggle('travado', s.el.classList.contains('travado'));
			b.querySelector('.pizza').style.setProperty('--p', s.pizza.style.getPropertyValue('--p') || '0%');
		}
		this.btn.fly.style.display = f.canFly ? '' : 'none';
		this.btn.fly.classList.toggle('on', f.body.flying);
	}
}
