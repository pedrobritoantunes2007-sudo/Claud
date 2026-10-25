// Galeria de teste: todos (ou alguns) cachorros lado a lado, animados. Abrir o jogo com ?teste=galeria
// Parâmetros: caes=caramelo,pug (lista) · anim=andar|correr|galope|voar|<Ação> · colunas=6 · zoom=1
import * as THREE from 'three';
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls.js';
import { R, render } from '../core/render.js';
import { createDogModel, setRigPose, SPECIES_MODELS } from '../dogs/rig.js';
import { DogAnimator } from '../dogs/animator.js';
import DADOS from '../data/dados.json';

export function startGallery(params) {
	const scene = R.scene;
	const ids = (params.get('caes') || '').split(',').filter(Boolean);
	const list = ids.length ? ids : DADOS.Order.filter((id) => SPECIES_MODELS[id]);
	const cols = Number(params.get('colunas')) || Math.ceil(Math.sqrt(list.length * 1.6));
	const anim = params.get('anim') || '';
	const spacing = 9;
	const ground = new THREE.Mesh(new THREE.BoxGeometry(cols * spacing + 10, 1, Math.ceil(list.length / cols) * spacing + 10), new THREE.MeshLambertMaterial({ color: '#7ccf5e' }));
	ground.position.y = -0.5;
	ground.receiveShadow = true;
	scene.add(ground);
	const dogs = [];
	list.forEach((id, n) => {
		const sp = DADOS.Species[id];
		const scale = (sp && sp.GameScale) || 1;
		const rig = createDogModel(id, scale);
		const animator = new DogAnimator(rig, { showcase: true, baseSpeed: sp ? sp.Stats.Speed : 16 });
		const col = n % cols, row = Math.floor(n / cols);
		const x = (col - (cols - 1) / 2) * spacing;
		const z = (row - (Math.ceil(list.length / cols) - 1) / 2) * spacing;
		const y = rig.asset.groundOffset * scale;
		rig.mesh.position.set(x, y, z);
		rig.mesh.rotation.y = Number(params.get("giro") ?? 2.5);
		scene.add(rig.mesh);
		const label = makeLabel(sp ? sp.Name : id);
		label.position.set(x, -0.4, z + 3.3);
		scene.add(label);
		dogs.push({ rig, animator, x, y, z });
	});
	const controls = new OrbitControls(R.camera, R.renderer.domElement);
	const zoom = Number(params.get('zoom')) || 1;
	const span = Math.max(cols, Math.ceil(list.length / cols)) * spacing;
	R.camera.position.set(0, span * 0.55 / zoom + 4, span * 0.75 / zoom + 6);
	controls.target.set(0, 1, 0);
	controls.update();
	R.sun.position.set(60, 100, 50);
	R.sun.target.position.set(0, 0, 0);
	R.sun.shadow.camera.left = -span;
	R.sun.shadow.camera.right = span;
	R.sun.shadow.camera.top = span;
	R.sun.shadow.camera.bottom = -span;
	R.sun.shadow.camera.far = 400;
	R.sun.shadow.camera.updateProjectionMatrix();

	const q = new THREE.Quaternion();
	let last = performance.now();
	window.__galeria = { dogs, ready: true };
	function frame() {
		const now = performance.now();
		const dt = Math.min(0.05, (now - last) / 1000);
		last = now;
		for (const d of dogs) {
			const a = d.animator;
			q.copy(d.rig.mesh.quaternion);
			a.pos = [d.x, d.y, d.z];
			a.quat = [q.x, q.y, q.z, q.w];
			const f = new THREE.Vector3(0, 0, -1).applyQuaternion(q);
			let speed = 0;
			if (anim === 'andar') speed = a.LegLen * 1.0;
			else if (anim === 'trotar') speed = a.LegLen * 2.6;
			else if (anim === 'galope') speed = a.LegLen * 5.5;
			a.vel = [f.x * speed, 0, f.z * speed];
			if (anim === 'voar') {
				a.flying = true;
				a.vel = [f.x * a.BaseSpeed * 4, 0, f.z * a.BaseSpeed * 4];
			} else if (anim && !['andar', 'trotar', 'galope'].includes(anim)) {
				a.action = anim;
			}
			a.update(dt);
			setRigPose(d.rig);
		}
		controls.update();
		render();
		requestAnimationFrame(frame);
	}
	requestAnimationFrame(frame);
}

function makeLabel(text) {
	const canvas = document.createElement('canvas');
	canvas.width = 256;
	canvas.height = 48;
	const g = canvas.getContext('2d');
	g.fillStyle = 'rgba(20,16,44,0.85)';
	g.fillRect(0, 0, 256, 48);
	g.font = '26px "Fredoka One", sans-serif';
	g.fillStyle = '#fff';
	g.textAlign = 'center';
	g.textBaseline = 'middle';
	g.fillText(text, 128, 25);
	const tex = new THREE.CanvasTexture(canvas);
	tex.colorSpace = THREE.SRGBColorSpace;
	const m = new THREE.Mesh(new THREE.PlaneGeometry(6, 1.1), new THREE.MeshBasicMaterial({ map: tex }));
	m.rotation.x = -Math.PI / 2.6;
	return m;
}
