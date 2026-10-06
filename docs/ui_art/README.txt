Fight HUD textures (BREAKFRAMEZ). Drawn by tools/hudart.py (python3 tools/hudart.py docs/ui_art).
Upload each PNG on Roblox (Creator Dashboard > Development Items > Decals), then put its id in
src/shared/UIArt.luau. While an id is 0 the HUD keeps its drawn look.

All PNGs are drawn at 2x. Slice margins (9-slice, in the PNG's pixels):
  hud_bar_frame_left.png   1024x96   SliceCenter 60,20 - 964,76   -> UIArt.BarFrameLeft
  hud_bar_frame_right.png  1024x96   SliceCenter 60,20 - 964,76   -> UIArt.BarFrameRight
  hud_timer_plate.png       256x256  stretched                    -> UIArt.TimerPlate
  hud_ki_plate_left.png     192x128  stretched, tinted per fighter -> UIArt.KiPlateLeft
  hud_ki_plate_right.png    192x128  stretched, tinted per fighter -> UIArt.KiPlateRight
  hud_announce_brush.png   2048x384  stretched                    -> UIArt.AnnounceBrush
  hud_portrait_frame.png    160x160  stretched, tinted per fighter -> UIArt.PortraitFrame
sheet.png: all of them on grey, to look at (not uploaded).
