// Monta o modelo 3D de um cachorro a partir do cachorros.json (exportado do DogBuilder do projeto Roblox).
// Cada cachorro vira UMA malha só (SkinnedMesh): cada peça de bloco fica presa num "osso" (junta do Roblox:
// Body, Neck1, Jaw1, LegFL, KneeFL, Tail, WingL, orelhas...). O Animator mexe os ossos.
// A geometria de cada espécie é montada uma vez e reaproveitada por todos os cachorros iguais.
import * as THREE from 'three';
import DOGS from '../data/cachorros.json';
import { CF, fromArray, IDENT } from './cf.js';

export const SPECIES_MODELS = DOGS;

// materiais compartilhados (todos os cachorros usam os mesmos 3)
export const DOG_MATERIALS = {
	opaque: new THREE.MeshLambertMaterial({ vertexColors: true }),
	neon: new THREE.MeshBasicMaterial({ vertexColors: true, toneMapped: false }),
	glass: new THREE.MeshLambertMaterial({ vertexColors: true, transparent: true, depthWrite: false }),
};

// faces de um bloco e de uma cunha (WedgePart do Roblox: rampa sobe da frente -Z para trás +Z)
function boxFaces(x, y, z) {
	const v = [
		[-x, -y, -z], [x, -y, -z], [x, y, -z], [-x, y, -z],
		[-x, -y, z], [x, -y, z], [x, y, z], [-x, y, z],
	];
	return {
		center: [0, 0, 0],
		faces: [
			[v[0], v[1], v[2], v[3]],
			[v[5], v[4], v[7], v[6]],
			[v[4], v[0], v[3], v[7]],
			[v[1], v[5], v[6], v[2]],
			[v[3], v[2], v[6], v[7]],
			[v[4], v[5], v[1], v[0]],
		],
	};
}

function wedgeFaces(x, y, z) {
	const A = [-x, -y, -z], B = [x, -y, -z], C = [-x, -y, z], D = [x, -y, z], E = [-x, y, z], F = [x, y, z];
	return {
		center: [0, -y / 3, z / 3],
		faces: [
			[A, B, D, C],
			[C, D, F, E],
			[A, E, F, B],
			[A, C, E],
			[B, F, D],
		],
	};
}

const _m = new THREE.Matrix4();
const _n = new THREE.Matrix3();
const _v = new THREE.Vector3();
const _c = new THREE.Color();

// junta tudo de um grupo num buffer: posição, normal, cor (rgba), osso
class Buffers {
	constructor() {
		this.pos = [];
		this.nor = [];
		this.col = [];
		this.bone = [];
	}

	addPart(shape, matrix, color, alpha, bone) {
		_n.getNormalMatrix(matrix);
		const ctr = shape.center;
		for (const face of shape.faces) {
			// normal da face (no espaço da peça), virada para fora
			const a = face[0], b = face[1], c = face[2];
			let nx = (b[1] - a[1]) * (c[2] - a[2]) - (b[2] - a[2]) * (c[1] - a[1]);
			let ny = (b[2] - a[2]) * (c[0] - a[0]) - (b[0] - a[0]) * (c[2] - a[2]);
			let nz = (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0]);
			let fx = 0, fy = 0, fz = 0;
			for (const p of face) {
				fx += p[0];
				fy += p[1];
				fz += p[2];
			}
			fx = fx / face.length - ctr[0];
			fy = fy / face.length - ctr[1];
			fz = fz / face.length - ctr[2];
			let flip = nx * fx + ny * fy + nz * fz < 0;
			if (flip) {
				nx = -nx;
				ny = -ny;
				nz = -nz;
			}
			const len = Math.hypot(nx, ny, nz);
			if (len < 1e-9) continue;
			_v.set(nx / len, ny / len, nz / len).applyMatrix3(_n).normalize();
			const wn = [_v.x, _v.y, _v.z];
			const pts = face.map((p) => {
				_v.set(p[0], p[1], p[2]).applyMatrix4(matrix);
				return [_v.x, _v.y, _v.z];
			});
			for (let i = 1; i < pts.length - 1; i++) {
				const tri = flip ? [pts[0], pts[i + 1], pts[i]] : [pts[0], pts[i], pts[i + 1]];
				for (const p of tri) {
					this.pos.push(p[0], p[1], p[2]);
					this.nor.push(wn[0], wn[1], wn[2]);
					this.col.push(color.r, color.g, color.b, alpha);
					this.bone.push(bone);
				}
			}
		}
	}
}

const assets = new Map();

