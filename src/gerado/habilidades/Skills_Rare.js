// Gerado automaticamente de server/Services/SpecialsPacks/Skills_Rare.lua (código do jogo Roblox) por tools/lua2js — não edite à mão.
import { $t, $a, $n, $1, $M, $mv, $lst, $get, $set, $tm, $tc, $len, $cat, $eq, $add, $sub, $mul, $div, $mod, $pow, $idiv, $unm, $mc, $cy, $sp, $sp1, $W, $WS, $ins, $ins3, $arr, $pairs, $iter, $pcallG, $warnWait } from '../../rbx/lua.js';

export default function ($G, $script) {
	let require = $G["require"], Color3 = $G["Color3"], Vector3 = $G["Vector3"], math = $G["math"], ipairs = $G["ipairs"], table = $G["table"], string = $G["string"];
	let SkillKit = $sp1(require($script.Parent.Parent.SkillKit));
	let C = Color3.fromRGB;
	let UP = Vector3.new(0, 1, 0);
	let G = SkillKit.Ground;
	let YELLOW = C(255, 235, 90);
	return function (Specials, _Fighters) {
		let def = function (id, slot, fn) {
			$sp(SkillKit.def(Specials, id, slot, fn));
		};
		def("SK_storm_pup_2", 2, function* (k) {
			$mc(k, "stop");
			$mc(k, "charge", 0.35, YELLOW);
			$mc(k, "pose", "Crouch", 0.35);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.35)))))) {
				return;
			}
			let c = $mc(k, "tpos");
			let prev = $mc(k, "feet");
			$mc(k, "pose", "Dash", 1);
			let a0 = $mc(k, "rand", 0, 360);
			for (let i = 1, $v1 = 3; i <= $v1; i++) {
				let a = math.rad($add(a0, (i * 120)));
				let p = $1((yield* $cy(G($add(c, $mul(Vector3.new(math.cos(a), 0, math.sin(a)), 6))))));
				if (!$t($1((yield* $cy($mc(k, "blink", p, 2, 0.03)))))) {
					return;
				}
				let now = $mc(k, "feet");
				$mc(k, "path", "Bolt", prev, now, { Color: YELLOW, Width: 2 });
				let seg = $sub(now, prev);
				$mc(k, "inLine", prev, seg, seg.Magnitude, 4, 0.15, { Color: YELLOW });
				prev = now;
				if (!$t($1((yield* $cy($mc(k, "wait", 0.08)))))) {
					return;
				}
			}
			(yield* $cy($mc(k, "blink", $sub(c, $mul($mc(k, "dir", c), 2.5)), 1, 0.01)));
			$mc(k, "face", c);
			$mc(k, "pillar", "Lightning", $1((yield* $cy(G(c)))), 2, { Color: YELLOW });
			$mc(k, "hit", 0.55, { Color: YELLOW });
			$mc(k, "stun", k.t, 1, "Shock");
		});
		def("SK_storm_pup_3", 3, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Summon", 1.6);
			let c = $mc(k, "tground");
			$mc(k, "zone", "Storm", c, 9, 2.3, 0);
			for (let i = 1, $v2 = 4; i <= $v2; i++) {
				if (!$t($1((yield* $cy($mc(k, "wait", 0.35)))))) {
					return;
				}
				let p = ($n(((((i === 1) || (i === 4))) && $mc(k, "tground"))) ?? $1((yield* $cy(G($add(c, Vector3.new($mc(k, "rand", (-4), 4), 0, $mc(k, "rand", (-4), 4))))))));
				$mc(k, "tele", p, 3.5, 0.25, YELLOW);
				$mc(k, "later", 0.25, function () {
					$mc(k, "pillar", "Lightning", p, 2.2, { Color: YELLOW });
					for (let $v3 = 0, $v4 = $arr($mc(k, "area", p, 4.5, 0.25, { Color: YELLOW })); $v3 < $v4.length; $v3++) {
						let e = $v4[$v3];
						if (e == null) break;
						$mc(k, "stun", e, 0.6, "Shock");
					}
				});
			}
		});
		def("SK_stone_hound_2", 2, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Dig", 0.4);
			$mc(k, "burst", "Rocks", $add($mc(k, "feet"), $mul($mc(k, "dir"), 2)), { Count: 6 });
			if (!$t($1((yield* $cy($mc(k, "wait", 0.35)))))) {
				return;
			}
			$mc(k, "pose", "Throw", 0.5);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.2)))))) {
				return;
			}
			let t = $mc(k, "shoot", "Boulder", { speed: 40, arc: 7, frac: 0.8, radius: 5, size: 1.6, impact: "Rock" });
			$mc(k, "later", t, function () {
				let p = ($n(($a($mc(k, "real")) && $mc(k, "tground"))) ?? undefined);
				if ($t(p)) {
					$mc(k, "shock", p, 7, C(150, 130, 110), true);
					for (let $v5 = 0, $v6 = $arr($mc(k, "area", p, 7, 0.2, { Color: C(150, 130, 110) })); $v5 < $v6.length; $v5++) {
						let e = $v6[$v5];
						if (e == null) break;
						$mc(k, "stun", e, 0.7, "Dizzy");
					}
				}
			});
		});
		def("SK_stone_hound_3", 3, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "aura", "Stone", 2.2, C(140, 125, 110));
			$mc(k, "shield", 2, 0.3);
			$mc(k, "pose", "Curl", 0.35);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.3)))))) {
				return;
			}
			$mc(k, "pose", "Roll", 1.3);
			let d = $mc(k, "dir");
			let a = $mc(k, "feet");
			let b = $add($mc(k, "tpos"), $mul(d, 7));
			if (!$t($1((yield* $cy($mc(k, "dash", b, 0.45, { frac: 0.4, radius: 3.5, opts: { Knockback: $add($mul(d, 20), $mul(UP, 14)) } })))))) {
				return;
			}
			if (!$t($1((yield* $cy($mc(k, "dash", a, 0.45, { frac: 0.4, radius: 3.5, opts: { Knockback: $add($mul($unm(d), 20), $mul(UP, 14)) } })))))) {
				return;
			}
			$mc(k, "pose", "Stomp", 0.4);
			let g = $mc(k, "feet");
			$mc(k, "shoot", "Rock", { from: $add(g, $mul(UP, 2)), points: $mc(k, "around", g, 9, 6, $mc(k, "rand", 0, 60)), speed: 35, arc: 4, frac: 0.2, radius: 3, size: 0.9 });
		});
		def("SK_robo_dog_2", 2, function* (k) {
			if (!$t($1((yield* $cy($mc(k, "reach", 22, 1)))))) {
				return;
			}
			$mc(k, "face");
			$mc(k, "pose", "Aim", 0.4);
			$mc(k, "mark", k.t, "Reticle", 0.5);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.35)))))) {
				return;
			}
			$mc(k, "pose", "Open", 1);
			(yield* $cy($mc(k, "beam", "Laser", { length: 30, width: 3, time: 0.9, ticks: 4, frac: 1, sweep: 10, color: C(255, 60, 60) })));
		});
		def("SK_robo_dog_3", 3, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Aim", 0.6);
			$mc(k, "charge", 0.45, C(255, 120, 60));
			if (!$t($1((yield* $cy($mc(k, "wait", 0.45)))))) {
				return;
			}
			$mc(k, "pose", "Spit", 0.7);
			let pts = $mc(k, "scatter", $mc(k, "tpos"), 5, 6, true);
			$mc(k, "shoot", "Missile", { from: $add($mc(k, "me"), $mul(UP, 2)), points: pts, speed: 45, arc: 10, frac: 0.17, radius: 4, gap: 0.08, size: 0.8, trail: "Smoke", impact: "Explode" });
		});
		def("SK_horned_pup_2", 2, function* (k) {
			if (!$t($1((yield* $cy($mc(k, "approach", 8, 1)))))) {
				return;
			}
			$mc(k, "face");
			$mc(k, "pose", "Headbutt", 0.6);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.2)))))) {
				return;
			}
			let d = $mc(k, "dir");
			(yield* $cy($mc(k, "dash", $sub($mc(k, "tpos"), $mul(d, 1.5)), 0.2, { frac: 0.55, radius: 3, opts: { Color: C(255, 220, 160) }, on: function (e) {
				$mc(k, "launch", e, 45);
				$mc(k, "impact", e.Root.Position, 4, C(255, 220, 160));
			} })));
			if (!$t($1((yield* $cy($mc(k, "wait", 0.45)))))) {
				return;
			}
			$mc(k, "pose", "Uppercut", 0.5);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.2)))))) {
				return;
			}
			$mc(k, "pop", "TOSS!", $add($mc(k, "tpos"), $mul(UP, 4)), C(255, 210, 150));
			$mc(k, "hit", 0.45, { Knockback: $add($mul(d, 35), $mul(UP, 15)), Color: C(255, 220, 160) });
		});
		def("SK_horned_pup_3", 3, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Stomp", 0.8);
			$mc(k, "shake", $mc(k, "me"), 0.4, 40);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.5)))))) {
				return;
			}
			let c = $mc(k, "tground");
			let d = $mc(k, "dir");
			let side = Vector3.new((-d.Z), 0, d.X);
			let pts = [];
			for (let i = (-1), $v7 = 1; i <= $v7; i++) {
				$ins(pts, $1((yield* $cy(G($add($add(c, $mul($mul(side, i), 3)), $mul(d, 1.5)))))));
			}
			$mc(k, "summon", "Bull", { from: $sub($mc(k, "feet"), $mul(d, 4)), points: pts, time: 0.6, gap: 0.12, frac: 0.34, radius: 4, color: C(255, 170, 90), path: "Run" });
			$mc(k, "path", "Crack", $mc(k, "feet"), $1((yield* $cy(G($add(c, $mul(d, 6)))))), { Duration: 1.2, Color: C(110, 80, 50) });
		});
		def("SK_skull_dog_2", 2, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Throw", 0.5);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.22)))))) {
				return;
			}
			let t = $mc(k, "shoot", "Bone", { speed: 50, arc: 2, frac: 0.75, size: 1.6, back: true, backFrac: 0.25, radius: 3.5 });
			$mc(k, "pose", "Bow", $mul(t, 1.9));
		});
		def("SK_skull_dog_3", 3, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Shake", 0.8);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.4)))))) {
				return;
			}
			let c = $mc(k, "tground");
			$mc(k, "zone", "Grave", c, 7, 1.8, 0);
			$mc(k, "ringOut", "Bone", c, 7, 2, { Count: 8, Time: 0.45, Height: 1, Rise: 2.5, Size: 1.1 });
			$mc(k, "later", 0.4, function () {
				$mc(k, "burst", "Bones", c, { Count: 8 });
				for (let $v8 = 0, $v9 = $arr($mc(k, "area", c, 7, 0.7, { Color: C(190, 130, 255) })); $v8 < $v9.length; $v8++) {
					let e = $v9[$v8];
					if (e == null) break;
					$mc(k, "curse", e, 3.5, 1.2);
				}
			});
			$mc(k, "later", 1.2, function () {
				$mc(k, "area", c, 7, 0.3, { Color: C(190, 130, 255) });
				$mc(k, "burst", "Bones", c, { Count: 5 });
			});
		});
		def("SK_crystal_hound_2", 2, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Stomp", 0.4);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.25)))))) {
				return;
			}
			$mc(k, "wave", "Crystal", { length: math.min(36, $add($mc(k, "dist"), 6)), width: 5, speed: 45, frac: 0.8, color: C(190, 230, 255), on: function (e) {
				$mc(k, "launch", e, 26);
				$mc(k, "slow", e, 1.5, 0.6);
			} });
			$mc(k, "later", (math.min(36, $add($mc(k, "dist"), 6)) / 45), function () {
				let p = ($n(($a($mc(k, "real")) && $mc(k, "tground"))) ?? undefined);
				if ($t(p)) {
					$mc(k, "fx", "S_Burst", { Kind: "Crystals", Position: p, Count: 10, Color: C(200, 235, 255) });
					$mc(k, "area", p, 5, 0.2, { Color: C(190, 230, 255) });
				}
			});
		});
		def("SK_crystal_hound_3", 3, function* (k) {
			if (!$t($1((yield* $cy($mc(k, "reach", 22, 1)))))) {
				return;
			}
			$mc(k, "face");
			$mc(k, "pose", "Focus", 0.5);
			$mc(k, "charge", 0.5, C(220, 200, 255));
			if (!$t($1((yield* $cy($mc(k, "wait", 0.5)))))) {
				return;
			}
			$mc(k, "pose", "Open", 0.9);
			let d = $mc(k, "dir");
			for (let $v10 = 0, $v11 = $arr([(-22), 22]); $v10 < $v11.length; $v10++) {
				let ang = $v11[$v10];
				if (ang == null) break;
				$mc(k, "fx", "S_Beam", { Kind: "Ice", Model: k.f.Model, From: $mc(k, "mouth"), To: $add($mc(k, "mouth"), $mul($1((yield* $cy(SkillKit.Turn(d, ang)))), 22)), Width: $mc(k, "R", 2), Duration: 0.8 });
				$mc(k, "inLine", $mc(k, "me"), $1((yield* $cy(SkillKit.Turn(d, ang)))), 22, 3, 0.15, { Color: C(190, 230, 255) }, function (e) {
					$mc(k, "slow", e, 1.5, 0.6);
				});
			}
			(yield* $cy($mc(k, "beam", "Rainbow", { length: 28, width: 3, time: 0.8, ticks: 3, frac: 0.75 })));
			$mc(k, "heal", 0.06);
		});
		def("SK_cactus_dog_2", 2, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Shake", 0.5);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.3)))))) {
				return;
			}
			$mc(k, "pose", "Spit", 0.4);
			$mc(k, "shoot", "Needle", { count: 7, spread: 50, speed: 80, arc: 1, frac: 0.2, radius: 2.5, size: 1.4 });
		});
		def("SK_cactus_dog_3", 3, function* (k) {
			if (!$t($1((yield* $cy($mc(k, "approach", 5, 1)))))) {
				return;
			}
			$mc(k, "pose", "Dig", 0.6);
			$mc(k, "burst", "Dirt", $mc(k, "feet"), { Count: 6 });
			if (!$t($1((yield* $cy($mc(k, "wait", 0.5)))))) {
				return;
			}
			$mc(k, "pose", "Focus", 0.8);
			let g = $mc(k, "feet");
			$mc(k, "prop", "Flower", { Position: $add(g, $mul(UP, ((k.f.Root.Size.Y + 3)))), Path: "Spin", Time: 0.7, Hold: 0.3, Size: $mul(3, k.A), Spin: 2, Color: C(255, 120, 170) });
			if (!$t($1((yield* $cy($mc(k, "wait", 0.35)))))) {
				return;
			}
			$mc(k, "shoot", "Needle", { from: $add(g, $mul(UP, 2)), points: $mc(k, "around", g, 8, 12, 0), speed: 70, arc: 1, frac: 0.15, radius: 3, size: 1.3 });
			for (let $v12 = 0, $v13 = $arr($mc(k, "area", g, 9, 0.55, { Color: C(150, 220, 110) })); $v12 < $v13.length; $v12++) {
				let e = $v13[$v12];
				if (e == null) break;
				$mc(k, "stun", e, 1.1, "Vines");
			}
		});
		def("SK_bee_dog_2", 2, function (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Spit", 0.6);
			let t = $mc(k, "summon", "Bee", { count: 2, time: 0.7, gap: 0.2, frac: 0.25, radius: 4, color: C(255, 210, 40), path: "Swarm" });
			$mc(k, "later", t, function () {
				$mc(k, "dot", k.t, 3, 0.5, "Poison");
			});
		});
		def("SK_bee_dog_3", 3, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Throw", 0.5);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.22)))))) {
				return;
			}
			let p = $mc(k, "tground");
			let t = $mc(k, "shoot", "Honey", { points: [p], speed: 40, arc: 6, frac: 0.2, radius: 5, size: 1.5, impact: "Honey" });
			$mc(k, "later", t, function () {
				$mc(k, "zone", "Honey", p, 6, 2.5, 0.2, { on: function (e) {
					$mc(k, "slow", e, 0.6, 0.35, "Honey");
				} });
				$mc(k, "stun", k.t, 1, "Honey");
				$mc(k, "summon", "Bee", { from: $add(p, $mul(UP, 12)), points: $mc(k, "scatter", p, 3, 3, true), time: 0.6, gap: 0.25, frac: 0.2, radius: 4, color: C(255, 210, 40), path: "Swarm" });
			});
		});
		def("SK_balloon_dog_2", 2, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Throw", 0.7);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.2)))))) {
				return;
			}
			let c = $mc(k, "tpos");
			let pts = [$mc(k, "tground"), $1((yield* $cy(G($add(c, Vector3.new($mc(k, "rand", (-3), 3), 0, $mc(k, "rand", (-3), 3))))))), ...$mv((yield* $cy(G($add(c, Vector3.new($mc(k, "rand", (-3), 3), 0, $mc(k, "rand", (-3), 3)))))))];
			$mc(k, "shoot", "Balloon", { points: pts, speed: 35, arc: 8, frac: 0.34, radius: 4, gap: 0.15, impact: "Splash", color: C(90, 170, 255) });
		});
		def("SK_balloon_dog_3", 3, function* (k) {
			if (!$t($1((yield* $cy($mc(k, "approach", 3, 1)))))) {
				return;
			}
			$mc(k, "pose", "Focus", 0.8);
			$mc(k, "charge", 0.7, C(255, 120, 200));
			for (let i = 1, $v14 = 3; i <= $v14; i++) {
				$mc(k, "later", (i * 0.2), function () {
					$mc(k, "pop", string.rep(".", i), undefined, C(255, 255, 255), 0.6);
				});
			}
			if (!$t($1((yield* $cy($mc(k, "wait", 0.8)))))) {
				return;
			}
			let g = $mc(k, "feet");
			$mc(k, "pose", "Bounce", 0.5);
			$mc(k, "pop", "POP!", undefined, C(255, 120, 200), 1.4);
			$mc(k, "burst", "Confetti", $mc(k, "me"), { Count: 26, Radius: 12 });
			$mc(k, "shock", g, 10, C(255, 160, 220));
			$mc(k, "area", g, 10, 1, { KnockbackPower: 14, Lift: 40, Color: C(255, 140, 210) });
		});
		def("SK_windup_dog_2", 2, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Focus", 0.55);
			$mc(k, "prop", "Key", { Position: $add($mc(k, "me"), $mul(UP, (((k.f.Root.Size.Y * 0.5) + 1.5)))), Path: "Spin", Time: 0.5, Hold: 0.6, Size: 1.5, Spin: 14 });
			$mc(k, "pop", "TIC TIC", undefined, C(255, 220, 90), 0.6);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.55)))))) {
				return;
			}
			$mc(k, "pose", "Zoom", 0.9);
			let c = $mc(k, "tpos");
			let d = $mc(k, "dir");
			let side = Vector3.new((-d.Z), 0, d.X);
			for (let i = 1, $v15 = 3; i <= $v15; i++) {
				let p = $add($add(c, $mul(side, (($n(((($mod(i, 2) === 0)) && 4)) ?? (-4))))), $mul($mul(d, ((i - 2))), 3));
				if (!$t($1((yield* $cy($mc(k, "dash", p, 0.18, { frac: 0.33, radius: 3.5, opts: { Color: YELLOW } })))))) {
					return;
				}
				$mc(k, "burst", "Stars", $mc(k, "feet"), { Count: 3, Color: YELLOW });
			}
		});
		def("SK_windup_dog_3", 3, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			for (let i = 1, $v16 = 3; i <= $v16; i++) {
				$mc(k, "pose", "Bounce", 0.5);
				if (!$t($1((yield* $cy($mc(k, "leap", $add($mc(k, "tpos"), Vector3.new($mc(k, "rand", (-1), 1), 0, $mc(k, "rand", (-1), 1))), 6, 0.38)))))) {
					return;
				}
				let g = $mc(k, "feet");
				$mc(k, "pop", "BOING!", undefined, YELLOW, (0.6 + (i * 0.15)));
				$mc(k, "shock", g, 5, YELLOW);
				$mc(k, "pillar", "Lightning", g, 1.5, { Color: YELLOW });
				for (let $v17 = 0, $v18 = $arr($mc(k, "area", g, 5, 0.33, { KnockbackPower: 10, Lift: 18, Color: YELLOW })); $v17 < $v18.length; $v17++) {
					let e = $v18[$v17];
					if (e == null) break;
					if ((i === 3)) {
						$mc(k, "stun", e, 0.8, "Shock");
					}
				}
			}
		});
		def("SK_mushroom_dog_2", 2, function (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Spit", 0.4);
			let p = $mc(k, "tground");
			let t = $mc(k, "shoot", "Spore", { points: [p], speed: 30, arc: 4, frac: 0.4, radius: 5, size: 1.5, impact: "Poison", color: C(190, 120, 230) });
			$mc(k, "later", t, function () {
				$mc(k, "zone", "Spores", p, 5, 1.6, 0.6);
				$mc(k, "stun", k.t, 1.4, "Sleep");
			});
		});
		def("SK_mushroom_dog_3", 3, function (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "pose", "Summon", 1.2);
			let c = $mc(k, "tground");
			$mc(k, "zone", "Spores", c, 8, 2.4, 0);
			for (let i = 1, $v19 = 3; i <= $v19; i++) {
				$mc(k, "later", (0.5 + (i * 0.55)), function () {
					$mc(k, "fx", "S_Ring", { Motif: "Spore", Position: c, R0: $mc(k, "R", 8), R1: 1, Count: 8, Time: 0.4, Height: 1, Color: C(200, 80, 200) });
					for (let $v20 = 0, $v21 = $arr($mc(k, "area", c, 8, 0.2, { Color: C(200, 80, 200) })); $v20 < $v21.length; $v20++) {
						let e = $v21[$v20];
						if (e == null) break;
						$mc(k, "slow", e, 0.6, 0.6);
					}
				});
			}
			$mc(k, "later", 0.6, function () {
				$mc(k, "dot", k.t, 3, 0.4, "Poison");
			});
		});
	};
}
