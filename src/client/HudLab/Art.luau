--!strict
-- The HUD variants' image art (hud-variants, 2026-10-07; the owner: "the
-- 'art' looks pretty bad... would benefit from some sort of image generation
-- or higher detail"). Drawn as SVG in art/hud/<variant>/, rendered by
-- art/hud/render.py, uploaded from Studio; each id here is the upload of
-- art/hud/out/<variant>_<name>.png. Re-render and re-upload to change one.
local Art = {}

Art.pro = {
	pedalGas = "rbxassetid://135274787038915", -- 400x1000
	pedalBrake = "rbxassetid://79262254764559", -- 560x520
	wheel = "rbxassetid://102449432767242", -- 800x800
	leverTrack = "rbxassetid://78580710859585", -- 220x640
	leverHandle = "rbxassetid://120524520893805", -- 300x340
	natlOff = "rbxassetid://102396238986805", -- 320x320
	natlOn = "rbxassetid://136280960014442",
	pill = "rbxassetid://134413685288700", -- 300x120, 9-slice
	tachoFace = "rbxassetid://117938827503151", -- 800x800, -135..100 deg for 0..8000 rpm
	needle = "rbxassetid://73792139926842", -- 800x800, pointing up from the centre
}

Art.midnight = {
	pedalGas = "rbxassetid://94086895929006", -- 400x1000
	pedalBrake = "rbxassetid://131885275960873", -- 560x520
	leverTrack = "rbxassetid://74728942538475", -- 220x640
	leverHandle = "rbxassetid://124121985830068", -- 300x340
	natlOff = "rbxassetid://80406845465658", -- 320x320
	natlOn = "rbxassetid://100416445193209",
	pill = "rbxassetid://136483454944060", -- 300x120, 9-slice
	sliderTrack = "rbxassetid://95611610015131", -- 900x200
	sliderKnob = "rbxassetid://84049795478501", -- 200x200
	tachoFace = "rbxassetid://75595994224917", -- 800x800, -132..112 deg for 0..8000 rpm
	needle = "rbxassetid://96376685753225", -- 800x800
}

Art.arcade = {
	pedalGas = "rbxassetid://84138672386198", -- 400x1000
	pedalBrake = "rbxassetid://122861768312475", -- 560x520
	leverTrack = "rbxassetid://87884056266485", -- 220x640
	leverHandle = "rbxassetid://79650287885942", -- 300x340
	natlOff = "rbxassetid://104848517231016", -- 320x320
	natlOn = "rbxassetid://116264961900969",
	pill = "rbxassetid://73273385296660", -- 300x120, 9-slice
	padBase = "rbxassetid://131299606826177", -- 800x800
	padKnob = "rbxassetid://82592957195255", -- 400x400
	gaugeFace = "rbxassetid://88818787660404", -- 800x800, under the LED arc
	coin = "rbxassetid://71668343633671", -- 256x256
}

-- KRUZER (art/hud/kruzer/make.py): the cluster and OEM controls.
Art.kruzer = {
	tachoFace = "rbxassetid://78743888301662", -- 768, -125..125 deg for 0..8000 r/min
	tachoNeedle = "rbxassetid://112051987716769", -- 768, pointing up from the centre
	tachoGlass = "rbxassetid://100351497070206", -- 768, glass and the centre cap
	rollFace = "rbxassetid://126111534047594", -- 320, -60..60 deg
	rollCar = "rbxassetid://124508038155819", -- 320, turns with the roll
	rollTip = "rbxassetid://116512343928669", -- 320, the tip mark, turned to the tip angle
	angleFace = "rbxassetid://104779528241846", -- 320, -90..90 deg
	podNeedle = "rbxassetid://126016089093752", -- 320
	podGlass = "rbxassetid://125379355499759", -- 320
	lcd = "rbxassetid://134653706143959", -- 960x96, 16 cells of 60x96
	dots = "rbxassetid://107119783118153", -- 960x640, cells of 96x128, 10 across
	mid = "rbxassetid://85359294258406", -- 960x300, the drift display
	mini = "rbxassetid://104592961517102", -- 600x200, the cash display
	lampShift = "rbxassetid://85945014875248", -- 96, lit
	lampBrake = "rbxassetid://118856957766301",
	lampSlip = "rbxassetid://82223043341647",
	lampNatl = "rbxassetid://99935766826306",
	pedalGas = "rbxassetid://130935025747673", -- 400x1000
	pedalBrake = "rbxassetid://95953172736966", -- 560x520
	padBase = "rbxassetid://109593595077939", -- 640
	padKnob = "rbxassetid://131731743148206", -- 300
	leverTrack = "rbxassetid://93012359671709", -- 220x640
	leverHandle = "rbxassetid://113256589189901", -- 360x260
	natlOff = "rbxassetid://109755520140252", -- 320
	natlOn = "rbxassetid://99166026440240",
	pill = "rbxassetid://79097207635316", -- 300x120, 9-slice
	leanTrack = "rbxassetid://122897827112719", -- 900x200
	leanKnob = "rbxassetid://100245561669893", -- 200
}

