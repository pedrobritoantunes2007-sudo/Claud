// HUD (estilo A escuro do projeto Roblox): cartão do cachorro, missão, chip da ilha, barra NEXT, avisos,
// dinheiro, radar, botões DOGS / EGGS / MAP / SETTINGS e a barra de golpes com recarga e cadeados.
import { formatCash, formatNumber } from '../core/util.js';
import { portrait } from '../dogs/retrato.js';
import { CONFIG, ISLANDS, RARITY, skillsOf, starsFor, xpToNext, hasSupreme, powerUnlockLevel } from '../data/jogo.js';
import { Input } from '../core/input.js';

export const SKILL_ICONS = {
	crown: '👑', shadow: '🌑', star: '⭐', boulder: '⛰️', ice: '❄️', fire: '🔥', wind: '🌪️', poison: '☠️', bolt: '⚡',
	water: '💧', shield: '🛡️', target: '🎯', leaf: '🍃', sword: '⚔️', wing: '🕊️', fang: '🦷', paw: '🐾', bone: '🦴',
	heart: '💖', gear: '⚙️',
};

const ISLAND_EMOJI = { village: '🏡', main: '⚔️', ...ISLANDS.EMOJI };

function el(tag, cls, html) {
	const e = document.createElement(tag);
	if (cls) e.className = cls;
	if (html !== undefined) e.innerHTML = html;
	return e;
}

export class Hud {
	constructor(app, root) {
		this.app = app;
		this.root = el('div', 'hud');
		root.appendChild(this.root);
		this.cool = {};
		this.build();
		this.lastCash = -1;
		this.toasts = [];
	}

	build() {
		const r = this.root;
		// ---- cima-esquerda
		const left = el('div', 'hud-esq');
		this.card = el('div', 'painel cartao');
		this.card.innerHTML = `<div class="rosto"><img alt=""><div class="selo-lv">LV 1</div></div>
			<div class="info"><div class="nome-cao"><span class="nm">Dog</span><span class="estrelas"></span></div>
			<div class="barra vida"><div class="enche"></div><div class="txt"></div></div>
			<div class="barra xp"><div class="enche"></div><div class="txt"></div></div></div>`;
		this.card.onclick = () => this.app.openMenu('dogs');
		this.cardImg = this.card.querySelector('img');
		this.cardLv = this.card.querySelector('.selo-lv');
		this.cardName = this.card.querySelector('.nm');
		this.cardStars = this.card.querySelector('.estrelas');
		this.hpBar = this.card.querySelector('.barra.vida');
		this.hpFill = this.hpBar.querySelector('.enche');
		this.hpTxt = this.hpBar.querySelector('.txt');
		this.xpFill = this.card.querySelector('.barra.xp .enche');
		this.xpTxt = this.card.querySelector('.barra.xp .txt');
		const round = el('div', 'redondos');
		this.btnSettings = this.roundButton('⚙️', 'SETTINGS', () => this.app.openMenu('settings'), 'linear-gradient(#a9a3c9, #6b6494)');
		this.btnHelp = this.roundButton('📖', 'GUIDE', () => this.app.openMenu('help'), 'linear-gradient(#ffd66b, #e8a12a)');
		round.append(this.btnSettings, this.btnHelp);
		this.quest = el('div', 'painel missao-hud vazia');
		this.quest.innerHTML = `<div class="titulo">📜 MISSION</div><div class="texto">Talk to the ❗ Mission Master</div><div class="barra missao"><div class="enche" style="width:0%"></div></div>`;
		this.questTxt = this.quest.querySelector('.texto');
		this.questFill = this.quest.querySelector('.enche');
		this.quest.onclick = () => this.app.questHint && this.app.questHint();
		left.append(this.card, round, this.quest);
		// ---- cima-meio
		const mid = el('div', 'hud-meio');
		this.islandChip = el('div', 'painel chip-ilha', '');
		this.next = el('div', 'painel proximo');
		this.next.innerHTML = `<div class="texto"></div><div class="barra xp"><div class="enche"></div><div class="txt"></div></div>`;
		this.nextTxt = this.next.querySelector('.texto');
		this.nextFill = this.next.querySelector('.enche');
		this.nextBarTxt = this.next.querySelector('.txt');
		this.next.onclick = () => this.app.openMenu('map');
		this.toastBox = el('div', 'avisos');
		mid.append(this.islandChip, this.next, this.toastBox);
		// ---- cima-direita
		const right = el('div', 'hud-dir');
		this.cash = el('div', 'painel dinheiro', `<span class="moeda">💰</span><span class="v">$0</span>`);
		this.cashTxt = this.cash.querySelector('.v');
		this.radar = el('div', 'radar');
		this.radarCanvas = document.createElement('canvas');
		this.radarCanvas.width = 150;
		this.radarCanvas.height = 150;
		this.radar.appendChild(this.radarCanvas);
		right.append(this.cash, this.radar);
		// ---- lado direito: menus
		const side = el('div', 'menu-lado');
		this.btnDogs = this.menuButton('caes', '🐶', 'DOGS', () => this.app.openMenu('dogs'));
		this.btnEggs = this.menuButton('ovos', '🥚', 'EGGS', () => this.app.openMenu('eggs'));
		this.btnMap = this.menuButton('mapa', '🗺️', 'MAP', () => this.app.openMenu('map'));
		side.append(this.btnDogs, this.btnEggs, this.btnMap);
		// ---- golpes
		this.bar = el('div', 'golpes');
		this.slots = {};
		for (const key of ['attack', 's0', 's1', 's2', 'dash']) {
			const g = el('div', 'golpe');
			g.innerHTML = `<div class="bola"><span class="ic"></span><div class="pizza"></div><div class="seg"></div></div>
				<div class="tecla"></div><div class="cadeado">🔒<span></span></div><div class="rotulo"></div>`;
			g.addEventListener('pointerdown', (e) => {
				e.preventDefault();
				this.app.pressSlot(key, true);
			});
			g.addEventListener('pointerup', () => this.app.pressSlot(key, false));
			g.addEventListener('pointerleave', () => this.app.pressSlot(key, false));
			this.bar.appendChild(g);
			this.slots[key] = {
				el: g,
				ic: g.querySelector('.ic'),
				pizza: g.querySelector('.pizza'),
				seg: g.querySelector('.seg'),
				key: g.querySelector('.tecla'),
				lock: g.querySelector('.cadeado span'),
				label: g.querySelector('.rotulo'),
				bola: g.querySelector('.bola'),
				ready: true,
			};
		}
		// ---- nocaute e dica de interação
		this.ko = el('div', 'nocaute', 'KNOCKED OUT!<small>Back to the portal in <b>5</b>...</small>');
		this.koSec = this.ko.querySelector('b');
		this.hint = el('div', 'painel dica-e');
		this.hint.onclick = () => this.app.interact && this.app.interact();
		r.append(left, mid, right, side, this.bar, this.ko, this.hint);
		this.layout();
		window.addEventListener('resize', () => this.layout());
	}

