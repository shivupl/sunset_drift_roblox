--!strict
-- Which of CarConfig.camera.views the chase camera drives in (CameraRig),
-- held on the LocalPlayer attribute CamView (a view's id) so it lasts the
-- session through respawns. V on a keyboard and the CAM button on a phone
-- cycle it; HudLab shows the new view's name.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigLoader = require(Shared:WaitForChild("ConfigLoader"))

export type View = {
	id: string,
	name: string,
	distance: number,
	height: number,
	lookHeight: number,
	baseFov: number,
	maxFov: number,
}

local ATTRIBUTE = "CamView"

local CameraViews = {}

CameraViews.ATTRIBUTE = ATTRIBUTE

function CameraViews.list(): { View }
	return ConfigLoader.current().camera.views
end

function CameraViews.current(): View
	local views = CameraViews.list()
	local id = Players.LocalPlayer:GetAttribute(ATTRIBUTE)
	for _, v in views do
		if v.id == id then
			return v
		end
	end
	return views[1]
end

-- The next view, from V or the CAM button.
function CameraViews.cycle()
	local views = CameraViews.list()
	local i = table.find(views, CameraViews.current()) or 0
	Players.LocalPlayer:SetAttribute(ATTRIBUTE, views[i % #views + 1].id)
end

return CameraViews
