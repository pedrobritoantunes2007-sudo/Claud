// Gerado automaticamente de client/EffectsPacks/PackB.lua (código do jogo Roblox) por tools/lua2js — não edite à mão.
import { $t, $a, $n, $1, $M, $mv, $lst, $get, $set, $tm, $tc, $len, $cat, $eq, $add, $sub, $mul, $div, $mod, $pow, $idiv, $unm, $mc, $cy, $sp, $sp1, $W, $WS, $ins, $ins3, $arr, $pairs, $iter, $pcallG, $warnWait } from '../../rbx/lua.js';

export default function ($G, $script) {
	let game = $G["game"], Color3 = $G["Color3"], math = $G["math"], workspace = $G["workspace"], Instance = $G["Instance"], table = $G["table"], NumberSequenceKeypoint = $G["NumberSequenceKeypoint"], NumberSequence = $G["NumberSequence"], Enum = $G["Enum"], pairs = $G["pairs"], os = $G["os"], pcall = $G["pcall"], warn = $G["warn"], ipairs = $G["ipairs"], ColorSequence = $G["ColorSequence"], NumberRange = $G["NumberRange"], Vector2 = $G["Vector2"], Vector3 = $G["Vector3"], CFrame = $G["CFrame"], task = $G["task"];
	const $va = [];
	let Debris = $mc(game, "GetService", "Debris");
	let Players = $mc(game, "GetService", "Players");
	let RunService = $mc(game, "GetService", "RunService");
	let TEX = { Sparkle: "rbxasset://textures/particles/sparkles_main.dds", Smoke: "rbxasset://textures/particles/smoke_main.dds", Fire: "rbxasset://textures/particles/fire_main.dds", Spark: "rbxasset://textures/particles/fire_sparks_main.dds", Glow: "rbxasset://textures/particles/forcefield_glow_main.dds" };
	let C = Color3.fromRGB;
	let WHITE = Color3.new(1, 1, 1);
	let PI = math.pi;
	return function (H, Effects) {
		let player = Players.LocalPlayer;
		let folder = $mc(workspace, "FindFirstChild", "FX");
		if (!$t(folder)) {
			folder = Instance.new("Folder");
			folder.Name = "FX";
			folder.Parent = workspace;
		}
		let QUALITY = { Alto: 1, "Médio": 0.6, Baixo: 0.3 };
		let quality = function () {
			return ($n($get(QUALITY, $mc(player, "GetAttribute", "GraphicsQuality"))) ?? 1);
		};
		let q = function (n) {
			return math.max(1, math.floor($add($mul(n, quality()), 0.5)));
		};
		let crowded = function () {
			return ($len($mc(folder, "GetChildren")) > $mul(450, ($add(0.35, $mul(0.65, quality())))));
		};
		let NS = function (...$va) {
			let a = [...$va];
			let kps = [];
			for (let i = 1, $v1 = $len(a); i <= $v1; i += 2) {
				$ins(kps, NumberSequenceKeypoint.new($get(a, i), $get(a, (i + 1))));
			}
			return NumberSequence.new(kps);
		};
		let rnd = function (a, b) {
			return $add(a, $mul(math.random(), ($sub(b, a))));
		};
		let part = function (props) {
			let p = Instance.new("Part");
			p.Anchored = true;
			p.CanCollide = false;
			p.CanQuery = false;
			p.CanTouch = false;
			p.CastShadow = false;
			p.Material = Enum.Material.Neon;
			p.TopSurface = Enum.SurfaceType.Smooth;
			p.BottomSurface = Enum.SurfaceType.Smooth;
			for (let [k, v] of $pairs(props)) {
				$set((p), k, v);
			}
			p.Parent = folder;
			return p;
		};
		let ball = function (size, color, material, transparency) {
			return part({ Shape: Enum.PartType.Ball, Size: size, Color: color, Material: ($n(material) ?? Enum.Material.Neon), Transparency: ($n(transparency) ?? 0) });
		};
		let anims = [];
		let animate = function (duration, fn, done) {
			$ins(anims, { Start: os.clock(), Dur: math.max(duration, 0.001), Fn: fn, Done: done });
		};
		$mc(RunService.RenderStepped, "Connect", function () {
			let now = os.clock();
			for (let i = $len(anims), $v2 = 1; i >= $v2; i += (-1)) {
				let a = $get(anims, i);
				let k = math.clamp($div(($sub(now, a.Start)), a.Dur), 0, 1);
				let [ok, stop] = $lst([], pcall(a.Fn, k, $sub(now, a.Start)), 2);
				if ((((k >= 1) || (stop === true)) || !$t(ok))) {
					$set(anims, i, $get(anims, $len(anims)));
					$set(anims, $len(anims), undefined);
					if (!$t(ok)) {
						warn("[EffectsB] anim", stop);
					}
					if ($t(a.Done)) {
						pcall(a.Done);
					}
				}
			}
		});
		let clean = function (list) {
			return function () {
				for (let $v3 = 0, $v4 = $arr(list); $v3 < $v4.length; $v3++) {
					let p = $v4[$v3];
					if (p == null) break;
					$mc(p, "Destroy");
				}
			};
		};
		let anchor = function (position, life) {
			let a = Instance.new("Attachment");
			a.Position = position;
			a.Parent = workspace.Terrain;
			$mc(Debris, "AddItem", a, life);
			return a;
		};
		let burst = function (position, color, count, size, speed, texture, extra) {
			let e = Instance.new("ParticleEmitter");
			e.Texture = ($n(texture) ?? TEX.Sparkle);
			e.Color = ColorSequence.new(color);
			e.LightEmission = 0.8;
			e.Size = NS(0, size, 1, 0);
			e.Transparency = NS(0, 0, 0.7, 0.3, 1, 1);
			e.Lifetime = NumberRange.new(0.35, 0.8);
			e.Speed = NumberRange.new($mul(speed, 0.4), speed);
			e.SpreadAngle = Vector2.new(180, 180);
			e.Drag = 4;
			e.Rotation = NumberRange.new(0, 360);
			e.RotSpeed = NumberRange.new((-120), 120);
			e.Enabled = false;
			for (let [k, v] of $pairs(($n(extra) ?? []))) {
				$set((e), k, v);
			}
			e.Parent = anchor(position, 3);
			$mc(e, "Emit", q(count));
		};
		let smoke = function (position, color, count, size, speed) {
			burst(position, color, count, size, speed, TEX.Smoke, { Size: NS(0, $mul(size, 0.5), 1, $mul(size, 1.6)), Transparency: NS(0, 0.35, 1, 1), Lifetime: NumberRange.new(0.7, 1.3), LightEmission: 0, Drag: 3, Acceleration: Vector3.new(0, 2, 0) });
		};
		let lights = 0;
		let light = function (position, color, range, duration) {
			if ((lights >= $add(3, $mul(6, quality())))) {
				return;
			}
			lights = $add(lights, 1);
			let l = Instance.new("PointLight");
			l.Color = color;
			l.Range = math.min(range, 60);
			l.Brightness = 4;
			l.Shadows = false;
			l.Parent = anchor(position, $add(duration, 0.1));
			animate(duration, function (k) {
				l.Brightness = $mul(4, ($sub(1, k)));
			}, function () {
				lights = $sub(lights, 1);
			});
		};
		let disc = function (position, radius, color, transparency, material) {
			return part({ Shape: Enum.PartType.Cylinder, Size: Vector3.new(0.12, $mul(radius, 2), $mul(radius, 2)), CFrame: $mul(CFrame.new($add(position, Vector3.new(0, 0.08, 0))), CFrame.Angles(0, 0, $div(PI, 2))), Color: color, Transparency: transparency, Material: ($n(material) ?? Enum.Material.Neon) });
		};
		let ring = function (cf, r0, r1, color, duration, thick) {
			let n = math.max(10, math.floor($mul(20, ($add(0.5, $mul(0.5, quality()))))));
			let list = [];
			for (let _ = 1, $v5 = n; _ <= $v5; _++) {
				$ins(list, part({ Size: Vector3.new(0.4, 0.4, 1), Color: color }));
			}
			let th = ($n(thick) ?? 0.6);
			animate(duration, function (k) {
				let e = $sub(1, $pow(($sub(1, k)), 3));
				let r = $add(r0, $mul(($sub(r1, r0)), e));
				let arc = $mul($div($mul($mul(2, PI), r), n), 1.12);
				for (let $v6 = 0, $v7 = $arr(list); $v6 < $v7.length; $v6++) {
					let p = $v7[$v6];
					if (p == null) break;
					let i = $v6 + 1;
					p.Size = Vector3.new($mul(th, ($sub(1, $mul(0.7, k)))), $mul(th, 0.6), math.max(0.05, arc));
					p.CFrame = $mul($mul(cf, CFrame.Angles(0, $mul($mul($div(i, n), PI), 2), 0)), CFrame.new(r, 0, 0));
					p.Transparency = $pow(k, 1.3);
				}
			}, clean(list));
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
		let partOf = function (model, name) {
			let p = ($a(model) && $mc(model, "FindFirstChild", name));
			if (($t(p) && $t($mc(p, "IsA", "BasePart")))) {
				return p;
			}
			return rootOf(model);
		};
		let fly = function (parts, from, to, duration, height, spin, done) {
			animate(duration, function (k) {
				let p = $add($mc(from, "Lerp", to, k), Vector3.new(0, $mul(math.sin($mul(k, PI)), height), 0));
				let ahead = $add($mc(from, "Lerp", to, math.min(1, $add(k, 0.05))), Vector3.new(0, $mul(math.sin($mul(math.min(1, $add(k, 0.05)), PI)), height), 0));
				let cf = ($n(((($sub(ahead, p)).Magnitude > 0.01) && CFrame.lookAt(p, ahead))) ?? CFrame.new(p));
				cf = $mul(cf, CFrame.Angles(0, 0, $mul((($n(spin) ?? 0)), k)));
				for (let $v8 = 0, $v9 = $arr(parts); $v8 < $v9.length; $v8++) {
					let e = $v9[$v8];
					if (e == null) break;
					$get(e, 1).CFrame = $mul(cf, $get(e, 2));
				}
			}, function () {
				for (let $v10 = 0, $v11 = $arr(parts); $v10 < $v11.length; $v10++) {
					let e = $v11[$v10];
					if (e == null) break;
					$mc($get(e, 1), "Destroy");
				}
				if ($t(done)) {
					$sp(done());
				}
			});
		};
		let trail = function (p, color, width, life, smokeLike) {
			let a0 = Instance.new("Attachment");
			a0.Position = Vector3.new(0, $div(width, 2), 0);
			a0.Parent = p;
			let a1 = Instance.new("Attachment");
			a1.Position = Vector3.new(0, $div($unm(width), 2), 0);
			a1.Parent = p;
			let tr = Instance.new("Trail");
			tr.Attachment0 = a0;
			tr.Attachment1 = a1;
			tr.Color = ColorSequence.new(color);
			tr.Transparency = NS(0, ($n(($a(smokeLike) && 0.4)) ?? 0.1), 1, 1);
			tr.Lifetime = life;
			tr.LightEmission = ($n(($a(smokeLike) && 0)) ?? 1);
			tr.FaceCamera = true;
			tr.Texture = ($n(($a(smokeLike) && TEX.Smoke)) ?? "");
			tr.Parent = p;
			return tr;
		};
		let residue = function (position, radius, color, duration, material, transparency) {
			if ($t(crowded())) {
				return undefined;
			}
			let d = disc($add(position, Vector3.new(0, 0.03, 0)), radius, color, ($n(transparency) ?? 0.35), ($n(material) ?? Enum.Material.SmoothPlastic));
			let t0 = d.Transparency;
			animate($add(duration, 0.8), function (_, t) {
				if ((t > duration)) {
					d.Transparency = $add(t0, $mul(($sub(1, t0)), ($div(($sub(t, duration)), 0.8))));
				}
			}, function () {
				$mc(d, "Destroy");
			});
			return d;
		};
		let clawMarks = function (position, direction, color, size, tiltZ) {
			let d = Vector3.new(direction.X, 0, direction.Z);
			if ((d.Magnitude < 0.01)) {
				d = Vector3.new(0, 0, (-1));
			}
			let base = $mul(CFrame.lookAt(position, $add(position, d.Unit)), CFrame.Angles(0, 0, tiltZ));
			for (let i = (-1), $v12 = 1; i <= $v12; i++) {
				let p = part({ Size: Vector3.new(0.25, size, 0.25), Color: color, Transparency: 0.05 });
				let cf = $mul(base, CFrame.new($mul($mul(i, size), 0.18), 0, (-1)));
				animate(0.35, function (k) {
					let e = math.min(1, $mul(k, 3));
					p.Size = Vector3.new($mul(0.25, ($sub(1, $mul(0.6, k)))), $mul(size, e), 0.25);
					p.CFrame = $mul(cf, CFrame.new(0, $mul(size, ($sub(0.5, $mul(e, 0.5)))), 0));
					p.Transparency = ($n(((k > 0.5) && $mul(($sub(k, 0.5)), 2))) ?? 0.05);
				}, function () {
					$mc(p, "Destroy");
				});
			}
			burst(position, color, 10, 0.5, 18, TEX.Spark, { Lifetime: NumberRange.new(0.2, 0.4) });
		};
		let attachEmitter = function (parentPart, duration, props) {
			let e = Instance.new("ParticleEmitter");
			e.Texture = TEX.Sparkle;
			e.LightEmission = 0.6;
			for (let [k, v] of $pairs(props)) {
				$set((e), k, v);
			}
			e.Rate = $mul((($n(props.Rate) ?? 10)), quality());
			e.Parent = parentPart;
			task.delay(duration, function () {
				e.Enabled = false;
			});
			$mc(Debris, "AddItem", e, $add(duration, 2));
			return e;
		};
		H.B_AnchorSpin = function (p) {
			let root = rootOf(p.Model);
			if (!$t(root)) {
				return;
			}
			let dur = ($n(p.Duration) ?? 0.7);
			let s = root.Size.Y;
			let shank = part({ Size: $mul($mul(Vector3.new(0.35, 0.35, 2.6), s), 0.5), Color: C(80, 82, 92), Material: Enum.Material.Metal });
			let arms = part({ Size: $mul($mul(Vector3.new(1.8, 0.3, 0.3), s), 0.5), Color: C(80, 82, 92), Material: Enum.Material.Metal });
			let list = [shank, arms];
			animate(dur, function (_, t) {
				if (!$t(root.Parent)) {
					return true;
				}
				let cf = $mul($mul($mul($mul(root.CFrame, CFrame.new(0, $mul(s, 1.6), 0)), CFrame.Angles(0, $mul(t, 14), 0)), CFrame.new(0, 0, $mul($unm(s), 0.9))), CFrame.Angles($div(PI, 2), 0, 0));
				shank.CFrame = cf;
				arms.CFrame = $mul(cf, CFrame.new(0, 0, $mul(s, 0.6)));
				return undefined;
			}, clean(list));
			burst($add(root.Position, Vector3.new(0, $mul(s, 1.6), 0)), C(200, 230, 255), 10, 0.5, 8);
		};
		H.B_Anchor = function (p) {
			let root = rootOf(p.Model), target = rootOf(p.Target);
			if ((!$t(root) || !$t(target))) {
				return;
			}
			let dur = ($n(p.Duration) ?? 1.2), travel = ($n(p.Travel) ?? 0.3);
			let s = math.max(1, (root.Size.Y * 0.6));
			let metal = C(80, 82, 92);
			let head = part({ Size: $mul(Vector3.new(0.4, 0.4, 2.2), s), Color: metal, Material: Enum.Material.Metal });
			let arms = part({ Size: $mul(Vector3.new(1.6, 0.35, 0.35), s), Color: metal, Material: Enum.Material.Metal });
			let links = [];
			for (let _ = 1, $v13 = q(10); _ <= $v13; _++) {
				$ins(links, part({ Size: $mul(Vector3.new(0.18, 0.4, 0.6), s), Color: C(150, 150, 160), Material: Enum.Material.Metal }));
			}
			let hit = false;
			animate(dur, function (_, t) {
				if (!$t(root.Parent)) {
					return true;
				}
				let from = $add(root.Position, Vector3.new(0, (root.Size.Y * 0.6), 0));
				let tp = ($n(($a(target.Parent) && target.Position)) ?? from);
				let k;
				if ((t < travel)) {
					k = $div(t, travel);
				} else if ((t < $sub(dur, 0.25))) {
					k = 1;
				} else {
					k = math.max(0, $sub(1, $div(($sub(t, ($sub(dur, 0.25)))), 0.25)));
				}
				if (((t >= travel) && !$t(hit))) {
					hit = true;
					burst(tp, C(200, 230, 255), 16, 0.7, 20, TEX.Spark);
					$sp(Effects.Shake(0.15));
				}
				let tip = $add($mc(from, "Lerp", tp, k), Vector3.new(0, $mul((math.sin($mul(k, PI)) * 3), (($n(((t < travel) && 1)) ?? 0))), 0));
				let dir = ($n(((($sub(tip, from)).Magnitude > 0.1) && ($sub(tip, from)).Unit)) ?? root.CFrame.LookVector);
				let cf = CFrame.lookAt(tip, $add(tip, dir));
				head.CFrame = cf;
				arms.CFrame = $mul(cf, CFrame.new(0, 0, $mul((-0.9), s)));
				for (let $v14 = 0, $v15 = $arr(links); $v14 < $v15.length; $v14++) {
					let l = $v15[$v14];
					if (l == null) break;
					let i = $v14 + 1;
					let u = (i / (($len(links) + 1)));
					let pos = $sub($mc(from, "Lerp", tip, u), Vector3.new(0, (math.sin($mul(u, PI)) * 0.6), 0));
					l.CFrame = $mul(CFrame.lookAt(pos, $add(pos, dir)), CFrame.Angles(0, 0, ($n((($mod(i, 2) === 0) && $div(PI, 2))) ?? 0)));
				}
				return undefined;
			}, function () {
				$mc(head, "Destroy");
				$mc(arms, "Destroy");
				$sp(clean(links)());
			});
		};
		H.B_Splash = function (p) {
			let pos = p.Position, r = ($n(p.Radius) ?? 7);
			let blue = C(90, 170, 255);
			burst($add(pos, Vector3.new(0, 1, 0)), C(200, 235, 255), 26, 0.9, 30, TEX.Sparkle, { Acceleration: Vector3.new(0, (-40), 0), Lifetime: NumberRange.new(0.6, 1), SpreadAngle: Vector2.new(35, 35), EmissionDirection: Enum.NormalId.Top, Drag: 0 });
			ring(CFrame.new($add(pos, Vector3.new(0, 0.2, 0))), 1, r, C(160, 210, 255), 0.5);
			let puddle = residue(pos, $mul(r, 0.6), blue, ($n(p.Duration) ?? 3), Enum.Material.Glass, 0.3);
			if ($t(puddle)) {
				puddle.Reflectance = 0.3;
			}
		};
		H.B_Sting = function (p) {
			let model = p.Model;
			let tip = partOf(model, "Ferrao");
			if (!$t(tip)) {
				return;
			}
			let color = ($n(p.Color) ?? C(255, 170, 40));
			let from = tip.Position;
			let to = p.To;
			let spike = part({ Size: Vector3.new(0.3, 0.3, 1.4), Color: color });
			trail(spike, color, 0.5, 0.25);
			fly([[spike, CFrame.new()]], from, to, 0.14, 2, undefined, function () {
				burst(to, color, 14, 0.6, 18, TEX.Spark);
				ring(CFrame.new(to), 0.5, 3, color, 0.3, 0.3);
			});
		};
		H.B_Poison = function (p) {
			let root = rootOf(p.Model);
			if (!$t(root)) {
				return;
			}
			let dur = ($n(p.Duration) ?? 4);
			attachEmitter(root, dur, { Color: ColorSequence.new(C(170, 255, 60)), Size: NS(0, 0.4, 1, 0.1), Transparency: NS(0, 0.1, 1, 1), Lifetime: NumberRange.new(0.6, 1), Speed: NumberRange.new(1, 3), Acceleration: Vector3.new(0, 5, 0), SpreadAngle: Vector2.new(180, 180), Rate: 16, LightEmission: 1 });
			let h = Instance.new("Highlight");
			h.FillColor = C(140, 255, 60);
			h.FillTransparency = 0.7;
			h.OutlineTransparency = 1;
			h.Adornee = p.Model;
			h.Parent = folder;
			$mc(Debris, "AddItem", h, dur);
		};
		H.B_Vines = function (p) {
			let pos = p.Position;
			let dur = ($n(p.Duration) ?? 2);
			let size = ($n(($a((($a(p.Model) && p.Model.Parent))) && $mc(p.Model, "GetExtentsSize"))) ?? Vector3.new(4, 4, 4));
			let r = (math.max(size.X, size.Z) * 0.55);
			let h = (size.Y * 0.9);
			let green = C(70, 160, 50);
			let list = [];
			let n = q(6);
			for (let i = 1, $v16 = n; i <= $v16; i++) {
				let a0 = $mul($mul($div(i, n), PI), 2);
				let segs = [];
				for (let j = 1, $v17 = 5; j <= $v17; j++) {
					let seg = part({ Size: Vector3.new(0.35, 0.35, 1), Color: ($n((($mod(j, 2) === 0) && green)) ?? C(95, 190, 60)), Material: Enum.Material.Grass });
					$ins(segs, seg);
					$ins(list, seg);
				}
				let leaf = part({ Size: Vector3.new(0.1, 0.6, 0.9), Color: C(120, 210, 80), Material: Enum.Material.Grass });
				$ins(list, leaf);
				animate(dur, function (k, t) {
					let grow = math.min(1, $div(t, 0.35));
					let fade = ($n(((k > 0.85) && $div(($sub(k, 0.85)), 0.15))) ?? 0);
					let last = $add(pos, $mul(Vector3.new(math.cos(a0), 0, math.sin(a0)), ($add(r, 1))));
					for (let $v18 = 0, $v19 = $arr(segs); $v18 < $v19.length; $v18++) {
						let seg = $v19[$v18];
						if (seg == null) break;
						let j = $v18 + 1;
						let u = $mul((j / $len(segs)), grow);
						let a = $add(a0, $mul($mul(u, PI), 1.4));
						let rr = $mul(r, ($add(1, $mul(0.4, ($sub(1, u))))));
						let pt = $add(pos, Vector3.new($mul(math.cos(a), rr), $mul(u, h), $mul(math.sin(a), rr)));
						let len = ($sub(pt, last)).Magnitude;
						seg.Size = Vector3.new(0.35, 0.35, math.max(0.1, $add(len, 0.2)));
						seg.CFrame = $mul(CFrame.lookAt(last, pt), CFrame.new(0, 0, $div($unm(len), 2)));
						seg.Transparency = fade;
						last = pt;
					}
					leaf.CFrame = $mul(CFrame.new(last), CFrame.Angles(0, a0, 0.6));
					leaf.Transparency = fade;
				});
			}
			animate(dur, function () {}, clean(list));
			smoke(pos, C(110, 90, 60), 12, 2, 10);
			ring(CFrame.new($add(pos, Vector3.new(0, 0.2, 0))), 1, $add(r, 3), C(120, 220, 80), 0.45);
		};
		H.B_Acid = function (p) {
			let pos = p.Position, r = ($n(p.Radius) ?? 6), dur = ($n(p.Duration) ?? 3);
			let pool = residue(pos, r, C(150, 230, 40), dur, Enum.Material.Neon, 0.45);
			burst($add(pos, Vector3.new(0, 0.5, 0)), C(190, 255, 70), 20, 0.6, 14);
			if ($t(pool)) {
				let a = anchor(pos, $add(dur, 1));
				let e = Instance.new("ParticleEmitter");
				e.Texture = TEX.Sparkle;
				e.Color = ColorSequence.new(C(190, 255, 70));
				e.Size = NS(0, 0.5, 1, 0.1);
				e.Lifetime = NumberRange.new(0.5, 0.9);
				e.Speed = NumberRange.new(1, 3);
				e.Acceleration = Vector3.new(0, 4, 0);
				e.Shape = Enum.ParticleEmitterShape.Disc;
				e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume;
				e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward;
				e.EmissionDirection = Enum.NormalId.Top;
				e.Rate = $mul(18, quality());
				e.LightEmission = 1;
				e.Parent = a;
				task.delay(dur, function () {
					e.Enabled = false;
				});
			}
		};
		H.B_Stun = function (p) {
			let root = rootOf(p.Model);
			if (!$t(root)) {
				return;
			}
			let dur = ($n(p.Duration) ?? 1.2);
			let size = $mc(p.Model, "GetExtentsSize");
			let stars = [];
			for (let i = 1, $v20 = 4; i <= $v20; i++) {
				$ins(stars, part({ Size: Vector3.new(0.5, 0.5, 0.15), Color: ($n((($mod(i, 2) === 0) && C(255, 230, 90))) ?? WHITE) }));
			}
			animate(dur, function (k, t) {
				if (!$t(root.Parent)) {
					return true;
				}
				let c = $add(root.Position, Vector3.new(0, ((size.Y * 0.6) + 0.6), 0));
				for (let $v21 = 0, $v22 = $arr(stars); $v21 < $v22.length; $v21++) {
					let s = $v22[$v21];
					if (s == null) break;
					let i = $v21 + 1;
					let a = $add($mul(t, 6), $mul($mul((i / $len(stars)), PI), 2));
					s.CFrame = $mul(CFrame.new($add(c, $mul(Vector3.new(math.cos(a), (math.sin($add($mul(t, 8), i)) * 0.15), math.sin(a)), math.max(1.2, (size.X * 0.35))))), CFrame.Angles(0, $unm(a), $div(PI, 4)));
					s.Transparency = ($n(((k > 0.85) && $div(($sub(k, 0.85)), 0.15))) ?? 0);
				}
				return undefined;
			}, clean(stars));
		};
		H.B_Beat = function (p) {
			let pos = p.Position, r = ($n(p.Radius) ?? 10), color = ($n(p.Color) ?? C(0, 240, 220));
			ring(CFrame.new($add(pos, Vector3.new(0, 0.3, 0))), 1, r, color, 0.4, 0.9);
			ring(CFrame.new($add(pos, Vector3.new(0, 1.5, 0))), 0.5, $mul(r, 0.7), WHITE, 0.35, 0.4);
			light($add(pos, Vector3.new(0, 3, 0)), color, $mul(r, 2), 0.35);
			$sp(Effects.Shake(0.08));
			let model = p.Model;
			if (($t(model) && $t(model.Parent))) {
				for (let $v23 = 0, $v24 = $arr($mc(model, "GetChildren")); $v23 < $v24.length; $v23++) {
					let d = $v24[$v23];
					if (d == null) break;
					if (($t($mc(d, "IsA", "BasePart")) && ((d.Name === "AltoLuz") || (d.Name === "FoneLuz")))) {
						burst(d.Position, color, 4, 0.6, 10, TEX.Sparkle);
					}
				}
			}
			for (let _ = 1, $v25 = q(3); _ <= $v25; _++) {
				let a = $mul($mul(math.random(), PI), 2);
				let start = $add(pos, Vector3.new((math.cos(a) * 3), 2, (math.sin(a) * 3)));
				let head = ball(Vector3.new(0.6, 0.45, 0.45), color);
				let stem = part({ Size: Vector3.new(0.12, 1.1, 0.12), Color: color });
				animate(0.9, function (k) {
					let c = $add(start, Vector3.new(0, $mul(k, 5), 0));
					head.CFrame = CFrame.new(c);
					stem.CFrame = CFrame.new($add(c, Vector3.new(0.25, 0.55, 0)));
					head.Transparency = k;
					stem.Transparency = k;
				}, clean([head, stem]));
			}
		};
		H.B_Drop = function (p) {
			let pos = p.Position, r = ($n(p.Radius) ?? 16), dur = ($n(p.Duration) ?? 2.5);
			let cols = [C(0, 240, 220), C(255, 60, 200), C(255, 230, 60), C(120, 90, 255)];
			ring(CFrame.new($add(pos, Vector3.new(0, 0.4, 0))), 1, r, $get(cols, 1), 0.5, 1.4);
			ring(CFrame.new($add(pos, Vector3.new(0, 0.6, 0))), 1, $mul(r, 0.8), $get(cols, 2), 0.6, 1);
			ring(CFrame.new($add(pos, Vector3.new(0, 3, 0))), 1, $mul(r, 0.6), WHITE, 0.4, 0.5);
			burst($add(pos, Vector3.new(0, 1, 0)), $get(cols, 2), 30, 1, 40, TEX.Spark);
			light($add(pos, Vector3.new(0, 4, 0)), $get(cols, 1), 40, 0.6);
			if ($t(crowded())) {
				return;
			}
			let tiles = [];
			let n = math.floor($add(3, $mul(2, quality())));
			let step = $div($mul(r, 1.4), ($add($mul(2, n), 1)));
			for (let x = $unm(n), $v26 = n; x <= $v26; x++) {
				for (let z = $unm(n), $v27 = n; z <= $v27; z++) {
					if (($add($mul(x, x), $mul(z, z)) <= $mul(n, n))) {
						$ins(tiles, part({ Size: Vector3.new($mul(step, 0.9), 0.1, $mul(step, 0.9)), CFrame: CFrame.new($add(pos, Vector3.new($mul(x, step), 0.1, $mul(z, step)))), Color: $get(cols, $add($mod(($add(x, z)), 4), 1)), Transparency: 0.4 }));
					}
				}
			}
			animate(dur, function (k, t) {
				let beat = math.floor($mul(t, 6));
				for (let $v28 = 0, $v29 = $arr(tiles); $v28 < $v29.length; $v28++) {
					let tile = $v29[$v28];
					if (tile == null) break;
					let i = $v28 + 1;
					tile.Color = $get(cols, $add($mod(($add(i, beat)), 4), 1));
					tile.Transparency = $add(0.35, $mul(0.65, $pow(k, 2)));
				}
			}, clean(tiles));
		};
		H.B_Shield = function (p) {
			let root = rootOf(p.Model);
			if (!$t(root)) {
				return;
			}
			let dur = ($n(p.Duration) ?? 1.1);
			let size = $mc(p.Model, "GetExtentsSize");
			let s = (math.max(size.Y, size.X) * 0.75);
			let wall = part({ Shape: Enum.PartType.Cylinder, Size: Vector3.new(0.2, s, s), Color: C(255, 215, 90), Transparency: 0.55 });
			let rim = part({ Shape: Enum.PartType.Cylinder, Size: Vector3.new(0.12, $mul(s, 1.08), $mul(s, 1.08)), Color: WHITE, Transparency: 0.7 });
			animate(dur, function (k, t) {
				if (!$t(root.Parent)) {
					return true;
				}
				let cf = $mul($mul(root.CFrame, CFrame.new(0, (size.Y * 0.1), ((-root.Size.Z) * 0.75))), CFrame.Angles(0, $div(PI, 2), 0));
				wall.CFrame = cf;
				rim.CFrame = $mul(cf, CFrame.new((-0.05), 0, 0));
				wall.Transparency = $add((0.5 + (0.15 * math.sin($mul(t, 20)))), (($n(((k > 0.8) && $mul(($sub(k, 0.8)), 2.5))) ?? 0)));
				rim.Transparency = $add(0.6, (($n(((k > 0.8) && $mul(($sub(k, 0.8)), 2))) ?? 0)));
				return undefined;
			}, clean([wall, rim]));
			burst(root.Position, C(255, 230, 140), 16, 0.6, 10);
		};
		H.B_Thrust = function (p) {
			let root = rootOf(p.Model);
			if (!$t(root)) {
				return;
			}
			let tipPart = partOf(p.Model, "LancaPonta3");
			let from = (($n(tipPart) ?? root)).Position;
			let d = ($n(p.Direction) ?? root.CFrame.LookVector);
			let len = ($n(p.Length) ?? 11), color = ($n(p.Color) ?? WHITE);
			let beam = part({ Size: Vector3.new(0.8, 0.8, 1), Color: color, Transparency: 0.2 });
			let core = part({ Size: Vector3.new(0.3, 0.3, 1), Color: WHITE });
			animate(0.25, function (k) {
				let l = $mul(len, math.min(1, $mul(k, 2.5)));
				let cf = $mul(CFrame.lookAt(from, $add(from, d)), CFrame.new(0, 0, $div($unm(l), 2)));
				beam.Size = Vector3.new($mul(0.8, ($sub(1, k))), $mul(0.8, ($sub(1, k))), l);
				core.Size = Vector3.new($mul(0.3, ($sub(1, k))), $mul(0.3, ($sub(1, k))), l);
				beam.CFrame = cf;
				core.CFrame = cf;
				beam.Transparency = $add(0.2, $mul(0.8, k));
			}, clean([beam, core]));
			burst($add(from, $mul(d, len)), color, 8, 0.5, 14, TEX.Spark);
		};
		H.B_Ball = function (p) {
			let root = rootOf(p.Model);
			if (!$t(root)) {
				return;
			}
			let dur = ($n(p.Duration) ?? 2.8);
			let d = (math.max(root.Size.Y, root.Size.X) * 1.15);
			let color = ($n(p.Color) ?? C(170, 140, 110));
			let core = ball($mul(Vector3.one, d), color, Enum.Material.SmoothPlastic);
			let bands = [];
			for (let i = (-2), $v30 = 2; i <= $v30; i++) {
				let band = part({ Shape: Enum.PartType.Cylinder, Size: Vector3.new(0.18, $mul($mul(d, math.cos((i * 0.32))), 1.02), $mul($mul(d, math.cos((i * 0.32))), 1.02)), Color: C(120, 95, 80), Material: Enum.Material.SmoothPlastic });
				$ins(bands, [band, i]);
			}
			let dustAt = 0;
			let last = root.Position;
			let roll = 0;
			animate(dur, function (_, t) {
				if (!$t(root.Parent)) {
					return true;
				}
				let pos = root.Position;
				let move = Vector3.new((pos.X - last.X), 0, (pos.Z - last.Z));
				last = pos;
				roll = $add(roll, $div(move.Magnitude, ($mul(d, 0.5))));
				let dir = ($n(((move.Magnitude > 0.01) && move.Unit)) ?? root.CFrame.LookVector);
				let cf = $mul(CFrame.lookAt(pos, $add(pos, Vector3.new(dir.X, 0, dir.Z))), CFrame.Angles($unm(roll), 0, 0));
				core.CFrame = cf;
				for (let $v31 = 0, $v32 = $arr(bands); $v31 < $v32.length; $v31++) {
					let e = $v32[$v31];
					if (e == null) break;
					$get(e, 1).CFrame = $mul($mul(cf, CFrame.Angles($add($mul($get(e, 2), 0.32), $div(PI, 2)), 0, 0)), CFrame.Angles(0, 0, $div(PI, 2)));
				}
				if (((t > dustAt) && (move.Magnitude > 0.05))) {
					dustAt = $add(t, 0.12);
					smoke($sub(pos, Vector3.new(0, $mul(d, 0.45), 0)), C(180, 160, 130), 3, 1.5, 4);
				}
				return undefined;
			}, function () {
				$mc(core, "Destroy");
				for (let $v33 = 0, $v34 = $arr(bands); $v33 < $v34.length; $v33++) {
					let e = $v34[$v33];
					if (e == null) break;
					$mc($get(e, 1), "Destroy");
				}
				burst(root.Position, C(190, 165, 135), 14, 0.8, 12, TEX.Smoke, { LightEmission: 0 });
			});
		};
		H.B_ClawX = function (p) {
			let color = ($n(p.Color) ?? WHITE);
			clawMarks(p.Position, ($n(p.Direction) ?? Vector3.new(0, 0, (-1))), color, 5, 0.6);
			clawMarks(p.Position, ($n(p.Direction) ?? Vector3.new(0, 0, (-1))), color, 5, (-0.6));
			$sp(Effects.Shake(0.12));
		};
		H.B_Bleed = function (p) {
			let root = rootOf(p.Model);
			if (!$t(root)) {
				return;
			}
			attachEmitter(root, ($n(p.Duration) ?? 3), { Color: ColorSequence.new(C(220, 30, 40)), Size: NS(0, 0.3, 1, 0.15), Lifetime: NumberRange.new(0.5, 0.8), Speed: NumberRange.new(1, 3), Acceleration: Vector3.new(0, (-25), 0), SpreadAngle: Vector2.new(60, 60), Rate: 12, LightEmission: 0.2 });
		};
		H.B_Jet = function (p) {
			let model = p.Model;
			let dur = ($n(p.Duration) ?? 2.4);
			for (let $v35 = 0, $v36 = $arr(($n(($a(model) && $mc(model, "GetChildren"))) ?? [])); $v35 < $v36.length; $v35++) {
				let d = $v36[$v35];
				if (d == null) break;
				if (($t($mc(d, "IsA", "BasePart")) && (d.Name === "Bocal"))) {
					attachEmitter(d, dur, { Texture: TEX.Fire, Color: ColorSequence.new(C(255, 240, 160), C(255, 110, 30)), Size: NS(0, 0.9, 1, 0.1), Lifetime: NumberRange.new(0.2, 0.35), Speed: NumberRange.new(14, 20), EmissionDirection: Enum.NormalId.Bottom, SpreadAngle: Vector2.new(8, 8), Rate: 60, LightEmission: 1 });
				}
			}
			let feet = feetOf(model);
			if ($t(feet)) {
				smoke(feet, C(220, 220, 230), 18, 3, 14);
				ring(CFrame.new($add(feet, Vector3.new(0, 0.2, 0))), 1, 7, C(255, 200, 120), 0.4);
			}
		};
		H.B_Rocket = function (p) {
			let root = rootOf(p.Model);
			if (!$t(root)) {
				return;
			}
			let from = (($n(partOf(p.Model, "Mochila")) ?? root)).Position;
			let to = p.To;
			let side = $mul((($n(p.Side) ?? 1)), 6);
			let dur = ($n(p.Duration) ?? 0.6);
			let body = part({ Size: Vector3.new(0.45, 0.45, 1.4), Color: WHITE, Material: Enum.Material.SmoothPlastic });
			let nose = part({ Size: Vector3.new(0.48, 0.48, 0.4), Color: C(255, 70, 50), Material: Enum.Material.SmoothPlastic });
			let flame = part({ Size: Vector3.new(0.35, 0.35, 0.6), Color: C(255, 180, 60) });
			trail(body, C(230, 230, 235), 0.8, 0.5, true);
			let right = root.CFrame.RightVector;
			animate(dur, function (k) {
				let at = function (u) {
					let up = (math.sin($mul(u, PI)) * 8);
					return $add($add($mc(from, "Lerp", to, u), $mul($mul(right, side), math.sin($mul(u, PI)))), Vector3.new(0, up, 0));
				};
				let pos = at(k), ahead = at(math.min(1, $add(k, 0.04)));
				let cf = ($n(((($sub(ahead, pos)).Magnitude > 0.01) && CFrame.lookAt(pos, ahead))) ?? CFrame.new(pos));
				body.CFrame = cf;
				nose.CFrame = $mul(cf, CFrame.new(0, 0, (-0.85)));
				flame.CFrame = $mul(cf, CFrame.new(0, 0, 0.95));
			}, clean([body, nose, flame]));
		};
		H.B_Snowball = function (p) {
			let root = rootOf(p.Model);
			if (!$t(root)) {
				return;
			}
			let dur = ($n(p.Duration) ?? 1);
			let s = root.Size.Y;
			let snow = ball($mul(Vector3.one, 0.5), C(245, 250, 255), Enum.Material.Snow);
			animate(dur, function (k) {
				if (!$t(root.Parent)) {
					return true;
				}
				let d = $mul(s, ($add(0.4, $mul(1.6, k))));
				snow.Size = $mul(Vector3.one, d);
				snow.CFrame = $mul(root.CFrame, CFrame.new(0, $add($mul(s, 1.4), $mul(d, 0.5)), ((-root.Size.Z) * 0.2)));
				return undefined;
			}, function () {
				$mc(snow, "Destroy");
			});
			attachEmitter(root, dur, { Color: ColorSequence.new(WHITE), Size: NS(0, 0.4, 1, 0), Lifetime: NumberRange.new(0.5, 0.9), Speed: NumberRange.new(3, 6), Acceleration: Vector3.new(0, 6, 0), SpreadAngle: Vector2.new(180, 180), Rate: 25 });
		};
		H.B_SnowThrow = function (p) {
			let root = rootOf(p.Model);
			if (!$t(root)) {
				return;
			}
			let s = root.Size.Y;
			let d = $mul(s, 2);
			let from = ($mul(root.CFrame, CFrame.new(0, $add($mul(s, 1.4), $mul(d, 0.5)), ((-root.Size.Z) * 0.2)))).Position;
			let snow = ball($mul(Vector3.one, d), C(245, 250, 255), Enum.Material.Snow);
			trail(snow, C(230, 240, 255), $mul(d, 0.8), 0.4, true);
			fly([[snow, CFrame.new()]], from, $add(p.To, Vector3.new(0, $mul(d, 0.4), 0)), ($n(p.Duration) ?? 0.55), 6, 8);
		};
		H.B_SnowBurst = function (p) {
			let pos = p.Position, r = ($n(p.Radius) ?? 10);
			burst($add(pos, Vector3.new(0, 1.5, 0)), WHITE, 40, 1.4, 35, TEX.Smoke, { LightEmission: 0.2, Size: NS(0, 1.5, 1, 4), Transparency: NS(0, 0.1, 1, 1), Lifetime: NumberRange.new(0.6, 1.2), Drag: 3 });
			burst($add(pos, Vector3.new(0, 1, 0)), C(200, 240, 255), 24, 0.6, 30, TEX.Sparkle);
			ring(CFrame.new($add(pos, Vector3.new(0, 0.3, 0))), 1, r, C(220, 240, 255), 0.5, 1.2);
			light($add(pos, Vector3.new(0, 3, 0)), C(190, 235, 255), 30, 0.5);
			$sp(Effects.Shake(0.45));
			for (let _ = 1, $v37 = q(5); _ <= $v37; _++) {
				let a = $mul($mul(math.random(), PI), 2);
				let pile = ball(Vector3.new(rnd(2, 3.5), rnd(0.8, 1.4), rnd(2, 3.5)), C(240, 246, 255), Enum.Material.Snow);
				pile.CFrame = CFrame.new($add(pos, $mul(Vector3.new(math.cos(a), 0, math.sin(a)), rnd(1, $mul(r, 0.7)))));
				animate(3.6, function (_$2, t) {
					if ((t > 3)) {
						pile.Transparency = $div(($sub(t, 3)), 0.6);
					}
				}, function () {
					$mc(pile, "Destroy");
				});
			}
		};
		H.B_Moon = function (p) {
			let pos = p.Position, dur = ($n(p.Duration) ?? 3.5);
			let moon = ball($mul(Vector3.one, 0.5), C(255, 248, 210));
			let halo = ball($mul(Vector3.one, 0.5), C(200, 210, 255), Enum.Material.Neon, 0.75);
			let spots = [];
			for (let i = 1, $v38 = 3; i <= $v38; i++) {
				$ins(spots, ball($mul(Vector3.one, ((1 + (i * 0.4)))), C(220, 210, 170), Enum.Material.SmoothPlastic));
			}
			animate(dur, function (k) {
				let e = math.min(1, $mul(k, 5));
				let fade = ($n(((k > 0.85) && $div(($sub(k, 0.85)), 0.15))) ?? 0);
				moon.Size = $mul($mul(Vector3.one, 10), e);
				moon.CFrame = CFrame.new(pos);
				moon.Transparency = fade;
				halo.Size = $mul($mul(Vector3.one, 16), e);
				halo.CFrame = CFrame.new(pos);
				halo.Transparency = $add(0.75, $mul(0.25, fade));
				for (let $v39 = 0, $v40 = $arr(spots); $v39 < $v40.length; $v39++) {
					let s = $v40[$v39];
					if (s == null) break;
					let i = $v39 + 1;
					s.CFrame = $mul(CFrame.new($add(pos, $mul(Vector3.new((math.cos((i * 2)) * 2.2), (math.sin((i * 2)) * 2.2), 0), e))), CFrame.new(0, 0, $mul(3.6, e)));
					s.Transparency = ($n(((e < 1) && 1)) ?? fade);
				}
			}, function () {
				$mc(moon, "Destroy");
				$mc(halo, "Destroy");
				$sp(clean(spots)());
			});
			light($sub(pos, Vector3.new(0, 20, 0)), C(170, 190, 255), 60, dur);
		};
		H.B_Claw = function (p) {
			clawMarks(p.Position, ($n(p.Direction) ?? Vector3.new(0, 0, (-1))), ($n(p.Color) ?? C(200, 210, 255)), 4.5, rnd((-0.9), 0.9));
			$sp(Effects.Shake(0.1));
		};
		H.B_Heal = function (p) {
			let root = rootOf(p.Model);
			if (!$t(root)) {
				return;
			}
			burst(root.Position, C(255, 80, 100), 10, 0.5, 6, TEX.Sparkle, { Acceleration: Vector3.new(0, 8, 0) });
		};
		H.B_Ink = function (p) {
			let root = rootOf(p.Model);
			if (!$t(root)) {
				return;
			}
			let dur = ($n(p.Duration) ?? 3);
			let h = Instance.new("Highlight");
			h.FillColor = C(20, 15, 30);
			h.FillTransparency = 0.35;
			h.OutlineColor = C(60, 40, 90);
			h.OutlineTransparency = 0.4;
			h.Adornee = p.Model;
			h.Parent = folder;
			animate(dur, function (k) {
				h.FillTransparency = $add(0.35, $mul(0.65, $pow(k, 2)));
			}, function () {
				$mc(h, "Destroy");
			});
			burst(root.Position, C(25, 15, 40), 20, 1, 14, TEX.Smoke, { LightEmission: 0 });
			let feet = feetOf(p.Model);
			if ($t(feet)) {
				residue(feet, 3, C(20, 15, 30), dur, Enum.Material.SmoothPlastic, 0.2);
			}
			if ($eq($mc(p.Model, "GetAttribute", "Owner"), player.UserId)) {
				let cc = Instance.new("ColorCorrectionEffect");
				cc.Brightness = (-0.25);
				cc.Saturation = (-0.6);
				cc.Parent = workspace.CurrentCamera;
				animate(dur, function (k) {
					cc.Brightness = $mul((-0.25), ($sub(1, k)));
					cc.Saturation = $mul((-0.6), ($sub(1, k)));
				}, function () {
					$mc(cc, "Destroy");
				});
			}
		};
		H.B_Tentacles = function (p) {
			let pos = p.Position;
			let dur = ($n(p.Duration) ?? 1.9);
			let size = ($n(($a((($a(p.Model) && p.Model.Parent))) && $mc(p.Model, "GetExtentsSize"))) ?? Vector3.new(4, 4, 4));
			let r = ((math.max(size.X, size.Z) * 0.6) + 1);
			let h = (size.Y * 1.1);
			let list = [];
			let n = q(5);
			for (let i = 1, $v41 = n; i <= $v41; i++) {
				let a0 = $mul($mul($div(i, n), PI), 2);
				let segs = [];
				for (let j = 1, $v42 = 6; j <= $v42; j++) {
					let seg = part({ Shape: Enum.PartType.Ball, Size: Vector3.one, Color: ($n(((j === 6) && C(255, 160, 210))) ?? C(175, 70, 145)), Material: Enum.Material.SmoothPlastic });
					$ins(segs, seg);
					$ins(list, seg);
				}
				animate(dur, function (k, t) {
					let grow = math.min(1, $div(t, 0.3));
					let squeeze = ((1 - (0.35 * math.min(1, (math.max(0, $sub(t, 0.3)) / 0.3)))) + (math.sin($mul(t, 14)) * 0.05));
					let sink = ($n(((k > 0.8) && $div(($sub(k, 0.8)), 0.2))) ?? 0);
					for (let $v43 = 0, $v44 = $arr(segs); $v43 < $v44.length; $v43++) {
						let seg = $v44[$v43];
						if (seg == null) break;
						let j = $v43 + 1;
						let u = (j / $len(segs));
						let a = $add(a0, $mul(u, 1.2));
						let rr = $mul($mul(r, squeeze), ($sub(1.2, $mul(u, 0.5))));
						let width = $mul(($sub(1.3, $mul(u, 0.9))), 1.2);
						seg.Size = $mul(Vector3.one, width);
						seg.CFrame = CFrame.new($add(pos, Vector3.new($mul(math.cos(a), rr), $sub($mul(($mul(u, h)), grow), $mul(sink, h)), $mul(math.sin(a), rr))));
					}
				});
			}
			animate(dur, function () {}, clean(list));
			smoke(pos, C(90, 60, 80), 14, 2.5, 10);
			residue(pos, r, C(40, 25, 50), dur, Enum.Material.SmoothPlastic, 0.3);
			$sp(Effects.Shake(0.2));
		};
		H.B_LaserSight = function (p) {
			let root = rootOf(p.Model), target = rootOf(p.Target);
			if ((!$t(root) || !$t(target))) {
				return;
			}
			let muzzle = ($n(partOf(p.Model, "CanhaoBoca")) ?? root);
			let beam = part({ Size: Vector3.new(0.15, 0.15, 1), Color: C(255, 30, 30), Transparency: 0.2 });
			let dot = part({ Shape: Enum.PartType.Cylinder, Size: Vector3.new(0.1, 3, 3), Color: C(255, 40, 40), Transparency: 0.3 });
			animate(($n(p.Duration) ?? 1), function (k, t) {
				if ((!$t(root.Parent) || !$t(target.Parent))) {
					return true;
				}
				let a = muzzle.Position;
				let b = target.Position;
				let len = ($sub(b, a)).Magnitude;
				beam.Size = Vector3.new(0.15, 0.15, len);
				beam.CFrame = $mul(CFrame.lookAt(a, b), CFrame.new(0, 0, $div($unm(len), 2)));
				let blink = (math.sin($mul(t, ($add(10, $mul(40, k))))) > 0);
				beam.Transparency = ($n(($a(blink) && 0.15)) ?? 0.6);
				let feet = ($n(feetOf(p.Target)) ?? b);
				dot.CFrame = $mul(CFrame.new($add(feet, Vector3.new(0, 0.1, 0))), CFrame.Angles(0, 0, $div(PI, 2)));
				dot.Size = Vector3.new(0.1, $add(3, $mul(4, ($sub(1, k)))), $add(3, $mul(4, ($sub(1, k)))));
				return undefined;
			}, clean([beam, dot]));
		};
		H.B_Shell = function (p) {
			let root = rootOf(p.Model);
			if (!$t(root)) {
				return;
			}
			let muzzle = ($n(partOf(p.Model, "CanhaoBoca")) ?? root);
			let from = muzzle.Position;
			burst(from, C(255, 200, 100), 20, 1.4, 25, TEX.Fire, { Lifetime: NumberRange.new(0.1, 0.25) });
			smoke(from, C(120, 115, 105), 16, 3, 16);
			light(from, C(255, 180, 80), 25, 0.25);
			$sp(Effects.Shake(0.3));
			let shell = part({ Size: Vector3.new(0.8, 0.8, 2), Color: C(255, 200, 90) });
			trail(shell, C(255, 160, 60), 0.9, 0.3);
			fly([[shell, CFrame.new()]], from, $add(p.To, Vector3.new(0, 0.5, 0)), ($n(p.Duration) ?? 0.3), 1.5);
		};
		H.B_Crater = function (p) {
			let pos = p.Position, r = ($n(p.Radius) ?? 9), dur = ($n(p.Duration) ?? 3.5);
			residue(pos, $mul(r, 0.7), C(30, 25, 22), dur, Enum.Material.Slate, 0.15);
			burst($add(pos, Vector3.new(0, 0.5, 0)), C(120, 100, 80), 14, 0.8, 30, TEX.Smoke, { LightEmission: 0, Acceleration: Vector3.new(0, (-30), 0) });
			if ($t(crowded())) {
				return;
			}
			for (let i = 1, $v45 = q(6); i <= $v45; i++) {
				let a = $add($mul($mul((i / 6), PI), 2), rnd((-0.3), 0.3));
				let at = anchor($add(pos, $mul($mul(Vector3.new(math.cos(a), 0.3, math.sin(a)), r), 0.65)), $add(dur, 1.2));
				let e = Instance.new("ParticleEmitter");
				e.Texture = TEX.Fire;
				e.Color = ColorSequence.new(C(255, 220, 120), C(255, 80, 20));
				e.Size = NS(0, 1.4, 1, 0.2);
				e.Lifetime = NumberRange.new(0.4, 0.7);
				e.Speed = NumberRange.new(2, 5);
				e.Acceleration = Vector3.new(0, 6, 0);
				e.EmissionDirection = Enum.NormalId.Top;
				e.SpreadAngle = Vector2.new(15, 15);
				e.LightEmission = 1;
				e.Rate = $mul(14, quality());
				e.Parent = at;
				task.delay(dur, function () {
					e.Enabled = false;
				});
			}
		};
		let orbColors = [C(120, 220, 255), C(255, 120, 230), C(160, 120, 255)];
		H.B_Orbs = function (p) {
			let root = rootOf(p.Model);
			if (!$t(root)) {
				return;
			}
			let dur = ($n(p.Duration) ?? 0.9);
			let s = math.max(2, (root.Size.Z * 0.8));
			let orbs = [];
			for (let i = 1, $v46 = 3; i <= $v46; i++) {
				let o = ball($mul(Vector3.one, 0.9), $get(orbColors, i));
				trail(o, $get(orbColors, i), 0.6, 0.3);
				$ins(orbs, o);
			}
			animate(dur, function (k, t) {
				if (!$t(root.Parent)) {
					return true;
				}
				for (let $v47 = 0, $v48 = $arr(orbs); $v47 < $v48.length; $v47++) {
					let o = $v48[$v47];
					if (o == null) break;
					let i = $v47 + 1;
					let a = $add($mul(t, 7), $mul($mul((i / 3), PI), 2));
					o.CFrame = $mul(root.CFrame, CFrame.new($mul(math.cos(a), s), (root.Size.Y * ((0.6 + (0.2 * math.sin($add($mul(t, 5), i)))))), $mul(math.sin(a), s)));
					o.Size = $mul(Vector3.one, ($add(0.6, $mul(0.6, k))));
				}
				return undefined;
			}, clean(orbs));
			ring($mul(root.CFrame, CFrame.new(0, ((-root.Size.Y) * 0.5), 0)), 1, $mul(s, 1.5), $get(orbColors, 1), dur, 0.4);
		};
		H.B_OrbShot = function (p) {
			let root = rootOf(p.Model), target = rootOf(p.Target);
			if ((!$t(root) || !$t(target))) {
				return;
			}
			let i = ($n(p.Index) ?? 1);
			let color = ($n(p.Color) ?? $get(orbColors, 1));
			let a = $mul($mul($div(i, 3), PI), 2);
			let s = math.max(2, (root.Size.Z * 0.8));
			let from = ($mul(root.CFrame, CFrame.new($mul(math.cos(a), s), (root.Size.Y * 0.7), $mul(math.sin(a), s)))).Position;
			let o = ball($mul(Vector3.one, 1.2), color);
			trail(o, color, 0.9, 0.35);
			let to = target.Position;
			fly([[o, CFrame.new()]], from, to, ($n(p.Duration) ?? 0.3), 2.5, undefined, function () {
				burst(to, color, 16, 0.8, 18);
				ring(CFrame.new(to), 0.5, 4, color, 0.3, 0.4);
			});
		};
		H.B_Seal = function (p) {
			let pos = p.Position, r = ($n(p.Radius) ?? 8), dur = ($n(p.Duration) ?? 0.9);
			let color = C(160, 120, 255);
			let base = disc(pos, r, color, 0.75);
			let list = [base];
			let n = q(10);
			for (let _ = 1, $v49 = n; _ <= $v49; _++) {
				$ins(list, part({ Size: Vector3.new(0.3, 0.12, $mul(r, 1.2)), Color: $get(orbColors, 2) }));
			}
			let runes = [];
			for (let _ = 1, $v50 = q(6); _ <= $v50; _++) {
				let rune = part({ Size: Vector3.new(0.8, 0.12, 0.8), Color: WHITE });
				$ins(runes, rune);
				$ins(list, rune);
			}
			animate(dur, function (k, t) {
				for (let i = 2, $v51 = $add(n, 1); i <= $v51; i++) {
					let a = $add($mul($mul($div(((i - 1)), n), PI), 2), $mul(t, 1.5));
					let mid = $add($add(pos, $mul($mul(Vector3.new(math.cos(a), 0, math.sin(a)), r), 0.45)), Vector3.new(0, 0.15, 0));
					$get(list, i).CFrame = $mul(CFrame.new(mid), CFrame.Angles(0, $add($add($unm(a), $div(PI, 2)), 0.6), 0));
					$get(list, i).Transparency = $sub(0.4, $mul(0.35, k));
				}
				for (let $v52 = 0, $v53 = $arr(runes); $v52 < $v53.length; $v52++) {
					let rune = $v53[$v52];
					if (rune == null) break;
					let j = $v52 + 1;
					let a = $sub($mul($mul((j / $len(runes)), PI), 2), $mul(t, 2));
					rune.CFrame = $mul(CFrame.new($add(pos, Vector3.new($mul($mul(math.cos(a), r), 0.85), $add(0.2, $mul(k, 1.5)), $mul($mul(math.sin(a), r), 0.85)))), CFrame.Angles(0, a, $div(PI, 4)));
				}
				base.Transparency = $sub(0.75, $mul(0.4, k));
			}, clean(list));
			light($add(pos, Vector3.new(0, 2, 0)), color, $mul(r, 3), $add(dur, 0.3));
		};
	};
}
