// Progresso salvo no navegador (localStorage). Campo novo = valor padrão aqui (saves antigos continuam valendo).
import { CONFIG } from '../data/jogo.js';

const KEY = 'dogfighter_save_v1';

export function defaultSave() {
	return {
		v: 1,
		cash: 0,
		dogs: [], // { id, sp, lv, xp, name, fav, got }
		equipped: null,
		nextId: 1,
		islands: { common: true },
		quest: null, // { island, kind: 'wild' | 'boss', need, have }
		questsDone: 0,
		eggs: {}, // ovos guardados (prêmios) { paw: 1 }
		spins: CONFIG.STARTER_ROLL.Chances, // giros grátis do 1º cachorro
		tutorial: 0,
		guide: {},
		seen: {}, // índice: espécies que já teve
		settings: { music: 0.5, sfx: 0.8, quality: 'auto', shake: true, names: true },
		stats: { kills: 0, hatched: 0, playTime: 0, bosses: 0 },
		lastIsland: 'village',
		created: Date.now(),
	};
}

export function loadSave() {
	let data = null;
	try {
		const raw = localStorage.getItem(KEY);
		if (raw) data = JSON.parse(raw);
	} catch (e) {
		data = null;
	}
	return sanitize(data);
}

export function sanitize(data) {
	const base = defaultSave();
	if (!data || typeof data !== 'object') return base;
	for (const k of Object.keys(base)) {
		if (data[k] === undefined || data[k] === null) {
			if (k !== 'quest' && k !== 'equipped') data[k] = base[k];
		}
	}
	data.settings = Object.assign(base.settings, data.settings || {});
	data.stats = Object.assign(base.stats, data.stats || {});
	data.islands = Object.assign({ common: true }, data.islands || {});
	if (!Array.isArray(data.dogs)) data.dogs = [];
	data.dogs = data.dogs.filter((d) => d && typeof d.sp === 'string');
	for (const d of data.dogs) {
		d.lv = Math.max(1, Math.min(CONFIG.MAX_LEVEL, Math.floor(d.lv || 1)));
		d.xp = Math.max(0, d.xp || 0);
		if (!d.id) d.id = data.nextId++;
	}
	if (data.equipped && !data.dogs.find((d) => d.id === data.equipped)) data.equipped = data.dogs[0] ? data.dogs[0].id : null;
	data.cash = Math.max(0, Math.floor(data.cash || 0));
	return data;
}

let saveTimer = null;
export function writeSave(data, now = false) {
	const go = () => {
		saveTimer = null;
		try {
			localStorage.setItem(KEY, JSON.stringify(data));
		} catch (e) {
			// sem espaço / navegação privada: segue sem salvar
		}
	};
	if (now) {
		if (saveTimer) clearTimeout(saveTimer);
		go();
		return;
	}
	if (!saveTimer) saveTimer = setTimeout(go, 800);
}

export function resetSave() {
	try {
		localStorage.removeItem(KEY);
	} catch (e) {
		// nada
	}
}

export function addDog(data, sp, lv = 1) {
	const dog = { id: data.nextId++, sp, lv, xp: 0, name: null, fav: false, got: Date.now() };
	data.dogs.push(dog);
	data.seen[sp] = true;
	if (!data.equipped) data.equipped = dog.id;
	return dog;
}

export function equippedDog(data) {
	return data.dogs.find((d) => d.id === data.equipped) || data.dogs[0] || null;
}
