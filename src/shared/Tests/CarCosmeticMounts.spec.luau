--!strict
-- Every car carries a windscreen strip spot and an exhaust spot, so the
-- garage's SUN STRIPS and EXHAUST show on every car (final review fix 5,
-- 2026-09-28). The garage greys those items out on a car without one
-- (CarCosmetics.hasSpot); this keeps a new car from shipping that way.
--
-- And every car's exhaust keeps the one standard (garage round 2 §1,
-- 2026-09-28), so flames work and look right on any car: at least one stock
-- outlet, tips 2-5 cm past the bumper face on a pipe that runs forward, every
-- outlet behind the rear axle, low and pointing back, and one outlet frame per
-- pipe mouth for every exhaust item.
--
-- And every pipe (each tip's, each factory one) is routed up into the body
-- (garage round 3 §2): riseM > 0 on every car and factory outlet, the
-- pipe's end at least riseM above its start with its whole rim, never
-- above the boot line, and clear of the rear tyre (behind it, or inboard).
local CarCosmeticMounts = require(script.Parent.Parent.CarCosmeticMounts)
local ConfigLoader = require(script.Parent.Parent.ConfigLoader)
local CosmeticsConfig = require(script.Parent.Parent.CosmeticsConfig)
local ExhaustTips = require(script.Parent.Parent.CosmeticMeshes.ExhaustTips)
local Tests = require(script.Parent)
type T = Tests.T

local R = CosmeticsConfig.render

-- Tip mouth past the bumper face: 2-5 cm (the spec), with 1 mm for rounding.
local PAST_MIN, PAST_MAX = 0.019, 0.051
-- The same bend CarCosmetics builds with (one helper, so the spec cannot
-- drift from the call site).
local BEND = CarCosmeticMounts.pipeBend(R)

return function(t: T)
	t.ok(R.quadPairGapM >= 2 * R.tipRadiusM, "quad tips of a pair do not overlap")
	t.ok(R.quadPairGapM / 2 <= 2 * R.tipRadiusM, "a quad pair sits over the pipe between its tips")

	-- Every car has windows, so a new car can't ship without tint.
	for id in ConfigLoader.catalog().cars do
		local m = CarCosmeticMounts.cars[id]
		t.ok(m ~= nil and m.windows ~= nil, `{id}: has windows for tint`)
		t.ok(m ~= nil, `{id}: has cosmetic spots`)
		local w = if m then m.windscreen else nil
		local e = if m then m.exhaust else nil
		t.ok(w ~= nil, `{id}: has a windscreen strip spot`)
		t.ok(e ~= nil, `{id}: has an exhaust spot`)
		if w then
			-- The strip generator's inputs (garage round 3 §3): a real body
			-- piece, a side, a height, and by-eye ends only where the glass is
			-- painted into a shell.
			local found = false
			for _, piece in ConfigLoader.entry(id).body.pieces do
				found = found or piece.name == w.piece
			end
			t.ok(found, `{id} windscreen: {w.piece} is a body piece`)
			t.ok(w.side == "inside" or w.side == "outside", `{id} windscreen: inside or outside`)
			t.ok(w.heightM > 0, `{id} windscreen: has a height`)
			if w.ends == "spot" then
				local pos, width = w.posM, w.widthM
				t.ok(pos ~= nil and #pos == 3 and pos[3] < 0.5, `{id} windscreen: a spot toward the front`)
				t.ok(width ~= nil and width > 0, `{id} windscreen: a width`)
			else
				t.eq(w.ends, "mesh", `{id} windscreen: ends from the mesh or a spot`)
			end
		end
		-- Window tint (garage round 2 §4): every named window is a real body
		-- piece, named once, and something is tinted.
		local win = if m then m.windows else nil
		if win then
			local pieces: { [string]: boolean } = {}
			local withLook: { [string]: boolean } = {}
			for _, piece in ConfigLoader.entry(id).body.pieces do
				pieces[piece.name] = true
				withLook[piece.name] = piece.look ~= nil
			end
			local seen: { [string]: boolean } = {}
			local n = 0
			for _, list in { win.side, win.screen, win.whole or {} } do
				for _, name in list do
					t.ok(pieces[name] == true, `{id} windows: {name} is a body piece`)
					t.ok(not seen[name], `{id} windows: {name} listed once`)
					-- Tint sets Color / Material / Transparency; a piece with a
					-- SurfaceAppearance (a CarLooks look) would not show it.
					t.ok(not withLook[name], `{id} windows: {name} has no SurfaceAppearance look`)
					seen[name] = true
					n += 1
				end
			end
			t.ok(n > 0, `{id} windows: at least one piece`)
		end
		if not e then
			continue
		end
		local rig = ConfigLoader.entry(id).rig
		local axleZ = rig.wheelbaseM / 2
		-- "Below the boot line": under the top of the rear tyres.
		local lowY = 2 * rig.wheelRadiusM

		t.ok(#e.stock >= 1, `{id} exhaust: at least one stock outlet`)
		for i, o in e.stock do
			t.eq(#o.posM, 3, `{id} stock {i}: x, y, z`)
			t.ok(o.posM[3] >= axleZ, `{id} stock {i}: behind the rear axle`)
			t.ok(o.posM[2] > 0.1 and o.posM[2] < lowY, `{id} stock {i}: low at the rear`)
			t.ok(o.posM[3] <= e.bumperZ + 0.05, `{id} stock {i}: not far behind the car`)
			if o.dir then
				t.eq(#o.dir, 3, `{id} stock {i}: dir x, y, z`)
			end
			if o.pipeLengthM then
				t.ok(o.pipeLengthM > 0, `{id} stock {i}: a factory pipe length`)
			end
		end
		if #e.stock >= 2 then
			t.ok(e.stock[1].posM[1] <= e.stock[2].posM[1], `{id} stock: listed left first`)
		end

		local tips = e.tips
		t.eq(#tips.posM, 3, `{id} tips: x, y, z`)
		t.ok(tips.spreadM > 0, `{id} tips: a spread`)
		t.ok(tips.pipeLengthM > 0, `{id} tips: a pipe running forward`)
		local past = tips.posM[3] - e.bumperZ
		t.ok(past >= PAST_MIN and past <= PAST_MAX, `{id} tips: 2-5 cm past the bumper (got {math.round(past * 1000)} mm)`)
		t.ok(tips.posM[3] >= axleZ, `{id} tips: behind the rear axle`)
		t.ok(tips.posM[2] < lowY, `{id} tips: below the boot line`)
		t.ok(tips.posM[2] - R.tipRadiusM > 0.08, `{id} tips: clear of the ground`)
		t.ok(tips.posM[3] - R.pipeRunFromM - tips.pipeLengthM > axleZ, `{id} tips: the pipe stops short of the rear axle`)

		-- The outlets: with tips on, one per tip and nothing else (the tips
		-- replace the whole exhaust); stock, one per stock outlet. All point
		-- back, upright, behind the axle and low.
		for _, n in { 0, 1, 2, 4 } do
			local frames = CarCosmeticMounts.outletFrames(e, n, R.quadPairGapM)
			t.eq(#frames, if n > 0 then n else #e.stock, `{id}: {n} tips give that many outlets`)
			for i, f in frames do
				t.ok(f.LookVector.Z > 0.5, `{id} outlet {i} of {n} tips: points out the back`)
				t.ok(f.UpVector.Y > 0.5, `{id} outlet {i} of {n} tips: upright`)
				t.ok(f.Position.Z >= axleZ, `{id} outlet {i} of {n} tips: behind the rear axle`)
				t.ok(f.Position.Y < lowY, `{id} outlet {i} of {n} tips: below the boot line`)
			end
			-- Every tip mouth 2-5 cm past the bumper above it, the quad's outer two
			-- included (where the bumper curves forward: quadOuterBumperZ).
			for i, p in CarCosmeticMounts.tipMouths(e, n, R.quadPairGapM) do
				local pastI = p.Z - CarCosmeticMounts.bumperAt(e, i, n)
				t.ok(pastI >= PAST_MIN and pastI <= PAST_MAX, `{id} tip {i} of {n}: 2-5 cm past the bumper (got {math.round(pastI * 1000)} mm)`)
			end
		end
		-- A one-pipe car's own pipe is under a tip for every tip count, so no
		-- stock pipe peeks out beside the tips.
		if #e.stock == 1 and not e.stock[1].factory then
			for _, n in { 1, 2, 4 } do
				t.ok(CarCosmeticMounts.tipCovers(e, e.stock[1], n, R.quadPairGapM, R.tipRadiusM), `{id}: {n} tips sit over its own pipe`)
			end
		end
		-- A quad on a one-pipe car puts a tip, not the gap between a pair's
		-- tips, over its own pipe (fix round 1: the kruzer80's showed there).
		if #e.stock == 1 and not e.stock[1].factory then
			local best = math.huge
			for _, x in CarCosmeticMounts.tipXs(e, 4, R.quadPairGapM) do
				best = math.min(best, math.abs(x - e.stock[1].posM[1]))
			end
			t.ok(best <= R.tipRadiusM / 2, `{id}: a quad tip, not a gap, over its own pipe (off by {math.round(best * 1000)} mm)`)
		end
		-- Routed pipes (garage round 3 §2).
		t.ok(e.riseM > 0, `{id}: riseM > 0 (the pipe bends up into the body)`)
		local function checkRoute(what: string, route: CarCosmeticMounts.PipeRoute, startY: number, rise: number, radius: number)
			local d = route.finishDir
			local rim = route.finish.Y - radius * math.sqrt(math.max(0, 1 - d.Y * d.Y))
			t.ok(route.finish.Y >= startY + rise, `{what}: the end is riseM above the start`)
			t.ok(rim >= startY + rise + BEND.buryM - 1e-4, `{what}: the end's whole rim is buried (rim {math.round((rim - startY) * 1000)} mm up)`)
			t.ok(d.Y > 0, `{what}: the end points up into the body`)
			-- The highest point of the pipe: a joint's ball reaches r above its
			-- centre; a cylinder's flat end reaches r * cos(its slope) above the
			-- end's centre (r at a level end, nothing at a vertical one, where the
			-- end face is level and its top is its centre). The kruzer80's riser
			-- ends vertical 8 mm under its boot line: a centimetre more riseM
			-- there fails this.
			local function top(p: Vector3, d: Vector3): number
				return p.Y + radius * math.sqrt(math.max(0, 1 - d.Y * d.Y))
			end
			for _, j in route.joints do
				t.ok(j.Y + radius < lowY, `{what}: joint ball below the boot line`)
			end
			-- The rear tyre's inner face (the catalog's own tyre width).
			local tyreInner = rig.trackWidthM / 2 - rig.wheelWidthM / 2
			for k, seg in route.segments do
				local along = (seg.b - seg.a).Unit
				for _, p in { seg.a, seg.b } do
					t.ok(top(p, along) < lowY, `{what} segment {k}: below the boot line`)
					local behind = p.Z - radius > axleZ + rig.wheelRadiusM
					local inboard = math.abs(p.X) + radius < tyreInner
					t.ok(behind or inboard, `{what} segment {k}: clear of the rear tyre`)
				end
				t.ok((seg.b - seg.a).Magnitude > 0.001, `{what} segment {k}: has a length`)
			end
			t.eq(#route.joints, #route.segments - 1, `{what}: a ball at every joint`)
			if route.hanger then
				t.ok(route.hanger.b.Y >= startY + rise, `{what}: the hanger reaches the body`)
			end
		end
		-- Every exhaust item's pipes, as the mesh tips have them and as the
		-- cylinder fallback has them (fix round 1: the fallback was not walked,
		-- and its quad ran the pickup's outer pipes through the rear tyres).
		local frontZ = CarCosmeticMounts.pipeFrontZ(e, R)
		local fallbackBack = Vector3.new(0, 0, ExhaustTips.pieces.Rolled.inletM[3])
		for _, item in CosmeticsConfig.inCategory("exhaust") do
			local n = item.tips or 0
			if n == 0 then
				continue
			end
			local style = R.tipStyles[item.tipStyle or "rolled"]
			local mesh = ExhaustTips.pieces[style.mesh]
			local inletM = Vector3.new(mesh.inletM[1], mesh.inletM[2], mesh.inletM[3])
			-- Every mesh mouth (each piece's frame at each of its bores) sits
			-- on its outlet, in order, pointing the same way: the flames leave
			-- the modelled mouths (final review M3; Studio had 0.12 mm).
			local pieces = CarCosmeticMounts.pieceFrames(e, n, R.quadPairGapM, style.pair == true)
			local outlets = CarCosmeticMounts.outletFrames(e, n, R.quadPairGapM)
			t.eq(#pieces * #mesh.bores, #outlets, `{id} {item.id}: a mesh mouth per outlet`)
			for i, frame in pieces do
				for j, b in mesh.bores do
					local o = outlets[(i - 1) * #mesh.bores + j]
					if o then
						local mouth = frame * CFrame.new(b.xM, 0, 0)
						t.ok((mouth.Position - o.Position).Magnitude < 1e-4, `{id} {item.id} mouth {i}.{j}: on its outlet`)
						t.ok(mouth.ZVector:Dot(o.LookVector) > 0.9999, `{id} {item.id} mouth {i}.{j}: its outlet points out of it`)
					end
				end
			end
			for _, way in { "mesh", "fallback" } do
				local at = if way == "mesh" then inletM else fallbackBack
				local inlets = CarCosmeticMounts.pipeInlets(e, n, R, at, style.pair == true)
				t.eq(#inlets, if n >= 4 then 2 else n, `{id} {item.id} {way}: one pipe per tip, one per quad pair`)
				for i, inlet in inlets do
					local what = `{id} {item.id} {way} pipe {i}`
					local route = CarCosmeticMounts.pipeRoute(inlet.Position, inlet.ZVector, R.pipeOverlapM, frontZ, e.riseM, R.pipeRadiusM, BEND)
					checkRoute(what, route, inlet.Y, e.riseM, R.pipeRadiusM)
					t.ok(route.segments[1].a.Z >= inlet.Z, `{what}: starts inside the tip`)
				end
			end
		end
		for i, o in e.stock do
			if o.factory then
				t.ok(o.riseM ~= nil and o.riseM > 0, `{id} factory {i}: its own riseM > 0`)
				local rise = o.riseM or e.riseM
				local mouth = Vector3.new(o.posM[1], o.posM[2], o.posM[3])
				local len = o.pipeLengthM or tips.pipeLengthM
				local route = CarCosmeticMounts.pipeRoute(mouth, Vector3.zAxis, 0, mouth.Z - len, rise, R.factoryPipeRadiusM, BEND)
				checkRoute(`{id} factory {i}`, route, mouth.Y, rise, R.factoryPipeRadiusM)
				t.ok(math.abs(route.segments[1].a.Z - mouth.Z) < 1e-6, `{id} factory {i}: starts at its mouth`)
			end
		end

		-- A single tip goes on stock[1]'s side (over a one-pipe car's own pipe).
		local single = CarCosmeticMounts.tipXs(e, 1, R.quadPairGapM)[1]
		local side = if e.stock[1].posM[1] > 0 then 1 else -1
		t.ok((single - tips.posM[1]) * side > 0, `{id}: a single tip on stock[1]'s side`)
	end
end
