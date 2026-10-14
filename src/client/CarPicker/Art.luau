--!strict
-- The car picker's images (art/carmenu: make.py draws the UI pieces, key.py
-- cuts the car photos out of a green-screen render; README there). The UI
-- pieces are white and tinted here; the 9-slice ones say their centre.
local Art = {}

-- A slanted tab (16 degrees), 277x128: the slant lives in the end caps.
-- Drawn at twice its old 138x64 (2026-10-14, the owner: "edges look wierd
-- and blury"): a 44 px tab on a phone is 88 to 132 device pixels, and
-- the 64 px art was being blown up to them.
Art.tab = "rbxassetid://97717198360566"
Art.tabSlice = Rect.new(60, 62, 216, 66)
Art.tabH = 128
-- The SPAWN button: slanted 12 degrees, shaded (light top, dark lip), 262x104.
Art.button = "rbxassetid://118789381950876"
Art.buttonSlice = Rect.new(40, 51, 222, 53)
Art.buttonH = 104
-- A car's box: rounded, its bottom-right corner cut, 200x200; the outline
-- thin and thick (picked). Drawn at twice the size they show.
Art.tile = "rbxassetid://116276672124703"
Art.tileEdge = "rbxassetid://126582935946876"
Art.tileEdgeThick = "rbxassetid://124679883264318"
Art.tileSlice = Rect.new(24, 24, 160, 160)
-- A soft round light, a thick ring, a dot for the panel's texture.
Art.spot = "rbxassetid://94717258950017"
Art.ring = "rbxassetid://125072678164855"
Art.dots = "rbxassetid://94780814278252"
-- Favourite: filled and outline stars; the stat bars' stripes; search.
Art.star = "rbxassetid://118002130486409"
Art.starLine = "rbxassetid://124916424365560"
Art.stripes = "rbxassetid://107527937258580"
Art.search = "rbxassetid://81747364737978"
-- Header buttons: the next layout, the number plates, the settings.
Art.layout = "rbxassetid://129442049520354"
Art.plates = "rbxassetid://100638528304414"
Art.settings = "rbxassetid://99840058514901"

-- Each car, from the same three-quarter front angle in daylight on green,
-- cut out with dark glass and a soft shadow (720x400). A car with no photo
-- shows its name over the empty stage.
Art.cars = {
	pickup = "rbxassetid://91036895315897",
	cruiser = "rbxassetid://93495257575428",
	lekzas = "rbxassetid://115867628820110",
	krownvik = "rbxassetid://115146785769259",
	krownvikfleet = "rbxassetid://113693684409082",
	kamri07 = "rbxassetid://74376669148342",
	hatch = "rbxassetid://93769819060170",
	batrol = "rbxassetid://105864113782329",
	kruzer80 = "rbxassetid://125170877525727",
} :: { [string]: string }

return Art
