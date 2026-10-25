// Telas especiais: abrir ovo (balança, racha, estoura, aparece o cachorro), roleta do Prof. Barkley,
// tela de entrada (logo + PLAY) e a cortina de viagem.
import { h, button } from './janela.js';
import { portrait } from '../dogs/retrato.js';
import { eggCss } from './menuOvos.js';
import { RARITY, SPECIES, CONFIG, speciesOfRarity } from '../data/jogo.js';

const wait = (ms) => new Promise((r) => setTimeout(r, ms));

// ---------------------------------------------------------------- abrir ovos
// results = [{ sp, isNew }]; devolve uma Promise que resolve quando fecha
export function hatchScreen(app, eggId, results) {
	return new Promise((resolve) => {
		const root = h('div', 'chocar');
		const rays = h('div', 'raios');
		const flash = h('div', 'flash');
		const stage = h('div', 'palco');
		const egg = eggCss(eggId);
		egg.appendChild(h('div', 'rachadura'));
		stage.appendChild(egg);
		const title = h('div');
		const buttons = h('div', 'botoes');
		root.append(rays, flash, stage, title, buttons);
		app.uiRoot.appendChild(root);
		let skipped = false;
		const close = () => {
			root.remove();
			resolve();
		};
		const skip = button('SKIP', 'cinza', () => {
			skipped = true;
		});
		buttons.appendChild(skip);
		(async () => {
			const best = results.reduce((a, b) => (RARITY[SPECIES[b.sp].Rarity].Order > RARITY[SPECIES[a.sp].Rarity].Order ? b : a), results[0]);
			const color = RARITY[SPECIES[best.sp].Rarity].Color;
			root.style.setProperty('--cor', color);
			if (!skipped) {
				for (const cls of ['balanca', 'balanca', 'balanca2']) {
					egg.classList.remove('balanca', 'balanca2');
					void egg.offsetWidth;
					egg.classList.add(cls);
					app.audio && app.audio.sfx2('EggCrack');
					await wait(cls === 'balanca2' ? 480 : 560);
					if (skipped) break;
				}
				egg.classList.add('rachado');
				if (!skipped) await wait(250);
			}
			egg.classList.add('estoura');
			flash.classList.add('vai');
			app.audio && app.audio.sfx2('EggPop');
			app.audio && app.audio.jingle('Hatch');
			await wait(260);
			stage.innerHTML = '';
			root.classList.add('revelou');
			buttons.innerHTML = '';
			if (results.length === 1) {
				const r = results[0];
				const s = SPECIES[r.sp];
				const rc = RARITY[s.Rarity];
				const img = h('img', 'cao');
				img.src = portrait(r.sp, 'corpo', 320);
				img.style.setProperty('--cor', rc.Color);
				stage.appendChild(img);
				title.innerHTML = `<div class="titulo-cao">${s.Name}${r.isNew ? '<span class="novo">NEW!</span>' : ''}</div><div class="raridade" style="--cor:${rc.Color};text-align:center">${rc.Label}</div>`;
			} else {
				stage.style.width = 'auto';
				stage.style.height = 'auto';
				const grid = h('div', 'resultados');
				for (const r of results) {
					const s = SPECIES[r.sp];
					const rc = RARITY[s.Rarity];
					const c = h('div', 'carta-cao');
					c.style.setProperty('--rar', rc.Color);
					const img = h('img');
					img.src = portrait(r.sp, 'corpo', 192);
					c.append(img, h('div', 'n', s.Name + (r.isNew ? ' ✨' : '')), h('div', 'r', rc.Label));
					grid.appendChild(c);
				}
				stage.appendChild(grid);
				title.innerHTML = `<div class="titulo-cao">${results.length} NEW DOGS!</div>`;
			}
			buttons.appendChild(button('CONTINUE', 'grande', close));
			if (results.length === 1) {
				buttons.appendChild(
					button('EQUIP', 'azul grande', () => {
						app.equipDog(results[0].dogId);
						close();
					}),
				);
			}
		})();
	});
}

