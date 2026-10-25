// Teclado, mouse e toque. Guarda o estado (teclas apertadas, mouse, joystick) e avisa cliques/teclas novas.
export const Input = {
	keys: new Set(),
	pressed: new Set(), // teclas que desceram neste quadro
	mouse: { x: 0, y: 0, dx: 0, dy: 0, left: false, right: false, wheel: 0, inside: false },
	clicks: [], // cliques do botão esquerdo neste quadro
	touch: false, // jogando no celular
	joy: { x: 0, y: 0, active: false }, // joystick virtual (-1..1)
	look: { dx: 0, dy: 0 }, // arrastar para girar a câmera (toque)
	locked: false, // ponteiro travado (trava da câmera)
	enabled: true,
	listeners: [],
};

export function initInput(canvas) {
	const I = Input;
	window.addEventListener('keydown', (e) => {
		if (e.target && (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA')) return;
		const k = keyName(e);
		if (!I.keys.has(k)) I.pressed.add(k);
		I.keys.add(k);
		if (['space', 'tab', 'arrowup', 'arrowdown', 'arrowleft', 'arrowright'].includes(k)) e.preventDefault();
		for (const fn of I.listeners) fn(k, e);
	});
	window.addEventListener('keyup', (e) => I.keys.delete(keyName(e)));
	window.addEventListener('blur', () => {
		I.keys.clear();
		I.mouse.left = I.mouse.right = false;
	});
	canvas.addEventListener('contextmenu', (e) => e.preventDefault());
	canvas.addEventListener('mousedown', (e) => {
		if (I.touch) return;
		if (e.button === 0) {
			I.mouse.left = true;
			I.clicks.push({ x: e.clientX, y: e.clientY });
		}
		if (e.button === 2) I.mouse.right = true;
		canvas.focus();
	});
	window.addEventListener('mouseup', (e) => {
		if (e.button === 0) I.mouse.left = false;
		if (e.button === 2) I.mouse.right = false;
	});
	window.addEventListener('mousemove', (e) => {
		if (I.touch && e.sourceCapabilities && e.sourceCapabilities.firesTouchEvents) return;
		I.mouse.x = e.clientX;
		I.mouse.y = e.clientY;
		I.mouse.dx += e.movementX || 0;
		I.mouse.dy += e.movementY || 0;
		I.mouse.inside = true;
	});
	canvas.addEventListener('wheel', (e) => {
		I.mouse.wheel += Math.sign(e.deltaY);
		e.preventDefault();
	}, { passive: false });
	document.addEventListener('pointerlockchange', () => {
		I.locked = document.pointerLockElement === canvas;
	});
	// toque na tela (fora dos botões): arrastar = girar a câmera
	const drags = new Map();
	canvas.addEventListener('touchstart', (e) => {
		I.touch = true;
		for (const t of e.changedTouches) drags.set(t.identifier, { x: t.clientX, y: t.clientY, sx: t.clientX, sy: t.clientY, t: performance.now() });
		e.preventDefault();
	}, { passive: false });
	canvas.addEventListener('touchmove', (e) => {
		for (const t of e.changedTouches) {
			const d = drags.get(t.identifier);
			if (!d) continue;
			I.look.dx += t.clientX - d.x;
			I.look.dy += t.clientY - d.y;
			d.x = t.clientX;
			d.y = t.clientY;
		}
		e.preventDefault();
	}, { passive: false });
	const end = (e) => {
		for (const t of e.changedTouches) {
			const d = drags.get(t.identifier);
			// toque rápido sem arrastar = mirar/atacar naquele ponto
			if (d && performance.now() - d.t < 250 && Math.hypot(t.clientX - d.sx, t.clientY - d.sy) < 12) {
				I.clicks.push({ x: t.clientX, y: t.clientY, touch: true });
			}
			drags.delete(t.identifier);
		}
	};
	canvas.addEventListener('touchend', end);
	canvas.addEventListener('touchcancel', end);
	if ('ontouchstart' in window && matchMedia('(pointer: coarse)').matches) I.touch = true;
}

function keyName(e) {
	if (e.code === 'Space') return 'space';
	if (e.code && e.code.startsWith('Key')) return e.code.slice(3).toLowerCase();
	if (e.code && e.code.startsWith('Digit')) return e.code.slice(5);
	if (e.code === 'ShiftLeft' || e.code === 'ShiftRight') return 'shift';
	if (e.code === 'ControlLeft' || e.code === 'ControlRight') return 'ctrl';
	return (e.key || '').toLowerCase();
}

export function onKey(fn) {
	Input.listeners.push(fn);
	return () => {
		const i = Input.listeners.indexOf(fn);
		if (i >= 0) Input.listeners.splice(i, 1);
	};
}

// chamar no fim de cada quadro
export function endInputFrame() {
	Input.pressed.clear();
	Input.clicks.length = 0;
	Input.mouse.dx = Input.mouse.dy = 0;
	Input.mouse.wheel = 0;
	Input.look.dx = Input.look.dy = 0;
}

export function down(k) {
	return Input.enabled && Input.keys.has(k);
}

export function pressed(k) {
	return Input.enabled && Input.pressed.has(k);
}

// direção do movimento (-1..1): WASD/setas ou joystick
export function moveAxis() {
	if (!Input.enabled) return [0, 0];
	if (Input.joy.active) return [Input.joy.x, Input.joy.y];
	let x = 0, y = 0;
	if (Input.keys.has('w') || Input.keys.has('arrowup')) y += 1;
	if (Input.keys.has('s') || Input.keys.has('arrowdown')) y -= 1;
	if (Input.keys.has('d') || Input.keys.has('arrowright')) x += 1;
	if (Input.keys.has('a') || Input.keys.has('arrowleft')) x -= 1;
	const m = Math.hypot(x, y);
	return m > 1 ? [x / m, y / m] : [x, y];
}
