--!strict
-- ARCADE's phone controls, laid out as ARCADE has them (the owner: "i like
-- arcade layout"), dressed in another variant's rendered parts
-- (hud-variants, 2026-10-07). The thumb pad bottom left with NATL beside
-- it, the brake and the tall gas bottom right, the handbrake lever above
-- them, EXIT / RESET / STYLE along the top left, the lean slider over the
-- pad while on two wheels.
--
-- The cluster variants (KRUZER, STREET, KABRIS) pass a Skin; the behaviour
-- is Widgets', so every style drives the car the same way.
local GuiService = game:GetService("GuiService")

local HudLab = script.Parent
local W = require(HudLab:WaitForChild("Widgets"))

export type Skin = {
	pedalGas: string, -- 400x1000
	pedalBrake: string, -- 560x520
	padBase: string,
	padKnob: string,
	leverTrack: string, -- 220x640
	leverHandle: string,
	natlOff: string,
	natlOn: string,
	pill: string, -- 300x120, stretched by its 9-slice centre
	pillSlice: Rect,
	leanTrack: string, -- 900x200
	leanKnob: string,
	font: Font, -- the buttons' labels
	text: Color3,
	litText: Color3,
}

local ARCADE_GREY = Color3.fromRGB(28, 35, 42)
local WHITE = Color3.new(1, 1, 1)

local Controls = {}

function Controls.build(gui: ScreenGui, api: any, skin: Skin): any
	local t = W.tracker()
	local root = W.frame(gui, "ArcadeControls")
	root.Size = UDim2.fromScale(1, 1)
	local top = GuiService:GetGuiInset().Y
	local font = skin.font

	local pad = W.pad(root, "Steer", {
		base = ARCADE_GREY,
		baseTransparency = 0.2,
		edge = WHITE,
		edgeThickness = 0,
		knob = WHITE,
		knobLow = WHITE,
		knobEdge = WHITE,
		arrows = WHITE,
		arrowFont = font,
		baseImage = skin.padBase,
		knobImage = skin.padKnob,
	}, t, function(frac)
		api.steerRaw(frac)
	end)
	W.square(pad.root, 0.42)
	W.at(pad.root, 0.15, 0.72)

	local function pedalSkin(image: string, minValue: number): W.PedalSkin
		return {
			plate = WHITE,
			plateLow = WHITE,
			edge = WHITE,
			edgeThickness = 0,
			radius = UDim.new(0.2, 0),
			slots = 0,
			slot = WHITE,
			slotTransparency = 1,
			label = "",
			labelFont = font,
			labelColor = WHITE,
			labelStroke = nil,
			shadow = WHITE,
			shadowTransparency = 1,
			depth = 0.06,
			fill = nil,
			minValue = minValue,
			image = image,
		}
	end
	local gas = W.pedal(root, "Gas", pedalSkin(skin.pedalGas, 0.45), t, function(v)
		api.throttle(v)
	end)
	W.box(gas.root, 0.18, 0.45)
	W.at(gas.root, 0.885, 0.7)
	local brake = W.pedal(root, "Brake", pedalSkin(skin.pedalBrake, 0.5), t, function(v)
		api.brake(v)
	end)
	W.box(brake.root, 0.24, 0.223)
	W.at(brake.root, 0.735, 0.8)

	local lever = W.lever(root, "Hand", {
		track = ARCADE_GREY,
		trackTransparency = 0,
		trackEdge = WHITE,
		handle = WHITE,
		handleLow = WHITE,
		handleEdge = WHITE,
		grip = WHITE,
		label = "",
		labelFont = font,
		labelColor = WHITE,
		engageAt = 0.3,
		active = WHITE,
		trackImage = skin.leverTrack,
		handleImage = skin.leverHandle,
	}, t, function(on)
		api.handbrake(on)
	end)
	W.box(lever.root, 0.12, 0.32)
	W.at(lever.root, 0.935, 0.31)

	local small: W.ButtonSkin = {
		fill = ARCADE_GREY,
		fillTransparency = 0,
		lit = WHITE,
		edge = WHITE,
		edgeThickness = 0,
		radius = UDim.new(0.5, 0),
		font = font,
		text = skin.text,
		litText = skin.litText,
		textStroke = nil,
		image = skin.pill,
		litImage = nil,
		slice = skin.pillSlice,
		sliceHeight = 120,
	}
	local natlSkin = table.clone(small)
	natlSkin.image = skin.natlOff
	natlSkin.litImage = skin.natlOn
	natlSkin.slice = nil -- drawn whole
	natlSkin.sliceHeight = nil
	local natl = W.button(root, "Natl", "", natlSkin, t, function()
		api.natl()
	end)
	W.square(natl.root, 0.17)
	W.at(natl.root, 0.33, 0.6)

	local lean = W.slider(root, "Lean", {
		track = ARCADE_GREY,
		trackTransparency = 0,
		edge = WHITE,
		edgeThickness = 0,
		knob = WHITE,
		knobEdge = WHITE,
		radius = UDim.new(0.5, 0),
		marks = nil,
		markFont = nil,
		left = nil,
		right = nil,
		trackImage = skin.leanTrack,
		knobImage = skin.leanKnob,
	}, t, function(frac)
		api.lean(frac)
	end)
	W.box(lean.root, 0.4, 0.11)
	W.at(lean.root, 0.15, 0.36)
	lean.root.Visible = false

	local row = W.frame(root, "Buttons")
	row.Position = UDim2.new(0, 12, 0, top + 6)
	-- Full screen size, so the buttons' RelativeYY sizes are of the screen.
	row.Size = UDim2.fromScale(1, 1)
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.Padding = UDim.new(0, 8)
	list.Parent = row
	local buttons = {
		W.button(row, "Exit", "EXIT", small, t, function()
			api.exit()
		end),
		W.button(row, "Reset", "RESET", small, t, function()
			api.reset()
		end),
		W.button(row, "Style", api.styleName(), small, t, function()
			api.cycle()
		end),
	}
	for _, b in buttons do
		W.box(b.root, 0.2, 0.1)
	end

	return {
		update = function(dt: number)
			pad.update(dt)
			gas.update(dt)
			brake.update(dt)
			lever.update(dt)
			natl.update(dt)
			lean.update(dt)
			for _, b in buttons do
				b.update(dt)
			end
		end,
		setLean = function(visible: boolean)
			lean.root.Visible = visible
			if not visible then
				api.lean(0)
			end
		end,
		setNatl = function(on: boolean)
			natl.setLit(on)
		end,
		destroy = function()
			W.release(t)
			root:Destroy()
		end,
	}
end

return Controls
