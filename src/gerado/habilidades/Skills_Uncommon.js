// Gerado automaticamente de server/Services/SpecialsPacks/Skills_Uncommon.lua (código do jogo Roblox) por tools/lua2js — não edite à mão.
import { $t, $a, $n, $1, $M, $mv, $lst, $get, $set, $tm, $tc, $len, $cat, $eq, $add, $sub, $mul, $div, $mod, $pow, $idiv, $unm, $mc, $cy, $sp, $sp1, $W, $WS, $ins, $ins3, $arr, $pairs, $iter, $pcallG, $warnWait } from '../../rbx/lua.js';

export default function ($G, $script) {
	let require = $G["require"], Color3 = $G["Color3"], Vector3 = $G["Vector3"], ipairs = $G["ipairs"], table = $G["table"], math = $G["math"];
	let SkillKit = $sp1(require($script.Parent.Parent.SkillKit));
	let C = Color3.fromRGB;
	let UP = Vector3.new(0, 1, 0);
	let G = SkillKit.Ground;
	return function (Specials, _Fighters) {
		let def = function (id, slot, fn) {
			$sp(SkillKit.def(Specials, id, slot, fn));
		};
		def("SK_snow_husky_2", 2, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Bow", 0.3);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.3)))))) {
				return;
			}
			let d = $mc(k, "dir");
			let from = $mc(k, "feet");
			let to = $add($mc(k, "tpos"), $mul(d, 7));
			$mc(k, "pose", "Slide", 0.7);
			$mc(k, "path", "Ice", from, $1((yield* $cy(G(to)))), { Duration: 2, Color: C(190, 235, 255), Width: 3 });
			(yield* $cy($mc(k, "dash", to, 0.5, { frac: 0.8, radius: 3.5, opts: { Knockback: $add($mul(d, 22), $mul(UP, 10)), Color: C(190, 235, 255) }, on: function (e) {
				$mc(k, "slow", e, 2.5, 0.5);
			} })));
			$mc(k, "burst", "Snow", $mc(k, "feet"), { Count: 10 });
			$mc(k, "area", $mc(k, "feet"), 5, 0.2, { Color: C(190, 235, 255) });
		});
		def("SK_snow_husky_3", 3, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Howl", 1);
			$mc(k, "fx", "Roar", { Model: k.f.Model, Color: C(200, 235, 255), Howl: true });
			if (!$t($1((yield* $cy($mc(k, "wait", 0.45)))))) {
				return;
			}
			let c = $mc(k, "tground");
			$mc(k, "zone", "Snow", c, 8, 2.2, 0.65, { every: 0.55, color: C(220, 240, 255), on: function (e) {
				$mc(k, "slow", e, 0.8, 0.6);
			} });
			$mc(k, "ringOut", "Snowflake", c, 9, 1.5, { Count: 10, Time: 2, Height: 3, Swirl: 6, Color: C(210, 240, 255) });
			$mc(k, "later", 2.1, function () {
				$mc(k, "impact", c, 7, C(190, 235, 255));
				for (let $v1 = 0, $v2 = $arr($mc(k, "area", c, 8, 0.35, { Color: C(190, 235, 255) })); $v1 < $v2.length; $v1++) {
					let e = $v2[$v1];
					if (e == null) break;
					$mc(k, "freeze", e, 1.4);
				}
			});
		});
		def("SK_armored_doberman_2", 2, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Headbutt", 0.35);
			$mc(k, "aura", "Metal", 1, C(200, 210, 230));
			if (!$t($1((yield* $cy($mc(k, "wait", 0.3)))))) {
				return;
			}
			let d = $mc(k, "dir");
			$mc(k, "pose", "Charge", 0.6);
			$mc(k, "fx", "Streak", { Model: k.f.Model, Color: C(210, 220, 240), Duration: 0.5, Width: 1.4 });
			(yield* $cy($mc(k, "dash", $add($mc(k, "tpos"), $mul(d, 9)), 0.45, { frac: 1, radius: 3.5, opts: { Knockback: $add($mul(d, 40), $mul(UP, 16)), Color: C(210, 220, 240) }, on: function (e) {
				$mc(k, "impact", e.Root.Position, 4, C(210, 220, 240));
			} })));
		});
		def("SK_armored_doberman_3", 3, function* (k) {
			if (!$t($1((yield* $cy($mc(k, "approach", 3, 1)))))) {
				return;
			}
			$mc(k, "pose", "Guard", 1);
			$mc(k, "shield", 3, 0.4, "Stone");
			$mc(k, "shock", $mc(k, "feet"), 6, C(170, 160, 150));
			if (!$t($1((yield* $cy($mc(k, "wait", 0.9)))))) {
				return;
			}
			$mc(k, "pose", "Stomp", 0.5);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.3)))))) {
				return;
			}
			let g = $mc(k, "feet");
			$mc(k, "shock", g, 11, C(170, 150, 120), true);
			$mc(k, "burst", "Rocks", g, { Count: 10 });
			$mc(k, "area", g, 11, 1, { KnockbackPower: 30, Lift: 20, Color: C(190, 170, 140) });
		});
		def("SK_boxer_2", 2, function* (k) {
			if (!$t($1((yield* $cy($mc(k, "approach", 3, 1)))))) {
				return;
			}
			$mc(k, "face");
			$mc(k, "pose", "Rear", 0.8);
			let words = ["POW!", "BAM!"];
			for (let i = 1, $v3 = 2; i <= $v3; i++) {
				if (!$t($1((yield* $cy($mc(k, "wait", 0.22)))))) {
					return;
				}
				$mc(k, "pop", $get(words, i), $add($mc(k, "tpos"), $mul(UP, 3)), C(255, 220, 80), 0.8);
				$mc(k, "impact", $mc(k, "tpos"), 2.5, C(255, 220, 80));
				$mc(k, "hit", 0.3, { Knockback: $mul($mc(k, "dir"), 8), Color: C(255, 220, 80) });
			}
			if (!$t($1((yield* $cy($mc(k, "wait", 0.2)))))) {
				return;
			}
			$mc(k, "pose", "Uppercut", 0.6);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.25)))))) {
				return;
			}
			$mc(k, "pop", "KO!", $add($mc(k, "tpos"), $mul(UP, 4)), C(255, 120, 60));
			$mc(k, "impact", $mc(k, "tpos"), 4, C(255, 200, 80));
			$mc(k, "hit", 0.4, { Knockback: $add($mul($mc(k, "dir"), 18), $mul(UP, 42)), Color: C(255, 200, 80) });
		});
		def("SK_boxer_3", 3, function* (k) {
			$mc(k, "stop");
			let c = $mc(k, "tground");
			$mc(k, "pose", "Dash", 1.1);
			$mc(k, "aura", "Haste", 1, C(210, 245, 255));
			$mc(k, "fx", "Streak", { Model: k.f.Model, Color: C(230, 250, 255), Duration: 0.9, Width: 1.1 });
			if (!$t($1((yield* $cy($mc(k, "circle", c, 7, 1, 0.75)))))) {
				return;
			}
			$mc(k, "face", c);
			$mc(k, "ringOut", "Feather", c, 9, 1, { Count: 10, Time: 0.35, Height: 1.5, Swirl: 3, Color: C(235, 250, 255) });
			$mc(k, "shock", c, 8, C(220, 245, 255));
			$mc(k, "area", c, 8, 0.5, { KnockbackPower: 4, Lift: 12, Color: C(220, 245, 255) });
			if (!$t($1((yield* $cy($mc(k, "wait", 0.25)))))) {
				return;
			}
			$mc(k, "shock", c, 6, C(220, 245, 255));
			$mc(k, "area", c, 7, 0.5, { KnockbackPower: 20, Lift: 18, Color: C(220, 245, 255) });
		});
		def("SK_golden_2", 2, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Throw", 0.5);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.22)))))) {
				return;
			}
			let t = $mc(k, "shoot", "Ball", { speed: 60, arc: 3, frac: 0.75, back: true, backFrac: 0.25, radius: 3 });
			$mc(k, "pose", "Bow", $mul(t, 2));
			if (!$t($1((yield* $cy($mc(k, "wait", $mul(t, 1.9))))))) {
				return;
			}
			$mc(k, "pose", "Victory", 0.5);
			$mc(k, "heal", 0.05);
		});
		def("SK_golden_3", 3, function* (k) {
			if (!$t($1((yield* $cy($mc(k, "approach", 3, 1)))))) {
				return;
			}
			$mc(k, "pose", "Sit", 1.3);
			$mc(k, "aura", "Holy", 1.6, C(255, 220, 120));
			for (let i = 1, $v4 = 3; i <= $v4; i++) {
				if (!$t($1((yield* $cy($mc(k, "wait", 0.4)))))) {
					return;
				}
				let g = $mc(k, "feet");
				$mc(k, "shock", g, (7 + (i * 2)), C(255, 220, 120));
				$mc(k, "burst", "Hearts", $mc(k, "me"), { Count: 3, Color: C(255, 150, 170) });
				$mc(k, "area", g, (7 + (i * 2)), 0.333, { KnockbackPower: 10, Lift: 8, Color: C(255, 220, 120) });
				$mc(k, "heal", 0.03);
			}
		});
		def("SK_dalmatian_2", 2, function* (k) {
			if (!$t($1((yield* $cy($mc(k, "reach", $mul($mc(k, "R", 26), 0.75), 1)))))) {
				return;
			}
			$mc(k, "face");
			$mc(k, "pose", "Open", 1);
			(yield* $cy($mc(k, "beam", "Water", { length: 26, width: 3, time: 0.9, ticks: 3, frac: 1, on: function (e) {
				$mc(k, "knock", e, $mc(k, "me"), 14, 4);
			} })));
			$mc(k, "burst", "Drops", $mc(k, "tpos"), { Count: 8 });
		});
		def("SK_dalmatian_3", 3, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Shake", 0.9);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.3)))))) {
				return;
			}
			let pts = $mc(k, "around", $mc(k, "tpos"), 5, 5, $mc(k, "rand", 0, 70), 0.4);
			$ins3(pts, 1, $mc(k, "tground"));
			$mc(k, "shoot", "Ink", { points: pts, speed: 35, arc: 6, frac: 0.18, radius: 4, impact: "Splash", size: 0.9, gap: 0.04 });
		});
		def("SK_pastor_alemao_2", 2, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Sniff", 0.5);
			$mc(k, "mark", k.t, "Reticle", 0.9);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.5)))))) {
				return;
			}
			$mc(k, "pose", "Leap", 0.5);
			if (!$t($1((yield* $cy($mc(k, "leap", $sub($mc(k, "tpos"), $mul($mc(k, "dir"), 2)), 5, 0.42)))))) {
				return;
			}
			$mc(k, "face");
			$mc(k, "fx", "Bite", { Model: k.f.Model, Head: 1 });
			$mc(k, "impact", $mc(k, "tground"), 4, C(255, 230, 200));
			$mc(k, "hit", 0.5, { Color: C(255, 90, 70) });
			$mc(k, "stun", k.t, 1.3, "Pin");
			for (let _ = 1, $v5 = 2; _ <= $v5; _++) {
				if (!$t($1((yield* $cy($mc(k, "wait", 0.3)))))) {
					return;
				}
				$mc(k, "fx", "Bite", { Model: k.f.Model, Head: 1 });
				$mc(k, "fx", "BiteMark", { Position: $mc(k, "tpos"), Direction: $mc(k, "dir"), Color: C(255, 230, 210) });
				$mc(k, "hit", 0.25, { Color: C(255, 90, 70) });
			}
		});
		def("SK_pastor_alemao_3", 3, function* (k) {
			if (!$t($1((yield* $cy($mc(k, "approach", 4, 1)))))) {
				return;
			}
			$mc(k, "face");
			$mc(k, "aura", "Siren", 1.6);
			$mc(k, "pose", "Bark", 1);
			for (let i = 1, $v6 = 3; i <= $v6; i++) {
				if (!$t($1((yield* $cy($mc(k, "wait", 0.32)))))) {
					return;
				}
				let col = ($n((($mod(i, 2) === 1) && C(255, 60, 60))) ?? C(70, 120, 255));
				$mc(k, "shock", $mc(k, "feet"), (5 + (i * 2.5)), col);
				$mc(k, "area", $mc(k, "feet"), (5 + (i * 2.5)), 0.2, { Color: col });
			}
			if (!$t($1((yield* $cy($mc(k, "wait", 0.2)))))) {
				return;
			}
			for (let $v7 = 0, $v8 = $arr($mc(k, "area", $mc(k, "feet"), 12, 0.4, { Color: C(255, 240, 120) })); $v7 < $v8.length; $v7++) {
				let e = $v8[$v7];
				if (e == null) break;
				$mc(k, "pillar", "Lightning", $1((yield* $cy(G(e.Root.Position)))), 2, { Color: C(170, 200, 255) });
				$mc(k, "stun", e, 1, "Shock");
			}
		});
		def("SK_border_collie_2", 2, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Throw", 0.5);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.22)))))) {
				return;
			}
			let far = $add($mc(k, "tground"), $mul($mc(k, "dir"), 4));
			let t = $mc(k, "shoot", "Frisbee", { points: [far], speed: 45, arc: 4, frac: 0.5, radius: 4, color: C(235, 70, 60) });
			if (!$t($1((yield* $cy($mc(k, "wait", $mul(t, 0.4))))))) {
				return;
			}
			$mc(k, "pose", "Leap", 0.8);
			if (!$t($1((yield* $cy($mc(k, "leap", far, 7, 0.6, { frac: 0.5, radius: 4 })))))) {
				return;
			}
			$mc(k, "pose", "Victory", 0.5);
			$mc(k, "pop", "CATCH!", undefined, C(255, 240, 120), 0.9);
		});
		def("SK_border_collie_3", 3, function* (k) {
			$mc(k, "stop");
			let c = $mc(k, "tground");
			$mc(k, "pose", "Dash", 1.2);
			$mc(k, "fx", "Streak", { Model: k.f.Model, Color: C(235, 250, 245), Duration: 0.9, Width: 1 });
			let a0 = $mc(k, "rand", 0, 360);
			for (let i = 1, $v9 = 3; i <= $v9; i++) {
				let a = math.rad($add(a0, (i * 120)));
				let p = $add(c, $mul(Vector3.new(math.cos(a), 0, math.sin(a)), 9));
				if (!$t($1((yield* $cy($mc(k, "blink", p, 2, 0.05)))))) {
					return;
				}
				$mc(k, "path", "Wind", p, c, { Duration: 0.5, Width: 3 });
				for (let $v10 = 0, $v11 = $arr($mc(k, "enemies", c, 13)); $v10 < $v11.length; $v10++) {
					let e = $v11[$v10];
					if (e == null) break;
					$mc(k, "pull", e, c, 18, 0.2);
				}
				if (!$t($1((yield* $cy($mc(k, "wait", 0.15)))))) {
					return;
				}
			}
			$mc(k, "face", c);
			$mc(k, "pose", "Bark", 0.4);
			$mc(k, "shock", c, 8, C(235, 250, 245));
			$mc(k, "area", c, 8, 1, { KnockbackPower: 26, Lift: 12, Color: C(235, 250, 245) });
		});
		def("SK_sao_bernardo_2", 2, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Throw", 0.5);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.22)))))) {
				return;
			}
			let t = $mc(k, "shoot", "Barrel", { speed: 40, arc: 6, frac: 0.85, radius: 5, impact: "Snow" });
			$mc(k, "later", t, function () {
				let p = $mc(k, "tground");
				$mc(k, "burst", "Snow", p, { Count: 12 });
				$mc(k, "zone", "Snow", p, 5, 1.5, 0.15);
			});
			$mc(k, "pose", "Sit", 0.8);
			if ($t($1((yield* $cy($mc(k, "wait", 0.4)))))) {
				$mc(k, "heal", 0.06);
				$mc(k, "pop", "COCOA!", undefined, C(200, 140, 90), 0.7);
			}
		});
		def("SK_sao_bernardo_3", 3, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Rear", 0.6);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.5)))))) {
				return;
			}
			$mc(k, "pose", "Slam", 0.4);
			let d = $mc(k, "dir");
			let from = $add($mc(k, "feet"), $mul(d, 3));
			let to = $add(from, $mul(d, 28));
			$mc(k, "shake", from, 0.4, 40);
			$mc(k, "shoot", "Snowball", { from: $add(from, $mul(UP, 2.5)), points: [to], speed: 32, arc: 0, size: $mul(4, k.A), frac: 0, impact: "Snow" });
			$mc(k, "wave", "Snow", { silent: true, from: from, dir: d, length: 28, width: 7, speed: 32, frac: 1, on: function (e) {
				$mc(k, "launch", e, 30);
				$mc(k, "burst", "Snow", e.Root.Position, { Count: 6 });
			} });
		});
		def("SK_akita_2", 2, function* (k) {
			if (!$t($1((yield* $cy($mc(k, "approach", 4, 1)))))) {
				return;
			}
			$mc(k, "face");
			$mc(k, "pose", "Guard", 0.9);
			let d = $mc(k, "dir");
			let base = $add($mc(k, "feet"), $mul(d, 3));
			$mc(k, "shield", 1.2, 0.3, "Stone");
			$mc(k, "prop", "Slab", { Position: base, Look: d, Path: "Rise", Time: 0.35, Hold: 0.25, Depth: 6, Size: $mul(0.9, k.A), End: "Sink" });
			if (!$t($1((yield* $cy($mc(k, "wait", 0.6)))))) {
				return;
			}
			$mc(k, "pose", "Headbutt", 0.5);
			$mc(k, "prop", "Slab", { Position: base, Look: d, Path: "Swing", Time: 0.5, Hold: 0.4, Reach: $mul(5, k.A), Size: $mul(0.9, k.A), Impact: "Rock", End: "Sink" });
			if (!$t($1((yield* $cy($mc(k, "wait", 0.5)))))) {
				return;
			}
			let hitAt = $add(base, $mul(d, 4.5));
			$mc(k, "area", hitAt, 6, 1, { KnockbackPower: 22, Lift: 14, Color: C(170, 150, 130) });
		});
		def("SK_akita_3", 3, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Crouch", 0.3);
			$mc(k, "tele", $mc(k, "tground"), 9, 0.95);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.3)))))) {
				return;
			}
			$mc(k, "pose", "Leap", 0.7);
			if (!$t($1((yield* $cy($mc(k, "leap", $mc(k, "tpos"), 10, 0.65)))))) {
				return;
			}
			$mc(k, "pose", "Slam", 0.4);
			let g = $mc(k, "feet");
			$mc(k, "ringOut", "Rock", g, 2, 9, { Count: 8, Time: 0.4, Rise: 1, Size: 1.2 });
			$mc(k, "shock", g, 9, C(175, 140, 95), true);
			$mc(k, "area", g, 9, 1, { KnockbackPower: 20, Lift: 30, Color: C(190, 160, 120) });
		});
		def("SK_galgo_2", 2, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			let d = $mc(k, "dir");
			let a = $mc(k, "feet");
			let b = $add($mc(k, "tpos"), $mul(d, 8));
			$mc(k, "pose", "Dash", 1);
			$mc(k, "aura", "Haste", 1);
			$mc(k, "path", "Wind", a, $1((yield* $cy(G(b)))), { Duration: 0.9, Width: 3 });
			if (!$t($1((yield* $cy($mc(k, "dash", b, 0.35, { frac: 0.5, radius: 3.5, opts: { Knockback: $mul(d, 12) } })))))) {
				return;
			}
			$mc(k, "face", a);
			$mc(k, "path", "Wind", $1((yield* $cy(G(b)))), a, { Duration: 0.9, Width: 3 });
			(yield* $cy($mc(k, "dash", a, 0.35, { frac: 0.5, radius: 3.5, opts: { Knockback: $mul($unm(d), 12) } })));
		});
		def("SK_galgo_3", 3, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			let d = $mc(k, "dir");
			$mc(k, "pose", "Crouch", 1);
			$mc(k, "prop", "Lights", { Position: $add($mc(k, "feet"), $mul(Vector3.new(d.Z, 0, (-d.X)), 4)), Look: $unm(d), Path: "Countdown", Time: 0.9, Size: 0.8 });
			$mc(k, "path", "Race", $mc(k, "feet"), $1((yield* $cy(G($add($mc(k, "feet"), $mul(d, 30)))))), { Duration: 1.8, Width: 2.5, Color: C(40, 40, 50) });
			if (!$t($1((yield* $cy($mc(k, "wait", 0.95)))))) {
				return;
			}
			$mc(k, "pose", "Dash", 0.6);
			$mc(k, "aura", "Haste", 0.6);
			$mc(k, "fx", "Streak", { Model: k.f.Model, Color: C(255, 230, 90), Duration: 0.5, Width: 1.6 });
			(yield* $cy($mc(k, "dash", $add($mc(k, "tpos"), $mul(d, 10)), 0.35, { frac: 1, radius: 4, opts: { Knockback: $add($mul(d, 70), $mul(UP, 30)), Color: C(255, 230, 90) }, on: function (e) {
				$mc(k, "pop", "ZOOM!", $add(e.Root.Position, $mul(UP, 4)), C(255, 230, 90));
				$mc(k, "impact", e.Root.Position, 5, C(255, 230, 90));
			} })));
		});
	};
}