	roundButton(icon, label, fn, bg) {
		const b = el('button', 'botao-redondo', `<div class="bola" style="background:${bg}">${icon}</div><span>${label}</span>`);
		b.onclick = fn;
		return b;
	}

	menuButton(cls, icon, label, fn) {
		const b = el('div', 'botao-menu ' + cls, `<div class="ic">${icon}</div><span>${label}</span><div class="bolinha"></div>`);
		b.onclick = fn;
		return b;
	}

	badge(name, text) {
		const b = { dogs: this.btnDogs, eggs: this.btnEggs, map: this.btnMap }[name];
		if (b) b.querySelector('.bolinha').textContent = text || '';
	}

	// tamanho das coisas pela tela (celular = maior para o dedo, telas pequenas = menor)
	layout() {
		const w = window.innerWidth, h = window.innerHeight;
		let s = Math.min(w / 1280, h / 720);
		if (Input.touch) s *= 1.1;
		s = Math.max(0.55, Math.min(1.15, s));
		this.root.style.setProperty('--s', s.toFixed(3));
		this.radar.style.display = Input.touch || h < 560 ? 'none' : '';
		this.next.style.display = w < 700 ? 'none' : '';
		this.bar.style.display = Input.touch ? 'none' : '';
		this.btnHelp.style.display = w < 600 ? 'none' : '';
	}

	show(on) {
		this.root.classList.toggle('escondido', !on);
	}

	setDog(f, dog) {
		this.f = f;
		this.dog = dog;
		this.cardImg.src = portrait(f.speciesId, 'rosto', 160);
		const rc = RARITY[f.species.Rarity];
		this.card.querySelector('.rosto').style.background = `radial-gradient(circle at 50% 35%, #ffffff, ${rc.Color})`;
		this.cardName.textContent = (dog && dog.name) || f.species.Name;
		this.setupSlots(f);
	}

