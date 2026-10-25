// Tira fotos do jogo num navegador de verdade (Chromium do Playwright), para conferir sem abrir na mão.
//   node tools/teste/foto.mjs "<parâmetros da URL>" saida.png [espera_ms] [largura]x[altura] [script.js]
// Ex.: node tools/teste/foto.mjs "teste=galeria&caes=caramelo,pug" /tmp/g.png 3000
// O script opcional roda na página depois de carregar (pode usar window.__jogo etc.) e pode devolver uma lista de
// passos [{ espera, foto, js }] para fotos em sequência.
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
let playwright;
try {
	playwright = require('playwright');
} catch {
	playwright = require('/opt/node22/lib/node_modules/playwright');
}

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..', 'jogo');
const [query = '', out = 'foto.png', waitArg = '2500', sizeArg = '1280x720', scriptPath] = process.argv.slice(2);
const [W, H] = sizeArg.split('x').map(Number);

const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.mp3': 'audio/mpeg', '.png': 'image/png', '.json': 'application/json' };
const server = http.createServer((req, res) => {
	const url = decodeURIComponent(req.url.split('?')[0]);
	const file = path.join(ROOT, url === '/' ? 'index.html' : url);
	if (!file.startsWith(ROOT) || !fs.existsSync(file)) {
		res.writeHead(404);
		res.end();
		return;
	}
	res.writeHead(200, { 'Content-Type': TYPES[path.extname(file)] || 'application/octet-stream' });
	fs.createReadStream(file).pipe(res);
});
await new Promise((r) => server.listen(0, r));
const port = server.address().port;

const browser = await playwright.chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--autoplay-policy=no-user-gesture-required'] });
const page = await browser.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: 1 });
const logs = [];
page.on('console', (m) => logs.push(`[${m.type()}] ${m.text()}`));
page.on('pageerror', (e) => logs.push(`[pageerror] ${e.message}\n${e.stack || ''}`));
const t0 = Date.now();
await page.goto(`http://localhost:${port}/?${query}`);
await page.waitForTimeout(Number(waitArg));
let steps = null;
if (scriptPath) {
	const code = fs.readFileSync(scriptPath, 'utf8');
	steps = await page.evaluate(code);
}
if (Array.isArray(steps)) {
	for (const st of steps) {
		if (st.js) await page.evaluate(st.js);
		if (st.teclas) {
			for (const k of st.teclas) {
				if (k.down) await page.keyboard.down(k.down);
				if (k.up) await page.keyboard.up(k.up);
				if (k.press) await page.keyboard.press(k.press);
				if (k.click) await page.mouse.click(k.click[0], k.click[1]);
				if (k.move) await page.mouse.move(k.move[0], k.move[1]);
				if (k.espera) await page.waitForTimeout(k.espera);
			}
		}
		if (st.espera) await page.waitForTimeout(st.espera);
		if (st.foto) await page.screenshot({ path: st.foto });
	}
} else {
	await page.screenshot({ path: out });
}
const info = await page.evaluate(() => (window.__info ? window.__info() : null)).catch(() => null);
console.log(`ok em ${((Date.now() - t0) / 1000).toFixed(1)} s`);
if (info) console.log('info:', JSON.stringify(info));
const shown = logs.filter((l) => !l.includes('GPU stall') && !l.includes('Automatic fallback to software WebGL'));
if (shown.length) console.log(shown.slice(0, 40).join('\n'));
await browser.close();
server.close();
