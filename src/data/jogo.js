// Regras e números do jogo — os mesmos do Config.lua / DogData.lua do projeto Roblox (exportados em dados.json).
import DADOS from './dados.json';

export const CONFIG = DADOS.Config;
export const SPECIES = DADOS.Species;
export const ORDER = DADOS.Order;
export const EGGS = DADOS.Eggs;
export const SKILLS = DADOS.Skills;
export const SHOT_STYLES = DADOS.ShotStyles;
export const ELEMENTS = DADOS.DogElements;
export const ELEMENT_STRONG = DADOS.ElementStrong;
export const ISLANDS = DADOS.Islands;
export const SFX_REGIONS = DADOS.Sfx.Regions;
export const RARITIES = CONFIG.RARITIES;
export const RARITY = CONFIG.RARITY;

export function rarityOf(speciesId) {
	return RARITY[SPECIES[speciesId].Rarity];
}

export function rarityColor(rarity) {
	return (RARITY[rarity] && RARITY[rarity].Color) || '#ffffff';
}

export function xpToNext(level) {
	return DADOS.XPToNext[Math.max(1, Math.min(level, DADOS.XPToNext.length)) - 1] || 1e12;
}

export function starsFor(level) {
	let n = 0;
	for (const at of CONFIG.STAR_LEVELS) if (level >= at) n++;
	return n;
}

export function stats(speciesId, level, mult) {
	const sp = SPECIES[speciesId];
	const r = RARITY[sp.Rarity];
	const growth = (1 + CONFIG.LEVEL_GROWTH * (level - 1)) * (1 + CONFIG.STAR_BONUS * starsFor(level));
	let hp = Math.floor(CONFIG.BASE_HP * r.Stat * sp.Stats.HP * growth);
	let atk = Math.floor(CONFIG.BASE_ATK * r.Stat * sp.Stats.Atk * growth);
	if (mult) {
		hp = Math.floor(hp * (mult.HP || 1));
		atk = Math.floor(atk * (mult.Atk || 1));
	}
	return { MaxHP: hp, Atk: atk, Speed: sp.Stats.Speed, Power: Math.floor(hp / 10 + atk * 3) };
}

export function killLevelMult(victimLevel, killerLevel) {
	let d = (victimLevel || 1) - (killerLevel || 1);
	if (d >= 0) return Math.min(CONFIG.KILL_LEVEL_BONUS_MAX, 1 + CONFIG.KILL_LEVEL_BONUS * d);
	d = Math.min(0, d + CONFIG.KILL_LEVEL_FREE);
	return Math.max(CONFIG.KILL_LEVEL_MIN, 1 + CONFIG.KILL_LEVEL_PENALTY * d);
}

// prêmio por derrotar um cachorro: [cash, xp]
export function killReward(victimLevel, victimPower, killerLevel) {
	victimLevel = Math.max(1, victimLevel || 1);
	victimPower = Math.max(1, victimPower || 1);
	const mult = killLevelMult(victimLevel, killerLevel);
	const cash = (CONFIG.KILL_CASH_BASE + CONFIG.KILL_CASH_PER_POWER * victimPower ** CONFIG.KILL_CASH_EXP) * mult;
	const commonPower = (CONFIG.BASE_HP / 10 + CONFIG.BASE_ATK * 3) * (1 + CONFIG.LEVEL_GROWTH * (victimLevel - 1));
	const rar = Math.min(3, Math.max(0.6, (victimPower / commonPower) ** CONFIG.KILL_XP_RARITY_EXP));
	const xp = (CONFIG.KILL_XP_BASE + CONFIG.KILL_XP_FRACTION * xpToNext(victimLevel) * rar) * mult;
	return [Math.max(1, Math.floor(cash)), Math.max(1, Math.floor(xp))];
}

export function elementsOf(speciesId) {
	return (SPECIES[speciesId] && SPECIES[speciesId].Elements) || [];
}

// vantagem de elemento (estilo Pokémon): +1 por par forte, -1 por par fraco
export function elementAdvantage(attackerId, targetId) {
	const a = elementsOf(attackerId), d = elementsOf(targetId);
	let score = 0;
	for (const ea of a) {
		for (const ed of d) {
			if ((ELEMENT_STRONG[ea] || []).includes(ed)) score += 1;
			if ((ELEMENT_STRONG[ed] || []).includes(ea)) score -= 1;
		}
	}
	return score;
}