	setupSlots(f) {
		const s = this.slots;
		const skills = skillsOf(f.speciesId);
		const shot = f.shot;
		s.attack.ic.textContent = shot ? shot.style.Icon || '💥' : '🐾';
		s.attack.label.textContent = shot ? shot.style.Name : 'BITE';
		s.attack.bola.style.setProperty('--cor', shot ? shot.style.Color : '#e0445a');
		s.attack.key.textContent = Input.touch ? '' : '1';
		for (let k = 0; k < 3; k++) {
			const slot = s['s' + k];
			const sk = skills[k];
			const exists = !!sk && (k < 2 || hasSupreme(f.species.Rarity));
			slot.el.style.display = exists ? '' : 'none';
			if (!exists) continue;
			slot.ic.textContent = SKILL_ICONS[sk.Icon] || '✨';
			slot.label.textContent = sk.Name;
			slot.bola.style.setProperty('--cor', sk.Color || '#8a5cff');
			slot.key.textContent = Input.touch ? '' : String(k + 2);
			slot.need = powerUnlockLevel(k);
		}
		s.dash.ic.textContent = '💨';
		s.dash.label.textContent = 'DASH';
		s.dash.bola.style.setProperty('--cor', '#5fd0ff');
		s.dash.key.textContent = Input.touch ? '' : 'Q';
	}

	cooldown(slot, seconds) {
		this.cool[slot] = { end: performance.now() / 1000 + seconds, dur: seconds };
	}

	setIsland(id) {
		const def = ISLANDS.List[id];
		const name = id === 'village' ? 'Pawville' : id === 'main' ? 'Dog Arena Island' : def ? def.Name : id;
		const sub = def ? `Wild Lv.${def.Levels[0]}-${def.Levels[1]}` : 'Safe zone';
		this.islandChip.innerHTML = `${ISLAND_EMOJI[id] || '🏝️'} ${name} <small>${sub}</small>`;
	}

	setQuest(q) {
		if (!q) {
			this.quest.classList.add('vazia');
			this.questTxt.textContent = this.app.questIdleText ? this.app.questIdleText() : 'Talk to the ❗ Mission Master';
			this.questFill.style.width = '0%';
			return;
		}
		this.quest.classList.remove('vazia');
		const def = ISLANDS.List[q.island];
		const what = q.kind === 'boss' ? `Defeat ${def.Champion.Name}` : `Defeat ${q.need} wild dogs`;
		this.questTxt.innerHTML = `${what} <b>${q.have}/${q.need}</b>${q.island !== this.app.game.islandId ? ` <small>(${def.Name})</small>` : ''}`;
		this.questFill.style.width = Math.min(100, (q.have / q.need) * 100) + '%';
	}

	setNext(text, have, need, ready) {
		this.nextTxt.innerHTML = text;
		const frac = need > 0 ? Math.min(1, have / need) : 1;
		this.nextFill.style.width = (frac * 100).toFixed(1) + '%';
		this.nextBarTxt.textContent = need > 0 ? `${formatCash(have)} / ${formatCash(need)}` : '';
		this.next.classList.toggle('pronto', !!ready);
	}

	toast(msg, kind = '', seconds = 3) {
		const t = el('div', 'painel aviso ' + kind);
		t.innerHTML = msg;
		this.toastBox.appendChild(t);
		this.toasts.push(t);
		while (this.toasts.length > 3) this.toasts.shift().remove();
		setTimeout(() => {
			t.classList.add('sumindo');
			setTimeout(() => {
				t.remove();
				this.toasts = this.toasts.filter((x) => x !== t);
			}, 320);
		}, seconds * 1000);
	}

	showKO(on, seconds) {
		this.ko.classList.toggle('ativo', on);
		if (on) this.koSec.textContent = Math.max(0, Math.ceil(seconds));
	}

	showHint(html) {
		if (!html) {
			this.hint.classList.remove('ativo');
			this.hintHtml = null;
			return;
		}
		if (html !== this.hintHtml) {
			this.hintHtml = html;
			this.hint.innerHTML = (Input.touch ? '' : '<kbd>E</kbd>') + html;
		}
		this.hint.classList.add('ativo');
	}

