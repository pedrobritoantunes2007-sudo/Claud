// Menu DOGS: seus cachorros (equipar, ver poderes, soltar) e o ÍNDICE com todos os 80.
import { openWindow, h, button, confirmBox } from './janela.js';
import { portrait, lazyPortrait } from '../dogs/retrato.js';
import { SPECIES, ORDER, RARITY, CONFIG, ELEMENTS, skillsOf, stats, hasSupreme, powerUnlockLevel, xpToNext, starsFor } from '../data/jogo.js';
import { SKILL_ICONS } from './hud.js';
import { formatNumber, formatCash } from '../core/util.js';

const RARITY_ORDER = Object.fromEntries(Object.entries(RARITY).map(([k, v]) => [k, v.Order]));

export function openDogsMenu(app, tab = 'meus') {
	const w = openWindow({ title: '🐶 DOGS' });
	const tabs = h('div', 'abas');
	const mine = button('MY DOGS', 'azul', () => render('meus'));
	const index = button('INDEX', 'roxo', () => render('indice'));
	tabs.append(mine, index);
	const count = h('span', 'etiqueta');
	count.style.marginLeft = 'auto';
	count.style.alignSelf = 'center';
	tabs.appendChild(count);
	const detail = h('div');
	const grid = h('div', 'grade-caes');
	w.body.append(tabs, detail, grid);
	let selected = null;

	function render(which) {
		tab = which;
		mine.classList.toggle('ativa', which === 'meus');
		index.classList.toggle('ativa', which === 'indice');
		grid.innerHTML = '';
		const save = app.save;
		count.textContent = which === 'meus' ? `${save.dogs.length} / ${CONFIG.MAX_DOGS}` : `${Object.keys(save.seen).length} / ${ORDER.length} found`;
		if (which === 'meus') {
			const dogs = [...save.dogs].sort((a, b) => (b.id === save.equipped) - (a.id === save.equipped) || RARITY_ORDER[SPECIES[b.sp].Rarity] - RARITY_ORDER[SPECIES[a.sp].Rarity] || b.lv - a.lv);
			if (!selected || !save.dogs.includes(selected)) selected = dogs[0] || null;
			for (const d of dogs) grid.appendChild(dogCard(d.sp, d, d === selected, d.id === save.equipped, () => select(d)));
			showDetail(selected);
		} else {
			for (const sp of ORDER) {
				const has = !!save.seen[sp];
				const card = dogCard(sp, null, false, false, () => showSpecies(sp));
				if (!has) card.classList.add('nao-tem');
				grid.appendChild(card);
			}
			detail.innerHTML = '<p style="margin:0 0 10px;color:#d8d2f5">Every dog in Dog Fighter. Hatch eggs on each island to find them all!</p>';
		}
	}

	function select(d) {
		selected = d;
		render('meus');
	}

	function dogCard(sp, dog, sel, equipped, onClick) {
		const s = SPECIES[sp];
		const r = RARITY[s.Rarity];
		const c = h('div', 'carta-cao' + (sel ? ' selecionado' : '') + (equipped ? ' equipado' : ''));
		c.style.setProperty('--rar', r.Color);
		const img = h('img');
		lazyPortrait(img, sp, 'corpo', 192);
		c.append(img, h('div', 'n', (dog && dog.name) || s.Name), h('div', 'r', r.Label));
		if (dog) c.appendChild(h('div', 'lv', 'Lv.' + dog.lv));
		c.onclick = onClick;
		return c;
	}

	function elementsHtml(sp) {
		return (SPECIES[sp].Elements || []).map((e) => `<span class="etiqueta">${ELEMENTS[e] ? ELEMENTS[e].Icon : ''} ${e}</span>`).join('');
	}

	function skillsHtml(sp, level) {
		const list = skillsOf(sp);
		const rar = SPECIES[sp].Rarity;
		const shot = SPECIES[sp].Shot;
		let html = `<div class="poder"><span class="ic">${shot ? '🎯' : '🐾'}</span><div><b>1 · ${shot ? 'Mouth Shot' : 'Paw Combo'}</b><div class="desc">${shot ? 'Shoots far where you aim. Every 3rd shot is a big one.' : 'Right paw, left paw, then a big BITE that pushes enemies away.'}</div></div></div>`;
		list.forEach((sk, i) => {
			if (i === 2 && !hasSupreme(rar)) return;
			const need = powerUnlockLevel(i);
			const locked = level !== null && level < need;
			html += `<div class="poder${locked ? ' travado' : ''}"><span class="ic">${SKILL_ICONS[sk.Icon] || '✨'}</span><div><b>${i + 2} · ${sk.Name}</b> ${locked ? `<span class="etiqueta">🔒 Lv.${need}</span>` : level === null ? `<span class="etiqueta">Lv.${need}</span>` : ''}<div class="desc">${sk.Desc}</div></div></div>`;
		});
		return html;
	}

	function showDetail(d) {
		detail.innerHTML = '';
		if (!d) {
			detail.innerHTML = '<p>No dogs yet!</p>';
			return;
		}
		const s = SPECIES[d.sp];
		const r = RARITY[s.Rarity];
		const st = stats(d.sp, d.lv);
		const box = h('div', 'detalhe-cao');
		const img = h('img');
		img.src = portrait(d.sp, 'corpo', 256);
		const col = h('div', 'col');
		const stars = starsFor(d.lv);
		col.innerHTML = `<h3 style="color:${r.Color}">${d.name || s.Name}</h3>
			<div class="etiquetas"><span class="etiqueta" style="color:${r.Color}">${r.Label}</span><span class="etiqueta">Lv.${d.lv} ${'★'.repeat(stars)}</span>${elementsHtml(d.sp)}<span class="etiqueta">${s.Role || ''}</span></div>
			<div class="etiquetas"><span class="etiqueta">❤️ HP ${formatNumber(st.MaxHP)}</span><span class="etiqueta">⚔️ ATK ${formatNumber(st.Atk)}</span><span class="etiqueta">💨 SPD ${st.Speed}</span><span class="etiqueta">💪 POWER ${formatNumber(st.Power)}</span></div>
			<div class="barra xp" style="height:14px"><div class="enche" style="width:${d.lv >= CONFIG.MAX_LEVEL ? 100 : Math.min(100, (d.xp / xpToNext(d.lv)) * 100)}%"></div><div class="txt">${d.lv >= CONFIG.MAX_LEVEL ? 'MAX LEVEL' : `XP ${formatNumber(d.xp)} / ${formatNumber(xpToNext(d.lv))}`}</div></div>
			<div class="lista-poderes">${skillsHtml(d.sp, d.lv)}</div>`;
		const row = h('div', 'opcoes');
		row.style.display = 'flex';
		row.style.gap = '8px';
		row.style.flexWrap = 'wrap';
		const equipped = d.id === app.save.equipped;
		const eq = button(equipped ? 'EQUIPPED' : 'EQUIP', equipped ? 'cinza' : '', () => {
			app.equipDog(d.id);
			render('meus');
		});
		if (equipped) eq.disabled = true;
		row.appendChild(eq);
		row.appendChild(
			button('✏️ RENAME', 'azul', () => {
				const name = prompt('New name for your dog:', d.name || s.Name);
				if (name !== null) {
					d.name = name.trim().slice(0, CONFIG.NAME_MAX) || null;
					app.saveNow();
					app.refreshDog();
					render('meus');
				}
			}),
		);
		const value = r.Release || 5;
		const rel = button(`RELEASE +${formatCash(value)}`, 'vermelho', () => {
			confirmBox('RELEASE DOG?', `Release <b>${d.name || s.Name}</b> (Lv.${d.lv}) for <b>${formatCash(value)}</b>? This can't be undone.`, 'RELEASE', () => {
				app.releaseDog(d.id, value);
				openDogsMenu(app, 'meus');
			});
		});
		if (equipped || app.save.dogs.length <= 1 || s.Rarity === 'Divine') rel.disabled = true;
		row.appendChild(rel);
		col.appendChild(row);
		box.append(img, col);
		detail.appendChild(box);
	}

	function showSpecies(sp) {
		const s = SPECIES[sp];
		const r = RARITY[s.Rarity];
		const has = !!app.save.seen[sp];
		detail.innerHTML = '';
		const box = h('div', 'detalhe-cao');
		const img = h('img');
		img.src = portrait(sp, 'corpo', 256);
		if (!has) img.style.filter = 'brightness(0) opacity(0.5)';
		const col = h('div', 'col');
		const st = stats(sp, 1);
		col.innerHTML = `<h3 style="color:${r.Color}">${has ? s.Name : '???'}</h3>
			<div class="etiquetas"><span class="etiqueta" style="color:${r.Color}">${r.Label}</span>${elementsHtml(sp)}<span class="etiqueta">${s.Role || ''}</span></div>
			<div class="etiquetas"><span class="etiqueta">❤️ HP ${formatNumber(st.MaxHP)} (Lv.1)</span><span class="etiqueta">⚔️ ATK ${formatNumber(st.Atk)}</span><span class="etiqueta">💨 SPD ${st.Speed}</span></div>
			<div class="lista-poderes">${has ? skillsHtml(sp, null) : '<div class="poder">Find this dog to see its powers!</div>'}</div>`;
		box.append(img, col);
		detail.appendChild(box);
		detail.scrollIntoView({ behavior: 'smooth', block: 'start' });
	}

	render(tab);
	return w;
}
