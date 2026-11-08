--!strict
-- Which of CarConfig.camera.views the chase camera drives in (CameraRig),
-- held on the LocalPlayer attribute CamView (a view's id) so it lasts the
-- session through respawns. V on a keyboard and the CAM button on a phone
-- cycle it; HudLab shows the new view's name.
--
-- DRIVER (firstPerson) is only for cars with a cabin (CarCockpits): on any
-- other car the view in use is the first chase view, and V skips DRIVER,
-- while the attribute keeps DRIVER so the next car with a cabin goes back to
-- it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigLoader = require(Shared:WaitForChild("ConfigLoader"))
local CarCockpits = require(Shared:WaitForChild("CarCockpits"))

export type View = {
	id: string,
	name: string,
	distance: number,
	height: number,
	lookHeight: number,
	baseFov: number,
	maxFov: number,
	firstPerson: boolean,
}

local ATTRIBUTE = "CamView"

local CameraViews = {}

CameraViews.ATTRIBUTE = ATTRIBUTE

function CameraViews.list(): { View }
	return ConfigLoader.current().camera.views
end

-- The car the local player sits in, if any.
function CameraViews.carId(): string?
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	local model = seat and seat.Parent and seat.Parent.Parent
	local id = model and model:GetAttribute("CarId")
	return if type(id) == "string" then id else nil
end

-- Whether a view can be used in the car the player sits in now.
function CameraViews.usable(v: View): boolean
	return not v.firstPerson or CarCockpits.of(CameraViews.carId()) ~= nil
end

-- The view picked (the attribute), whether or not this car can use it.
function CameraViews.picked(): View
	local views = CameraViews.list()
	local id = Players.LocalPlayer:GetAttribute(ATTRIBUTE)
	for _, v in views do
		if v.id == id then
			return v
		end
	end
	return views[1]
end

-- The view in use: the one picked, or the first if this car cannot use it.
function CameraViews.current(): View
	local v = CameraViews.picked()
	return if CameraViews.usable(v) then v else CameraViews.list()[1]
end

-- The chase view the chase camera scales its profiles by: the view in use,
-- or the first while in first person.
function CameraViews.chase(): View
	local v = CameraViews.current()
	return if v.firstPerson then CameraViews.list()[1] else v
end

-- This view, from the menu's SETTINGS (its CAMERA row).
function CameraViews.set(id: string)
	Players.LocalPlayer:SetAttribute(ATTRIBUTE, id)
end

-- The next view this car can use, from V or the CAM button.
function CameraViews.cycle()
	local views = CameraViews.list()
	local i = table.find(views, CameraViews.current()) or 0
	for step = 1, #views do
		local v = views[(i + step - 1) % #views + 1]
		if CameraViews.usable(v) then
			Players.LocalPlayer:SetAttribute(ATTRIBUTE, v.id)
			return
		end
	end
end

return CameraViews