export function elementMultiplier(attackerId, targetId) {
	const s = elementAdvantage(attackerId, targetId);
	if (s > 0) return CONFIG.ELEMENT_STRONG;
	if (s < 0) return CONFIG.ELEMENT_WEAK;
	return 1;
}

export function hasSupreme(rarity) {
	const r = RARITY[rarity];
	return !!r && r.Order >= RARITY.Epic.Order;
}

export function skillTier(rarity) {
	return CONFIG.SKILL_TIER[rarity] || CONFIG.SKILL_TIER.Rare;
}

export function powerUnlockLevel(index) {
	return CONFIG.POWER_UNLOCK[index] || 1;
}

export function speciesOfRarity(rarity) {
	return ORDER.filter((id) => SPECIES[id] && SPECIES[id].Rarity === rarity && !SPECIES[id].BossOnly);
}

export function speciesWithElement(rarity, element) {
	return speciesOfRarity(rarity).filter((id) => elementsOf(id).includes(element));
}

// chances de um ovo (o nível do cachorro melhora um pouco as raridades altas)
export function eggOdds(eggId, dogLevel = 1) {
	const egg = EGGS[eggId];
	const odds = { ...egg.Odds };
	const order = ['Common', 'Uncommon', 'Rare', 'Epic', 'Legendary', 'Mythic', 'Halloween'];
	const present = order.filter((r) => odds[r] !== undefined);
	if (present.length >= 2) {
		let bonus = Math.min(5, Math.floor((dogLevel || 1) / 10));
		const lowest = present[0], top = present[present.length - 1], second = present[present.length - 2];
		bonus = Math.max(0, Math.min(bonus, odds[lowest] - 1));
		odds[lowest] -= bonus;
		odds[top] += bonus * 0.4;
		odds[second] += bonus * 0.6;
	}
	let total = 0;
	for (const r of present) total += odds[r];
	return present.map((r) => ({ Rarity: r, Chance: (odds[r] / total) * 100 }));
}

export function rollRarity(list, rnd = Math.random) {
	let roll = rnd() * 100;
	for (const e of list) {
		roll -= e.Chance !== undefined ? e.Chance : e[1];
		if (roll <= 0) return e.Rarity || e[0];
	}
	const last = list[list.length - 1];
	return last.Rarity || last[0];
}

// sorteia o cachorro de um ovo: [espécie, raridade]
export function rollEgg(eggId, dogLevel = 1, rnd = Math.random) {
	const egg = EGGS[eggId];
	for (let i = 0; i < 8; i++) {
		const rarity = rollRarity(eggOdds(eggId, dogLevel), rnd);
		const list = egg.Pool ? speciesWithElement(rarity, egg.Pool) : speciesOfRarity(rarity);
		if (list.length) return [list[Math.floor(rnd() * list.length)], rarity];
	}
	const list = speciesOfRarity('Common');
	return [list[Math.floor(rnd() * list.length)], 'Common'];
}

// roleta do Prof. Barkley: chances por raridade (Config.ROULETTE)
export function rollRoulette(kind = 'Normal', rnd = Math.random) {
	const odds = CONFIG.ROULETTE[kind].map(([r, c]) => ({ Rarity: r, Chance: c }));
	for (let i = 0; i < 8; i++) {
		const rarity = rollRarity(odds, rnd);
		const list = speciesOfRarity(rarity);
		if (list.length) return [list[Math.floor(rnd() * list.length)], rarity];
	}
	return ['caramelo', 'Common'];
}

// habilidades de um cachorro: [tecla 2, tecla 3, tecla 4?] (catálogo Skills.lua)
export function skillsOf(speciesId) {
	return SKILLS[speciesId] || [];
}

export function shotOf(speciesId) {
	const name = SPECIES[speciesId] && SPECIES[speciesId].Shot;
	return name && SHOT_STYLES[name] ? { name, style: SHOT_STYLES[name] } : null;
}

export function gameScale(speciesId) {
	return (SPECIES[speciesId] && SPECIES[speciesId].GameScale) || 1;
}

export function canFly(speciesId) {
	return elementsOf(speciesId).includes('Fly');
}