-- STREET (art/hud/street/make.py): the white-face cluster and drift-car hardware.
Art.street = {
	tachoFace = "rbxassetid://108388805554491", -- 768, -135..135 deg for 0..9000 r/min
	needle = "rbxassetid://132383203721023", -- 768
	needleShadow = "rbxassetid://136445104139666", -- 768, offset down-right by the HUD
	peak = "rbxassetid://112296814192293", -- 768, the peak-hold needle
	tachoGlass = "rbxassetid://120154002447272", -- 768
	shiftOff = "rbxassetid://120197415138216", -- 160
	shiftOn = "rbxassetid://83269705529659",
	drum = "rbxassetid://106161483060176", -- 48x792, 0..9,0
	drumTenths = "rbxassetid://88005772887032",
	drumShade = "rbxassetid://76896976477528", -- 48x72
	speed = "rbxassetid://85148172590541", -- 800x150, cells of 80x150, 0..9
	gear = "rbxassetid://79074122323209", -- 896x160, cells of 112x160, 123456RN
	kmh = "rbxassetid://126741206893761", -- 220x80
	tyreFace = "rbxassetid://107868653438542", -- 320, -120..120 deg for 40..140 C
	podNeedle = "rbxassetid://72813661855970", -- 320
	podNeedleShadow = "rbxassetid://135468852888566",
	podGlass = "rbxassetid://73934767757603",
	dots = "rbxassetid://85284516475366", -- 960x640, red LEDs
	board = "rbxassetid://140552097432934", -- 960x300
	mini = "rbxassetid://136853505388172", -- 600x200
	pedalGas = "rbxassetid://119885551343539", -- 400x1000
	pedalBrake = "rbxassetid://84226814032224", -- 560x520
	padBase = "rbxassetid://138237324340001", -- 640
	padKnob = "rbxassetid://118783042700856", -- 300
	leverTrack = "rbxassetid://89035246851844", -- 220x640
	leverHandle = "rbxassetid://93086231111005", -- 360x260
	natlOff = "rbxassetid://114797356683263", -- 320
	natlOn = "rbxassetid://74966294557411",
	pill = "rbxassetid://127773022273857", -- 300x120, 9-slice
	leanTrack = "rbxassetid://121856851965042", -- 900x200
	leanKnob = "rbxassetid://96228336250197", -- 200
}

-- KABRIS (art/hud/kabris/make.py): the box sedan's cluster and Brougham trim.
-- Its odometer drums are STREET's.
Art.kabris = {
	housing = "rbxassetid://116035696182002", -- 1000x320, the whole cluster
	glass = "rbxassetid://112883777935476", -- 1000x320
	sweep = "rbxassetid://78538098967659", -- 40x120, the speed needle
	podNeedle = "rbxassetid://118668579965761", -- 320, pivot at the centre
	pointer = "rbxassetid://137081451120254", -- 40x32, the gear pointer
	lampBrake = "rbxassetid://115332371325115", -- 112x70, lit
	lampNatl = "rbxassetid://126785118044734",
	lampTemp = "rbxassetid://77696570787341",
	lampShift = "rbxassetid://91441772810651",
	seg = "rbxassetid://129830378978658", -- 960x640, 14-segment, cells of 96x128
	vfd = "rbxassetid://94520300071106", -- 960x300
	vfdOver = "rbxassetid://77328648797668", -- 960x300, the mesh and glass over it
	vfdMini = "rbxassetid://106447247728108", -- 600x200
	vfdMiniOver = "rbxassetid://79515600578328",
	pedalGas = "rbxassetid://134602851525004", -- 400x1000
	pedalBrake = "rbxassetid://97637079751228", -- 560x520
	padBase = "rbxassetid://114989429953650", -- 640
	padKnob = "rbxassetid://100013875872461", -- 300
	leverTrack = "rbxassetid://71880176360470", -- 220x640
	leverHandle = "rbxassetid://116432583673755", -- 360x260
	natlOff = "rbxassetid://102072599149389", -- 320
	natlOn = "rbxassetid://121132279941029",
	pill = "rbxassetid://102599971543311", -- 300x120, 9-slice
	leanTrack = "rbxassetid://109946610445924", -- 900x200
	leanKnob = "rbxassetid://71355769245692", -- 200
}

return Art
