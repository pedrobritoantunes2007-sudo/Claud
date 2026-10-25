// Foto do HUD de verdade: node hud_render.js <arvore.json do hud_dump.py> <foto.png>
const http = require('http');
const fs = require('fs');
const path = require('path');
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const [, , dumpPath, output] = process.argv;
const dir = __dirname;
const dump = JSON.parse(fs.readFileSync(dumpPath, 'utf8'));
const types = { '.js': 'text/javascript', '.html': 'text/html', '.json': 'application/json', '.png': 'image/png', '.woff2': 'font/woff2' };
// (fotos de cima do mapa: /maptiles/<chave>.png vem de Imagens/Mapa do projeto)
const mapDir = path.join(dir, '..', '..', 'Imagens', 'Mapa');
const server = http.createServer((req, res) => {
  const url = decodeURIComponent(req.url.split('?')[0]);
  const file = url.startsWith('/maptiles/') ? path.join(mapDir, path.basename(url)) : path.join(dir, url);
  if (!(file.startsWith(dir) || file.startsWith(mapDir)) || !fs.existsSync(file) || !fs.statSync(file).isFile()) { res.writeHead(404); return res.end(); }
  res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream' });
  fs.createReadStream(file).pipe(res);
});
server.listen(0, '127.0.0.1', async () => {
  const port = server.address().port;
  const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  try {
    const phone = dump.screen.Touch;
    const page = await browser.newPage({ viewport: { width: dump.screen.W, height: dump.screen.H }, deviceScaleFactor: phone ? 2 : 1 });
    page.on('pageerror', (e) => console.log('[page error]', e.message));
    page.on('console', (m) => { if (m.type() === 'error' || m.type() === 'warning') console.log('[page]', m.text()); });
    await page.addInitScript((d) => { window.DUMP = d; }, dump);
    await page.goto(`http://127.0.0.1:${port}/hud_render.html`);
    await page.waitForFunction(() => window.ready === true, null, { timeout: 120000 });
    await page.screenshot({ path: output });
    console.log('ok:', output);
  } finally { await browser.close(); server.close(); }
});
