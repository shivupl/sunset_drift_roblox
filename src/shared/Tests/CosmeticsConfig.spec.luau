--!strict
local CosmeticsConfig = require(script.Parent.Parent.CosmeticsConfig)
local DriftStyles = require(script.Parent.Parent.DriftStyles)
local ExhaustStyles = require(script.Parent.Parent.ExhaustStyles)
local ExhaustTips = require(script.Parent.Parent.CosmeticMeshes.ExhaustTips)
local Tests = require(script.Parent)
type T = Tests.T

return function(t: T)
	local seen: { [string]: boolean } = {}
	local categorySet: { [string]: boolean } = {}
	for _, c in CosmeticsConfig.CATEGORIES do
		categorySet[c] = true
	end

	local zeroPriceCount: { [string]: number } = {}
	for _, item in CosmeticsConfig.items do
		t.ok(not seen[item.id], `id {item.id} is unique`)
		seen[item.id] = true

		t.ok(categorySet[item.category], `{item.id}'s category {item.category} is in CATEGORIES`)

		if item.price == 0 then
			zeroPriceCount[item.category] = (zeroPriceCount[item.category] or 0) + 1
			t.eq(CosmeticsConfig.stockId(item.category), item.id, `{item.id} is the stock id of {item.category}`)
		else
			t.ok(item.price > 0, `{item.id} (non-stock) has a positive price`)
		end

		if item.category == "paint" and item.id ~= "paint_stock" then
			t.ok(item.color ~= nil, `{item.id} has a color`)
		end

		if item.category == "finish" and item.id ~= "finish_stock" then
			t.ok(item.material ~= nil, `{item.id} has a material`)
		end

		if item.category == "rims" and item.id ~= "rims_stock" then
			t.ok(item.material ~= nil, `{item.id} has a material`)
		end

		if item.category == "exhaust" then
			t.ok(item.tips ~= nil, `{item.id} has tips`)
			t.ok(item.engineVolume ~= nil, `{item.id} has engineVolume`)
			t.ok(item.crackleChance ~= nil, `{item.id} has crackleChance`)
			-- The flame profile (garage round 2 §2).
			t.ok(item.flameSize ~= nil and (item.flameSize :: number) > 0, `{item.id} has a positive flameSize`)
			t.ok(item.flameCore ~= nil, `{item.id} has a flameCore`)
			t.ok(item.flameColor ~= nil, `{item.id} has a flameColor`)
			-- The pops a lift-off asks for now travel as one relay message a
			-- burst (ExhaustStyles.spec checks the scale every item can ask for).
		end
	end

	-- Window tint (garage round 2 §4): every film has a colour and both
	-- transparencies, the windscreen's always lighter than the sides' (a
	-- legal-looking windscreen), none opaque, and darker up the ladder.
	local films = {}
	for _, item in CosmeticsConfig.inCategory("tint") do
		if item.price > 0 then
			table.insert(films, item)
			local side, screen = item.glassTransparency, item.screenTransparency
			t.ok(item.glassColor ~= nil, `{item.id} has a glassColor`)
			t.ok(side ~= nil and side > 0 and side < 1, `{item.id} glassTransparency in (0, 1)`)
			t.ok(screen ~= nil and screen >= 0.5 and screen < 1, `{item.id} screenTransparency at least 0.5`)
			t.ok(side ~= nil and screen ~= nil and screen > side, `{item.id} windscreen lighter than the sides`)
		else
			t.eq(item.glassColor, nil, "the factory tint has no film")
		end
	end
	t.eq(#films, 3, "three tint films (Light, Dark, Limo)")
	for i = 2, #films do
		t.ok((films[i].glassTransparency :: number) < (films[i - 1].glassTransparency :: number), `{films[i].id} is darker than {films[i - 1].id}`)
	end

	-- Round 2's new items exist in their categories (ids are permanent).
	for id, category in {
		paint_clay = "paint", paint_teal = "paint", paint_gulf = "paint", paint_olive = "paint",
		rims_red = "rims", rims_champagne = "rims",
		decal_natl = "decal", decal_white = "decal",
		tint_stock = "tint", tint_light = "tint", tint_dark = "tint", tint_limo = "tint",
	} :: { [string]: string } do
		local item = CosmeticsConfig.find(id)
		t.ok(item ~= nil and (item.category :: string) == category, `{id} is a {category} item`)
	end
	-- A decal draws a strip with readable text (or none at all).
	for _, item in CosmeticsConfig.inCategory("decal") do
		if item.price > 0 then
			t.ok(item.stripColor ~= nil, `{item.id} has a stripColor`)
			t.ok(item.text ~= nil, `{item.id} has text ("" for none)`)
			if item.text ~= "" then
				t.ok(item.textColor ~= nil, `{item.id} has a textColor`)
			end
		end
	end
	-- New slots go on the end, so every look string written before them is
	-- unchanged: tint (garage round 2), then tyre and flame
	-- (garage-tyres-flames).
	local n = #CosmeticsConfig.CATEGORIES
	t.eq(CosmeticsConfig.CATEGORIES[n - 2], "tint", "tint comes after the round 1 slots")
	t.eq(CosmeticsConfig.CATEGORIES[n - 1], "tyre", "tyre comes after tint")
	t.eq(CosmeticsConfig.CATEGORIES[n], "flame", "flame is the last category")

	-- Tyres (garage-tyres-flames): the stock tyre is every drivetrain's
	-- Classic and fits every car; each other tyre names a real drift mode of
	-- its own drivetrain, fits only that drivetrain, and every mode bar the
	-- Classics is sold as one tyre.
	local stockTyre = CosmeticsConfig.find(CosmeticsConfig.stockId("tyre")) :: CosmeticsConfig.Item
	t.eq(stockTyre.id, "tyre_classic", "the stock tyre is Classic")
	t.eq(stockTyre.driftStyle, nil, "the stock tyre names no mode (each drivetrain's default)")
	local sold: { [string]: boolean } = {}
	for _, layout in DriftStyles.layouts do
		t.ok(CosmeticsConfig.fits(stockTyre, layout), `the stock tyre fits {layout}`)
		t.eq(DriftStyles.styles[DriftStyles.default(layout)].name, "Classic", `{layout}'s default mode is Classic`)
	end
	for _, item in CosmeticsConfig.inCategory("tyre") do
		if item.price > 0 then
			local style = if item.driftStyle then DriftStyles.styles[item.driftStyle] else nil
			t.ok(style ~= nil, `{item.id} names a drift mode`)
			if style then
				t.eq(item.layout, style.layout, `{item.id} fits its mode's drivetrain`)
				t.eq(item.name, style.name, `{item.id} is called what its mode is`)
				t.ok(style.name ~= "Classic", `{item.id} is not a Classic`)
				for _, layout in DriftStyles.layouts do
					t.eq(CosmeticsConfig.fits(item, layout), layout == style.layout, `{item.id} fits {layout} only if it is its own`)
				end
				sold[item.driftStyle :: string] = true
			end
		end
	end
	for id, style in DriftStyles.styles do
		if style.name ~= "Classic" then
			t.ok(sold[id], `the {id} mode is sold as a tyre`)
		end
	end

	-- Flames: each names a real flame style, Classic is the free one, and
	-- every style is sold.
	t.eq(CosmeticsConfig.stockId("flame"), "flame_classic", "the stock flame is Classic")
	t.eq((CosmeticsConfig.find("flame_classic") :: CosmeticsConfig.Item).flameStyle, ExhaustStyles.default, "the stock flame is the default flame style")
	local soldFlames: { [string]: boolean } = {}
	for _, item in CosmeticsConfig.inCategory("flame") do
		t.ok(item.flameStyle ~= nil and ExhaustStyles.styles[item.flameStyle :: string] ~= nil, `{item.id} names a flame style`)
		t.ok(item.flameCore ~= nil and item.flameColor ~= nil, `{item.id} has its tile's colours`)
		t.ok(CosmeticsConfig.fits(item, "FWD"), `{item.id} fits every car`)
		soldFlames[item.flameStyle or ""] = true
	end
	for _, id in ExhaustStyles.order do
		t.ok(soldFlames[id], `the {id} flame style is sold`)
	end

	-- Flames get bigger up the exhaust ladder: factory smallest, titanium
	-- largest (the spec's "factory small ... sport tips larger").
	local size = function(id: string): number
		local item = CosmeticsConfig.find(id)
		return if item then item.flameSize or 0 else 0
	end
	t.ok(size("exhaust_stock") < size("exhaust_single"), "factory flame is smaller than a sport tip's")
	t.ok(size("exhaust_twin") <= size("exhaust_quad") and size("exhaust_quad") <= size("exhaust_titanium"), "titanium flame is the largest")
	-- The Big Oval (garage round 3 §1): the single's flame, a little bigger.
	t.ok(size("exhaust_oval") > size("exhaust_single") and size("exhaust_oval") < size("exhaust_titanium"), "oval flame between the single's and the titanium's")

	-- Modelled tips (garage round 3 §1): every tip item names a style that
	-- exists, whose generated meshes exist and keep the budget; the round
	-- tips are built at render.tipRadiusM and the quad's Y inlet at
	-- render.quadPairGapM (the mouth maths use those); the pipe fits inside
	-- every inlet collar.
	local R = CosmeticsConfig.render
	local pieces = ExhaustTips.pieces :: { [string]: any }
	for _, item in CosmeticsConfig.inCategory("exhaust") do
		if (item.tips or 0) == 0 then
			continue
		end
		local style = if item.tipStyle then R.tipStyles[item.tipStyle] else nil
		t.ok(style ~= nil, `{item.id} names a tip style that exists ({item.tipStyle})`)
		if style then
			local piece = pieces[style.mesh]
			t.ok(piece ~= nil, `{item.id}: tip mesh {style.mesh} is generated`)
			t.eq(style.pair == true, item.tips == 4, `{item.id}: a pair mesh exactly when it is a quad`)
			if piece then
				-- One bore disc per tip the mesh holds (a pair holds two).
				t.eq(#piece.bores, piece.tips, `{item.id}: a bore for every tip in {style.mesh}`)
				t.eq(piece.tips, if style.pair then 2 else 1, `{item.id}: {style.mesh} holds its tips`)
			end
		end
	end
	-- One EditableMesh per style, at most 4 (fix round 1: a client holds 8).
	local meshes: { [string]: boolean } = {}
	local count = 0
	for _, style in R.tipStyles do
		if not meshes[style.mesh] then
			meshes[style.mesh] = true
			count += 1
		end
	end
	t.ok(count <= 4, `tip styles use at most 4 meshes (use {count})`)
	t.ok(R.tipMeshReserve >= 0, "tipMeshReserve is set")
	for name, piece in pieces do
		t.ok(piece.triangleCount / piece.tips <= 1500, `tip mesh {name}: at most 1,500 triangles a tip (has {piece.triangleCount} for {piece.tips})`)
		if piece.inletRadiusM > 0 then
			t.ok(R.pipeRadiusM < piece.inletRadiusM, `tip mesh {name}: the pipe fits inside its inlet`)
		end
	end
	for _, name in { "Rolled", "QuadPair", "Slash" } do
		local r = pieces[name] and pieces[name].radiusM
		t.ok(r ~= nil and math.abs(r[1] - R.tipRadiusM) < 0.001, `tip mesh {name}: built at tipRadiusM`)
	end
	t.ok(math.abs(ExhaustTips.pairGapM - R.quadPairGapM) < 0.001, "QuadPair built for quadPairGapM")

	-- Every flame layer: whole, ordered particle counts; lifetimes and
	-- keyframes that run 0 to 1.
	local flames = CosmeticsConfig.flames
	local total = 0
	for name, L in flames.layers :: { [string]: any } do
		t.ok(L.count[1] >= 0 and L.count[1] <= L.count[2] and math.floor(L.count[2]) == L.count[2], `flame layer {name}: count is a whole min..max`)
		t.ok(L.lifetime[1] > 0 and L.lifetime[1] <= L.lifetime[2], `flame layer {name}: lifetime range`)
		for _, seq in { L.size, L.transparency, L.squash } do
			t.eq(seq[1][1], 0, `flame layer {name}: a sequence starts at 0`)
			t.eq(seq[#seq][1], 1, `flame layer {name}: a sequence ends at 1`)
		end
		total += L.count[2]
	end
	-- Emit bursts only, and few: at most 30 particles per pop at one outlet
	-- (a quad at the titanium's 8-pop burst is then under 1,000 over half a
	-- second).
	t.ok(total <= 30, `at most 30 particles per pop per outlet (is {total})`)
	t.eq(flames.timeScale, 1, "flame timeScale is 1 (only a Studio harness changes it)")

	for _, c in CosmeticsConfig.CATEGORIES do
		t.eq(zeroPriceCount[c], 1, `{c} has exactly one price-0 item`)
	end

	t.eq(CosmeticsConfig.find("nope"), nil, "find refuses an unknown id")
end
