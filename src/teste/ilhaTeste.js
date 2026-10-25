// Tela de teste de uma ilha: ?teste=ilha&id=common&cam=x,y,z&alvo=x,y,z
import * as THREE from 'three';
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls.js';
import { R, render, followSun } from '../core/render.js';
import { World } from '../world/mundo.js';

export async function startIslandTest(params) {
	const world = new World();
	const id = params.get('id') || 'common';
	const t0 = performance.now();
	const data = await world.load(id);
	const tLoad = performance.now() - t0;
	const g = data.grid;
	const cx = g.x0 + (g.w * g.cell) / 2, cz = g.z0 + (g.d * g.cell) / 2;
	const alvo = (params.get('alvo') || `${cx},0,${cz}`).split(',').map(Number);
	const cam = (params.get('cam') || `${cx},${Math.max(g.w, g.d) * 2.2},${cz + Math.max(g.w, g.d) * 2.6}`).split(',').map(Number);
	R.camera.position.set(cam[0], cam[1], cam[2]);
	R.camera.far = 6000;
	R.camera.updateProjectionMatrix();
	R.scene.fog.near = Number(params.get('fogNear') || 4000);
	R.scene.fog.far = Number(params.get('fogFar') || 6000);
	const controls = new OrbitControls(R.camera, R.renderer.domElement);
	controls.target.set(alvo[0], alvo[1], alvo[2]);
	controls.update();
	const t1 = performance.now();
	world.view.update(alvo[0], alvo[2], 1e9, true);
	if (params.get('tudo')) {
		world.view.quality = 'high';
		for (const ch of world.view.chunks) {
			if (!ch.group) {
				world.view.update(ch.cx, ch.cz, 1e9, true);
			}
		}
	}
	const tBuild = performance.now() - t1;
	followSun(alvo[0], 0, alvo[2]);
	R.sun.shadow.camera.left = -200;
	R.sun.shadow.camera.right = 200;
	R.sun.shadow.camera.top = 200;
	R.sun.shadow.camera.bottom = -200;
	R.sun.shadow.camera.far = 600;
	R.sun.shadow.camera.updateProjectionMatrix();
	let tris = 0, meshes = 0;
	R.scene.traverse((o) => {
		if (o.isMesh && o.geometry.index) {
			tris += o.geometry.index.count / 3;
			meshes++;
		}
	});
	window.__info = () => ({ id, tLoad: Math.round(tLoad), tBuild: Math.round(tBuild), tris, meshes, parts: data.parts.count, models: data.info.models.filter((m) => m[1] === 0).map((m) => m[0] + '@' + m[2].map(Math.round).join(',')) });
	const start = performance.now();
	function frame() {
		const t = (performance.now() - start) / 1000;
		world.update(0.016, t, controls.target.x, controls.target.z, R.camera.position.x, R.camera.position.z);
		controls.update();
		render();
		requestAnimationFrame(frame);
	}
	requestAnimationFrame(frame);
	void THREE;
}
