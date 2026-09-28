--!strict
-- Garage cosmetics: paint, finish, rims, head/tail lamp colour, decals and
-- exhaust tips. Asked by the owner on 2026-09-28, alongside the garage and
-- customisation spec (hajwala-project-phases.md / the 2026-09-28 garage
-- design docs): every car should have paint, wheels, lights, a decal and an
-- exhaust to buy and swap, priced in the same economy as PlateConfig's plate
-- prices (10,000 to 1,000,000). The prices below are first guesses for the
-- owner to weigh against how fast cash is earned, same as PlateConfig's.
--
-- Ids are permanent: they are stored on player profiles (as a CarLook
-- string) and never renamed once shipped, only added to. A stock id per
-- category (price 0) is the factory look nobody has to buy; CarLook falls
-- back to it when nothing is owned or chosen for that slot.
local CosmeticsConfig = {}

export type Category = "paint" | "finish" | "rims" | "head" | "tail" | "decal" | "exhaust"

export type Item = {
	id: string,
	category: Category,
	name: string,
	price: number,
	rare: boolean?,
	color: Color3?,
	material: Enum.Material?,
	reflectance: number?,
	darken: number?, -- finish only: the paint colour's value this much lower (0..1)
	desaturate: number?, -- finish only: the paint colour's saturation this much lower (0..1)
	text: string?,
	textColor: Color3?,
	stripColor: Color3?,
	stripColor2: Color3?,
	tips: number?,
	tipColor: Color3?,
	tipMaterial: Enum.Material?,
	engineVolume: number?,
	crackleChance: number?,
}

-- Garage actions (buy, equip, plate) a player may send per second through
-- CosmeticsAction; more get "busy". Each is one tap in the garage, so 4 is
-- well above a person and well below a script (garage plan, task 2,
-- 2026-09-28; same idea as PlateConfig.actionsPerSecond).
CosmeticsConfig.actionsPerSecond = 4

-- How a look is drawn on the car (CarCosmetics, CarLamps; garage plan,
-- task 3, 2026-09-28). The spots themselves are per car, CarCosmeticMounts.
CosmeticsConfig.render = {
	-- A chosen tail colour's brake lamp: that colour this much brighter (HSV
	-- value), so braking still reads over the tail lamps. Smoked (#4A0A0C)
	-- brakes at #670E11, which is dim: raise this if braking gets lost.
	brakeBrighten = 0.4,
	-- The windscreen strip: a thin card, its canvas drawn at this many pixels
	-- per metre, not drawn past drawStuds (the text is unreadable by then).
	stripThicknessM = 0.004,
	stripPixelsPerM = 400,
	stripDrawStuds = 250,
	-- Exhaust tips along the car, metres before the car's scale: a 0.09 m
	-- radius, 0.16 m long pipe with a dark bore flush at its open end so it
	-- reads as a pipe, not a rod. Quad tips are two pairs, each pair's tips
	-- quadPairGapM apart centre to centre.
	tipRadiusM = 0.09,
	tipLengthM = 0.16,
	boreRadiusM = 0.065,
	boreColor = Color3.fromRGB(18, 18, 20),
	quadPairGapM = 0.2,
}

-- Panel order: also the order categories' chips appear in within the panel.
CosmeticsConfig.CATEGORIES = { "paint", "finish", "rims", "head", "tail", "decal", "exhaust" } :: { Category }

