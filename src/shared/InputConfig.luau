-- Keyboard/gamepad bindings per logical action. Mouse buttons are listed separately because
-- they are UserInputTypes, not KeyCodes. Q and Z cover AZERTY keyboards.
-- Key codes that may not exist on every engine version are looked up safely.
local function codes(...)
	local list = {}
	for _, name in { ... } do
		local ok, code = pcall(function() return Enum.KeyCode[name] end)
		if ok and code then table.insert(list, code) end
	end
	return list
end
return {
	Left = { Enum.KeyCode.A, Enum.KeyCode.Q, Enum.KeyCode.Left, Enum.KeyCode.DPadLeft },
	Right = { Enum.KeyCode.D, Enum.KeyCode.Right, Enum.KeyCode.DPadRight },
	Jump = { Enum.KeyCode.Space, Enum.KeyCode.W, Enum.KeyCode.Z, Enum.KeyCode.Up, Enum.KeyCode.DPadUp, Enum.KeyCode.ButtonA },
	Crouch = { Enum.KeyCode.S, Enum.KeyCode.Down, Enum.KeyCode.DPadDown },
	Dash = { Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.ButtonR2 },
	Block = { Enum.KeyCode.F, Enum.KeyCode.I, Enum.KeyCode.ButtonR1 },
	Light = { Enum.KeyCode.J, Enum.KeyCode.ButtonX },
	Heavy = { Enum.KeyCode.K, Enum.KeyCode.L, Enum.KeyCode.ButtonB },
	Special = { Enum.KeyCode.E, Enum.KeyCode.U, Enum.KeyCode.ButtonY },
	Ultimate = { Enum.KeyCode.R, Enum.KeyCode.O, Enum.KeyCode.ButtonL2 },
	Reset = { Enum.KeyCode.Backspace, Enum.KeyCode.ButtonSelect },
	Dummy = { Enum.KeyCode.M },
	Kit = { Enum.KeyCode.T }, -- next fighter (kit)
	FoeKit = { Enum.KeyCode.G }, -- the CPU's fighter (solo)
	-- TARO's styles: 1 / & = BOXEUR CLASSIQUE, 2 / é = BOXEUR ESQUIVE (AZERTY: World73 is é).
	Stance1 = codes("One", "KeypadOne", "Ampersand"),
	Stance2 = codes("Two", "KeypadTwo", "World73"),
	Mouse = {
		Light = Enum.UserInputType.MouseButton1,
		Heavy = Enum.UserInputType.MouseButton2,
	},
	Deadzone = 0.18,
}
