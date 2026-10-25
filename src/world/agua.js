// Água do mar: plano grande, um pouco transparente (dá para ver a areia embaixo, como no Roblox),
// com brilhos que se mexem.
import * as THREE from 'three';
import { WATER_Y } from './fisica.js';

const vertex = `
#include <common>
#include <fog_pars_vertex>
varying vec3 vWorld;
void main() {
	vec4 wp = modelMatrix * vec4(position, 1.0);
	vWorld = wp.xyz;
	vec4 mvPosition = viewMatrix * wp;
	gl_Position = projectionMatrix * mvPosition;
	#include <fog_vertex>
}`;

const fragment = `
#include <common>
#include <fog_pars_fragment>
uniform float uTime;
uniform vec3 uColor;
uniform vec3 uLight;
uniform float uOpacity;
varying vec3 vWorld;
void main() {
	vec2 p = vWorld.xz * 0.07;
	float a = sin(p.x * 3.1 + uTime * 0.9) * sin(p.y * 2.7 - uTime * 0.7);
	float b = sin((p.x + p.y) * 5.3 + uTime * 1.6) * sin((p.x - p.y) * 4.1 - uTime * 1.1);
	float spark = smoothstep(0.55, 0.95, a * 0.55 + b * 0.45);
	vec3 col = mix(uColor, uLight, spark * 0.6);
	gl_FragColor = vec4(col, min(1.0, uOpacity + spark * 0.2));
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
	#include <fog_fragment>
}`;

export function createWater(size = 9000) {
	const mat = new THREE.ShaderMaterial({
		uniforms: THREE.UniformsUtils.merge([
			THREE.UniformsLib.fog,
			{
				uTime: { value: 0 },
				uColor: { value: new THREE.Color('#38b6de') },
				uLight: { value: new THREE.Color('#e8fbff') },
				uOpacity: { value: 0.58 },
			},
		]),
		vertexShader: vertex,
		fragmentShader: fragment,
		transparent: true,
		depthWrite: false,
		fog: true,
	});
	const geo = new THREE.PlaneGeometry(size, size, 1, 1);
	geo.rotateX(-Math.PI / 2);
	const mesh = new THREE.Mesh(geo, mat);
	mesh.position.y = WATER_Y;
	mesh.renderOrder = 2;
	mesh.frustumCulled = false;
	return mesh;
}

export function updateWater(mesh, t, x, z) {
	mesh.material.uniforms.uTime.value = t;
	// acompanha a câmera (o plano é finito)
	mesh.position.x = Math.round(x / 50) * 50;
	mesh.position.z = Math.round(z / 50) * 50;
}
