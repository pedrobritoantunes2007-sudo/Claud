// Tela 3D: renderer, cena, câmera, luz do sol (com sombra que acompanha o jogador) e céu.
import * as THREE from 'three';

export const R = {
	renderer: null,
	scene: null,
	camera: null,
	sun: null,
	hemi: null,
	sky: null,
	quality: 'high',
};

export function initRender(container, quality = 'high') {
	R.quality = quality;
	const renderer = new THREE.WebGLRenderer({ antialias: quality !== 'low', powerPreference: 'high-performance', alpha: false });
	renderer.setPixelRatio(pixelRatioFor(quality));
	renderer.setSize(window.innerWidth, window.innerHeight, false);
	renderer.outputColorSpace = THREE.SRGBColorSpace;
	renderer.toneMapping = THREE.NoToneMapping;
	renderer.shadowMap.enabled = quality !== 'low';
	renderer.shadowMap.type = quality === 'high' ? THREE.PCFSoftShadowMap : THREE.PCFShadowMap;
	container.appendChild(renderer.domElement);
	R.renderer = renderer;

	const scene = new THREE.Scene();
	scene.background = new THREE.Color('#8fd3ff');
	scene.fog = new THREE.Fog('#a9ddff', 160, 520);
	R.scene = scene;

	const camera = new THREE.PerspectiveCamera(55, window.innerWidth / window.innerHeight, 0.3, 2400);
	camera.position.set(0, 12, 24);
	R.camera = camera;

	const hemi = new THREE.HemisphereLight('#dff1ff', '#6a7a52', 1.7);
	scene.add(hemi);
	R.hemi = hemi;

	const sun = new THREE.DirectionalLight('#fff4de', 2.1);
	sun.position.set(40, 80, 30);
	sun.castShadow = quality !== 'low';
	const size = quality === 'high' ? 2048 : 1024;
	sun.shadow.mapSize.set(size, size);
	sun.shadow.camera.near = 1;
	sun.shadow.camera.far = 260;
	const ext = 70;
	sun.shadow.camera.left = -ext;
	sun.shadow.camera.right = ext;
	sun.shadow.camera.top = ext;
	sun.shadow.camera.bottom = -ext;
	sun.shadow.bias = -0.0008;
	sun.shadow.normalBias = 0.04;
	scene.add(sun);
	scene.add(sun.target);
	R.sun = sun;

	R.sky = makeSky(scene);

	window.addEventListener('resize', onResize);
	return R;
}

function pixelRatioFor(quality) {
	const dpr = window.devicePixelRatio || 1;
	if (quality === 'low') return Math.min(dpr, 1);
	if (quality === 'medium') return Math.min(dpr, 1.5);
	return Math.min(dpr, 2);
}

export function setQuality(quality) {
	R.quality = quality;
	R.renderer.setPixelRatio(pixelRatioFor(quality));
	R.renderer.shadowMap.enabled = quality !== 'low';
	R.sun.castShadow = quality !== 'low';
	R.scene.traverse((o) => {
		if (o.material) {
			const list = Array.isArray(o.material) ? o.material : [o.material];
			list.forEach((m) => (m.needsUpdate = true));
		}
	});
	onResize();
}

function onResize() {
	const w = window.innerWidth, h = window.innerHeight;
	R.renderer.setSize(w, h, false);
	R.camera.aspect = w / h;
	R.camera.updateProjectionMatrix();
}

// céu: esfera grande com degradê (azul em cima, claro no horizonte), acompanha a câmera
function makeSky(scene) {
	const geo = new THREE.SphereGeometry(1800, 32, 16);
	const mat = new THREE.ShaderMaterial({
		side: THREE.BackSide,
		depthWrite: false,
		fog: false,
		uniforms: {
			top: { value: new THREE.Color('#3f9cf0') },
			mid: { value: new THREE.Color('#9ed8ff') },
			bottom: { value: new THREE.Color('#dff3ff') },
		},
		vertexShader: `varying vec3 vPos; void main(){ vPos = position; gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.0); }`,
		fragmentShader: `uniform vec3 top; uniform vec3 mid; uniform vec3 bottom; varying vec3 vPos;
			void main(){ float h = normalize(vPos).y; vec3 c = h > 0.0 ? mix(mid, top, smoothstep(0.0, 0.55, h)) : mix(mid, bottom, smoothstep(0.0, -0.25, h));
			gl_FragColor = vec4(c, 1.0); }`,
	});
	const sky = new THREE.Mesh(geo, mat);
	sky.renderOrder = -10;
	sky.frustumCulled = false;
	scene.add(sky);
	return sky;
}

// cores do céu/neblina por ilha
export function setAtmosphere({ top, mid, bottom, fog, fogNear, fogFar, hemiSky, hemiGround, sun, sunIntensity, hemiIntensity }) {
	const u = R.sky.material.uniforms;
	if (top) u.top.value.set(top);
	if (mid) u.mid.value.set(mid);
	if (bottom) u.bottom.value.set(bottom);
	if (fog) {
		R.scene.fog.color.set(fog);
		R.scene.background.set(fog);
	}
	if (fogNear !== undefined) R.scene.fog.near = fogNear;
	if (fogFar !== undefined) R.scene.fog.far = fogFar;
	if (hemiSky) R.hemi.color.set(hemiSky);
	if (hemiGround) R.hemi.groundColor.set(hemiGround);
	if (hemiIntensity !== undefined) R.hemi.intensity = hemiIntensity;
	if (sun) R.sun.color.set(sun);
	if (sunIntensity !== undefined) R.sun.intensity = sunIntensity;
}

// a sombra do sol acompanha um ponto (o jogador)
const SUN_DIR = new THREE.Vector3(0.45, 1, 0.32).normalize();
export function followSun(x, y, z) {
	const sun = R.sun;
	// prende numa grade para a sombra não "tremer" quando anda
	const step = 2;
	const gx = Math.round(x / step) * step, gz = Math.round(z / step) * step;
	sun.target.position.set(gx, y, gz);
	sun.position.set(gx + SUN_DIR.x * 120, y + SUN_DIR.y * 120, gz + SUN_DIR.z * 120);
	R.sky.position.set(x, 0, z);
}

export function render() {
	R.renderer.render(R.scene, R.camera);
}