// ---------------------------------------------------------------- roleta do 1º cachorro
// chances = Config.ROULETTE.Normal; spins = giros grátis (3: gira, vê e pode girar de novo; o último fica)
export function rouletteScreen(app, opts) {
	return new Promise((resolve) => {
		const root = h('div', 'roleta');
		const title = h('h1', null, opts.title || "🎓 PROF. BARKLEY'S ROULETTE");
		const sub = h('div', 'sub', opts.sub || 'Spin to get your first dog! Any dog can come out — even a Mythic!');
		const win = h('div', 'janela-fita');
		const strip = h('div', 'fita');
		win.append(strip, h('div', 'ponteiro'));
		const odds = h('div', 'chances-roleta');
		for (const [r, c] of CONFIG.ROULETTE.Normal) odds.appendChild(h('span', null, `<b style="color:${RARITY[r].Color}">${RARITY[r].Label}</b> ${c}%`));
		const spinsTxt = h('div', 'giros');
		const result = h('div', 'sub');
		const buttons = h('div', 'botoes');
		buttons.style.display = 'flex';
		buttons.style.gap = '12px';
		root.append(title, sub, win, odds, spinsTxt, result, buttons);
		app.uiRoot.appendChild(root);
		let spins = opts.spins;
		const ITEM = 160;
		const show = () => {
			spinsTxt.textContent = spins > 0 ? `🎟️ ${spins} spin${spins > 1 ? 's' : ''} left` : 'Last spin — this dog is yours!';
		};
		show();
		const randomOfRarity = (rar) => {
			const list = speciesOfRarity(rar);
			return list[Math.floor(Math.random() * list.length)];
		};
		const fakePick = () => {
			// a fita mostra mais raros do que sai de verdade (fica emocionante)
			const roll = Math.random() * 100;
			const rar = roll < 30 ? 'Common' : roll < 52 ? 'Uncommon' : roll < 70 ? 'Rare' : roll < 82 ? 'Epic' : roll < 92 ? 'Legendary' : 'Mythic';
			return randomOfRarity(rar) || 'caramelo';
		};
		const spin = async () => {
			buttons.innerHTML = '';
			result.textContent = '';
			const [sp] = opts.roll();
			spins--;
			show();
			strip.innerHTML = '';
			const N = 46, target = 40;
			const items = [];
			for (let i = 0; i < N; i++) items.push(i === target ? sp : i === target - 1 || i === target + 1 ? randomOfRarity(Math.random() < 0.5 ? 'Legendary' : 'Mythic') || fakePick() : fakePick());
			for (const id of items) {
				const s = SPECIES[id];
				const it = h('div', 'item');
				it.style.setProperty('--rar', RARITY[s.Rarity].Color);
				const img = h('img');
				img.src = portrait(id, 'corpo', 160);
				it.append(img, h('span', null, s.Name));
				strip.appendChild(it);
			}
			const width = win.clientWidth;
			const end = target * ITEM - width / 2 + ITEM / 2 - 5 + (Math.random() - 0.5) * 90;
			strip.style.transition = 'none';
			strip.style.transform = 'translateX(0px)';
			void strip.offsetWidth;
			strip.style.transition = 'transform 5.2s cubic-bezier(0.08, 0.6, 0.12, 1)';
			strip.style.transform = `translateX(${-end}px)`;
			// tique-taque enquanto passa
			let last = -1;
			const t0 = performance.now();
			await new Promise((done) => {
				const tick = () => {
					const m = new DOMMatrix(getComputedStyle(strip).transform);
					const idx = Math.floor((-m.m41 + width / 2) / ITEM);
					if (idx !== last) {
						last = idx;
						app.audio && app.audio.sfx2('Click', 0.5);
					}
					if (performance.now() - t0 < 5300) requestAnimationFrame(tick);
					else done();
				};
				requestAnimationFrame(tick);
			});
			// encaixa no ganhador
			strip.style.transition = 'transform 0.35s ease-out';
			strip.style.transform = `translateX(${-(target * ITEM - width / 2 + ITEM / 2 - 5)}px)`;
			await wait(380);
			const s = SPECIES[sp];
			const rc = RARITY[s.Rarity];
			const won = strip.children[target];
			won.style.transform = 'scale(1.08)';
			won.style.transition = 'transform 0.3s';
			won.style.boxShadow = `0 0 30px ${rc.Color}`;
			const big = rc.Order >= RARITY.Legendary.Order;
			app.audio && app.audio.jingle(big ? 'Victory' : 'Hatch');
			result.innerHTML = `<b style="font-family:Luckiest Guy;font-size:30px;color:${rc.Color}">${big ? '🎉 JACKPOT! ' : ''}${s.Name}</b><br><span style="color:${rc.Color}">${rc.Label}</span>`;
			if (spins > 0) {
				buttons.append(
					button('KEEP THIS DOG', 'grande', () => finish(sp)),
					button(`SPIN AGAIN (${spins})`, 'roxo grande', () => spin()),
				);
			} else {
				buttons.append(button('THIS IS MY DOG!', 'ouro grande', () => finish(sp)));
			}
		};
		const finish = (sp) => {
			root.remove();
			resolve(sp);
		};
		buttons.appendChild(button('🎰 SPIN!', 'ouro grande', () => spin()));
	});
}

// ---------------------------------------------------------------- tela de entrada
export function titleScreen(app) {
	return new Promise((resolve) => {
		const root = h('div', 'inicio');
		const top = h('div', 'meio');
		top.innerHTML = '<div class="logo"><span class="l1">DOG</span><span class="l2">FIGHTER</span></div><div class="faixa-sub">🐾 Become your dog! 🐾</div>';
		const mid = h('div', 'meio');
		const play = button('▶ PLAY', 'btn-jogar grande', () => {
			root.remove();
			resolve();
		});
		mid.appendChild(play);
		const foot = h('div', 'rodape', '80 dogs · 10 islands · v' + (app.version || '1.0'));
		root.append(top, mid, foot);
		app.uiRoot.appendChild(root);
	});
}

// ---------------------------------------------------------------- cortina (viagem)
export function curtain(app) {
	let el = app.uiRoot.querySelector('.cortina');
	if (!el) {
		el = h('div', 'cortina', '<div class="titulo"></div><div class="barra xp"><div class="enche" style="width:0%"></div></div>');
		app.uiRoot.appendChild(el);
	}
	return {
		show(text) {
			el.querySelector('.titulo').textContent = text;
			el.querySelector('.enche').style.width = '0%';
			el.classList.add('ativa');
			return wait(360);
		},
		progress(p) {
			el.querySelector('.enche').style.width = Math.round(p * 100) + '%';
		},
		hide() {
			el.classList.remove('ativa');
		},
	};
}
