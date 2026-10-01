-- Keyboard/gamepad bindings per logical action. Mouse buttons are listed separately because
-- they are UserInputTypes, not KeyCodes. Q and Z cover AZERTY keyboards.
return {
	Left = { Enum.KeyCode.A, Enum.KeyCode.Q, Enum.KeyCode.Left, Enum.KeyCode.DPadLeft },
	Right = { Enum.KeyCode.D, Enum.KeyCode.Right, Enum.KeyCode.DPadRight },
	Jump = { Enum.KeyCode.Space, Enum.KeyCode.W, Enum.KeyCode.Z, Enum.KeyCode.Up, Enum.KeyCode.DPadUp, Enum.KeyCode.ButtonA },
	Crouch = { Enum.KeyCode.S, Enum.KeyCode.Down, Enum.KeyCode.DPadDown },
	Dash = { Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.ButtonR2 },
	Block = { Enum.KeyCode.F, Enum.KeyCode.I, Enum.KeyCode.ButtonR1 },
	Light = { Enum.KeyCode.J, Enum.KeyCode.ButtonX },
	Heavy = { Enum.KeyCode.K, Enum.KeyCode.L, Enum.KeyCode.ButtonB },
	Reset = { Enum.KeyCode.R, Enum.KeyCode.ButtonSelect },
	Mouse = {
		Light = Enum.UserInputType.MouseButton1,
		Heavy = Enum.UserInputType.MouseButton2,
	},
	Deadzone = 0.18,
}