	update(dt) {
		const f = this.f;
		const save = this.app.save;
		if (f) {
			const hpf = Math.max(0, f.hp / f.maxHp);
			this.hpFill.style.width = (hpf * 100).toFixed(1) + '%';
			this.hpBar.classList.toggle('baixa', hpf < 0.3);
			this.hpTxt.textContent = `${formatNumber(Math.ceil(f.hp))} / ${formatNumber(f.maxHp)}`;
			const need = xpToNext(f.level);
			const xpf = f.level >= CONFIG.MAX_LEVEL ? 1 : Math.min(1, (f.xp || 0) / need);
			this.xpFill.style.width = (xpf * 100).toFixed(1) + '%';
			this.xpTxt.textContent = f.level >= CONFIG.MAX_LEVEL ? 'MAX' : `XP ${formatNumber(f.xp || 0)} / ${formatNumber(need)}`;
			this.cardLv.textContent = 'LV ' + f.level;
			const stars = starsFor(f.level);
			this.cardStars.textContent = '★'.repeat(stars) + '☆'.repeat(CONFIG.STAR_LEVELS.length - stars);
		}
		if (save.cash !== this.lastCash) {
			if (this.lastCash >= 0 && save.cash > this.lastCash) {
				this.cash.classList.remove('pulo');
				void this.cash.offsetWidth;
				this.cash.classList.add('pulo');
			}
			this.lastCash = save.cash;
			this.cashTxt.textContent = formatCash(save.cash);
		}
		// golpes: recarga e cadeados
		const now = performance.now() / 1000;
		for (const [key, s] of Object.entries(this.slots)) {
			if (s.el.style.display === 'none') continue;
			let locked = false;
			if (s.need && f && f.level < s.need) {
				locked = true;
				s.lock.textContent = 'Lv.' + s.need;
			}
			s.el.classList.toggle('travado', locked);
			const c = this.cool[key];
			let left = 0;
			if (c) left = c.end - now;
			if (key.startsWith('s') && this.app.skillCooldown) {
				const cd = this.app.skillCooldown(Number(key.slice(1)));
				if (cd) {
					left = cd.left;
					this.cool[key] = { end: now + cd.left, dur: cd.dur };
				}
			}
			if (left > 0 && c) {
				s.pizza.style.setProperty('--p', ((left / c.dur) * 100).toFixed(1) + '%');
				s.seg.textContent = left > 1.5 ? Math.ceil(left) : '';
				s.ready = false;
			} else {
				s.pizza.style.setProperty('--p', '0%');
				s.seg.textContent = '';
				if (!s.ready && !locked) {
					s.el.classList.remove('pronto');
					void s.el.offsetWidth;
					s.el.classList.add('pronto');
				}
				s.ready = true;
			}
		}
		this.drawRadar();
	}

	drawRadar() {
		if (this.radar.style.display === 'none') return;
		const g = this.radarCanvas.getContext('2d');
		const game = this.app.game;
		const p = game.player;
		if (!p) return;
		const W = 150, R = 72, range = 160;
		g.clearRect(0, 0, W, W);
		g.save();
		g.translate(W / 2, W / 2);
		// o radar gira com a câmera (para cima = para onde a câmera olha)
		const yaw = game.cam.yaw;
		g.strokeStyle = 'rgba(201,193,230,0.25)';
		g.lineWidth = 2;
		for (const rr of [R * 0.5, R]) {
			g.beginPath();
			g.arc(0, 0, rr, 0, Math.PI * 2);
			g.stroke();
		}
		const plot = (x, z) => {
			const dx = x - p.x, dz = z - p.z;
			const c = Math.cos(yaw), s = Math.sin(yaw);
			const rx = dx * c - dz * s, rz = dx * s + dz * c;
			let px = (rx / range) * R, py = (rz / range) * R;
			const m = Math.hypot(px, py);
			if (m > R - 4) {
				px *= (R - 4) / m;
				py *= (R - 4) / m;
			}
			return [px, py];
		};
		for (const portal of game.portals) {
			const [x, y] = plot(portal.x, portal.z);
			g.fillStyle = '#5fe0c8';
			g.fillRect(x - 4, y - 4, 8, 8);
		}
		if (this.app.npcSpots) {
			for (const n of this.app.npcSpots()) {
				const [x, y] = plot(n.x, n.z);
				g.fillStyle = n.color || '#ffe066';
				g.beginPath();
				g.arc(x, y, 4.5, 0, Math.PI * 2);
				g.fill();
			}
		}
		for (const w of game.wild) {
			if (w.dead) continue;
			const [x, y] = plot(w.x, w.z);
			g.fillStyle = w.kind === 'champion' ? '#ffb81c' : w.target ? '#ff3b5c' : '#ff8a8a';
			g.beginPath();
			g.arc(x, y, w.kind === 'champion' ? 5.5 : 3, 0, Math.PI * 2);
			g.fill();
		}
		g.fillStyle = '#ffffff';
		g.beginPath();
		const a = -(p.yaw - yaw);
		g.moveTo(Math.sin(a) * -7, Math.cos(a) * -7);
		g.lineTo(Math.sin(a + 2.5) * -5, Math.cos(a + 2.5) * -5);
		g.lineTo(Math.sin(a - 2.5) * -5, Math.cos(a - 2.5) * -5);
		g.fill();
		g.restore();
		// N
		const nx = W / 2 + Math.sin(yaw) * (R - 9), ny = W / 2 - Math.cos(yaw) * (R - 9);
		g.font = '13px "Luckiest Guy"';
		g.fillStyle = '#ffe066';
		g.textAlign = 'center';
		g.textBaseline = 'middle';
		g.fillText('N', nx, ny);
	}
}
