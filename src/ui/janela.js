// Janela de menu (DOGS, EGGS, MAP...): fundo escuro, título, botão X, fecha com ESC ou clicando fora.
let current = null;

export function openWindow({ title, small = false, onClose, root = document.getElementById('ui') }) {
	if (current) current.close();
	const back = document.createElement('div');
	back.className = 'fundo-janela';
	const win = document.createElement('div');
	win.className = 'janela' + (small ? ' pequena' : '');
	const top = document.createElement('div');
	top.className = 'topo';
	const h = document.createElement('h2');
	h.innerHTML = title;
	const x = document.createElement('button');
	x.className = 'fechar';
	x.textContent = 'X';
	top.append(h, x);
	const body = document.createElement('div');
	body.className = 'corpo';
	win.append(top, body);
	back.appendChild(win);
	root.appendChild(back);
	const onKey = (e) => {
		if (e.key === 'Escape') api.close();
	};
	const api = {
		el: win,
		body,
		title: h,
		closed: false,
		close() {
			if (api.closed) return;
			api.closed = true;
			back.remove();
			window.removeEventListener('keydown', onKey);
			if (current === api) current = null;
			onClose && onClose();
		},
	};
	x.onclick = () => api.close();
	back.addEventListener('pointerdown', (e) => {
		if (e.target === back) api.close();
	});
	window.addEventListener('keydown', onKey);
	current = api;
	return api;
}

export function windowOpen() {
	return !!current;
}

export function closeWindow() {
	if (current) current.close();
}

export function h(tag, cls, html, attrs) {
	const e = document.createElement(tag);
	if (cls) e.className = cls;
	if (html !== undefined && html !== null) e.innerHTML = html;
	if (attrs) for (const [k, v] of Object.entries(attrs)) e.setAttribute(k, v);
	return e;
}

export function button(label, cls, fn) {
	const b = h('button', 'btn ' + (cls || ''), label);
	b.onclick = (e) => {
		e.stopPropagation();
		if (!b.disabled) fn && fn(b);
	};
	return b;
}

// pergunta de confirmação
export function confirmBox(title, text, yesLabel, onYes) {
	const w = openWindow({ title, small: true });
	w.body.appendChild(h('p', null, text));
	const row = h('div', 'opcoes');
	row.style.display = 'flex';
	row.style.gap = '10px';
	row.style.justifyContent = 'center';
	row.append(
		button(yesLabel, 'vermelho', () => {
			w.close();
			onYes();
		}),
		button('CANCEL', 'cinza', () => w.close()),
	);
	w.body.appendChild(row);
	return w;
}
