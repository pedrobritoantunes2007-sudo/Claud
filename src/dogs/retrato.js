// Fotos dos cachorros para as telas (cartão do HUD, menu DOGS, ovos): renderizadas uma vez e guardadas.
import * as THREE from 'three';
import { createDogModel, setRigPose, disposeDogModel } from './rig.js';
import { HEAD, A } from './cf.js';

let renderer = null, scene = null, camera = null;
const cache = new Map();

function init() {
	if (renderer) return;
	renderer = new THREE.WebGLRenderer({ alpha: true, antialias: true, preserveDrawingBuffer: true });
	renderer.setPixelRatio(1);
	renderer.setSize(256, 256, false);
	renderer.outputColorSpace = THREE.SRGBColorSpace;
	renderer.setClearColor(0x000000, 0);
	scene = new THREE.Scene();
	scene.add(new THREE.HemisphereLight('#ffffff', '#8a7a9a', 2.2));
	const sun = new THREE.DirectionalLight('#fff6e8', 2.4);
	sun.position.set(-3, 5, -6);
	scene.add(sun);
	camera = new THREE.PerspectiveCamera(30, 1, 0.1, 200);
}

// foto sem travar a tela: põe na fila e preenche o <img> aos poucos (várias fotos num menu)
const queue = [];
let pumping = false;
export function lazyPortrait(img, speciesId, mode = 'corpo', size = 192) {
	const key = speciesId + '|' + mode + '|' + size;
	if (cache.has(key)) {
		img.src = cache.get(key);
		return;
	}
	queue.push({ img, speciesId, mode, size });
	if (!pumping) {
		pumping = true;
		requestAnimationFrame(pump);
	}
}

function pump() {
	const t0 = performance.now();
	while (queue.length && performance.now() - t0 < 12) {
		const job = queue.shift();
		if (!job.img.isConnected) continue;
		job.img.src = portrait(job.speciesId, job.mode, job.size);
	}
	if (queue.length) requestAnimationFrame(pump);
	else pumping = false;
}

// mode: 'rosto' (cabeça de perto) ou 'corpo' (cachorro inteiro, 3/4 de frente)
export function portrait(speciesId, mode = 'rosto', size = 256) {
	const key = speciesId + '|' + mode + '|' + size;
	if (cache.has(key)) return cache.get(key);
	init();
	renderer.setSize(size, size, false);
	const rig = createDogModel(speciesId, 1);
	const neck = rig.asset.byName.Neck1;
	if (neck !== undefined) rig.poses[neck] = HEAD(0.08, mode === 'rosto' ? 0.3 : 0.15, 0.12);
	const jaw = rig.asset.byName.Jaw1;
	if (jaw !== undefined) rig.poses[jaw] = A(-0.25);
	setRigPose(rig);
	scene.add(rig.mesh);
	rig.mesh.updateMatrixWorld(true);
	const box = new THREE.Box3();
	const v = new THREE.Vector3();
	// caixa pelos ossos (posições das juntas) + raio da geometria
	const bb = rig.asset.geometry.boundingBox;
	box.copy(bb);
	let target, dist;
	if (mode === 'rosto' && neck !== undefined) {
		const head = rig.bones[neck];
		head.updateWorldMatrix(true, false);
		target = v.setFromMatrixPosition(head.matrixWorld).clone();
		target.y += 0.15 * rig.asset.data.scale;
		dist = 3.4 * Math.max(0.9, rig.asset.data.scale) + 1.5;
		camera.position.set(target.x - dist * 0.45, target.y + dist * 0.12, target.z - dist * 0.9);
		target.z -= 0.25 * rig.asset.data.scale;
	} else {
		target = new THREE.Vector3();
		box.getCenter(target);
		const sz = new THREE.Vector3();
		box.getSize(sz);
		dist = Math.max(sz.x, sz.y, sz.z) * 1.75 + 1;
		camera.position.set(target.x - dist * 0.62, target.y + dist * 0.28, target.z - dist * 0.75);
	}
	camera.lookAt(target);
	renderer.render(scene, camera);
	const url = renderer.domElement.toDataURL('image/png');
	scene.remove(rig.mesh);
	disposeDogModel(rig);
	cache.set(key, url);
	return url;
}