-- Ordered as shown in the panel within each category.
CosmeticsConfig.items = {
	-- PAINT. The body colour. Stock keeps the catalog's own paint (no
	-- override); every other swatch is a flat Color3 the applier paints on.
	{ id = "paint_stock", category = "paint", name = "Factory", price = 0 },
	{ id = "paint_pearl", category = "paint", name = "Pearl White", price = 15000, color = Color3.fromHex("#EDEAE2") },
	{ id = "paint_sand", category = "paint", name = "Desert Sand", price = 15000, color = Color3.fromHex("#C9AE84") },
	{ id = "paint_sodium", category = "paint", name = "Sodium Orange", price = 25000, color = Color3.fromHex("#F08A24") },
	{ id = "paint_gold", category = "paint", name = "Dune Gold", price = 40000, color = Color3.fromHex("#B8913A") },
	{ id = "paint_black", category = "paint", name = "Asphalt Black", price = 15000, color = Color3.fromHex("#16151A") },
	{ id = "paint_green", category = "paint", name = "Gantry Green", price = 25000, color = Color3.fromHex("#145C38") },
	{ id = "paint_red", category = "paint", name = "Beacon Red", price = 25000, color = Color3.fromHex("#B3161E") },
	{ id = "paint_blue", category = "paint", name = "Night Blue", price = 25000, color = Color3.fromHex("#1B2A4E") },
	{ id = "paint_violet", category = "paint", name = "Dusk Violet", price = 40000, rare = true, color = Color3.fromHex("#5A2E6E") },
	{ id = "paint_silver", category = "paint", name = "Silver", price = 15000, color = Color3.fromHex("#A9ABAE") },
	{ id = "paint_gunmetal", category = "paint", name = "Gunmetal", price = 20000, color = Color3.fromHex("#3D4046") },
	{ id = "paint_rose", category = "paint", name = "Riyadh Rose", price = 40000, rare = true, color = Color3.fromHex("#C77D86") },

	-- FINISH. The paint's material, reflectance and darkening; stock is the
	-- catalog's own material at reflectance 0.
	--
	-- Retuned in the lit bay 2026-09-28 (garage task 6, fix round 2), because
	-- the first values did not read: Lighting.Technology is ShadowMap, where
	-- the view's SpotLights give no specular highlight at all, Metal and Foil
	-- ignore Reflectance on these meshes (a red Lekzas at Metal 0.08 and at
	-- 0.35 was the same flat red as SmoothPlastic), and EnvironmentSpecular-
	-- and EnvironmentDiffuseScale changed nothing measurable indoors. Glass is
	-- the one material that answers the view's lights: at Reflectance 0 it
	-- keeps the paint colour and lays a lit sheen over the bonnet, roof and
	-- flanks (clear coat); more Reflectance washes the panels toward a pale
	-- silver. So the finishes are a ladder on Glass:
	--   matte    flat SmoothPlastic, the colour 20% darker and 30% less
	--            saturated: no sheen, and dull beside the factory colour
	--            (the old 8% darker could not be told from factory on red)
	--   gloss    Glass 0: the colour, with the lit sheen
	--   metallic Glass 0.05 over the colour 25% darker: sheen over the whole
	--            panel on a deeper base
	--   chrome   Glass 0.15 on the colour: pale liquid silver tinted by it
	--            (0.3 and a colour lightened toward white read as a plain
	--            white car)
	{ id = "finish_stock", category = "finish", name = "Factory", price = 0, reflectance = 0 },
	{ id = "finish_gloss", category = "finish", name = "Gloss", price = 10000, material = Enum.Material.Glass, reflectance = 0 },
	{ id = "finish_matte", category = "finish", name = "Matte", price = 30000, material = Enum.Material.SmoothPlastic, reflectance = 0, darken = 0.2, desaturate = 0.3 },
	{ id = "finish_metallic", category = "finish", name = "Metallic", price = 45000, material = Enum.Material.Glass, reflectance = 0.05, darken = 0.25 },
	{ id = "finish_chrome", category = "finish", name = "Chrome", price = 200000, rare = true, material = Enum.Material.Glass, reflectance = 0.15 },

	-- RIMS.
	{ id = "rims_stock", category = "rims", name = "Factory", price = 0 },
	{ id = "rims_black", category = "rims", name = "Gloss Black", price = 12000, color = Color3.fromHex("#121214"), material = Enum.Material.SmoothPlastic, reflectance = 0.1 },
	-- Chrome and gold on Glass, for the reason under FINISH (Foil and Metal
	-- read flat in the bay; 2026-09-28).
	{ id = "rims_chrome", category = "rims", name = "Chrome", price = 30000, color = Color3.fromHex("#B8BCC2"), material = Enum.Material.Glass, reflectance = 0.15 },
	{ id = "rims_gold", category = "rims", name = "Gold", price = 60000, rare = true, color = Color3.fromHex("#B8892E"), material = Enum.Material.Glass, reflectance = 0.05 },
	{ id = "rims_bronze", category = "rims", name = "Bronze", price = 35000, color = Color3.fromHex("#8C6A3F"), material = Enum.Material.Metal, reflectance = 0.1 },
	{ id = "rims_gunmetal", category = "rims", name = "Gunmetal", price = 20000, color = Color3.fromHex("#3A3C40"), material = Enum.Material.Metal, reflectance = 0.08 },
	{ id = "rims_white", category = "rims", name = "White", price = 20000, color = Color3.fromHex("#EDEDEA"), material = Enum.Material.SmoothPlastic, reflectance = 0.08 },

	-- HEAD (headlamp colour).
	{ id = "head_stock", category = "head", name = "Factory", price = 0 },
	{ id = "head_xenon", category = "head", name = "Xenon White", price = 20000, color = Color3.fromHex("#EAF2FF") },
	{ id = "head_ice", category = "head", name = "Ice Blue", price = 30000, color = Color3.fromHex("#A8D4FF") },
	{ id = "head_yellow", category = "head", name = "Halogen Yellow", price = 20000, color = Color3.fromHex("#FFD877") },
	{ id = "head_amber", category = "head", name = "Amber", price = 25000, color = Color3.fromHex("#FFB347") },

	-- TAIL (tail lamp colour).
	{ id = "tail_stock", category = "tail", name = "Factory", price = 0 },
	{ id = "tail_deep", category = "tail", name = "Deep Red", price = 15000, color = Color3.fromHex("#8A0508") },
	{ id = "tail_smoked", category = "tail", name = "Smoked", price = 25000, color = Color3.fromHex("#4A0A0C") },

	-- DECAL: a windscreen/body strip with text, or none.
	{ id = "decal_none", category = "decal", name = "None", price = 0 },
	{ id = "decal_hajwala", category = "decal", name = "Hajwala Strip", price = 20000, text = "هجولة", stripColor = Color3.fromHex("#111111"), textColor = Color3.fromHex("#EDEAE2") },
	{ id = "decal_sunset", category = "decal", name = "Sunset Drift", price = 20000, text = "SUNSET DRIFT", stripColor = Color3.fromHex("#111111"), textColor = Color3.fromHex("#FFBA5C") },
	{ id = "decal_tarat", category = "decal", name = "Tarat", price = 25000, text = "طارت", stripColor = Color3.fromHex("#FFBA5C"), textColor = Color3.fromHex("#15130F") },
	{ id = "decal_gradient", category = "decal", name = "Dusk Gradient", price = 50000, rare = true, text = "", stripColor = Color3.fromHex("#FFBA5C"), stripColor2 = Color3.fromHex("#5A2E6E") },

	-- EXHAUST: tip count, tip colour/material, and the sound tweaks they buy
	-- (engineVolume multiplies the engine sound, crackleChance the pops).
	{ id = "exhaust_stock", category = "exhaust", name = "Factory", price = 0, tips = 0, engineVolume = 1, crackleChance = 1 },
	{ id = "exhaust_single", category = "exhaust", name = "Single Chrome Tip", price = 15000, tips = 1, tipColor = Color3.fromHex("#D8DADD"), tipMaterial = Enum.Material.Foil, engineVolume = 1.1, crackleChance = 1.3 },
	{ id = "exhaust_twin", category = "exhaust", name = "Twin Chrome Tips", price = 30000, tips = 2, tipColor = Color3.fromHex("#D8DADD"), tipMaterial = Enum.Material.Foil, engineVolume = 1.2, crackleChance = 1.6 },
	{ id = "exhaust_quad", category = "exhaust", name = "Quad Tips", price = 60000, tips = 4, tipColor = Color3.fromHex("#2A2A2E"), tipMaterial = Enum.Material.Metal, engineVolume = 1.3, crackleChance = 2 },
	{ id = "exhaust_titanium", category = "exhaust", name = "Burnt Titanium Twin", price = 120000, rare = true, tips = 2, tipColor = Color3.fromHex("#6F5A8C"), tipMaterial = Enum.Material.Metal, engineVolume = 1.35, crackleChance = 2.5 },
} :: { Item }

local byId: { [string]: Item } = {}
local stockByCategory: { [string]: string } = {}
for _, item in CosmeticsConfig.items do
	byId[item.id] = item
	if item.price == 0 then
		stockByCategory[item.category] = item.id
	end
end
CosmeticsConfig.byId = byId

-- Every item in a category, in panel order.
function CosmeticsConfig.inCategory(c: Category): { Item }
	local out: { Item } = {}
	for _, item in CosmeticsConfig.items do
		if item.category == c then
			table.insert(out, item)
		end
	end
	return out
end

-- The free, factory-default item id for a category.
function CosmeticsConfig.stockId(c: Category): string
	local id = stockByCategory[c]
	assert(id, `no stock item for category {c}`)
	return id
end

-- Whether an id is a category's free, factory-default item.
function CosmeticsConfig.isStock(id: string): boolean
	local item = byId[id]
	return item ~= nil and item.price == 0
end

-- The item with this id, or nil.
function CosmeticsConfig.find(id: string?): Item?
	if id == nil then
		return nil
	end
	return byId[id]
end

return CosmeticsConfig