// tudo que não muda entre cachorros da mesma espécie
export function speciesAsset(id) {
	let asset = assets.get(id);
	if (asset) return asset;
	const d = DOGS[id];
	if (!d) throw new Error('cachorro desconhecido: ' + id);
	const n = d.bones.length;
	const joint = d.bones.map((b) => fromArray(b.j));
	const child = d.bones.map((b) => fromArray(b.c));
	const restModel = new Array(n);
	for (let i = 0; i < n; i++) {
		const local = joint[i].mul(child[i]);
		restModel[i] = d.bones[i].p < 0 ? local : restModel[d.bones[i].p].mul(local);
	}
	const groups = { opaque: new Buffers(), neon: new Buffers(), glass: new Buffers() };
	const partCF = new CF();
	const partM = new THREE.Matrix4();
	let minY = Infinity, maxY = -Infinity, maxR = 0;
	for (const p of d.parts) {
		const [bone, wedge, sx, sy, sz, px, py, pz, qx, qy, qz, qw, hex, mat, tr] = p;
		partCF.x = px;
		partCF.y = py;
		partCF.z = pz;
		partCF.qx = qx;
		partCF.qy = qy;
		partCF.qz = qz;
		partCF.qw = qw;
		restModel[bone].mul(partCF).toMatrix(partM);
		const shape = wedge ? wedgeFaces(sx / 2, sy / 2, sz / 2) : boxFaces(sx / 2, sy / 2, sz / 2);
		_c.setHex(hex);
		let alpha = 1 - tr;
		let group = 'opaque';
		if (mat === 1) group = 'neon';
		else if (mat === 2) {
			group = 'glass';
			alpha = Math.min(alpha, 0.8);
		} else if (mat === 4) {
			group = 'glass';
			alpha = Math.min(alpha, 0.85);
		} else if (tr > 0.04) group = 'glass';
		if (mat === 3) _c.offsetHSL(0, -0.05, 0.04); // metal um pouco mais claro
		groups[group].addPart(shape, partM, _c, alpha, bone);
		const e = partM.elements;
		const r = Math.hypot(sx, sy, sz) / 2;
		minY = Math.min(minY, e[13] - r);
		maxY = Math.max(maxY, e[13] + r);
		maxR = Math.max(maxR, Math.hypot(e[12], e[13], e[14]) + r);
	}
	const geometry = new THREE.BufferGeometry();
	let total = 0;
	for (const b of Object.values(groups)) total += b.bone.length;
	const pos = new Float32Array(total * 3), nor = new Float32Array(total * 3), col = new Float32Array(total * 4);
	const skinIndex = new Uint16Array(total * 4);
	const skinWeight = new Float32Array(total * 4);
	const materials = [];
	let at = 0;
	for (const [name, b] of Object.entries(groups)) {
		const n = b.bone.length;
		if (n === 0) continue;
		geometry.addGroup(at, n, materials.length);
		materials.push(DOG_MATERIALS[name]);
		pos.set(b.pos, at * 3);
		nor.set(b.nor, at * 3);
		col.set(b.col, at * 4);
		for (let i = 0; i < n; i++) {
			skinIndex[(at + i) * 4] = b.bone[i];
			skinWeight[(at + i) * 4] = 1;
		}
		at += n;
	}
	geometry.setAttribute('position', new THREE.BufferAttribute(pos, 3));
	geometry.setAttribute('normal', new THREE.BufferAttribute(nor, 3));
	geometry.setAttribute('color', new THREE.BufferAttribute(col, 4));
	geometry.setAttribute('skinIndex', new THREE.Uint16BufferAttribute(skinIndex, 4));
	geometry.setAttribute('skinWeight', new THREE.Float32BufferAttribute(skinWeight, 4));
	geometry.boundingSphere = new THREE.Sphere(new THREE.Vector3(0, 0, 0), maxR * 1.7 + 1);
	geometry.boundingBox = new THREE.Box3(new THREE.Vector3(-maxR, minY, -maxR), new THREE.Vector3(maxR, maxY, maxR));
	const boneInverses = restModel.map((cf) => cf.toMatrix(new THREE.Matrix4()).invert());
	const byName = {};
	d.bones.forEach((b, i) => {
		if (b.n !== 'Ear' && byName[b.n] === undefined) byName[b.n] = i;
	});
	asset = {
		id,
		data: d,
		geometry,
		materials,
		joint,
		child,
		restModel,
		boneInverses,
		byName,
		// altura do centro da raiz acima do chão (unidades do modelo)
		groundOffset: d.hip + d.rootY / 2,
		height: maxY,
		radius: maxR,
	};
	assets.set(id, asset);
	return asset;
}

// um cachorro novo na cena (SkinnedMesh + ossos). scale = tamanho no jogo.
export function createDogModel(id, scale = 1) {
	const asset = speciesAsset(id);
	const d = asset.data;
	const bones = d.bones.map(() => {
		const b = new THREE.Bone();
		b.matrixAutoUpdate = false;
		return b;
	});
	d.bones.forEach((def, i) => {
		if (def.p >= 0) bones[def.p].add(bones[i]);
	});
	const mesh = new THREE.SkinnedMesh(asset.geometry, asset.materials);
	mesh.add(bones[0]);
	mesh.bind(new THREE.Skeleton(bones, asset.boneInverses), new THREE.Matrix4());
	mesh.castShadow = true;
	mesh.receiveShadow = false;
	mesh.scale.setScalar(scale);
	const rig = { id, asset, mesh, bones, scale, poses: new Array(bones.length).fill(IDENT) };
	setRigPose(rig);
	return rig;
}


// aplica as poses (rig.poses[i] = CF da junta i) nos ossos: osso = junta * pose * filho
export function setRigPose(rig) {
	const { asset, bones, poses } = rig;
	for (let i = 0; i < bones.length; i++) {
		const pose = poses[i];
		const local = pose === IDENT || pose.isIdentity() ? asset.joint[i].mul(asset.child[i]) : asset.joint[i].mul(pose).mul(asset.child[i]);
		local.toMatrix(bones[i].matrix);
		bones[i].matrixWorldNeedsUpdate = true;
	}
}

export function disposeDogModel(rig) {
	if (rig.mesh.parent) rig.mesh.parent.remove(rig.mesh);
	rig.mesh.skeleton.dispose();
}
