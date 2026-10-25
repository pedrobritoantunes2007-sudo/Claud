// Menu EGGS: comprar ovos (cada um precisa da ilha dele aberta) e abrir ovos ganhos de prêmio.
import { openWindow, h, button } from './janela.js';
import { CONFIG, EGGS, ISLANDS, RARITY, eggOdds } from '../data/jogo.js';
import { formatCash } from '../core/util.js';

export function eggIsland(eggId) {
	if (eggId === 'halloween') return 'legendary';
	return ISLANDS.EGG_ISLAND[eggId] || null;
}

export function eggCss(eggId, size = 1) {
	const e = EGGS[eggId];
	const d = h('div', 'ovo-css');
	d.style.background = e.Color;
	d.style.transform = `scale(${size})`;
	const spots = [[18, 22], [44, 14], [52, 46], [16, 56], [38, 66], [60, 70]];
	spots.forEach(([x, y], i) => {
		const s = h('i');
		s.style.left = x + 'px';
		s.style.top = y + 'px';
		s.style.background = e.Spots;
		const k = 0.7 + ((i * 37) % 10) / 20;
		s.style.width = s.style.height = Math.round(16 * k) + 'px';
		d.appendChild(s);
	});
	if (e.Shiny || e.Glass) d.style.boxShadow = `inset -8px -10px 0 rgba(0,0,0,0.15), inset 6px 8px 0 rgba(255,255,255,0.45), 0 0 18px ${e.Spots}`;
	return d;
}

export function openEggsMenu(app) {
	const w = openWindow({ title: '🥚 EGGS' });
	const level = app.game.player ? app.game.player.level : 1;
	const owned = Object.entries(app.save.eggs).filter(([, n]) => n > 0);
	if (owned.length) {
		const box = h('div', 'detalhe-cao');
		box.appendChild(h('div', null, '<b style="font-family:Luckiest Guy;font-size:20px">🎁 YOUR EGGS</b>'));
		for (const [id, n] of owned) {
			const row = h('div', 'opcao-missao');
			row.append(eggCss(id, 0.45), h('div', 'q', `${EGGS[id].Name} ×${n}`), button('OPEN', 'ouro', () => {
				w.close();
				app.openOwnedEgg(id);
			}));
			box.appendChild(row);
		}
		w.body.appendChild(box);
	}
	const grid = h('div', 'grade-ovos');
	for (const id of CONFIG.EGG_SHOP) {
		const egg = EGGS[id];
		if (!egg) continue;
		const isl = eggIsland(id);
		const unlocked = !isl || app.save.islands[isl];
		const price = CONFIG.EGG_PRICE[id];
		const card = h('div', 'carta-ovo' + (unlocked ? '' : ' trancado'));
		card.appendChild(eggCss(id));
		card.appendChild(h('h4', null, egg.Name));
		const odds = h('div', 'chances');
		for (const o of eggOdds(id, level)) {
			const r = RARITY[o.Rarity];
			odds.appendChild(h('div', null, `<span style="color:${r.Color}">${r.Label}</span><span>${o.Chance < 1 ? o.Chance.toFixed(1) : Math.round(o.Chance * 10) / 10}%</span>`));
		}
		if (egg.Pool === 'Fly') odds.appendChild(h('div', null, '<span>🕊️ only flying dogs</span>'));
		card.appendChild(odds);
		if (!unlocked) {
			card.appendChild(h('div', 'etiqueta', `🔒 Unlock ${ISLANDS.List[isl].Name}`));
		} else {
			const row = h('div');
			row.style.display = 'flex';
			row.style.gap = '6px';
			const b1 = button(`BUY ${formatCash(price)}`, 'ouro', () => {
				if (app.buyEggs(id, 1)) w.close();
			});
			const b3 = button('×3', 'roxo', () => {
				if (app.buyEggs(id, 3)) w.close();
			});
			if (app.save.cash < price) b1.classList.add('desligado');
			if (app.save.cash < price * 3) b3.classList.add('desligado');
			row.append(b1, b3);
			card.appendChild(row);
		}
		grid.appendChild(card);
	}
	w.body.appendChild(grid);
	return w;
}
