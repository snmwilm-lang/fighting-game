--!strict
-- The fight HUD's textures (drawn by tools/hudart.py, the PNGs in docs/ui_art): Wilhem uploads
-- each one on Roblox (Creator Dashboard › Decals / Images) and gives its id. An id still 0 keeps the
-- HUD's drawn look (frames, strokes, gradients). Never an invented id.
-- Pure: no Roblox API, no require (the HUD builds the ImageLabels).
-- slice: the 9-slice centre in the PNG's pixels {left, top, right, bottom}; every PNG is drawn
-- at 2x. size: the PNG's size in pixels.
local UIArt = {}

UIArt.Images = {
	BarFrameLeft = { id = 105285466036643, file = "hud_bar_frame_left.png", size = { 1024, 96 }, slice = { 60, 20, 964, 76 } },
	BarFrameRight = { id = 118186509371016, file = "hud_bar_frame_right.png", size = { 1024, 96 }, slice = { 60, 20, 964, 76 } },
	TimerPlate = { id = 86141379572910, file = "hud_timer_plate.png", size = { 256, 256 } },
	KiPlateLeft = { id = 98110178479026, file = "hud_ki_plate_left.png", size = { 192, 128 } },
	KiPlateRight = { id = 130625196291397, file = "hud_ki_plate_right.png", size = { 192, 128 } },
	AnnounceBrush = { id = 116762484843122, file = "hud_announce_brush.png", size = { 2048, 384 } },
	PortraitFrame = { id = 79582148341008, file = "hud_portrait_frame.png", size = { 160, 160 } },
}

-- The asset string of an image, or nil while its id is 0 (the drawn look stays).
function UIArt.asset(name: string): string?
	local image = UIArt.Images[name]
	if image == nil or image.id == 0 then
		return nil
	end
	return "rbxassetid://" .. tostring(image.id)
end

return UIArt
