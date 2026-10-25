// Plaquinhas em cima dos cachorros: nome, nível, barra de vida e ícones de estado (❗ bravo, 💫 tonto, ❄️ gelo...).
import * as THREE from 'three';
import { rarityColor } from '../data/jogo.js';

const ICONS = {
	Alert: '❗', Dizzy: '💫', Sleep: '💤', Charm: '💗', Ice: '🧊', Slow: '🐌', Burn: '🔥', Poison: '☠️', Curse: '💀',
	shield: '🛡️', rage: '💢', haste: '⚡', Roots: '🌿', Stun: '💫',
};

const _v = new THREE.Vector3();

export class Plates {
	constructor(root, camera) {
		this.root = document.createElement('div');
		this.root.className = 'plaquinhas';
		root.appendChild(this.root);
		this.camera = camera;
		this.list = new Map();
		this.maxDist = 120;
	}

	attach(f) {
		const el = document.createElement('div');
		el.className = 'plaquinha' + (f.kind === 'champion' ? ' campeao' : '') + (f.kind === 'player' ? ' minha' : '');
		const marks = document.createElement('div');
		marks.className = 'marcas';
		const name = document.createElement('div');
		name.className = 'nome';
		const bar = document.createElement('div');
		bar.className = 'vida';
		const fill = document.createElement('div');
		fill.className = 'vida-cheia';
		const ghost = document.createElement('div');
		ghost.className = 'vida-fantasma';
		bar.append(ghost, fill);
		el.append(marks, name, bar);
		this.root.appendChild(el);
		const p = { f, el, name, fill, ghost, marks, hp: -1, ghostHp: 1, markList: [], text: '' };
		this.list.set(f, p);
		f.plate = el;
		this.setName(f);
		return p;
	}

	setName(f) {
		const p = this.list.get(f);
		if (!p) return;
		const text = `${f.name} <span class="nv">Lv.${f.level}</span>`;
		if (text !== p.text) {
			p.text = text;
			p.name.innerHTML = text;
			p.name.style.color = f.kind === 'player' ? '#ffffff' : rarityColor(f.species.Rarity);
		}
	}

	detach(f) {
		const p = this.list.get(f);
		if (!p) return;
		p.el.remove();
		this.list.delete(f);
		f.plate = null;
	}

	add(f, mark, seconds) {
		const p = this.list.get(f);
		if (!p) return;
		const now = performance.now() / 1000;
		const ex = p.markList.find((m) => m.mark === mark);
		if (ex) ex.until = Math.max(ex.until, now + seconds);
		else p.markList.push({ mark, until: now + seconds });
		this.renderMarks(p, now);
	}

	renderMarks(p, now) {
		p.markList = p.markList.filter((m) => m.until > now);
		const s = p.markList.map((m) => ICONS[m.mark] || '✨').join('');
		if (s !== p.marksText) {
			p.marksText = s;
			p.marks.textContent = s;
		}
	}

	update(dt) {
		const cam = this.camera;
		const w = window.innerWidth, h = window.innerHeight;
		const now = performance.now() / 1000;
		for (const p of this.list.values()) {
			const f = p.f;
			const dist = cam.position.distanceTo(_v.set(f.x, f.y, f.z));
			const limit = f.kind === 'champion' ? this.maxDist * 2 : this.maxDist;
			if (f.dead && now - f.deadAt > 1.2) {
				p.el.style.display = 'none';
				continue;
			}
			if (dist > limit || !f.mesh.visible) {
				p.el.style.display = 'none';
				continue;
			}
			_v.set(f.x, f.visualY + f.body.height + 0.6 * f.scale, f.z).project(cam);
			if (_v.z > 1 || Math.abs(_v.x) > 1.2 || Math.abs(_v.y) > 1.2) {
				p.el.style.display = 'none';
				continue;
			}
			p.el.style.display = '';
			const sx = (_v.x * 0.5 + 0.5) * w, sy = (-_v.y * 0.5 + 0.5) * h;
			const sc = Math.max(0.55, Math.min(1, 26 / Math.max(1, dist)));
			p.el.style.transform = `translate(${sx.toFixed(1)}px, ${sy.toFixed(1)}px) translate(-50%, -100%) scale(${sc.toFixed(3)})`;
			p.el.style.opacity = dist > limit * 0.8 ? String((limit - dist) / (limit * 0.2)) : '1';
			const frac = Math.max(0, f.hp / f.maxHp);
			if (frac !== p.hp) {
				p.hp = frac;
				p.fill.style.width = (frac * 100).toFixed(1) + '%';
				p.fill.className = 'vida-cheia' + (frac < 0.3 ? ' baixa' : frac < 0.6 ? ' media' : '');
			}
			p.ghostHp += (frac - p.ghostHp) * Math.min(1, dt * 3);
			if (p.ghostHp < frac) p.ghostHp = frac;
			p.ghost.style.width = (p.ghostHp * 100).toFixed(1) + '%';
			if (p.markList.length) this.renderMarks(p, now);
		}
	}

	clear() {
		for (const p of this.list.values()) p.el.remove();
		this.list.clear();
	}
}
