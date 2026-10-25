// Gerado automaticamente de client/EffectsPacks/PackC.lua (código do jogo Roblox) por tools/lua2js — não edite à mão.
import { $t, $a, $n, $1, $M, $mv, $lst, $get, $set, $tm, $tc, $len, $cat, $eq, $add, $sub, $mul, $div, $mod, $pow, $idiv, $unm, $mc, $cy, $sp, $sp1, $W, $WS, $ins, $ins3, $arr, $pairs, $iter, $pcallG, $warnWait } from '../../rbx/lua.js';

export default function ($G, $script) {
	let game = $G["game"], Color3 = $G["Color3"], math = $G["math"], Enum = $G["Enum"], workspace = $G["workspace"], Instance = $G["Instance"], pairs = $G["pairs"], ipairs = $G["ipairs"], table = $G["table"], os = $G["os"], pcall = $G["pcall"], warn = $G["warn"], NumberSequenceKeypoint = $G["NumberSequenceKeypoint"], NumberSequence = $G["NumberSequence"], ColorSequence = $G["ColorSequence"], NumberRange = $G["NumberRange"], Vector2 = $G["Vector2"], Vector3 = $G["Vector3"], CFrame = $G["CFrame"], task = $G["task"], typeof$3 = $G["typeof"];
	const $va = [];
	let CollectionService = $mc(game, "GetService", "CollectionService");
	let Debris = $mc(game, "GetService", "Debris");
	let Lighting = $mc(game, "GetService", "Lighting");
	let Players = $mc(game, "GetService", "Players");
	let RunService = $mc(game, "GetService", "RunService");
	let C = Color3.fromRGB;
	let WHITE = Color3.new(1, 1, 1);
	let TAU = $mul(math.pi, 2);
	let NEON = Enum.Material.Neon;
	let GLASS = Enum.Material.Glass;
	let TEX = { Sparkle: "rbxasset://textures/particles/sparkles_main.dds", Smoke: "rbxasset://textures/particles/smoke_main.dds", Fire: "rbxasset://textures/particles/fire_main.dds", Spark: "rbxasset://textures/particles/fire_sparks_main.dds", Swirl: "rbxasset://textures/particles/forcefield_vortex_main.dds" };
	let RAINBOW = [C(255, 70, 80), C(255, 160, 50), C(255, 230, 70), C(90, 220, 110), C(80, 170, 255), C(170, 100, 255)];
	return function (H, Effects) {
		let player = Players.LocalPlayer;
		let QUALITY = { Alto: 1, "Médio": 0.6, Baixo: 0.3 };
		let quality = function () {
			return ($n($get(QUALITY, $mc(player, "GetAttribute", "GraphicsQuality"))) ?? 1);
		};
		let q = function (n) {
			return math.max(1, math.floor($add($mul(n, quality()), 0.5)));
		};
		let folder = $mc(workspace, "FindFirstChild", "FX");
		if (!$t(folder)) {
			folder = Instance.new("Folder");
			folder.Name = "FX";
			folder.Parent = workspace;
		}
		let MAX_PARTS = 260;
		let myParts = 0;
		let full = function (extra) {
			return ($add(myParts, (($n(extra) ?? 0))) > $mul(MAX_PARTS, ($add(0.4, $mul(0.6, quality())))));
		};
		let fxPart = function (props) {
			let p = Instance.new("Part");
			p.Anchored = true;
			p.CanCollide = false;
			p.CanQuery = false;
			p.CanTouch = false;
			p.CastShadow = false;
			p.Material = NEON;
			p.TopSurface = Enum.SurfaceType.Smooth;
			p.BottomSurface = Enum.SurfaceType.Smooth;
			for (let [k, v] of $pairs(props)) {
				$set(p, k, v);
			}
			myParts = $add(myParts, 1);
			$mc(p.Destroying, "Connect", function () {
				myParts = $sub(myParts, 1);
			});
			p.Parent = folder;
			$mc(Debris, "AddItem", p, 12);
			return p;
		};
		let kill = function (list) {
			for (let $v1 = 0, $v2 = $arr(list); $v1 < $v2.length; $v1++) {
				let p = $v2[$v1];
				if (p == null) break;
				if ($t(p.Parent)) {
					$mc(p, "Destroy");
				}
			}
		};
		let anims = [];
		let animate = function (duration, fn, done) {
			$ins(anims, { Start: os.clock(), Dur: math.max(duration, 0.001), Fn: fn, Done: done });
		};
		$mc(RunService.RenderStepped, "Connect", function () {
			let now = os.clock();
			for (let i = $len(anims), $v3 = 1; i >= $v3; i += (-1)) {
				let a = $get(anims, i);
				let k = math.clamp($div(($sub(now, a.Start)), a.Dur), 0, 1);
				let [ok, stop] = $lst([], pcall(a.Fn, k, $sub(now, a.Start)), 2);
				if (!$t(ok)) {
					warn("[EffectsPackC]", stop);
				}
				if ((((k >= 1) || (stop === true)) || !$t(ok))) {
					$set(anims, i, $get(anims, $len(anims)));
					$set(anims, $len(anims), undefined);
					if ($t(a.Done)) {
						let [okDone, err] = $lst([], pcall(a.Done), 2);
						if (!$t(okDone)) {
							warn("[EffectsPackC] fim", err);
						}
					}
				}
			}
		});
		let NS = function (...$va) {
			let a = [...$va];
			let kps = [];
			for (let i = 1, $v4 = $len(a); i <= $v4; i += 2) {
				$ins(kps, NumberSequenceKeypoint.new($get(a, i), $get(a, (i + 1))));
			}
			return NumberSequence.new(kps);
		};
		let rnd = function (a, b) {
			return $add(a, $mul(math.random(), ($sub(b, a))));
		};
		let outCubic = function (k) {
			return $sub(1, $pow(($sub(1, k)), 3));
		};
		let anchor = function (position, life) {
			let a = Instance.new("Attachment");
			a.Position = position;
			a.Parent = workspace.Terrain;
			$mc(Debris, "AddItem", a, life);
			return a;
		};
		let burst = function (position, color, count, size, speed, texture, extra) {
			let a = anchor(position, 3);
			let e = Instance.new("ParticleEmitter");
			e.Enabled = false;
			e.Texture = ($n(texture) ?? TEX.Sparkle);
			e.LightEmission = 0.8;
			e.Color = ColorSequence.new(color);
			e.Size = NS(0, size, 1, 0);
			e.Transparency = NS(0, 0, 0.7, 0.3, 1, 1);
			e.Lifetime = NumberRange.new(0.4, 0.9);
			e.Speed = NumberRange.new($mul(speed, 0.4), speed);
			e.SpreadAngle = Vector2.new(180, 180);
			e.Drag = 3;
			e.Rotation = NumberRange.new(0, 360);
			e.RotSpeed = NumberRange.new((-120), 120);
			if ($t(extra)) {
				for (let [k, v] of $pairs(extra)) {
					$set((e), k, v);
				}
			}
			e.Parent = a;
			$mc(e, "Emit", q(count));
			return e;
		};
		let lights = 0;
		let light = function (position, color, range, duration) {
			if ((lights >= math.floor($add(3, $mul(5, quality()))))) {
				return;
			}
			lights = $add(lights, 1);
			let a = anchor(position, $add(duration, 0.1));
			let l = Instance.new("PointLight");
			l.Color = color;
			l.Range = math.min(range, 60);
			l.Brightness = 4;
			l.Shadows = false;
			l.Parent = a;
			animate(duration, function (k) {
				l.Brightness = $mul(4, ($sub(1, k)));
			}, function () {
				lights = $sub(lights, 1);
			});
		};
		let shake = function (position, amount, radius) {
			let cam = workspace.CurrentCamera;
			if (($t(cam) && $t(Effects.Shake))) {
				let dist = ($sub(cam.CFrame.Position, position)).Magnitude;
				if ((dist < $mul(radius, 1.5))) {
					$sp(Effects.Shake($mul(amount, math.clamp($sub(1, $div(dist, ($mul(radius, 1.5)))), 0.15, 1))));
				}
			}
		};
		let flash = function (position, radius, color, duration) {
			let ball = fxPart({ Shape: Enum.PartType.Ball, Size: $mul($mul(Vector3.one, radius), 0.4), CFrame: CFrame.new(position), Color: color });
			animate(($n(duration) ?? 0.3), function (k) {
				ball.Size = $mul($mul(Vector3.one, radius), ($add(0.4, $mul(1.6, outCubic(k)))));
				ball.Transparency = $pow(k, 0.6);
			}, function () {
				$mc(ball, "Destroy");
			});
		};
		let stretch = function (p, a, b, w, h) {
			let len = ($sub(b, a)).Magnitude;
			if ((len < 0.01)) {
				p.CFrame = CFrame.new(a);
				return;
			}
			p.Size = Vector3.new(w, ($n(h) ?? w), $add(len, $mul(w, 0.3)));
			p.CFrame = $mul(CFrame.lookAt(a, b), CFrame.new(0, 0, $div($unm(len), 2)));
		};
		let rootOf = function (model) {
			return ($a(($a(model) && model.Parent)) && model.PrimaryPart);
		};
		let feetOf = function (model) {
			let root = rootOf(model);
			if (!$t(root)) {
				return undefined;
			}
			let hum = $mc(model, "FindFirstChildOfClass", "Humanoid");
			let hip = ($n(($a(hum) && hum.HipHeight)) ?? (($n($mc(model, "GetAttribute", "HipHeight")) ?? 2)));
			return $sub(root.Position, Vector3.new(0, $add((root.Size.Y / 2), hip), 0));
		};
		let hideParts = function (model, names, seconds) {
			let list = [];
			for (let $v5 = 0, $v6 = $arr($mc(model, "GetDescendants")); $v5 < $v6.length; $v5++) {
				let d = $v6[$v5];
				if (d == null) break;
				if (($t($mc(d, "IsA", "BasePart")) && $t($get(names, d.Name)))) {
					$ins(list, [d, d.LocalTransparencyModifier]);
					d.LocalTransparencyModifier = 1;
				}
			}
			task.delay(seconds, function () {
				for (let $v7 = 0, $v8 = $arr(list); $v7 < $v8.length; $v7++) {
					let e = $v8[$v7];
					if (e == null) break;
					if ($t($get(e, 1).Parent)) {
						$get(e, 1).LocalTransparencyModifier = $get(e, 2);
					}
				}
			});
			return list;
		};
		let groundRing = function (position, r0, r1, color, duration, thick) {
			if (($t(H.Shockwave) && (r0 < 2))) {
				$sp(H.Shockwave({ Position: position, Radius: r1, Color: color }));
				return;
			}
			let n = q(20);
			let list = [];
			for (let _ = 1, $v9 = n; _ <= $v9; _++) {
				$ins(list, fxPart({ Size: Vector3.new(0.4, 0.4, 1), Color: color }));
			}
			animate(duration, function (k) {
				let r = $add(r0, $mul(($sub(r1, r0)), outCubic(k)));
				let arc = $mul($div($mul(TAU, r), n), 1.15);
				for (let $v10 = 0, $v11 = $arr(list); $v10 < $v11.length; $v10++) {
					let p = $v11[$v10];
					if (p == null) break;
					let i = $v10 + 1;
					let a = $mul($div(i, n), TAU);
					p.Size = Vector3.new(($n(thick) ?? 0.6), 0.5, arc);
					p.CFrame = $mul($mul(CFrame.new(position), CFrame.Angles(0, a, 0)), CFrame.new(r, 0.25, 0));
					p.Transparency = $pow(k, 1.4);
				}
			}, function () {
				kill(list);
			});
		};
		let tracked = [];
		let collect = function (model) {
			let list = [];
			for (let $v12 = 0, $v13 = $arr($mc(model, "GetDescendants")); $v12 < $v13.length; $v12++) {
				let d = $v13[$v12];
				if (d == null) break;
				if (($t($mc(d, "IsA", "Weld")) && $t(d.Part1))) {
					let spin = $mc(d.Part1, "GetAttribute", "CSpin");
					let wave = $mc(d.Part1, "GetAttribute", "CWave");
					if (((typeof$3(spin) === "Vector3") || (typeof$3(wave) === "Vector3"))) {
						$ins(list, { Weld: d, Base: d.C0, Last: d.C0, Spin: ($n(((typeof$3(spin) === "Vector3") && spin)) ?? undefined), Wave: ($n(((typeof$3(wave) === "Vector3") && wave)) ?? undefined), Freq: ($n($mc(d.Part1, "GetAttribute", "CFreq")) ?? 2), Phase: ($n($mc(d.Part1, "GetAttribute", "CPhase")) ?? 0) });
					}
				}
			}
			return list;
		};
		let track = function (model) {
			if (!$t($mc(model, "IsA", "Model"))) {
				return;
			}
			let try$1 = function () {
				if (($t($mc(model, "GetAttribute", "CAnim")) && $t(model.Parent))) {
					$set(tracked, model, collect(model));
				}
			};
			try$1();
			$mc(model.DescendantAdded, "Connect", function () {
				task.defer(try$1);
			});
			$mc(model.AncestryChanged, "Connect", function () {
				if (!$t(model.Parent)) {
					$set(tracked, model, undefined);
				}
			});
		};
		$mc($mc(CollectionService, "GetInstanceAddedSignal", "Dog"), "Connect", track);
		for (let $v14 = 0, $v15 = $arr($mc(CollectionService, "GetTagged", "Dog")); $v14 < $v15.length; $v14++) {
			let m = $v15[$v14];
			if (m == null) break;
			track(m);
		}
		let frame = 0;
		$mc(RunService.PreSimulation, "Connect", function () {
			frame = $add(frame, 1);
			let t = os.clock();
			let cam = workspace.CurrentCamera;
			let camPos = ($a(cam) && cam.CFrame.Position);
			let far = $add(90, $mul(110, quality()));
			for (let [model, list] of $pairs(tracked)) {
				let root = model.PrimaryPart;
				if (($t(root) && $t(model.Parent))) {
					let dist = ($n(($a(camPos) && ($sub(root.Position, camPos)).Magnitude)) ?? 0);
					if (((dist < far) && ((dist < $mul(far, 0.5)) || ($mod(frame, 3) === 0)))) {
						for (let $v16 = 0, $v17 = $arr(list); $v16 < $v17.length; $v16++) {
							let e = $v17[$v16];
							if (e == null) break;
							let w = e.Weld;
							if ($t(w.Parent)) {
								if (!$eq(w.C0, e.Last)) {
									e.Base = w.C0;
								}
								let rot = CFrame.identity;
								if ($t(e.Spin)) {
									let s = e.Spin;
									rot = CFrame.Angles($mod($mul(s.X, t), TAU), $mod($mul(s.Y, t), TAU), $mod($mul(s.Z, t), TAU));
								}
								if ($t(e.Wave)) {
									let v = math.sin($add($mul(t, e.Freq), e.Phase));
									let v2 = math.sin($add($mul($mul(t, e.Freq), 0.73), $mul(e.Phase, 1.7)));
									rot = $mul(rot, CFrame.Angles($mul(e.Wave.X, v2), $mul(e.Wave.Y, v), $mul(e.Wave.Z, v)));
								}
								let c0 = $mul(e.Base, rot);
								w.C0 = c0;
								e.Last = c0;
							}
						}
					}
				}
			}
		});
		H.C_HydraNeck = function (p) {
			let model = p.Model;
			let head = ($a(model) && $mc(model, "FindFirstChild", $cat("Head", (($n(p.Head) ?? 1)))));
			if ((!($t(head) && $t(p.To)) || $t(full(10)))) {
				return;
			}
			let color = ($n(p.Color) ?? C(150, 255, 120));
			let n = $add(q(9), 2);
			let segs = [], dur = ($n(p.Duration) ?? 0.5);
			for (let i = 1, $v18 = n; i <= $v18; i++) {
				$ins(segs, fxPart({ Shape: Enum.PartType.Ball, Color: ($n((($mod(i, 2) === 0) && C(40, 112, 78))) ?? C(60, 140, 95)), Material: Enum.Material.SmoothPlastic }));
			}
			let skull = fxPart({ Size: Vector3.new(1.6, 1.2, 2.2), Color: C(40, 112, 78), Material: Enum.Material.SmoothPlastic });
			let jaw = fxPart({ Size: Vector3.new(1.2, 0.4, 1.8), Color: C(214, 206, 140), Material: Enum.Material.SmoothPlastic });
			let eye = fxPart({ Size: Vector3.new(1.7, 0.3, 0.4), Color: C(255, 220, 40) });
			let side = ($n((($mod((($n(p.Head) ?? 1)), 2) === 0) && 1)) ?? (-1));
			animate(dur, function (k) {
				if (!$t(head.Parent)) {
					return true;
				}
				let a = head.Position;
				let b = p.To;
				let reach = math.sin($mul($mul(math.min($div(k, 0.55), 1), math.pi), 0.5));
				if ((k > 0.7)) {
					reach = $sub(1, $div(($sub(k, 0.7)), 0.3));
				}
				let tip = $mc(a, "Lerp", b, reach);
				let dir = ($sub(b, a));
				let right = ($n(((dir.Magnitude > 0.1) && $mc(dir.Unit, "Cross", Vector3.yAxis))) ?? Vector3.xAxis);
				for (let $v19 = 0, $v20 = $arr(segs); $v19 < $v20.length; $v19++) {
					let s = $v20[$v19];
					if (s == null) break;
					let i = $v19 + 1;
					let u = $div(i, ($add(n, 1)));
					let pos = $add($add($mc(a, "Lerp", tip, u), $mul($mul($mul($mul(right, math.sin($add($mul($mul(u, math.pi), 2), $mul(k, 10)))), 1.4), side), reach)), Vector3.new(0, $mul((math.sin($mul(u, math.pi)) * 2.5), reach), 0));
					let r = $sub(1.3, $mul(u, 0.4));
					s.Size = $mul(Vector3.one, r);
					s.CFrame = CFrame.new(pos);
				}
				let look = CFrame.lookAt(tip, $add(tip, (($n(((dir.Magnitude > 0.1) && dir.Unit)) ?? Vector3.zAxis))));
				let bite = ($n((((k > 0.45) && (k < 0.6)) && 0)) ?? 0.5);
				skull.CFrame = $mul(look, CFrame.new(0, 0.25, 0));
				jaw.CFrame = $mul($mul(look, CFrame.new(0, (-0.45), 0.2)), CFrame.Angles(bite, 0, 0));
				eye.CFrame = $mul(look, CFrame.new(0, 0.45, 0.2));
				return undefined;
			}, function () {
				kill(segs);
				$mc(skull, "Destroy");
				$mc(jaw, "Destroy");
				$mc(eye, "Destroy");
			});
			task.delay($mul(dur, 0.5), function () {
				burst(p.To, color, 12, 0.8, 18, TEX.Spark);
			});
		};
		H.C_Heal = function (p) {
			let root = rootOf(p.Model);
			if (!$t(root)) {
				return;
			}
			let color = ($n(p.Color) ?? C(130, 255, 140));
			let base = ($n(feetOf(p.Model)) ?? root.Position);
			let r = math.max(2, (root.Size.X * 0.8));
			let list = [];
			for (let i = 1, $v21 = q(8); i <= $v21; i++) {
				$ins(list, [fxPart({ Shape: Enum.PartType.Ball, Size: $mul(Vector3.one, 0.5), Color: color }), i]);
			}
			animate(0.9, function (k) {
				if (!$t(root.Parent)) {
					return true;
				}
				for (let $v22 = 0, $v23 = $arr(list); $v22 < $v23.length; $v22++) {
					let e = $v23[$v22];
					if (e == null) break;
					let a = $add($mul($div($get(e, 2), $len(list)), TAU), $mul(k, 7));
					$get(e, 1).CFrame = CFrame.new($add(base, Vector3.new($mul(math.cos(a), r), $mul($mul(k, root.Size.Y), 2.2), $mul(math.sin(a), r))));
					$get(e, 1).Transparency = $pow(k, 2);
				}
				return undefined;
			}, function () {
				for (let $v24 = 0, $v25 = $arr(list); $v24 < $v25.length; $v24++) {
					let e = $v25[$v24];
					if (e == null) break;
					$mc($get(e, 1), "Destroy");
				}
			});
			burst(root.Position, color, 16, 0.7, 6, TEX.Sparkle, { Acceleration: Vector3.new(0, 8, 0) });
		};
		H.C_BonePile = function (p) {
			let pos = p.Position;
			if ((!$t(pos) || $t(full(10)))) {
				return;
			}
			let color = ($n(p.Color) ?? C(90, 255, 200));
			let list = [];
			for (let _ = 1, $v26 = q(10); _ <= $v26; _++) {
				let bone = fxPart({ Size: Vector3.new(0.4, 0.4, rnd(1.2, 2.2)), Color: C(236, 228, 204), Material: Enum.Material.SmoothPlastic });
				let away = $mul(Vector3.new(rnd((-1), 1), 0, rnd((-1), 1)).Unit, rnd(2, 5));
				$ins(list, [bone, away, Vector3.new(rnd((-6), 6), rnd((-6), 6), rnd((-6), 6))]);
			}
			let rise = (p.Mode === "rise");
			animate(0.55, function (k) {
				for (let $v27 = 0, $v28 = $arr(list); $v27 < $v28.length; $v27++) {
					let e = $v28[$v27];
					if (e == null) break;
					let u = ($n(($a(rise) && ($sub(1, k)))) ?? k);
					let at = $add($add(pos, $mul($get(e, 2), u)), Vector3.new(0, $add((0.3 + (math.sin($mul(u, math.pi)) * 2)), (($n(($a(rise) && $mul(k, 2))) ?? $mul(($sub(1, k)), 2)))), 0));
					$get(e, 1).CFrame = $mul(CFrame.new(at), CFrame.Angles($mul($get(e, 3).X, u), $mul($get(e, 3).Y, u), $mul($get(e, 3).Z, u)));
				}
			}, function () {
				for (let $v29 = 0, $v30 = $arr(list); $v29 < $v30.length; $v29++) {
					let e = $v30[$v29];
					if (e == null) break;
					$mc($get(e, 1), "Destroy");
				}
			});
			burst($add(pos, Vector3.new(0, 1, 0)), color, 20, 1.2, 10, TEX.Smoke, { LightEmission: 0.6 });
		};
		H.C_RibCage = function (p) {
			let pos = p.Position, r = ($n(p.Radius) ?? 6), dur = ($n(p.Duration) ?? 1.6);
			if ((!$t(pos) || $t(full(30)))) {
				return;
			}
			let ribs = [];
			let n = 8;
			let per = 4;
			for (let i = 1, $v31 = n; i <= $v31; i++) {
				let segs = [];
				for (let _ = 1, $v32 = per; _ <= $v32; _++) {
					$ins(segs, fxPart({ Shape: Enum.PartType.Ball, Color: C(236, 228, 204), Material: Enum.Material.SmoothPlastic }));
				}
				$ins(ribs, [segs, $mul($div(((i - 0.5)), n), TAU)]);
			}
			let spine = fxPart({ Size: Vector3.new(1, 1, $mul(r, 2)), Color: C(220, 212, 188), Material: Enum.Material.SmoothPlastic, Transparency: 1 });
			let glowCore = fxPart({ Shape: Enum.PartType.Ball, Size: $mul(Vector3.one, 2), Color: C(90, 255, 200), Transparency: 0.6, CFrame: CFrame.new($add(pos, Vector3.new(0, 2, 0))) });
			let rib = function (a, close, s) {
				let pts = [];
				for (let j = 0, $v33 = per; j <= $v33; j++) {
					let u = $div(j, per);
					let ang = $mul($mul($mul(u, math.pi), 0.5), close);
					let rr = $mul(r, math.cos(ang));
					let h = $mul($mul($mul(r, 1.4), math.sin(ang)), s);
					$ins(pts, $add(pos, Vector3.new($mul(math.cos(a), rr), h, $mul(math.sin(a), rr))));
				}
				return pts;
			};
			animate(dur, function (k, t) {
				let grow = outCubic(math.min(1, $div(t, 0.35)));
				let close = $add(0.4, $mul(0.6, outCubic(math.clamp($div(($sub(t, 0.25)), 0.5), 0, 1))));
				for (let $v34 = 0, $v35 = $arr(ribs); $v34 < $v35.length; $v34++) {
					let e = $v35[$v34];
					if (e == null) break;
					let pts = rib($get(e, 2), close, grow);
					for (let $v36 = 0, $v37 = $arr($get(e, 1)); $v36 < $v37.length; $v36++) {
						let s = $v37[$v36];
						if (s == null) break;
						let j = $v36 + 1;
						let w = (0.75 - (j * 0.1));
						stretch(s, $get(pts, j), $get(pts, (j + 1)), w);
					}
				}
				spine.Transparency = ($n(((close > 0.95) && 0)) ?? 1);
				spine.CFrame = CFrame.new($add(pos, Vector3.new(0, $mul($mul(r, 1.4), grow), 0)));
				glowCore.Transparency = (0.5 + (0.3 * math.sin($mul(t, 20))));
				if ((k > 0.85)) {
					let f = $div(($sub(k, 0.85)), 0.15);
					for (let $v38 = 0, $v39 = $arr(ribs); $v38 < $v39.length; $v38++) {
						let e = $v39[$v38];
						if (e == null) break;
						for (let $v40 = 0, $v41 = $arr($get(e, 1)); $v40 < $v41.length; $v40++) {
							let s = $v41[$v40];
							if (s == null) break;
							s.Transparency = f;
						}
					}
				}
			}, function () {
				for (let $v42 = 0, $v43 = $arr(ribs); $v42 < $v43.length; $v42++) {
					let e = $v43[$v42];
					if (e == null) break;
					kill($get(e, 1));
				}
				$mc(spine, "Destroy");
				$mc(glowCore, "Destroy");
				burst($add(pos, Vector3.new(0, 2, 0)), C(236, 228, 204), 24, 0.8, 26, TEX.Sparkle, { LightEmission: 0.2 });
				burst($add(pos, Vector3.new(0, 1, 0)), C(90, 255, 200), 18, 2.5, 12, TEX.Smoke, { LightEmission: 0.7 });
			});
			burst(pos, C(150, 140, 120), 18, 2.5, 12, TEX.Smoke, { LightEmission: 0 });
			shake(pos, 0.35, 50);
		};
		H.C_Tentacles = function (p) {
			let pos = p.Position, r = ($n(p.Radius) ?? 7), dur = ($n(p.Duration) ?? 2.2);
			if ((!$t(pos) || $t(full(40)))) {
				return;
			}
			let count = math.min(($n(p.Count) ?? 6), $add(q(6), 1));
			let per = 6;
			let list = [];
			for (let i = 1, $v44 = count; i <= $v44; i++) {
				let segs = [], suck = [];
				for (let j = 1, $v45 = per; j <= $v45; j++) {
					$ins(segs, fxPart({ Shape: Enum.PartType.Ball, Color: ($n((($mod(j, 2) === 0) && C(150, 45, 95))) ?? C(165, 55, 105)), Material: Enum.Material.SmoothPlastic }));
					if (($mod(j, 2) === 1)) {
						$ins(suck, fxPart({ Shape: Enum.PartType.Ball, Size: $mul(Vector3.one, 0.5), Color: C(250, 195, 210), Material: Enum.Material.SmoothPlastic }));
					}
				}
				$ins(list, [segs, suck, $add($mul($div(((i - 1)), count), TAU), rnd((-0.2), 0.2)), rnd(0, 6)]);
			}
			let holeList = [];
			for (let $v46 = 0, $v47 = $arr(list); $v46 < $v47.length; $v46++) {
				let e = $v47[$v46];
				if (e == null) break;
				let a = $get(e, 3);
				let hole = fxPart({ Shape: Enum.PartType.Cylinder, Size: Vector3.new(0.15, 3, 3), CFrame: $mul(CFrame.new($add(pos, Vector3.new($mul(math.cos(a), r), 0.08, $mul(math.sin(a), r)))), CFrame.Angles(0, 0, $div(math.pi, 2))), Color: C(25, 15, 25), Material: Enum.Material.SmoothPlastic });
				$ins(holeList, hole);
			}
			animate(dur, function (k, t) {
				let up = outCubic(math.min(1, $div(t, 0.4)));
				let grab = math.clamp($div(($sub(t, 0.45)), 0.35), 0, 1);
				let down = ($n(((k > 0.82) && ($sub(1, $div(($sub(k, 0.82)), 0.18))))) ?? 1);
				for (let $v48 = 0, $v49 = $arr(list); $v48 < $v49.length; $v48++) {
					let e = $v49[$v48];
					if (e == null) break;
					let a = $get(e, 3);
					let base = $add(pos, Vector3.new($mul(math.cos(a), r), 0, $mul(math.sin(a), r)));
					let inward = ($sub(pos, base)).Unit;
					let pts = [base];
					let height = $mul($mul(9, up), down);
					for (let j = 1, $v50 = per; j <= $v50; j++) {
						let u = $div(j, per);
						let bend = $mul($mul(u, u), ($add(0.3, $mul(grab, 1.3))));
						let sway = $mul((math.sin($add($add($mul(t, 5), $get(e, 4)), $mul(u, 4))) * 0.8), ($sub(1, $mul(grab, 0.7))));
						let pt = $add($add($add(base, Vector3.new(0, $mul($mul(height, u), ($sub(1, $mul($mul(grab, u), 0.45)))), 0)), $mul($mul($mul(inward, r), bend), 0.85)), $mul($mc(inward, "Cross", Vector3.yAxis), sway));
						$ins(pts, pt);
					}
					for (let $v51 = 0, $v52 = $arr($get(e, 1)); $v51 < $v52.length; $v51++) {
						let s = $v52[$v51];
						if (s == null) break;
						let j = $v51 + 1;
						let w = (((1.6 - (j * 0.2))) * math.max(0.2, up));
						stretch(s, $get(pts, j), $get(pts, (j + 1)), w);
					}
					for (let $v53 = 0, $v54 = $arr($get(e, 2)); $v53 < $v54.length; $v53++) {
						let s = $v54[$v53];
						if (s == null) break;
						let m = $v53 + 1;
						let j = ((m * 2) - 1);
						let mid = $div(($add($get(pts, j), $get(pts, $add(j, 1)))), 2);
						s.CFrame = CFrame.new($add(mid, $mul(inward, ($sub(0.8, $mul(j, 0.1))))));
						s.Transparency = ($n(((up < 0.3) && 1)) ?? 0);
					}
				}
			}, function () {
				for (let $v55 = 0, $v56 = $arr(list); $v55 < $v56.length; $v55++) {
					let e = $v56[$v55];
					if (e == null) break;
					kill($get(e, 1));
					kill($get(e, 2));
				}
				kill(holeList);
			});
			burst(pos, C(120, 200, 230), 20, 1.5, 14, TEX.Smoke, { LightEmission: 0.2 });
			shake(pos, 0.3, 50);
		};
		H.C_Ink = function (p) {
			let pos = p.Position;
			if (!$t(pos)) {
				return;
			}
			let r = ($n(p.Radius) ?? 8);
			burst($add(pos, Vector3.new(0, 1.5, 0)), C(15, 10, 25), 30, 6, 16, TEX.Smoke, { LightEmission: 0, Size: NS(0, 3, 1, 9), Lifetime: NumberRange.new(1, 1.8) });
			if (!$t(full(1))) {
				let d = fxPart({ Shape: Enum.PartType.Cylinder, Size: Vector3.new(0.12, $mul(r, 2), $mul(r, 2)), CFrame: $mul(CFrame.new($add(pos, Vector3.new(0, 0.06, 0))), CFrame.Angles(0, 0, $div(math.pi, 2))), Color: C(20, 12, 30), Material: Enum.Material.SmoothPlastic, Transparency: 0.2 });
				animate(3, function (k) {
					d.Transparency = $add(0.2, $mul(0.8, $pow(k, 2)));
				}, function () {
					$mc(d, "Destroy");
				});
			}
		};
		let grayToken = 0;
		H.C_TimeStop = function (p) {
			let pos = p.Position, r = ($n(p.Radius) ?? 30), dur = ($n(p.Duration) ?? 2.4);
			if (!$t(pos)) {
				return;
			}
			let cam = workspace.CurrentCamera;
			if (($t(cam) && (($sub(cam.CFrame.Position, pos)).Magnitude < $mul(r, 2.5)))) {
				grayToken = $add(grayToken, 1);
				let token = grayToken;
				let cc = Instance.new("ColorCorrectionEffect");
				cc.Name = "C_TimeStop";
				cc.Parent = Lighting;
				animate(dur, function (k) {
					let inK = math.min(1, $div(k, 0.12));
					let outK = ($n(((k > 0.9) && $div(($sub(k, 0.9)), 0.1))) ?? 0);
					cc.Saturation = $mul($mul((-1), inK), ($sub(1, outK)));
					cc.Contrast = $mul($mul(0.2, inK), ($sub(1, outK)));
					cc.TintColor = $mc(WHITE, "Lerp", C(200, 225, 255), $mul(inK, ($sub(1, outK))));
				}, function () {
					$mc(cc, "Destroy");
					if ($eq(token, grayToken)) {
						$sp(Effects.Shake(0.4));
					}
				});
			}
			if ($t(full(40))) {
				return;
			}
			let center = $add(pos, Vector3.new(0, 16, 0));
			let faceR = 9;
			let look = ($n(($a(cam) && CFrame.lookAt(center, Vector3.new(cam.CFrame.Position.X, center.Y, cam.CFrame.Position.Z)))) ?? CFrame.new(center));
			let face = fxPart({ Shape: Enum.PartType.Cylinder, Size: Vector3.new(0.4, $mul(faceR, 2), $mul(faceR, 2)), CFrame: $mul(look, CFrame.Angles(0, $div(math.pi, 2), 0)), Color: C(246, 236, 210), Material: Enum.Material.SmoothPlastic, Transparency: 1 });
			let rim = [];
			for (let i = 1, $v57 = 24; i <= $v57; i++) {
				let a = $mul((i / 24), TAU);
				$ins(rim, fxPart({ Size: Vector3.new(0.8, 2.6, 0.9), Color: C(220, 175, 80), CFrame: $mul($mul(look, CFrame.Angles(0, 0, a)), CFrame.new(0, faceR, (-0.3))), Transparency: 1 }));
			}
			for (let h = 1, $v58 = 12; h <= $v58; h++) {
				let a = $mul((h / 12), TAU);
				$ins(rim, fxPart({ Size: Vector3.new(0.5, ($n((($mod(h, 3) === 0) && 2)) ?? 1.1), 0.3), Color: C(40, 30, 30), Material: Enum.Material.SmoothPlastic, CFrame: $mul($mul(look, CFrame.Angles(0, 0, a)), CFrame.new(0, $sub(faceR, 1.6), (-0.35))), Transparency: 1 }));
			}
			let hourH = fxPart({ Size: Vector3.new(0.7, 5, 0.3), Color: C(30, 25, 30), Material: Enum.Material.SmoothPlastic, Transparency: 1 });
			let minH = fxPart({ Size: Vector3.new(0.45, 7.5, 0.3), Color: C(30, 25, 30), Material: Enum.Material.SmoothPlastic, Transparency: 1 });
			let all = [face, hourH, minH];
			for (let $v59 = 0, $v60 = $arr(rim); $v59 < $v60.length; $v59++) {
				let x = $v60[$v59];
				if (x == null) break;
				$ins(all, x);
			}
			animate(dur, function (k, t) {
				let vis = math.min(1, $div(t, 0.25));
				if ((k > 0.85)) {
					vis = $sub(1, $div(($sub(k, 0.85)), 0.15));
				}
				for (let $v61 = 0, $v62 = $arr(all); $v61 < $v62.length; $v61++) {
					let x = $v62[$v61];
					if (x == null) break;
					x.Transparency = $sub(1, $mul(vis, (($n(($eq(x, face) && 0.75)) ?? 1))));
				}
				let spin = $mul($unm(t), (($n(((k < 0.15) && 12)) ?? 0.6)));
				hourH.CFrame = $mul($mul(look, CFrame.Angles(0, 0, $mul(spin, 0.25))), CFrame.new(0, 2.3, (-0.5)));
				minH.CFrame = $mul($mul(look, CFrame.Angles(0, 0, spin)), CFrame.new(0, 3.6, (-0.55)));
			}, function () {
				kill(all);
				flash(center, 8, C(200, 230, 255), 0.35);
			});
			groundRing(pos, 2, r, C(170, 220, 255), 0.6, 0.5);
			light($add(pos, Vector3.new(0, 6, 0)), C(150, 210, 255), 40, dur);
		};
		H.C_AfterImage = function (p) {
			let model = p.Model;
			let root = rootOf(model);
			if ((!$t(root) || $t(full(1)))) {
				return;
			}
			let size = $mc(model, "GetExtentsSize");
			let ghost = fxPart({ Shape: Enum.PartType.Ball, Size: $mul(size, Vector3.new(0.7, 0.8, 0.9)), CFrame: root.CFrame, Color: C(150, 210, 255), Transparency: 0.5 });
			animate(($n(p.Duration) ?? 1.2), function (k) {
				ghost.Transparency = $add(0.5, $mul(0.5, k));
			}, function () {
				$mc(ghost, "Destroy");
			});
			burst(root.Position, C(200, 235, 255), 8, 0.6, 8);
		};
		H.C_Singularity = function (p) {
			let model = p.Model;
			let root = rootOf(model);
			if ((!$t(root) || $t(full(30)))) {
				return;
			}
			let dur = ($n(p.Duration) ?? 2.2), r = ($n(p.Radius) ?? 14);
			let hole = fxPart({ Shape: Enum.PartType.Ball, Size: Vector3.one, Color: C(0, 0, 0), Material: Enum.Material.SmoothPlastic });
			let halo = fxPart({ Shape: Enum.PartType.Ball, Size: Vector3.one, Color: C(255, 160, 70), Transparency: 0.7 });
			let n = q(22);
			let disk = [];
			for (let i = 1, $v63 = n; i <= $v63; i++) {
				$ins(disk, [fxPart({ Size: Vector3.new(0.6, 0.15, 1), Color: ($n((($mod(i, 3) === 0) && C(255, 245, 220))) ?? (($n((($mod(i, 3) === 1) && C(255, 140, 50))) ?? C(255, 200, 90)))) }), i]);
			}
			let a = Instance.new("Attachment");
			a.Parent = hole;
			let e = Instance.new("ParticleEmitter");
			e.Texture = TEX.Swirl;
			e.Color = ColorSequence.new(C(255, 170, 90));
			e.LightEmission = 1;
			e.Size = NS(0, $mul(r, 0.9), 1, 0.5);
			e.Transparency = NS(0, 0.6, 1, 1);
			e.Lifetime = NumberRange.new(0.6, 0.8);
			e.Speed = NumberRange.new(0, 0);
			e.Rotation = NumberRange.new(0, 360);
			e.RotSpeed = NumberRange.new(300, 400);
			e.Rate = $mul(8, quality());
			e.Parent = a;
			let s = Instance.new("ParticleEmitter");
			s.Texture = TEX.Sparkle;
			s.Color = ColorSequence.new(C(255, 220, 160));
			s.LightEmission = 1;
			s.Size = NS(0, 0.6, 1, 0);
			s.Lifetime = NumberRange.new(0.5, 0.7);
			s.Speed = NumberRange.new($mul($unm(r), 2), $mul($unm(r), 1.6));
			s.SpreadAngle = Vector2.new(180, 180);
			s.Rate = $mul(60, quality());
			s.Parent = a;
			animate(dur, function (k, t) {
				if (!$t(root.Parent)) {
					return true;
				}
				let grow = outCubic(math.min(1, $div(t, 0.4)));
				if ((k > 0.88)) {
					grow = $sub(1, $div(($sub(k, 0.88)), 0.12));
				}
				let c = root.Position;
				let hr = $add(2, $mul(4, grow));
				hole.CFrame = CFrame.new(c);
				hole.Size = $mul(Vector3.one, hr);
				halo.CFrame = CFrame.new(c);
				halo.Size = $mul($mul(Vector3.one, hr), 1.35);
				let tilt = $mul(CFrame.new(c), CFrame.Angles(0.35, 0, 0.2));
				let rr = $mul(hr, 1.5);
				let arc = $mul($div($mul(TAU, rr), n), 1.1);
				for (let $v64 = 0, $v65 = $arr(disk); $v64 < $v65.length; $v64++) {
					let d = $v65[$v64];
					if (d == null) break;
					let ang = $add($mul($div($get(d, 2), n), TAU), $mul(t, 6));
					$get(d, 1).Size = Vector3.new($add($mul(1.1, grow), 0.1), 0.15, arc);
					$get(d, 1).CFrame = $mul($mul(tilt, CFrame.Angles(0, ang, 0)), CFrame.new(rr, 0, 0));
				}
				return undefined;
			}, function () {
				$mc(hole, "Destroy");
				$mc(halo, "Destroy");
				for (let $v66 = 0, $v67 = $arr(disk); $v66 < $v67.length; $v66++) {
					let d = $v67[$v66];
					if (d == null) break;
					$mc($get(d, 1), "Destroy");
				}
			});
			light(root.Position, C(255, 160, 70), 30, dur);
			shake(root.Position, 0.25, 40);
		};
		H.C_WhiteHole = function (p) {
			let pos = p.Position;
			if (!$t(pos)) {
				return;
			}
			let r = ($n(p.Radius) ?? 10);
			flash(pos, r, WHITE, 0.4);
			groundRing($sub(pos, Vector3.new(0, 1, 0)), 2, $mul(r, 1.6), C(255, 245, 230), 0.5, 0.8);
			if (!$t(full(10))) {
				let rays = [];
				for (let i = 1, $v68 = q(10); i <= $v68; i++) {
					let d = Vector3.new(rnd((-1), 1), rnd((-0.3), 0.9), rnd((-1), 1)).Unit;
					$ins(rays, [fxPart({ Size: Vector3.new(0.5, 0.5, 1), Color: ($n((($mod(i, 2) === 0) && WHITE)) ?? C(200, 220, 255)) }), d]);
				}
				animate(0.45, function (k) {
					for (let $v69 = 0, $v70 = $arr(rays); $v69 < $v70.length; $v69++) {
						let e = $v70[$v69];
						if (e == null) break;
						stretch($get(e, 1), $add(pos, $mul($mul($get(e, 2), r), 0.2)), $add(pos, $mul($mul($get(e, 2), r), ($add(0.3, $mul(1.6, outCubic(k)))))), $add($mul(0.6, ($sub(1, k))), 0.05));
						$get(e, 1).Transparency = k;
					}
				}, function () {
					for (let $v71 = 0, $v72 = $arr(rays); $v71 < $v72.length; $v71++) {
						let e = $v72[$v71];
						if (e == null) break;
						$mc($get(e, 1), "Destroy");
					}
				});
			}
			burst(pos, WHITE, 30, 1.2, 45);
			light(pos, WHITE, $mul(r, 3), 0.5);
			shake(pos, 0.6, 60);
		};
		H.C_Judgement = function (p) {
			let pos = p.Position, r = ($n(p.Radius) ?? 12), dur = ($n(p.Duration) ?? 1.6);
			if ((!$t(pos) || $t(full(30)))) {
				return;
			}
			let gold = C(255, 225, 120);
			let pts = [];
			for (let i = 1, $v73 = 6; i <= $v73; i++) {
				let a = $mul((i / 6), TAU);
				$ins(pts, $add(pos, Vector3.new($mul(math.cos(a), r), 0.1, $mul(math.sin(a), r))));
			}
			let lines = [];
			for (let i = 1, $v74 = 6; i <= $v74; i++) {
				let a = $get(pts, i), b = $get(pts, ($mod(((i + 1)), 6) + 1));
				let l = fxPart({ Color: gold, Transparency: 0.2 });
				stretch(l, a, b, 0.35, 0.1);
				$ins(lines, l);
			}
			let pillars = [];
			for (let i = 1, $v75 = 6; i <= $v75; i++) {
				$ins(pillars, fxPart({ Shape: Enum.PartType.Cylinder, Color: ($n((($mod(i, 2) === 0) && WHITE)) ?? gold), Transparency: 0.3 }));
			}
			animate(dur, function (k, t) {
				let u = math.clamp($div(($sub(t, 0.35)), ($sub(dur, 0.55))), 0, 1);
				let w = (2.2 * math.min(1, $div(t, 0.25)));
				for (let $v76 = 0, $v77 = $arr(pillars); $v76 < $v77.length; $v76++) {
					let pl = $v77[$v76];
					if (pl == null) break;
					let i = $v76 + 1;
					let a = $add($mul((i / 6), TAU), $mul(u, 1.4));
					let rr = $mul(r, ($sub(1, outCubic(u))));
					let at = $add(pos, Vector3.new($mul(math.cos(a), rr), 30, $mul(math.sin(a), rr)));
					pl.Size = Vector3.new(60, w, w);
					pl.CFrame = $mul(CFrame.new(at), CFrame.Angles(0, 0, $div(math.pi, 2)));
					pl.Transparency = (0.25 + (0.15 * math.sin($add($mul(t, 30), i))));
				}
				for (let $v78 = 0, $v79 = $arr(lines); $v78 < $v79.length; $v78++) {
					let l = $v79[$v78];
					if (l == null) break;
					l.Transparency = $add(0.2, $mul(0.8, k));
				}
			}, function () {
				kill(pillars);
				kill(lines);
				let col = fxPart({ Shape: Enum.PartType.Cylinder, Color: WHITE, Transparency: 0 });
				animate(0.6, function (k) {
					let w = $mul($mul(10, outCubic(math.min(1, $mul(k, 3)))), ($sub(1, $mul(k, 0.6))));
					col.Size = Vector3.new(80, w, w);
					col.CFrame = $mul(CFrame.new($add(pos, Vector3.new(0, 40, 0))), CFrame.Angles(0, 0, $div(math.pi, 2)));
					col.Transparency = $pow(k, 1.5);
				}, function () {
					$mc(col, "Destroy");
				});
				flash($add(pos, Vector3.new(0, 2, 0)), 9, C(255, 245, 200), 0.35);
				groundRing(pos, 2, $mul(r, 1.4), gold, 0.6, 0.9);
				burst($add(pos, Vector3.new(0, 2, 0)), gold, 40, 1.3, 35);
				light($add(pos, Vector3.new(0, 4, 0)), gold, 50, 0.8);
				shake(pos, 0.6, 70);
			});
			burst($add(pos, Vector3.new(0, 1, 0)), gold, 20, 0.8, 6, TEX.Sparkle, { Acceleration: Vector3.new(0, 6, 0) });
		};
		H.C_CrystalPrison = function (p) {
			let model = p.Model;
			let root = rootOf(model);
			if ((!$t(root) || $t(full(14)))) {
				return;
			}
			let dur = ($n(p.Duration) ?? 1.6);
			let size = $mc(model, "GetExtentsSize");
			let base = ($n(feetOf(model)) ?? root.Position);
			let rr = ((math.max(size.X, size.Z) * 0.55) + 0.8);
			let hh = ((size.Y * 1.3) + 2);
			let cry = C(80, 245, 225);
			let walls = [], tops = [];
			for (let i = 1, $v80 = 6; i <= $v80; i++) {
				$ins(walls, fxPart({ Size: Vector3.new(0.6, 0.2, $mul(rr, 1.2)), Color: cry, Material: GLASS, Transparency: 0.35 }));
				$ins(tops, fxPart({ Shape: Enum.PartType.Wedge, Size: Vector3.new(0.5, 0.2, rr), Color: C(200, 255, 250), Material: GLASS, Transparency: 0.3 }));
			}
			let core = fxPart({ Size: Vector3.new($mul(rr, 1.5), 0.2, $mul(rr, 1.5)), Color: cry, Transparency: 0.75 });
			animate(dur, function (_, t) {
				let g = outCubic(math.min(1, $div(t, 0.25)));
				let h = $mul(hh, g);
				for (let $v81 = 0, $v82 = $arr(walls); $v81 < $v82.length; $v81++) {
					let w = $v82[$v81];
					if (w == null) break;
					let i = $v81 + 1;
					let a = $mul((i / 6), TAU);
					w.Size = Vector3.new(0.6, math.max(0.2, h), $mul(rr, 1.18));
					w.CFrame = $mul($mul(CFrame.new(base), CFrame.Angles(0, a, 0)), CFrame.new(rr, $div(h, 2), 0));
					let tp = $get(tops, i);
					tp.Size = Vector3.new(0.5, math.max(0.2, $mul(h, 0.35)), $mul(rr, 1));
					tp.CFrame = $mul($mul($mul(CFrame.new(base), CFrame.Angles(0, a, 0)), CFrame.new($mul(rr, 0.5), $add(h, $mul(h, 0.175)), 0)), CFrame.Angles(0, $div($unm(math.pi), 2), 0));
				}
				core.Size = Vector3.new($mul(rr, 1.6), math.max(0.2, h), $mul(rr, 1.6));
				core.CFrame = $mul(CFrame.new($add(base, Vector3.new(0, $div(h, 2), 0))), CFrame.Angles(0, $div(math.pi, 6), 0));
			}, function () {
				kill(walls);
				kill(tops);
				$mc(core, "Destroy");
			});
			burst($add(base, Vector3.new(0, 1, 0)), cry, 24, 0.9, 20);
			light($add(base, Vector3.new(0, 3, 0)), cry, 22, dur);
		};
		H.C_CrystalShatter = function (p) {
			let pos = p.Position;
			if (!$t(pos)) {
				return;
			}
			let cry = C(80, 245, 225);
			flash($add(pos, Vector3.new(0, 2, 0)), 7, C(210, 255, 250), 0.3);
			if (!$t(full(14))) {
				for (let _ = 1, $v83 = q(14); _ <= $v83; _++) {
					let s = rnd(0.6, 1.6);
					let shard = fxPart({ Size: Vector3.new($mul(s, 0.5), $mul(s, 1.6), $mul(s, 0.5)), Color: cry, Material: GLASS, Transparency: 0.2, CFrame: CFrame.new(pos) });
					let v = $mul(Vector3.new(rnd((-1), 1), rnd(0.6, 1.5), rnd((-1), 1)).Unit, rnd(25, 45));
					let spin = Vector3.new(rnd((-9), 9), rnd((-9), 9), rnd((-9), 9));
					animate(rnd(0.8, 1.1), function (k, t) {
						let at = $add($add(pos, $mul(v, t)), Vector3.new(0, $mul($mul((-50), t), t), 0));
						if ((at.Y < (pos.Y - 0.5))) {
							at = Vector3.new(at.X, (pos.Y - 0.5), at.Z);
						}
						shard.CFrame = $mul(CFrame.new(at), CFrame.Angles($mul(spin.X, t), $mul(spin.Y, t), $mul(spin.Z, t)));
						shard.Transparency = (0.2 + ((0.8 * math.max(0, $sub(k, 0.6))) / 0.4));
					}, function () {
						$mc(shard, "Destroy");
					});
				}
			}
			groundRing(pos, 2, 14, cry, 0.5, 0.8);
			burst($add(pos, Vector3.new(0, 1, 0)), C(220, 255, 255), 40, 1.1, 40);
			light(pos, cry, 30, 0.6);
			shake(pos, 0.8, 70);
		};
		H.C_IceEgg = function (p) {
			let model = p.Model;
			let root = rootOf(model);
			if ((!$t(root) || $t(full(8)))) {
				return;
			}
			let dur = ($n(p.Duration) ?? 1.4);
			let size = $mc(model, "GetExtentsSize");
			let egg = fxPart({ Shape: Enum.PartType.Ball, Size: Vector3.one, Color: C(190, 235, 255), Material: Enum.Material.Ice, Transparency: 0.25 });
			let cracks = [];
			for (let _ = 1, $v84 = 5; _ <= $v84; _++) {
				$ins(cracks, [fxPart({ Size: Vector3.new(0.15, 0.15, 1), Color: WHITE, Transparency: 1 }), Vector3.new(rnd((-1), 1), rnd((-0.6), 1), rnd((-1), 1)).Unit]);
			}
			let eggSize = Vector3.new(((size.X * 0.9) + 1.5), ((size.Y * 1.25) + 1.5), ((size.Z * 0.7) + 1.5));
			animate(dur, function (k, t) {
				if (!$t(root.Parent)) {
					return true;
				}
				let g = outCubic(math.min(1, $div(t, 0.25)));
				egg.Size = $mul(eggSize, g);
				egg.CFrame = $mul(CFrame.new(root.Position), CFrame.Angles(0, $mul(t, 0.5), 0));
				for (let $v85 = 0, $v86 = $arr(cracks); $v85 < $v86.length; $v85++) {
					let c = $v86[$v85];
					if (c == null) break;
					let i = $v85 + 1;
					let show = (k > (0.45 + (i * 0.08)));
					let at = $add(root.Position, $mul($mul($get(c, 2), eggSize.Y), 0.48));
					$get(c, 1).CFrame = $mul(CFrame.lookAt(at, $add(at, $mc($get(c, 2), "Cross", Vector3.yAxis))), CFrame.Angles(0, 0, i));
					$get(c, 1).Size = Vector3.new(0.15, 0.15, ($n(($a(show) && (eggSize.X * 0.5))) ?? 0.1));
					$get(c, 1).Transparency = ($n(($a(show) && 0)) ?? 1);
				}
				return undefined;
			}, function () {
				$mc(egg, "Destroy");
				for (let $v87 = 0, $v88 = $arr(cracks); $v87 < $v88.length; $v87++) {
					let c = $v88[$v87];
					if (c == null) break;
					$mc($get(c, 1), "Destroy");
				}
			});
			burst(root.Position, C(220, 245, 255), 16, 0.8, 8);
		};
		H.C_FeatherStorm = function (p) {
			let pos = p.Position;
			if (!$t(pos)) {
				return;
			}
			let r = ($n(p.Radius) ?? 16);
			let n = math.min(($n(p.Count) ?? 14), $add(q(14), 2));
			flash(pos, 6, C(220, 245, 255), 0.3);
			if ($t(full($mul(n, 2)))) {
				return;
			}
			let cols = [C(240, 250, 255), C(150, 215, 255), C(80, 160, 255)];
			for (let i = 1, $v89 = n; i <= $v89; i++) {
				let a = $mul($div(i, n), TAU);
				let feather = fxPart({ Size: Vector3.new(0.25, 0.8, 2.6), Color: $get(cols, ($mod(i, 3) + 1)), Material: GLASS, Transparency: 0.1 });
				let tip = fxPart({ Size: Vector3.new(0.3, 0.3, 1.2), Color: WHITE });
				let land = $add(pos, Vector3.new($mul($mul(math.cos($add(a, 0.6)), r), rnd(0.6, 1)), (-1), $mul($mul(math.sin($add(a, 0.6)), r), rnd(0.6, 1))));
				let from = $add(pos, Vector3.new(0, 1, 0));
				animate((0.45 + (i * 0.015)), function (k) {
					let u = outCubic(k);
					let sp = $add(a, $mul(u, 0.6));
					let at = $add($add($mc(from, "Lerp", land, u), $mul($mul(Vector3.new(math.cos(sp), 0, math.sin(sp)), math.sin($mul(u, math.pi))), 3)), Vector3.new(0, (math.sin($mul(u, math.pi)) * 4), 0));
					let nextAt = $add(at, ($sub(land, from)).Unit);
					feather.CFrame = CFrame.lookAt(at, nextAt);
					tip.CFrame = $mul(feather.CFrame, CFrame.new(0, 0, (-1.4)));
				}, function () {
					$mc(tip, "Destroy");
					feather.CFrame = $mul(CFrame.new($add(land, Vector3.new(0, 1, 0))), CFrame.Angles(math.rad((-70)), a, 0));
					animate(1.6, function (k) {
						feather.Transparency = (0.1 + ((0.9 * math.max(0, $sub(k, 0.6))) / 0.4));
					}, function () {
						$mc(feather, "Destroy");
					});
					burst($add(land, Vector3.new(0, 0.5, 0)), C(200, 240, 255), 5, 0.6, 8);
				});
			}
			groundRing($sub(pos, Vector3.new(0, 1, 0)), 2, r, C(170, 225, 255), 0.6, 0.8);
			burst(pos, C(230, 250, 255), 40, 1, 40);
			light(pos, C(170, 225, 255), 40, 0.7);
			shake(pos, 0.5, 60);
		};
		let bolt = Effects.Bolt;
		H.C_RodStrike = function (p) {
			let model = p.Model;
			let root = rootOf(model);
			if (!$t(root)) {
				return;
			}
			let cloud = $mc(model, "FindFirstChild", "NuvemBolo");
			let top = (($n(($a(cloud) && cloud.Position)) ?? $add(root.Position, Vector3.new(0, (root.Size.Y * 2), 0))));
			let sky = $add(top, Vector3.new(rnd((-3), 3), 45, rnd((-3), 3)));
			let yellow = C(255, 230, 80);
			if ($t(bolt)) {
				$sp(bolt(sky, top, yellow, 0.35, 1.6));
				task.delay(0.12, function () {
					if ($t(root.Parent)) {
						$sp(bolt(top, root.Position, yellow, 0.3, 1));
					}
				});
			}
			flash(top, 6, C(255, 250, 200), 0.3);
			burst(root.Position, yellow, 30, 1, 30, TEX.Spark);
			light(root.Position, yellow, 40, 0.6);
			shake(root.Position, 0.5, 70);
		};
		H.C_ThunderWall = function (p) {
			let from = p.From, dir = p.Direction;
			if (!($t(from) && $t(dir))) {
				return;
			}
			let len = ($n(p.Length) ?? 30), width = ($n(p.Width) ?? 10), dur = ($n(p.Duration) ?? 0.6);
			let right = $mc(dir, "Cross", Vector3.yAxis).Unit;
			let rows = math.max(3, math.floor($div(len, 4)));
			let per = math.max(2, q(4));
			let yellow = C(255, 230, 80);
			for (let i = 1, $v90 = rows; i <= $v90; i++) {
				task.delay($div($mul(dur, ((i - 1))), rows), function () {
					let c = $add(from, $mul(dir, ($div($mul(i, len), rows))));
					for (let j = 1, $v91 = per; j <= $v91; j++) {
						let x = $mul($div(($sub(j, $div(($add(per, 1)), 2))), per), width);
						let bottom = $add(c, $mul(right, ($add(x, rnd((-0.8), 0.8)))));
						if (($t(bolt) && !$t(full($mul(per, 2))))) {
							$sp(bolt($add(bottom, Vector3.new(rnd((-1), 1), rnd(10, 16), rnd((-1), 1))), bottom, ($n((($mod(j, 2) === 0) && yellow)) ?? C(170, 220, 255)), 0.25, 0.7));
						}
					}
					burst($add(c, Vector3.new(0, 0.5, 0)), yellow, 10, 0.8, 18, TEX.Spark);
					if (($mod(i, 2) === 0)) {
						light(c, yellow, 20, 0.25);
					}
				});
			}
			shake(from, 0.5, 70);
		};
		H.C_Rainbow = function (p) {
			let from = p.From, to = p.To;
			if ((!($t(from) && $t(to)) || $t(full(60)))) {
				return;
			}
			let height = ($n(p.Height) ?? 14), dur = ($n(p.Duration) ?? 1.6);
			let n = $add(q(14), 4);
			let bands = [];
			let span = $sub(to, from);
			let right = Vector3.new((-span.Z), 0, span.X);
			right = ($n(((right.Magnitude > 0.01) && right.Unit)) ?? Vector3.xAxis);
			for (let $v92 = 0, $v93 = $arr(RAINBOW); $v92 < $v93.length; $v92++) {
				let col = $v93[$v92];
				if (col == null) break;
				let b = $v92 + 1;
				let segs = [];
				for (let _ = 1, $v94 = n; _ <= $v94; _++) {
					$ins(segs, fxPart({ Color: col, Transparency: 0.15 }));
				}
				$ins(bands, [segs, b]);
			}
			let arc = function (u, b) {
				let y = $mul(math.sin($mul(u, math.pi)), ($add(height, $mul(($sub(3.5, b)), 0.9))));
				return $add($mc(from, "Lerp", to, u), Vector3.new(0, $add(y, 0.5), 0));
			};
			animate(dur, function (k, t) {
				let reveal = math.min(1, $div(t, 0.4));
				for (let $v95 = 0, $v96 = $arr(bands); $v95 < $v96.length; $v95++) {
					let e = $v96[$v95];
					if (e == null) break;
					for (let $v97 = 0, $v98 = $arr($get(e, 1)); $v97 < $v98.length; $v97++) {
						let s = $v98[$v97];
						if (s == null) break;
						let i = $v97 + 1;
						let u0 = $div(((i - 1)), n), u1 = $div(i, n);
						if ((u1 <= reveal)) {
							stretch(s, arc(u0, $get(e, 2)), arc(u1, $get(e, 2)), 0.9, 0.4);
							s.Transparency = (0.15 + ((0.85 * math.max(0, $sub(k, 0.75))) / 0.25));
						} else {
							s.Transparency = 1;
						}
					}
				}
			}, function () {
				for (let $v99 = 0, $v100 = $arr(bands); $v99 < $v100.length; $v99++) {
					let e = $v100[$v99];
					if (e == null) break;
					kill($get(e, 1));
				}
			});
			burst($add(from, Vector3.new(0, 1, 0)), C(255, 220, 250), 20, 1, 14);
		};
		H.C_Prism = function (p) {
			let pos = p.Position;
			if (!$t(pos)) {
				return;
			}
			let r = ($n(p.Radius) ?? 10);
			flash($add(pos, Vector3.new(0, 1.5, 0)), $mul(r, 0.7), WHITE, 0.3);
			for (let $v101 = 0, $v102 = $arr(RAINBOW); $v101 < $v102.length; $v101++) {
				let col = $v102[$v101];
				if (col == null) break;
				let i = $v101 + 1;
				task.delay((i * 0.05), function () {
					groundRing(pos, 2, $mul(r, ((0.6 + (i * 0.12)))), col, 0.55, 0.7);
				});
				burst($add(pos, Vector3.new(0, 1.5, 0)), col, 8, 1, 35);
			}
			light(pos, C(255, 200, 255), 35, 0.6);
			shake(pos, 0.6, 60);
		};
		let BLADE_PARTS = { KatanaLamina: true, KatanaFio: true, KatanaCabo: true, KatanaTsuba: true };
		H.C_Blades = function (p) {
			let owner = p.Model, target = p.Target;
			let oRoot = rootOf(owner), tRoot = rootOf(target);
			if ((!($t(oRoot) && $t(tRoot)) || $t(full(16)))) {
				return;
			}
			let dur = ($n(p.Duration) ?? 2.2);
			let count = ($n(p.Count) ?? 4);
			hideParts(owner, BLADE_PARTS, dur);
			let blades = [];
			for (let i = 1, $v103 = count; i <= $v103; i++) {
				let blade = fxPart({ Size: Vector3.new(0.15, 0.5, 4.2), Color: C(225, 230, 240), Material: Enum.Material.Metal });
				let edge = fxPart({ Size: Vector3.new(0.1, 0.12, 4.1), Color: C(255, 50, 50) });
				let hilt = fxPart({ Size: Vector3.new(0.25, 0.25, 1.1), Color: C(30, 20, 25), Material: Enum.Material.Fabric });
				$ins(blades, [blade, edge, hilt, $mul($div(((i - 1)), count), TAU)]);
			}
			let trailT = 0;
			animate(dur, function (k, t) {
				if (!($t(oRoot.Parent) && $t(tRoot.Parent))) {
					return true;
				}
				let out = math.min(1, $div(t, 0.3));
				let back = ($n(((k > 0.85) && $div(($sub(k, 0.85)), 0.15))) ?? 0);
				let orbitR = math.max(3.5, ((tRoot.Size.Z * 0.9) + 2));
				for (let $v104 = 0, $v105 = $arr(blades); $v104 < $v105.length; $v104++) {
					let e = $v105[$v104];
					if (e == null) break;
					let i = $v104 + 1;
					let a = $add($get(e, 4), $mul(t, 9));
					let tilt = (math.sin($add($mul(t, 4), i)) * 0.6);
					let orbit = $add(tRoot.Position, Vector3.new($mul(math.cos(a), orbitR), ((math.sin($add($mul(a, 2), i)) * 1.2) + 0.5), $mul(math.sin(a), orbitR)));
					let home = $add(oRoot.Position, Vector3.new(0, oRoot.Size.Y, 0));
					let at = $mc($mc(home, "Lerp", orbit, out), "Lerp", home, back);
					let cf = $mul($mul(CFrame.new(at), CFrame.Angles(tilt, $unm(a), 0)), CFrame.Angles(0, 0, $mul(t, 20)));
					$get(e, 1).CFrame = cf;
					$get(e, 2).CFrame = $mul(cf, CFrame.new(0, (-0.28), 0));
					$get(e, 3).CFrame = $mul(cf, CFrame.new(0, 0, 2.6));
				}
				if (($sub(t, trailT) > 0.12)) {
					trailT = t;
					burst(tRoot.Position, C(255, 60, 60), 4, 0.8, 20, TEX.Spark);
				}
				return undefined;
			}, function () {
				for (let $v106 = 0, $v107 = $arr(blades); $v106 < $v107.length; $v106++) {
					let e = $v107[$v106];
					if (e == null) break;
					$mc($get(e, 1), "Destroy");
					$mc($get(e, 2), "Destroy");
					$mc($get(e, 3), "Destroy");
				}
			});
		};
		H.C_Missiles = function (p) {
			let owner = p.Model, target = p.Target;
			let oRoot = rootOf(owner);
			if (!$t(oRoot)) {
				return;
			}
			let count = math.min(($n(p.Count) ?? 12), $add(6, q(6)));
			let flight = ($n(p.Flight) ?? 1.1), interval = ($n(p.Interval) ?? 0.08);
			let tips = [];
			for (let $v108 = 0, $v109 = $arr($mc(owner, "GetDescendants")); $v108 < $v109.length; $v108++) {
				let d = $v109[$v108];
				if (d == null) break;
				if (($t($mc(d, "IsA", "BasePart")) && (d.Name === "MissilPonta"))) {
					$ins(tips, d);
				}
			}
			let lastPos = ($n(p.Position) ?? oRoot.Position);
			for (let i = 1, $v110 = count; i <= $v110; i++) {
				task.delay($mul(((i - 1)), interval), function () {
					if ((!$t(oRoot.Parent) || $t(full(3)))) {
						return;
					}
					let src = $get(tips, ($mod(((i - 1)), math.max(1, $len(tips))) + 1));
					let start = ($n(($a(($a(src) && src.Parent)) && src.Position)) ?? $add(oRoot.Position, Vector3.new(0, oRoot.Size.Y, 0)));
					let up = $add(start, Vector3.new(rnd((-6), 6), rnd(14, 22), rnd((-6), 6)));
					let body = fxPart({ Size: Vector3.new(0.45, 0.45, 1.6), Color: C(235, 235, 240), Material: Enum.Material.Metal });
					let nose = fxPart({ Shape: Enum.PartType.Ball, Size: $mul(Vector3.one, 0.5), Color: C(230, 50, 40), Material: Enum.Material.SmoothPlastic });
					let att = Instance.new("Attachment");
					att.Parent = body;
					att.Position = Vector3.new(0, 0, 0.8);
					let smoke = Instance.new("ParticleEmitter");
					smoke.Texture = TEX.Smoke;
					smoke.Color = ColorSequence.new(C(220, 220, 225));
					smoke.LightEmission = 0;
					smoke.Size = NS(0, 0.5, 1, 1.8);
					smoke.Transparency = NS(0, 0.3, 1, 1);
					smoke.Lifetime = NumberRange.new(0.5, 0.8);
					smoke.Speed = NumberRange.new(0, 1);
					smoke.Rate = $mul(30, quality());
					smoke.Parent = att;
					let fire = Instance.new("ParticleEmitter");
					fire.Texture = TEX.Fire;
					fire.Color = ColorSequence.new(C(255, 180, 60));
					fire.LightEmission = 1;
					fire.Size = NS(0, 0.6, 1, 0);
					fire.Lifetime = NumberRange.new(0.1, 0.2);
					fire.Speed = NumberRange.new(0, 0);
					fire.Rate = $mul(40, quality());
					fire.Parent = att;
					let last = start;
					animate(flight, function (k) {
						let tRoot = rootOf(target);
						if ($t(tRoot)) {
							lastPos = tRoot.Position;
						}
						let goal = $add(lastPos, Vector3.new((math.sin((i * 2.3)) * 2.5), (-0.5), (math.cos((i * 1.7)) * 2.5)));
						let a = $mc(start, "Lerp", up, k);
						let b = $mc(up, "Lerp", goal, k);
						let at = $mc(a, "Lerp", b, k);
						if ((($sub(at, last)).Magnitude > 0.01)) {
							body.CFrame = CFrame.lookAt(at, $add(at, ($sub(at, last))));
						}
						nose.CFrame = $mul(body.CFrame, CFrame.new(0, 0, (-0.85)));
						last = at;
					}, function () {
						let hit = body.Position;
						$mc(body, "Destroy");
						$mc(nose, "Destroy");
						flash(hit, 3, C(255, 200, 100), 0.2);
						burst(hit, C(255, 150, 50), 10, 1.8, 18, TEX.Fire, { LightEmission: 1 });
						burst(hit, C(90, 85, 85), 6, 2.5, 8, TEX.Smoke, { LightEmission: 0 });
						if (($mod(i, 3) === 0)) {
							light(hit, C(255, 160, 60), 18, 0.25);
							shake(hit, 0.2, 50);
						}
					});
				});
			}
		};
		H.C_Cannon = function (p) {
			let owner = p.Model;
			let oRoot = rootOf(owner);
			if (!($t(oRoot) && $t(p.To))) {
				return;
			}
			let mouth = $mc(owner, "FindFirstChild", "CanhaoBoca");
			let from = ($n(($a(mouth) && mouth.Position)) ?? oRoot.Position);
			let cyan = C(80, 230, 255);
			let beam = fxPart({ Color: cyan, Transparency: 0.1 });
			let core = fxPart({ Color: WHITE });
			animate(0.5, function (k) {
				let w = $mul((2.6 * math.sin($mul($mul(math.min(1, $mul(k, 2)), math.pi), 0.5))), ($sub(1, $mul(k, 0.7))));
				stretch(beam, from, p.To, $add(w, 0.1));
				stretch(core, from, p.To, $add($mul(w, 0.4), 0.05));
				beam.Transparency = $add(0.1, $mul(0.9, $pow(k, 2)));
				core.Transparency = $pow(k, 2);
			}, function () {
				$mc(beam, "Destroy");
				$mc(core, "Destroy");
			});
			flash(from, 3, cyan, 0.2);
			flash(p.To, 6, cyan, 0.35);
			burst(p.To, cyan, 30, 1.2, 35, TEX.Spark);
			light(p.To, cyan, 30, 0.5);
			shake(p.To, 0.5, 60);
		};
		let MOON_PARTS = { Lua: true, Cratera: true };
		H.C_MoonFall = function (p) {
			let owner = p.Model;
			let oRoot = rootOf(owner);
			let pos = p.Position;
			if ((!($t(oRoot) && $t(pos)) || $t(full(10)))) {
				return;
			}
			let delay = ($n(p.Delay) ?? 1.4);
			let r = ($n(p.Radius) ?? 11);
			let moonPart = $mc(owner, "FindFirstChild", "Lua");
			let start = ($n(($a(moonPart) && moonPart.Position)) ?? $add(oRoot.Position, Vector3.new(4, 2, 0)));
			hideParts(owner, MOON_PARTS, $add(delay, 1.5));
			let moon = fxPart({ Shape: Enum.PartType.Ball, Size: $mul(Vector3.one, 2), Color: C(205, 205, 215), Material: Enum.Material.Slate });
			let craters = [];
			for (let i = 1, $v111 = 5; i <= $v111; i++) {
				$ins(craters, [fxPart({ Shape: Enum.PartType.Ball, Color: C(150, 150, 162), Material: Enum.Material.Slate }), Vector3.new(math.cos((i * 1.3)), (math.sin((i * 2.1)) * 0.6), math.sin((i * 1.3))).Unit]);
			}
			let a = Instance.new("Attachment");
			a.Parent = moon;
			let fire = Instance.new("ParticleEmitter");
			fire.Texture = TEX.Fire;
			fire.Color = ColorSequence.new(C(255, 220, 160), C(255, 120, 60));
			fire.LightEmission = 1;
			fire.Size = NS(0, 4, 1, 1);
			fire.Transparency = NS(0, 0.3, 1, 1);
			fire.Lifetime = NumberRange.new(0.3, 0.5);
			fire.Speed = NumberRange.new(2, 4);
			fire.SpreadAngle = Vector2.new(30, 30);
			fire.Rate = 0;
			fire.Parent = a;
			let sky = $add(pos, Vector3.new($mul(r, 0.6), 55, $mul(r, 0.4)));
			animate(delay, function (k) {
				let size;
				let at;
				if ((k < 0.45)) {
					let u = outCubic($div(k, 0.45));
					at = $mc(start, "Lerp", sky, u);
					size = $add(2, $mul(14, u));
				} else {
					let u = $pow(($div(($sub(k, 0.45)), 0.55)), 2);
					at = $mc(sky, "Lerp", $add(pos, Vector3.new(0, 4, 0)), u);
					size = $sub(16, $mul(4, u));
					fire.Rate = $mul(60, quality());
				}
				moon.Size = $mul(Vector3.one, size);
				moon.CFrame = $mul(CFrame.new(at), CFrame.Angles($mul(k, 3), $mul(k, 2), 0));
				for (let $v112 = 0, $v113 = $arr(craters); $v112 < $v113.length; $v112++) {
					let c = $v113[$v112];
					if (c == null) break;
					$get(c, 1).Size = Vector3.new($mul(size, 0.3), $mul(size, 0.3), $mul(size, 0.1));
					$get(c, 1).CFrame = CFrame.lookAt($add(at, $mul($mul($mul(moon.CFrame.Rotation, $get(c, 2)), size), 0.46)), $add(at, $mul($mul(moon.CFrame.Rotation, $get(c, 2)), size)));
				}
			}, function () {
				$mc(moon, "Destroy");
				for (let $v114 = 0, $v115 = $arr(craters); $v114 < $v115.length; $v114++) {
					let c = $v115[$v114];
					if (c == null) break;
					$mc($get(c, 1), "Destroy");
				}
				if ($t(H.Explosion)) {
					$sp(H.Explosion({ Position: $add(pos, Vector3.new(0, 1, 0)), Radius: r, Color: C(230, 220, 200), Kind: "void" }));
				}
				if (!$t(full(12))) {
					let rocks = [];
					for (let i = 1, $v116 = q(12); i <= $v116; i++) {
						let ang = $mul((i / 12), TAU);
						let s = rnd(1.5, 3);
						$ins(rocks, fxPart({ Size: Vector3.new(s, $mul(s, 0.8), s), Color: C(120, 115, 120), Material: Enum.Material.Slate, CFrame: $mul(CFrame.new($add(pos, Vector3.new($mul($mul(math.cos(ang), r), 0.75), 0.3, $mul($mul(math.sin(ang), r), 0.75)))), CFrame.Angles(rnd(0, 3), rnd(0, 3), 0)) }));
					}
					task.delay(2.5, function () {
						kill(rocks);
					});
				}
				groundRing(pos, 2, $mul(r, 1.8), C(235, 210, 160), 0.7, 1.2);
				task.delay(0.15, function () {
					groundRing(pos, 2, $mul(r, 2.2), C(205, 170, 120), 0.8, 0.9);
				});
				burst($add(pos, Vector3.new(0, 2, 0)), C(170, 160, 150), 30, 5, 20, TEX.Smoke, { LightEmission: 0, Size: NS(0, 3, 1, 8) });
				shake(pos, 1, 90);
			});
		};
	};
}
