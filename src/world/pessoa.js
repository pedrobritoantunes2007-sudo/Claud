// Bonequinhos de blocos (NPCs): Mission Master das ilhas, Prof. Barkley na Pawville.
// Estilo do "VillageFolk" do projeto Roblox: cabeça, tronco, braços e pernas de blocos, rosto simples.
import * as THREE from 'three';

const box = new THREE.BoxGeometry(1, 1, 1);
const mats = new Map();
function mat(color) {
	let m = mats.get(color);
	if (!m) {
		m = new THREE.MeshLambertMaterial({ color });
		mats.set(color, m);
	}
	return m;
}

function part(group, color, sx, sy, sz, x, y, z) {
	const m = new THREE.Mesh(box, mat(color));
	m.scale.set(sx, sy, sz);
	m.position.set(x, y, z);
	m.castShadow = true;
	group.add(m);
	return m;
}

// look: { skin, shirt, pants, hair, hat: 'explorer' | 'grad' | 'cap' | null, hatColor, beard }
export function makePerson(look = {}) {
	const skin = look.skin || '#f2c49b';
	const g = new THREE.Group();
	const legL = new THREE.Group(), legR = new THREE.Group(), armL = new THREE.Group(), armR = new THREE.Group();
	legL.position.set(-0.5, 2, 0);
	legR.position.set(0.5, 2, 0);
	part(legL, look.pants || '#3b4f8f', 0.95, 2, 1, 0, -1, 0);
	part(legR, look.pants || '#3b4f8f', 0.95, 2, 1, 0, -1, 0);
	part(legL, look.shoes || '#2a2230', 1, 0.4, 1.15, 0, -1.85, -0.07);
	part(legR, look.shoes || '#2a2230', 1, 0.4, 1.15, 0, -1.85, -0.07);
	const torso = part(g, look.shirt || '#d94a4a', 2, 2, 1, 0, 3, 0);
	if (look.vest) part(g, look.vest, 2.06, 1.6, 1.06, 0, 3.15, 0);
	armL.position.set(-1.5, 3.85, 0);
	armR.position.set(1.5, 3.85, 0);
	part(armL, look.sleeve || look.shirt || '#d94a4a', 0.95, 1.2, 1, 0, -0.45, 0);
	part(armR, look.sleeve || look.shirt || '#d94a4a', 0.95, 1.2, 1, 0, -0.45, 0);
	part(armL, skin, 0.9, 0.85, 0.95, 0, -1.45, 0);
	part(armR, skin, 0.9, 0.85, 0.95, 0, -1.45, 0);
	const head = new THREE.Group();
	head.position.set(0, 4.65, 0);
	part(head, skin, 1.25, 1.25, 1.25, 0, 0, 0);
	// rosto (olha para -Z, igual aos cachorros)
	part(head, '#1b1430', 0.18, 0.26, 0.05, -0.27, 0.1, -0.63);
	part(head, '#1b1430', 0.18, 0.26, 0.05, 0.27, 0.1, -0.63);
	part(head, '#ffffff', 0.07, 0.08, 0.04, -0.24, 0.17, -0.66);
	part(head, '#ffffff', 0.07, 0.08, 0.04, 0.3, 0.17, -0.66);
	part(head, '#7a3b2e', 0.42, 0.08, 0.05, 0, -0.27, -0.63);
	part(head, '#e88c8c', 0.16, 0.08, 0.04, -0.4, -0.12, -0.63);
	part(head, '#e88c8c', 0.16, 0.08, 0.04, 0.4, -0.12, -0.63);
	if (look.hair) {
		part(head, look.hair, 1.33, 0.35, 1.33, 0, 0.62, 0.02);
		part(head, look.hair, 1.33, 0.9, 0.3, 0, 0.25, 0.55);
	}
	if (look.beard) part(head, look.beard, 1.0, 0.45, 0.2, 0, -0.45, -0.6);
	if (look.glasses) {
		part(head, '#20202a', 0.38, 0.32, 0.06, -0.27, 0.1, -0.67);
		part(head, '#20202a', 0.38, 0.32, 0.06, 0.27, 0.1, -0.67);
		part(head, '#20202a', 0.2, 0.06, 0.06, 0, 0.14, -0.67);
	}
	const hc = look.hatColor || '#8a5a2b';
	if (look.hat === 'explorer') {
		part(head, hc, 2.0, 0.14, 2.0, 0, 0.72, 0);
		part(head, hc, 1.3, 0.55, 1.3, 0, 0.98, 0);
		part(head, '#3b2a1a', 1.32, 0.14, 1.32, 0, 0.8, 0);
	} else if (look.hat === 'grad') {
		part(head, '#1b1430', 1.3, 0.35, 1.3, 0, 0.75, 0);
		part(head, '#1b1430', 1.9, 0.1, 1.9, 0, 0.95, 0);
		part(head, '#ffd34d', 0.08, 0.6, 0.08, 0.8, 0.7, -0.8);
	} else if (look.hat === 'cap') {
		part(head, hc, 1.32, 0.4, 1.32, 0, 0.75, 0);
		part(head, hc, 1.0, 0.1, 0.7, 0, 0.6, -0.9);
	}
	g.add(legL, legR, armL, armR, head);
	g.userData = { legL, legR, armL, armR, head, torso, t: Math.random() * 10 };
	g.scale.setScalar(look.scale || 1.15);
	return g;
}

// animação simples: respirar, olhar, acenar de vez em quando
export function animatePerson(g, dt, lookAt) {
	const u = g.userData;
	u.t += dt;
	const t = u.t;
	u.torso.position.y = 3 + Math.sin(t * 2) * 0.03;
	u.head.position.y = 4.65 + Math.sin(t * 2) * 0.03;
	const wave = (t % 6) < 1.4;
	u.armR.rotation.x = wave ? 0 : Math.sin(t * 1.3) * 0.05;
	u.armR.rotation.z = wave ? -2.6 + Math.sin(t * 12) * 0.35 : 0.05;
	u.armL.rotation.z = -0.05;
	if (lookAt) {
		const wp = new THREE.Vector3();
		g.getWorldPosition(wp);
		const a = Math.atan2(-(lookAt.x - wp.x), -(lookAt.z - wp.z)) - g.rotation.y;
		let d = ((a + Math.PI) % (Math.PI * 2)) - Math.PI;
		if (d < -Math.PI) d += Math.PI * 2;
		u.head.rotation.y += (Math.max(-1, Math.min(1, d)) - u.head.rotation.y) * Math.min(1, dt * 4);
	}
}

// "❗" flutuando em cima da cabeça (placa de missão)
export function makeBang(color = '#ffd34d', text = '!') {
	const c = document.createElement('canvas');
	c.width = 128;
	c.height = 128;
	const g = c.getContext('2d');
	g.font = 'bold 110px "Luckiest Guy", sans-serif';
	g.textAlign = 'center';
	g.textBaseline = 'middle';
	g.lineWidth = 14;
	g.strokeStyle = '#1b1430';
	g.strokeText(text, 64, 70);
	g.fillStyle = color;
	g.fillText(text, 64, 70);
	const tex = new THREE.CanvasTexture(c);
	tex.colorSpace = THREE.SRGBColorSpace;
	const s = new THREE.Sprite(new THREE.SpriteMaterial({ map: tex, depthTest: false, transparent: true }));
	s.scale.set(2.6, 2.6, 1);
	s.renderOrder = 10;
	return s;
}
