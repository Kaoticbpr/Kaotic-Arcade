'*****************************************************************************************************
' LIGHT SHOWS: the attract show between games, and quick full-table flashes on the big moments
'
' LightShowTimer (100 ms) runs the attract show while no game is on. During a game it only runs to
' flash every insert for a moment (FlashLights); UpdateLights waits until the flash is over.
'*****************************************************************************************************

Dim ShowLights, ShowStep, ShowFlashLeft

' Every insert, from the bottom of the playfield to the top, so a sweep runs up the table.
Sub InitLightShow()
	ShowLights = Array(ShootAgainLight, BonusXLight2, BonusXLight3, BonusXLight4, BonusXLight5, _
		RightOrbitArrow, RampArrow, RightRampArrow, ExtraBallLight, LeftOrbitArrow, LockLight, _
		ModeLight1, ModeLight5, ModeLight2, ModeLight4, ModeLight3, ScoopLight, _
		TopLaneLight1, TopLaneLight2, TopLaneLight3)
	ShowStep = 0
	ShowFlashLeft = 0
End Sub

Sub StartLightShow()
	ShowStep = 0
	LightShowTimer.Enabled = True
End Sub

' ticks: how many 100 ms steps to flash for (the lights toggle every step).
Sub FlashLights(ticks)
	ShowFlashLeft = ticks
	LightShowTimer.Enabled = True
End Sub

Sub LightShowTimer_Timer()
	Dim i, n, lit
	n = UBound(ShowLights) + 1
	If ShowFlashLeft > 0 Then
		ShowFlashLeft = ShowFlashLeft - 1
		lit = (ShowFlashLeft Mod 2 = 1)
		For i = 0 To n - 1 : ShowLights(i).State = Abs(lit) : Next
		' After a flash in a game, hand the lights back to the rules; between games the attract show goes on.
		If ShowFlashLeft = 0 And GameOn Then
			LightShowTimer.Enabled = False
			UpdateLights
		End If
		Exit Sub
	End If
	If GameOn Then LightShowTimer.Enabled = False : Exit Sub

	' Attract: three patterns, about 6 seconds each.
	ShowStep = ShowStep + 1
	Select Case (ShowStep \ 60) Mod 3
		Case 0      ' a band of three lights sweeping up the table
			For i = 0 To n - 1 : ShowLights(i).State = Abs(((ShowStep - i) Mod n + n) Mod n < 3) : Next
		Case 1      ' everything blinking together
			For i = 0 To n - 1 : ShowLights(i).State = Abs((ShowStep \ 3) Mod 2 = 0) : Next
		Case 2      ' sparkle
			For i = 0 To n - 1 : ShowLights(i).State = Abs(Rnd < 0.25) : Next
	End Select
End Sub
