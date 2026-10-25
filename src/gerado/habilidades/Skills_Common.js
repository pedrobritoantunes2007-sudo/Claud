// Gerado automaticamente de server/Services/SpecialsPacks/Skills_Common.lua (código do jogo Roblox) por tools/lua2js — não edite à mão.
import { $t, $a, $n, $1, $M, $mv, $lst, $get, $set, $tm, $tc, $len, $cat, $eq, $add, $sub, $mul, $div, $mod, $pow, $idiv, $unm, $mc, $cy, $sp, $sp1, $W, $WS, $ins, $ins3, $arr, $pairs, $iter, $pcallG, $warnWait } from '../../rbx/lua.js';

export default function ($G, $script) {
	let require = $G["require"], Color3 = $G["Color3"], Vector3 = $G["Vector3"], string = $G["string"], ipairs = $G["ipairs"], math = $G["math"];
	let SkillKit = $sp1(require($script.Parent.Parent.SkillKit));
	let C = Color3.fromRGB;
	let UP = Vector3.new(0, 1, 0);
	let G = SkillKit.Ground;
	return function (Specials, _Fighters) {
		let def = function (id, slot, fn) {
			$sp(SkillKit.def(Specials, id, slot, fn));
		};
		def("SK_caramelo_2", 2, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Throw", 0.5);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.22)))))) {
				return;
			}
			let land = $mc(k, "tground");
			let t = $mc(k, "shoot", "Stick", { points: [land], speed: 50, arc: 5, frac: 0.55, radius: 3, size: 1.1 });
			$mc(k, "pose", "Dash", $add(t, 0.5));
			if (!$t($1((yield* $cy($mc(k, "wait", $mul(t, 0.6))))))) {
				return;
			}
			$mc(k, "pose", "Leap", 0.5);
			if (!$t($1((yield* $cy($mc(k, "leap", land, 3, 0.4, { frac: 0.45, radius: 3, opts: { Knockback: $add($mul($mc(k, "dir", land), 18), $mul(UP, 10)) } })))))) {
				return;
			}
			$mc(k, "pose", "Victory", 0.5);
			$mc(k, "pop", "FETCH!", undefined, C(255, 220, 120), 0.8);
		});
		def("SK_caramelo_3", 3, function* (k) {
			$mc(k, "stop");
			let d = $mc(k, "dir");
			$mc(k, "face", $sub($mc(k, "me"), $mul(d, 5)));
			$mc(k, "pose", "Dig", 0.6);
			$mc(k, "burst", "Dirt", $mc(k, "feet"), { Count: 5 });
			if (!$t($1((yield* $cy($mc(k, "wait", 0.55)))))) {
				return;
			}
			$mc(k, "pose", "Kick", 0.6);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.18)))))) {
				return;
			}
			let from = $mc(k, "feet");
			$mc(k, "burst", "Dirt", $add(from, $mul(d, 1.5)), { Count: 14, Dir: $add(d, $mul(UP, 0.4)), Cone: 0.45, Radius: 10 });
			$mc(k, "wave", "Sand", { from: from, dir: d, length: 15, width: 7, speed: 40, frac: 0.7, color: C(170, 130, 80), on: function (e) {
				$mc(k, "slow", e, 2, 0.6);
			} });
			$mc(k, "shoot", "Rock", { from: $add(from, $mul(UP, 1.5)), count: 3, spread: 30, speed: 45, arc: 3, frac: 0.1, size: 0.5 });
		});
		def("SK_pug_2", 2, function* (k) {
			if (!$t($1((yield* $cy($mc(k, "approach", 8, 1)))))) {
				return;
			}
			$mc(k, "face");
			$mc(k, "pose", "Crouch", 0.3);
			$mc(k, "tele", $mc(k, "tground"), 6, 0.6);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.3)))))) {
				return;
			}
			$mc(k, "pose", "Belly", 0.7);
			if (!$t($1((yield* $cy($mc(k, "leap", $mc(k, "tpos"), 6, 0.45)))))) {
				return;
			}
			let g = $mc(k, "feet");
			$mc(k, "impact", g, 6, C(225, 190, 140));
			$mc(k, "pop", "BONK!", undefined, C(255, 200, 120));
			$mc(k, "area", g, 6, 1, { KnockbackPower: 18, Lift: 22 });
			if ($t($1((yield* $cy($mc(k, "wait", 0.3)))))) {
				$mc(k, "pose", "Shake", 0.5);
			}
		});
		def("SK_pug_3", 3, function* (k) {
			if (!$t($1((yield* $cy($mc(k, "approach", 2, 1)))))) {
				return;
			}
			$mc(k, "pose", "Snore", 2);
			for (let i = 1, $v1 = 3; i <= $v1; i++) {
				if (!$t($1((yield* $cy($mc(k, "wait", 0.55)))))) {
					return;
				}
				let g = $mc(k, "feet");
				$mc(k, "pop", $cat("Z", string.rep("z", i)), $add($mc(k, "me"), $mul(UP, 4)), C(200, 220, 255), (0.7 + (i * 0.15)));
				$mc(k, "shock", g, (6 + (i * 2)), C(205, 180, 140));
				let hits = $mc(k, "area", g, (6 + (i * 2)), ($n(((i === 3) && 0.45)) ?? 0.275), { KnockbackPower: (10 + (i * 6)), Lift: 10 });
				if ((i === 3)) {
					for (let $v2 = 0, $v3 = $arr(hits); $v2 < $v3.length; $v2++) {
						let e = $v3[$v2];
						if (e == null) break;
						$mc(k, "stun", e, 1.2, "Sleep");
					}
				}
			}
		});
		def("SK_pinscher_2", 2, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Focus", 0.35);
			$mc(k, "pop", "!!", undefined, C(255, 120, 120), 0.7);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.35)))))) {
				return;
			}
			let home = $mc(k, "feet");
			$mc(k, "pose", "Dash", 0.7);
			$mc(k, "fx", "Streak", { Model: k.f.Model, Color: C(240, 240, 255), Duration: 0.6, Width: 0.8 });
			if (!$t($1((yield* $cy($mc(k, "blink", $sub($mc(k, "tpos"), $mul($mc(k, "dir"), 2.5)), 3, 0.03)))))) {
				return;
			}
			for (let _ = 1, $v4 = 2; _ <= $v4; _++) {
				$mc(k, "face");
				$mc(k, "fx", "Bite", { Model: k.f.Model, Head: 1 });
				$mc(k, "fx", "BiteMark", { Position: $mc(k, "tpos"), Direction: $mc(k, "dir"), Color: C(255, 255, 255) });
				$mc(k, "hit", 0.5);
				if (!$t($1((yield* $cy($mc(k, "wait", 0.18)))))) {
					return;
				}
			}
			(yield* $cy($mc(k, "blink", home, 3, 0.03)));
		});
		def("SK_pinscher_3", 3, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Twirl", 0.6);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.45)))))) {
				return;
			}
			let from = $mc(k, "feet"), to = $mc(k, "tground");
			let time = math.clamp($div($mc(k, "dist"), 30), 0.3, 0.9);
			$mc(k, "prop", "Tornado", { Position: from, To: to, Path: "Fly", Time: time, Size: $mul(2.4, k.A), Color: C(215, 245, 235) });
			$mc(k, "later", time, function () {
				$mc(k, "prop", "Tornado", { Position: to, Path: "Spin", Time: 0.5, Hold: 0.2, Size: $mul(2.4, k.A), Spin: 9, Color: C(215, 245, 235) });
				$mc(k, "burst", "Leaves", to, { Count: 8 });
				$mc(k, "area", to, 6, 0.6, { KnockbackPower: 24, Lift: 18 });
			});
			$mc(k, "later", $add(time, 0.4), function () {
				$mc(k, "area", to, 6, 0.4, { KnockbackPower: 16, Lift: 12 });
			});
		});
		def("SK_poodle_2", 2, function* (k) {
			if (!$t($1((yield* $cy($mc(k, "approach", 2, 1)))))) {
				return;
			}
			$mc(k, "pose", "Twirl", 0.8);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.35)))))) {
				return;
			}
			let g = $mc(k, "feet");
			$mc(k, "ringOut", "Pom", g, 1, 8, { Count: 8, Time: 0.5, Height: 1.5, Size: 0.9, Color: C(255, 225, 238) });
			$mc(k, "area", g, 8, 1, { KnockbackPower: 16, Lift: 12 });
			$mc(k, "burst", "Hearts", $mc(k, "me"), { Count: 4, Color: C(255, 140, 190) });
		});
		def("SK_poodle_3", 3, function* (k) {
			if (!$t($1((yield* $cy($mc(k, "reach", $mul($mc(k, "R", 19), 0.7), 1)))))) {
				return;
			}
			$mc(k, "face");
			$mc(k, "pose", "Inhale", 0.4);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.4)))))) {
				return;
			}
			$mc(k, "pose", "Open", 0.9);
			(yield* $cy($mc(k, "breath", "Perfume", { length: 19, angle: 28, time: 0.9, ticks: 3, frac: 0.8, color: C(255, 150, 210), on: function (e) {
				$mc(k, "knock", e, $mc(k, "me"), 5, 4);
			} })));
			$mc(k, "inCone", $mc(k, "me"), $mc(k, "dir"), 19, 28, 0.2, undefined, function (e) {
				$mc(k, "stun", e, 1.2, "Charm");
			});
		});
		def("SK_bulldog_2", 2, function* (k) {
			if (!$t($1((yield* $cy($mc(k, "approach", 9, 1)))))) {
				return;
			}
			$mc(k, "face");
			$mc(k, "pose", "Headbutt", 0.6);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.22)))))) {
				return;
			}
			let d = $mc(k, "dir");
			(yield* $cy($mc(k, "dash", $sub($mc(k, "tpos"), $mul(d, 1.5)), 0.18, { frac: 1, radius: 3, opts: { Knockback: $add($mul(d, 45), $mul(UP, 18)) }, on: function (e) {
				$mc(k, "pop", "BONK!", $add(e.Root.Position, $mul(UP, 4)), C(255, 230, 120));
				$mc(k, "impact", e.Root.Position, 4, C(220, 200, 170));
			} })));
		});
		def("SK_bulldog_3", 3, function* (k) {
			if (!$t($1((yield* $cy($mc(k, "approach", 7, 0.8)))))) {
				return;
			}
			$mc(k, "face");
			$mc(k, "pose", "Stomp", 0.8);
			for (let i = 1, $v5 = 2; i <= $v5; i++) {
				if (!$t($1((yield* $cy($mc(k, "wait", 0.36)))))) {
					return;
				}
				let g = $add($mc(k, "feet"), $mul($mc(k, "dir"), 2));
				$mc(k, "shock", g, (6 + (i * 2)), C(190, 160, 120), (i === 2));
				$mc(k, "burst", "Rocks", g, { Count: (4 + (i * 2)) });
				let hits = $mc(k, "area", g, (6 + (i * 2)), ($n(((i === 1) && 0.4)) ?? 0.6), { KnockbackPower: 10, Lift: 16 });
				if ((i === 2)) {
					for (let $v6 = 0, $v7 = $arr(hits); $v6 < $v7.length; $v6++) {
						let e = $v7[$v6];
						if (e == null) break;
						$mc(k, "stun", e, 1, "Dizzy");
					}
				}
			}
		});
		def("SK_beagle_2", 2, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Sniff", 0.6);
			$mc(k, "path", "Scent", $mc(k, "feet"), $mc(k, "tground"), { Duration: 1.4, Color: C(140, 255, 120) });
			if (!$t($1((yield* $cy($mc(k, "wait", 0.55)))))) {
				return;
			}
			$mc(k, "pose", "Dash", 0.4);
			let d = $mc(k, "dir");
			$mc(k, "path", "Paw", $mc(k, "feet"), $mc(k, "tground"), { Duration: 1.2, Color: C(120, 90, 60) });
			if (!$t($1((yield* $cy($mc(k, "dash", $sub($mc(k, "tpos"), $mul(d, 2)), 0.3)))))) {
				return;
			}
			$mc(k, "face");
			$mc(k, "fx", "Bite", { Model: k.f.Model, Head: 1 });
			$mc(k, "fx", "BiteMark", { Position: $mc(k, "tpos"), Direction: d, Color: C(200, 255, 190) });
			$mc(k, "hit", 1, { Knockback: $add($mul(d, 25), $mul(UP, 8)) });
		});
		def("SK_beagle_3", 3, function* (k) {
			if (!$t($1((yield* $cy($mc(k, "approach", 4, 0.9)))))) {
				return;
			}
			$mc(k, "pose", "Howl", 1);
			$mc(k, "fx", "Roar", { Model: k.f.Model, Color: C(150, 230, 120), Howl: true });
			if (!$t($1((yield* $cy($mc(k, "wait", 0.4)))))) {
				return;
			}
			let g = $mc(k, "feet");
			$mc(k, "ringOut", "Leaf", g, 1, 11, { Count: 10, Time: 0.7, Height: 1, Swirl: 2, Color: C(110, 200, 80) });
			let hits = $mc(k, "area", g, 11, 1, { KnockbackPower: 14, Lift: 8 });
			for (let $v8 = 0, $v9 = $arr(hits); $v8 < $v9.length; $v8++) {
				let e = $v9[$v8];
				if (e == null) break;
				$mc(k, "stun", e, 1, "Vines");
			}
		});
		def("SK_corgi_2", 2, function* (k) {
			if (!$t($1((yield* $cy($mc(k, "approach", 10, 1)))))) {
				return;
			}
			$mc(k, "face");
			$mc(k, "pose", "Crouch", 0.3);
			$mc(k, "tele", $mc(k, "tground"), 6, 0.85);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.3)))))) {
				return;
			}
			$mc(k, "pose", "Flip", 0.6);
			if (!$t($1((yield* $cy($mc(k, "leap", $mc(k, "tpos"), 8, 0.55)))))) {
				return;
			}
			$mc(k, "pose", "Bounce", 0.85);
			let g = $mc(k, "feet");
			$mc(k, "pop", "BOING!", undefined, C(255, 205, 150));
			$mc(k, "shock", g, 6, C(255, 205, 150));
			$mc(k, "area", g, 6, 0.7, { KnockbackPower: 20, Lift: 26 });
			if (!$t($1((yield* $cy($mc(k, "wait", 0.42)))))) {
				return;
			}
			$mc(k, "shock", $mc(k, "feet"), 4, C(255, 205, 150));
			$mc(k, "area", $mc(k, "feet"), 4.5, 0.3, { KnockbackPower: 10, Lift: 16 });
		});
		def("SK_corgi_3", 3, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Curl", 0.3);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.25)))))) {
				return;
			}
			$mc(k, "pose", "Roll", 0.8);
			let d = $mc(k, "dir");
			$mc(k, "fx", "Streak", { Model: k.f.Model, Color: C(255, 230, 190), Duration: 0.6, Width: 1.2 });
			(yield* $cy($mc(k, "dash", $add($mc(k, "tpos"), $mul(d, 8)), 0.55, { frac: 1, radius: 3.5, opts: { Knockback: $add($mul(d, 30), $mul(UP, 25)) }, on: function (e) {
				$mc(k, "burst", "Crumbs", e.Root.Position, { Count: 8 });
				$mc(k, "pop", "ROLL!", $add(e.Root.Position, $mul(UP, 4)), C(255, 225, 175), 0.8);
			} })));
			$mc(k, "burst", "Crumbs", $mc(k, "feet"), { Count: 6 });
		});
		def("SK_salsicha_2", 2, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Throw", 0.5);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.22)))))) {
				return;
			}
			let d = $mc(k, "dir");
			let p1 = $mc(k, "tground");
			let p2 = $1((yield* $cy(G($add(p1, $mul(d, 1.5))))));
			let p3 = $1((yield* $cy(G($add(p1, $mul(d, 2.5))))));
			let t1 = $mc(k, "shoot", "HotDog", { points: [p1], speed: 45, arc: 6, frac: 0.5, radius: 4 });
			$mc(k, "later", t1, function () {
				$mc(k, "shoot", "HotDog", { from: $add(p1, UP), points: [p2], speed: 12, arc: 3, frac: 0.3, radius: 4 });
			});
			$mc(k, "later", $add(t1, 0.3), function () {
				$mc(k, "shoot", "HotDog", { from: $add(p2, UP), points: [p3], speed: 10, arc: 2, frac: 0.2, radius: 4 });
			});
			$mc(k, "pose", "Bow", 0.6);
		});
		def("SK_salsicha_3", 3, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Dive", 0.75);
			$mc(k, "burst", "Dirt", $mc(k, "feet"), { Count: 8 });
			if (!$t($1((yield* $cy($mc(k, "wait", 0.6)))))) {
				return;
			}
			let target = $mc(k, "tground");
			$mc(k, "path", "Crack", $mc(k, "feet"), target, { Duration: 1, Color: C(120, 90, 60) });
			$mc(k, "pose", "Vanish", 0.45);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.4)))))) {
				return;
			}
			(yield* $cy($mc(k, "blink", target, 1, 0.01)));
			$mc(k, "pose", "Leap", 0.5);
			$mc(k, "burst", "Dirt", target, { Count: 14, Radius: 8 });
			$mc(k, "impact", target, 5, C(170, 130, 80), true);
			$mc(k, "area", target, 5, 1, { KnockbackPower: 6, Lift: 42 });
			(yield* $cy($mc(k, "leap", $add(target, $mul($mc(k, "dir"), 0.5)), 4, 0.35)));
		});
		def("SK_chihuahua_2", 2, function* (k) {
			if (!$t($1((yield* $cy($mc(k, "reach", $mul($mc(k, "R", 18), 0.7), 1)))))) {
				return;
			}
			$mc(k, "face");
			$mc(k, "pose", "Focus", 0.35);
			$mc(k, "pop", "!!!", undefined, C(255, 80, 80), 0.8);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.35)))))) {
				return;
			}
			$mc(k, "pose", "Bark", 1);
			for (let i = 1, $v10 = 3; i <= $v10; i++) {
				$mc(k, "face");
				let d = $mc(k, "dir");
				$mc(k, "fx", "S_Cone", { Kind: "Sound", Model: k.f.Model, Length: $mc(k, "R", 18), Angle: 26, Duration: 0.25, Color: C(255, 150, 210) });
				$mc(k, "pop", "YAP!", $add($mc(k, "mouth"), UP), C(255, 120, 200), (0.6 + (i * 0.15)));
				$mc(k, "inCone", $mc(k, "me"), d, 18, 26, ($n(((i === 3) && 0.4)) ?? 0.3), { Knockback: $mul(d, (($n(((i === 3) && 30)) ?? 4))) }, ($n(((i === 3) && function (e) {
					$mc(k, "stun", e, 1, "Dizzy");
				})) ?? undefined));
				if (!$t($1((yield* $cy($mc(k, "wait", 0.32)))))) {
					return;
				}
			}
		});
		def("SK_chihuahua_3", 3, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			let step = (math.max(0, $sub($mc(k, "dist"), 4)) / 3);
			for (let i = 1, $v11 = 3; i <= $v11; i++) {
				$mc(k, "pose", "Bounce", 0.45);
				if (!$t($1((yield* $cy($mc(k, "leap", $add($mc(k, "me"), $mul($mc(k, "dir"), step)), 2.5, 0.3)))))) {
					return;
				}
				let g = $mc(k, "feet");
				$mc(k, "pop", ($n(((i === 3) && "GRRR!")) ?? "!"), $add($mc(k, "me"), $mul(UP, 3)), C(255, 90, 120), (0.6 + (i * 0.2)));
				$mc(k, "shock", g, (6 + (i * 2)), C(255, 140, 200));
				$mc(k, "ringOut", "Note", g, 1, (6 + (i * 2)), { Count: 6, Time: 0.4, Height: 1.5, Color: C(255, 120, 200) });
				$mc(k, "area", g, (6 + (i * 2)), ($n(((i === 3) && 0.5)) ?? 0.25), { KnockbackPower: ($n(((i === 3) && 40)) ?? 12), Lift: 12 });
			}
		});
	};
}
