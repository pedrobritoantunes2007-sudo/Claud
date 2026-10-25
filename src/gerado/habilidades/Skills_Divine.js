// Gerado automaticamente de server/Services/SpecialsPacks/Skills_Divine.lua (código do jogo Roblox) por tools/lua2js — não edite à mão.
import { $t, $a, $n, $1, $M, $mv, $lst, $get, $set, $tm, $tc, $len, $cat, $eq, $add, $sub, $mul, $div, $mod, $pow, $idiv, $unm, $mc, $cy, $sp, $sp1, $W, $WS, $ins, $ins3, $arr, $pairs, $iter, $pcallG, $warnWait } from '../../rbx/lua.js';

export default function ($G, $script) {
	let require = $G["require"], Color3 = $G["Color3"], Vector3 = $G["Vector3"], ipairs = $G["ipairs"];
	let SkillKit = $sp1(require($script.Parent.Parent.SkillKit));
	let C = Color3.fromRGB;
	let UP = Vector3.new(0, 1, 0);
	let G = SkillKit.Ground;
	let SUN = C(255, 200, 70);
	return function (Specials, _Fighters) {
		let def = function (id, slot, fn) {
			$sp(SkillKit.def(Specials, id, slot, fn));
		};
		def("SK_sun_dragon_3", 3, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "aura", "Fire", 1.8, SUN);
			$mc(k, "pose", "Fly", 1.8);
			$mc(k, "fx", "PhoenixRise", { Model: k.f.Model, Duration: 0.6 });
			if (!$t($1((yield* $cy($mc(k, "rise", 12, 0.45)))))) {
				return;
			}
			let c = $mc(k, "tpos");
			let d = $mc(k, "dir", c);
			let land = $1((yield* $cy(G($add(c, $mul(d, 9))))));
			$mc(k, "tele", $1((yield* $cy(G(c)))), 8, 0.3, SUN);
			if (!$t($1((yield* $cy($mc(k, "wait", 0.25)))))) {
				return;
			}
			let start = $mc(k, "feet");
			$mc(k, "fx", "Streak", { Model: k.f.Model, Color: SUN, Duration: 0.5, Width: 3, Neon: true, Sparks: true });
			if (!$t($1((yield* $cy($mc(k, "land", land, 0.35, { frac: 0.6, radius: 6, opts: { Knockback: $add($mul(d, 30), $mul(UP, 25)), Color: SUN } })))))) {
				return;
			}
			$mc(k, "path", "Fire", start, land, { Duration: 2.4, Width: 3.5, Color: SUN });
			$mc(k, "fx", "Explosion", { Position: $add($1((yield* $cy(G(c)))), UP), Radius: $mc(k, "R", 9), Color: SUN });
			$mc(k, "pillar", "Holy", $1((yield* $cy(G(c)))), 4, { Height: 28, Time: 0.15, Hold: 0.6, Color: C(255, 230, 140) });
			for (let $v1 = 0, $v2 = $arr($mc(k, "area", $1((yield* $cy(G(c)))), 9, 0.4, { KnockbackPower: 25, Lift: 25, Color: SUN })); $v1 < $v2.length; $v1++) {
				let e = $v2[$v1];
				if (e == null) break;
				$mc(k, "dot", e, 2.5, 0.05, "Burn");
			}
			$mc(k, "heal", 0.15);
		});
		def("SK_sun_dragon_4", 4, function* (k) {
			$mc(k, "stop");
			$mc(k, "face");
			$mc(k, "sky", "Gold", 3.8);
			$mc(k, "pose", "Summon", 2.8);
			let c = $mc(k, "tground");
			let sky = $add(c, $mul(UP, 30));
			$mc(k, "prop", "Sun", { Position: sky, Path: "Hover", Time: 0.6, Hold: 2.6, Size: $mul(1.8, k.A), Spin: 0.5 });
			$mc(k, "zone", "Holy", c, 13, 3.4, 0, { color: SUN });
			for (let i = 1, $v3 = 3; i <= $v3; i++) {
				$mc(k, "later", (0.6 + (i * 0.4)), function () {
					let p = $sp1(G($add(c, Vector3.new($mc(k, "rand", (-6), 6), 0, $mc(k, "rand", (-6), 6)))));
					$mc(k, "fx", "S_Beam", { Kind: "Sun", From: $sub(sky, $mul(UP, 3)), To: p, Width: $mc(k, "R", 4), Duration: 0.6, Sweep: 25 });
					$mc(k, "area", c, 10, 0.08, { Color: SUN });
					$mc(k, "area", p, 5, 0.06, { Color: SUN });
				});
			}
			for (let i = 1, $v4 = 3; i <= $v4; i++) {
				$mc(k, "later", (0.5 + (i * 0.6)), function () {
					$mc(k, "heal", 0.1);
				});
			}
			$mc(k, "later", 2.6, function () {
				$mc(k, "fx", "Explosion", { Position: $add(c, $mul(UP, 2)), Radius: $mc(k, "R", 16), Color: SUN });
				$mc(k, "fx", "S_Burst", { Kind: "Stars", Position: c, Count: 26, Radius: 18, Color: C(255, 240, 170) });
				$mc(k, "shake", c, 1.4, 100);
				for (let $v5 = 0, $v6 = $arr($mc(k, "area", c, 16, 0.58, { KnockbackPower: 50, Lift: 40, Color: SUN })); $v5 < $v6.length; $v5++) {
					let e = $v6[$v5];
					if (e == null) break;
					$mc(k, "dot", e, 3, 0.04, "Burn");
				}
			});
			(yield* $cy($mc(k, "wait", 1.8)));
		});
	};
}
