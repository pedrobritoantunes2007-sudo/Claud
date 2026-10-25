// Menu MAP: viajar para as ilhas abertas e abrir a próxima com Cash (em ordem, como no Roblox).
import { openWindow, h, button } from './janela.js';
import { ISLANDS, RARITY, EGGS, SPECIES } from '../data/jogo.js';
import { formatCash } from '../core/util.js';

export const PLACES = [
	{ id: 'village', name: 'Pawville', emoji: '🏡', color: '#ffb6d5', sub: 'Town · Prof. Barkley · start here' },
	{ id: 'main', name: 'Dog Arena Island', emoji: '⚔️', color: '#3fd0c9', sub: 'Colosseum · Portal Plaza' },
];

export function canUnlock(save, id) {
	const def = ISLANDS.List[id];
	if (!def || save.islands[id]) return false;
	return !def.Requires || !!save.islands[def.Requires];
}

export function openMapMenu(app) {
	const w = openWindow({ title: '🗺️ MAP' });
	const grid = h('div', 'lista-ilhas');
	const here = app.game.islandId;
	const card = (id, name, emoji, color, sub, extra) => {
		const c = h('div', 'carta-ilha' + (id === here ? ' aqui' : ''));
		c.style.setProperty('--cor', color);
		c.append(h('div', 'faixa'), h('div', 'emoji', emoji), h('h4', null, name), h('div', 'sub', sub));
		if (extra) c.appendChild(extra);
		return c;
	};
	for (const p of PLACES) {
		const act = p.id === here ? h('div', 'etiqueta', '📍 YOU ARE HERE') : button('TRAVEL', 'azul', () => {
			w.close();
			app.travel(p.id);
		});
		grid.appendChild(card(p.id, p.name, p.emoji, p.color, p.sub, act));
	}
	for (const id of ISLANDS.ORDER) {
		const def = ISLANDS.List[id];
		const color = (RARITY[def.Rarity] && RARITY[def.Rarity].Color) || ISLANDS.COLORS[id] || '#9ed8ff';
		const egg = def.Egg ? EGGS[def.Egg].Name : 'No egg (Divine altar)';
		const sub = `Wild Lv.${def.Levels[0]}-${def.Levels[1]} · ${egg}<br>👑 ${def.Champion.Name} (${SPECIES[def.Champion.Species].Name})${def.Flyers ? '<br>🕊️ Only dogs that FLY can fight here' : ''}`;
		let act;
		if (id === here) act = h('div', 'etiqueta', '📍 YOU ARE HERE');
		else if (app.save.islands[id]) act = button('TRAVEL', 'azul', () => {
			w.close();
			app.travel(id);
		});
		else if (canUnlock(app.save, id)) {
			act = button(`UNLOCK ${formatCash(def.Price)}`, 'ouro', () => {
				if (app.unlockIsland(id)) {
					w.close();
					app.travel(id);
				}
			});
			if (app.save.cash < def.Price) act.classList.add('desligado');
		} else act = h('div', 'etiqueta', `🔒 Unlock ${ISLANDS.List[def.Requires].Name} first`);
		const c = card(id, def.Name, ISLANDS.EMOJI[id] || '🏝️', color, sub, act);
		if (!app.save.islands[id]) c.classList.add('trancada');
		grid.appendChild(c);
	}
	w.body.appendChild(grid);
	return w;
}
