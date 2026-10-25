// Foto da prévia do HUD: node render_hud.js <modo pc|phone> <saida.png>
const http = require('http');
const fs = require('fs');
const path = require('path');
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
// (o Chromium do ambiente muda de versão: usa o primeiro que existir; nenhum = o padrão do Playwright)
const CHROME = ['/opt/pw-browsers/chromium-1194/chrome-linux/chrome', '/opt/pw-browsers/chromium-1243/chrome-linux64/chrome'].find((p) => require('fs').existsSync(p));
const [, , mode, output] = process.argv;
const dir = __dirname;
const types = { '.js': 'text/javascript', '.html': 'text/html', '.json': 'application/json', '.png': 'image/png', '.woff2': 'font/woff2', '.css': 'text/css' };
const server = http.createServer((req, res) => {
  const file = path.join(dir, decodeURIComponent(req.url.split('?')[0]));
  if (!file.startsWith(dir) || !fs.existsSync(file)) { res.writeHead(404); return res.end(); }
  res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream' });
  fs.createReadStream(file).pipe(res);
});
server.listen(0, '127.0.0.1', async () => {
  const port = server.address().port;
  const browser = await chromium.launch({ executablePath: CHROME, args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  try {
    const phone = mode === 'phone';
    const page = await browser.newPage({ viewport: phone ? { width: 844, height: 390 } : { width: 1920, height: 1080 }, deviceScaleFactor: phone ? 2 : 1 });
    page.on('pageerror', (e) => console.log('[page error]', e.message));
    page.on('console', (m) => { if (m.type() === 'error' || m.type() === 'warning') console.log('[page]', m.text()); });
    await page.goto(`http://127.0.0.1:${port}/hud_mock.html?mode=${mode}&theme=${process.argv[4] || 'escuro'}`);
    await page.waitForFunction(() => window.ready === true, null, { timeout: 60000 });
    await page.waitForTimeout(300);
    await page.screenshot({ path: output });
    console.log('ok:', output);
  } finally { await browser.close(); server.close(); }
});
