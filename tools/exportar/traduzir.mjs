// Traduz o código Lua das habilidades e dos efeitos do projeto Roblox para JavaScript (src/gerado/).
// Uso: DF_ROBLOX=<pasta do DogFighterSimulator> node tools/exportar/traduzir.mjs
// (sem DF_ROBLOX: usa ../DogFighterSimulator ao lado deste repositório)
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { translate } from '../lua2js/gerador.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const repo = path.resolve(here, '..', '..');
const roblox = process.env.DF_ROBLOX || path.resolve(repo, '..', 'DogFighterSimulator');
const src = path.join(roblox, 'src');
if (!fs.existsSync(src)) {
	console.error(`Não achei o projeto Roblox em ${roblox} (defina DF_ROBLOX).`);
	process.exit(1);
}

// métodos do kit (k:...) que esperam: viram yield* no JS
const KIT_WAITS = ['wait', 'waitOk', 'approach', 'reach', 'lunge', 'dash', 'blink', 'leap', 'glide', 'rise', 'land', 'circle', 'beam', 'breath'];

const JOBS = [
	{ from: 'client/Effects.lua', to: 'efeitos/Effects.js' },
	{ from: 'client/SkillArt.lua', to: 'efeitos/SkillArt.js' },
	{ from: 'client/EffectsPacks/PackB.lua', to: 'efeitos/PackB.js' },
	{ from: 'client/EffectsPacks/PackC.lua', to: 'efeitos/PackC.js' },
	{ from: 'client/EffectsPacks/PackSkills.lua', to: 'efeitos/PackSkills.js' },
];
for (const name of ['Common', 'Uncommon', 'Rare', 'Epic', 'Legendary', 'Mythic', 'Halloween', 'Divine', 'Signature']) {
	JOBS.push({ from: `server/Services/SpecialsPacks/Skills_${name}.lua`, to: `habilidades/Skills_${name}.js`, kit: true });
}

const outDir = path.join(repo, 'src', 'gerado');
let total = 0;
const report = [];
for (const job of JOBS) {
	const file = path.join(src, job.from);
	const lua = fs.readFileSync(file, 'utf8');
	const t0 = Date.now();
	const res = translate(lua, { file: job.from, yieldMethods: job.kit ? KIT_WAITS : [], runtime: '../../rbx/lua.js' });
	const dest = path.join(outDir, job.to);
	fs.mkdirSync(path.dirname(dest), { recursive: true });
	fs.writeFileSync(dest, res.js);
	total += res.js.length;
	report.push(`${job.from} → src/gerado/${job.to} (${(res.js.length / 1024).toFixed(0)} KB, ${Date.now() - t0} ms) globais: ${res.freeNames.join(' ')}`);
}
console.log(report.join('\n'));
console.log(`total ${(total / 1024).toFixed(0)} KB`);
