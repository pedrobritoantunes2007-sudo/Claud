// Teste rápido do jogo: ?teste=jogo&ilha=common&cao=caramelo&nivel=5
import { initInput } from '../core/input.js';
import { R } from '../core/render.js';
import { Game } from '../game/jogo.js';

export async function startGameTest(params) {
	initInput(R.renderer.domElement);
	const game = new Game(document.getElementById('ui'));
	window.__jogo = game;
	game.quality = params.get('qualidade') || 'high';
	game.setPlayerDog(params.get('cao') || 'caramelo', Number(params.get('nivel') || 5));
	await game.enterIsland(params.get('ilha') || 'common');
	game.on('portal', (p) => game.enterIsland(p.to, {}));
	let last = performance.now();
	window.__info = () => {
		const p = game.player;
		let tris = 0;
		R.scene.traverse((o) => {
			if (o.isMesh && o.visible && o.geometry.index) tris += o.geometry.index.count / 3;
		});
		return { ilha: game.islandId, x: Math.round(p.x), y: Math.round(p.y * 10) / 10, z: Math.round(p.z), hp: Math.round(p.hp), lv: p.level, wild: game.wild.length, calls: R.renderer.info.render.calls, tris: Math.round(tris), fps: window.__fps };
	};
	let frames = 0, acc = 0, sim = 0;
	// passo fixo: no navegador de teste (sem placa de vídeo) o desenho é lento, mas a simulação anda no tempo certo
	const fixed = params.get('passo') === 'fixo';
	function loop() {
		const now = performance.now();
		const dt = (now - last) / 1000;
		last = now;
		acc += dt;
		frames++;
		if (acc > 1) {
			window.__fps = Math.round(frames / acc);
			frames = 0;
			acc = 0;
		}
		if (fixed) {
			sim += Math.min(dt, 1);
			let n = 0;
			while (sim > 1 / 30 && n < 40) {
				game.update(1 / 30);
				sim -= 1 / 30;
				n++;
			}
			game.render();
		} else game.frame(dt);
		requestAnimationFrame(loop);
	}
	requestAnimationFrame(loop);
}
