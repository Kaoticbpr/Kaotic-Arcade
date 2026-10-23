'*****************************************************************************************************
' PHYSICS AND SOUND HELPERS (from the VPX starter table)
'*****************************************************************************************************

'---------------------------------------------------------------- slingshot animations
Dim RStep, LStep

Sub RightSlingShot_Slingshot()
	PlaySoundAt SoundFX("right_slingshot", DOFContactors), Sling1
	RSling.Visible = 0
	RSling1.Visible = 1
	Sling1.RotX = 20
	RStep = 0
	RightSlingShot.TimerEnabled = 1
	gi1.State = 0 : gi2.State = 0
	If GameOn Then Switch : AddScore 110
End Sub

Sub RightSlingShot_Timer()
	Select Case RStep
		Case 3 : RSling1.Visible = 0 : RSling2.Visible = 1 : Sling1.RotX = 10
		Case 4 : RSling2.Visible = 0 : RSling.Visible = 1 : Sling1.RotX = 0 : RightSlingShot.TimerEnabled = 0 : gi1.State = 1 : gi2.State = 1
	End Select
	RStep = RStep + 1
End Sub

Sub LeftSlingShot_Slingshot()
	PlaySoundAt SoundFX("left_slingshot", DOFContactors), Sling2
	LSling.Visible = 0
	LSling1.Visible = 1
	Sling2.RotX = 20
	LStep = 0
	LeftSlingShot.TimerEnabled = 1
	gi3.State = 0 : gi4.State = 0
	If GameOn Then Switch : AddScore 110
End Sub

Sub LeftSlingShot_Timer()
	Select Case LStep
		Case 3 : LSling1.Visible = 0 : LSling2.Visible = 1 : Sling2.RotX = 10
		Case 4 : LSling2.Visible = 0 : LSling.Visible = 1 : Sling2.RotX = 0 : LeftSlingShot.TimerEnabled = 0 : gi3.State = 1 : gi4.State = 1
	End Select
	LStep = LStep + 1
End Sub

'---------------------------------------------------------------- positional sound
' Missing sound names are silent, so these calls are safe before the sound pack exists.

Sub PlaySoundAt(soundname, tableobj)
	PlaySound soundname, 1, 1, AudioPan(tableobj), 0, 0, 0, 1, AudioFade(tableobj)
End Sub

Sub PlaySoundAtBall(soundname)
	PlaySoundAt soundname, ActiveBall
End Sub

Function AudioFade(tableobj)
	Dim tmp
	tmp = tableobj.y * 2 / Table1.Height - 1
	If tmp > 0 Then AudioFade = CSng(tmp ^ 10) Else AudioFade = CSng(-((-tmp) ^ 10))
End Function

Function AudioPan(tableobj)
	Dim tmp
	tmp = tableobj.x * 2 / Table1.Width - 1
	If tmp > 0 Then AudioPan = CSng(tmp ^ 10) Else AudioPan = CSng(-((-tmp) ^ 10))
End Function

Sub LeftFlipper_Collide(parm) : PlaySound "flip_hit_" & Int(Rnd * 3) + 1, 0, parm / 10, -0.1, 0.15 : End Sub
Sub RightFlipper_Collide(parm) : PlaySound "flip_hit_" & Int(Rnd * 3) + 1, 0, parm / 10, 0.1, 0.15 : End Sub
