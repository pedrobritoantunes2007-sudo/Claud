// Caixa de conversa com NPC (embaixo da tela): retrato, nome, fala (máquina de escrever) e botões.
import { h, button } from './janela.js';

let current = null;

export function closeDialog() {
	if (current) current.close();
}

export function dialogOpen() {
	return !!current;
}

// opts: { who, face (emoji), text, options: [{ label, cls, fn, html }] , onClose }
export function openDialog(root, opts) {
	closeDialog();
	const box = h('div', 'painel dialogo');
	const face = h('div', 'retrato', opts.face || '🙂');
	if (opts.faceBg) face.style.background = opts.faceBg;
	const talk = h('div', 'fala');
	const who = h('div', 'quem', opts.who || '');
	const text = h('div', 'texto');
	const opt = h('div', 'opcoes');
	opt.style.flexDirection = opts.column ? 'column' : 'row';
	talk.append(who, text, opt);
	const x = h('button', 'fechar', 'X');
	x.style.alignSelf = 'flex-start';
	box.append(face, talk, x);
	root.appendChild(box);
	let timer = null;
	const api = {
		el: box,
		close() {
			if (api.closed) return;
			api.closed = true;
			clearInterval(timer);
			box.remove();
			window.removeEventListener('keydown', onKey);
			if (current === api) current = null;
			opts.onClose && opts.onClose();
		},
		set(newText, options) {
			clearInterval(timer);
			// máquina de escrever
			const full = newText || '';
			let i = 0;
			text.innerHTML = '';
			const plain = full.replace(/<[^>]+>/g, '');
			if (plain.length > 0 && full === plain) {
				timer = setInterval(() => {
					i += 2;
					text.textContent = full.slice(0, i);
					if (i >= full.length) clearInterval(timer);
				}, 18);
			} else text.innerHTML = full;
			opt.innerHTML = '';
			for (const o of options || []) {
				if (o.html) {
					const row = h('div', 'opcao-missao', `<div class="q">${o.html}</div>`);
					if (o.label) row.appendChild(button(o.label, o.cls || '', () => o.fn(api)));
					opt.appendChild(row);
				} else opt.appendChild(button(o.label, o.cls || '', () => o.fn(api)));
			}
		},
	};
	const onKey = (e) => {
		if (e.key === 'Escape') api.close();
	};
	window.addEventListener('keydown', onKey);
	x.onclick = () => api.close();
	api.set(opts.text, opts.options);
	current = api;
	return api;
}
