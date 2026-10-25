// Foto de uma imagem da página do jogo: node tools/preview/thumbs_render.js pasta_dados spec.json saida.png
// (pasta_dados = onde estão os JSON das ilhas e dos cachorros; a página busca em /data/<arquivo>)
const http = require('http');
const fs = require('fs');
const path = require('path');
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
// (o Chromium do ambiente muda de versão: usa o primeiro que existir; nenhum = o padrão do Playwright)
const CHROME = ['/opt/pw-browsers/chromium-1194/chrome-linux/chrome', '/opt/pw-browsers/chromium-1243/chrome-linux64/chrome'].find((p) => require('fs').existsSync(p));

const [, , dataDir, specFile, output] = process.argv;
const spec = JSON.parse(fs.readFileSync(specFile, 'utf8'));
const tools = path.resolve(__dirname, '..');
const TYPES = { '.js': 'text/javascript', '.html': 'text/html', '.json': 'application/json', '.woff2': 'font/woff2', '.png': 'image/png' };
const server = http.createServer((req, res) => {
  const url = decodeURIComponent(req.url.split('?')[0]);
  let file;
  if (url.startsWith('/data/')) file = path.join(path.resolve(dataDir), url.slice(6));
  else file = path.join(tools, url);
  const okRoot = file.startsWith(tools) || file.startsWith(path.resolve(dataDir));
  if (!okRoot || !fs.existsSync(file)) { res.writeHead(404); return res.end(); }
  res.writeHead(200, { 'Content-Type': TYPES[path.extname(file)] || 'application/octet-stream' });
  fs.createReadStream(file).pipe(res);
});
server.listen(0, '127.0.0.1', async () => {
  const port = server.address().port;
  const browser = await chromium.launch({ executablePath: CHROME, args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  try {
    const page = await browser.newPage({ viewport: { width: spec.w || 1920, height: spec.h || 1080 } });
    page.on('pageerror', (e) => console.log('[page error]', e.message));
    page.on('console', (m) => { if (m.type() === 'error' || m.type() === 'log') console.log('[page]', m.text()); });
    await page.goto(`http://127.0.0.1:${port}/preview/thumbs_render.html`);
    await page.waitForFunction(() => window.ready === true, null, { timeout: 30000 });
    await page.evaluate((s) => window.renderThumb(s), spec);
    if (spec.probe) {
      // (ajuda para montar a cena: altura do chão e posição na tela de alguns pontos)
      const info = await page.evaluate((pts) => pts.map((p) => ({ p, ground: window.groundAt(p[0], p[2]), screen: window.project(p) })), spec.probe);
      console.log('PROBE', JSON.stringify(info));
    }
    const el = await page.$('#out');
    await el.screenshot({ path: output });
    console.log('ok:', output);
  } finally { await browser.close(); server.close(); }
});
