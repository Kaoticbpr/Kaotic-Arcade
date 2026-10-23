'*****************************************************************************************************
' RULES: switches, segments (modes), locks and multiball, the finale
'
'  Segment          Hot shot          Goal
'  1 UNBOXING       either ramp       5 ramps
'  2 FIRST FLIPS    orbits            5 orbits (either direction)
'  3 CHAT ATTACK    pop bumpers       25 hits
'  4 BUG HUNT       drop targets      6 targets
'  5 THE VERDICT    spinner           60 spins
'  The scoop starts the lit segment. Finish all five to light YO! RETRO LIVE at the scoop.
'  Drop target bank lights a lock at the scoop; the third lock starts Half-A-Dozen Multiball:
'  either ramp = jackpot, every 6th jackpot = super jackpot (6x).
'  Combo: the left ramp then the right ramp (or the other way) within 4 seconds.
'*****************************************************************************************************

Dim ModeGoals : ModeGoals = Array(0, 5, 5, 25, 6, 60)
Dim ModeValues : ModeValues = Array(0, 25000, 25000, 5000, 10000, 2000)
Const ModeCompleteAward = 100000
Const FinaleShotValue = 100000
Const ComboValue = 50000
Const ComboTicks = 40            ' 4 seconds

' Called by every playfield switch before it scores.
Sub Switch()
	StartBallSaveClock
	SkillShotActive = False
End Sub

'------------------------------------------------------------------------------------------------ top lanes

Sub TopLane1_Hit() : TopLaneHit 1 : End Sub
Sub TopLane2_Hit() : TopLaneHit 2 : End Sub
Sub TopLane3_Hit() : TopLaneHit 3 : End Sub

Sub TopLaneHit(n)
	If Not GameOn Then Exit Sub
	If SkillShotActive And n = SkillLane Then
		SkillShotActive = False
		AddScore 50000
		DMD_Message "YO! SKILL SHOT", "50,000", 1500
		PlaySound "fx_skillshot"
		Callout "skill_shot", True
	End If
	Switch
	AddScore 1000
	TopLane(n) = True
	If TopLane(1) And TopLane(2) And TopLane(3) Then
		TopLane(1) = False : TopLane(2) = False : TopLane(3) = False
		AddScore 25000
		If BonusX < 5 Then BonusX = BonusX + 1
		If ActiveMode = 0 And Not WizardLit Then ModeLit = True
		DMD_Message "BONUS X" & BonusX, "", 1500
		Callout "bonus_x", False
	End If
	UpdateLights
End Sub

' Flipper buttons move the lit lanes, or the skill shot lane until the ball hits its first switch.
Sub RotateLanes(direction)
	Dim t
	If SkillShotActive Then
		SkillLane = ((SkillLane - 1 + direction + 3) Mod 3) + 1
	ElseIf direction > 0 Then
		t = TopLane(3) : TopLane(3) = TopLane(2) : TopLane(2) = TopLane(1) : TopLane(1) = t
	Else
		t = TopLane(1) : TopLane(1) = TopLane(2) : TopLane(2) = TopLane(3) : TopLane(3) = t
	End If
	UpdateLights
End Sub

'------------------------------------------------------------------------------------------------ bumpers, slings, lanes

Sub Bumper1_Hit() : BumperHit Bumper1 : End Sub
Sub Bumper2_Hit() : BumperHit Bumper2 : End Sub
Sub Bumper3_Hit() : BumperHit Bumper3 : End Sub

Sub BumperHit(b)
	PlaySoundAt SoundFX("fx_bumper", DOFContactors), b
	If Not GameOn Then Exit Sub
	Switch
	AddScore 1000
	ModeProgress 3
	FinaleShot 0
End Sub

Sub LeftInlane_Hit() : LaneHit 1000 : End Sub
Sub RightInlane_Hit() : LaneHit 1000 : End Sub
Sub LeftOutlane_Hit() : LaneHit 5000 : End Sub
Sub RightOutlane_Hit() : LaneHit 5000 : End Sub

Sub LaneHit(points)
	If Not GameOn Then Exit Sub
	Switch
	AddScore points
	AddBonus 1000
End Sub

'------------------------------------------------------------------------------------------------ ramp and orbits

Sub RampEnter_Hit() : PlaySoundAtBall "fx_rampenter" : End Sub
Sub RightRampEnter_Hit() : PlaySoundAtBall "fx_rampenter" : End Sub
Sub RampMade_Hit() : RampShot 1 : End Sub
Sub RightRampMade_Hit() : RampShot 2 : End Sub

' side: 1 = left ramp, 2 = right ramp. Both ramps do the same jobs; alternating them is a combo.
Sub RampShot(side)
	If Not GameOn Then Exit Sub
	Switch
	If LastRampSide <> 0 And LastRampSide <> side And Ticks - LastRampTick <= ComboTicks Then
		AddScore ComboValue
		AddBonus 5000
		DMD_Message "COMBO!", FormatScore(ComboValue), 1500
		FlashLights 6
		Callout "combo", True
		LastRampSide = 0
	Else
		LastRampSide = side
	End If
	LastRampTick = Ticks
	RampsThisBall = RampsThisBall + 1
	AddScore 10000
	AddBonus 2000
	If Multiball And Not WizardRunning Then
		JackpotCount = JackpotCount + 1
		If JackpotCount Mod 6 = 0 Then
			AddScore JackpotValue * 6
			DMD_Message "HALF-A-DOZEN!", "SUPER JACKPOT " & FormatScore(JackpotValue * 6), 3000
			Callout "half_a_dozen", True
		Else
			AddScore JackpotValue
			DMD_Message "JACKPOT", FormatScore(JackpotValue) & "  (" & (6 - JackpotCount Mod 6) & " TO SUPER)", 2000
			Callout "jackpot", True
		End If
		JackpotValue = JackpotValue + 25000
		PlaySound "fx_jackpot"
		FlashLights 8
	Else
		Callout "ramp", False
	End If
	If RampsThisBall = ExtraBallRamps And Not ExtraBallUsed(CurPlayer) Then
		ExtraBallLit = True
		DMD_Message "EXTRA BALL", "IS LIT", 1500
		Callout "extra_ball_lit", True
	End If
	ModeProgress 1
	FinaleShot FinaleShotValue
	UpdateLights
End Sub

Sub LeftOrbit_Hit() : OrbitHit LastLeftOrbitTick, LastRightOrbitTick : End Sub
Sub RightOrbit_Hit() : OrbitHit LastRightOrbitTick, LastLeftOrbitTick : End Sub

' An orbit counts when the ball crosses both orbit switches within two seconds.
Sub OrbitHit(ByRef thisSide, otherSide)
	If Not GameOn Then Exit Sub
	Switch
	thisSide = Ticks
	If Ticks - otherSide <= 20 Then
		LastLeftOrbitTick = -100 : LastRightOrbitTick = -100
		AddScore 15000
		AddBonus 1000
		DMD_Message "ORBIT", "15,000", 1000
		Callout "orbit", False
		ModeProgress 2
		FinaleShot FinaleShotValue
	Else
		AddScore 500
	End If
End Sub

Sub Spinner_Spin()
	PlaySoundAt "fx_spinner", Spinner
	If Not GameOn Then Exit Sub
	Switch
	AddScore 100
	ModeProgress 5
End Sub

'------------------------------------------------------------------------------------------------ targets

Sub Drop1_Hit() : DropHit 1 : End Sub
Sub Drop2_Hit() : DropHit 2 : End Sub
Sub Drop3_Hit() : DropHit 3 : End Sub

Sub DropHit(n)
	PlaySoundAtBall SoundFX("fx_droptarget", DOFContactors)
	If Not GameOn Then Exit Sub
	If DropDown(n) Then Exit Sub
	Switch
	DropDown(n) = True
	AddScore 2500
	ModeProgress 4
	FinaleShot 0
	If DropDown(1) And DropDown(2) And DropDown(3) Then
		AddScore 10000
		If Not Multiball Then
			LockLit = True
			DMD_Message "LOCK IS LIT", "SHOOT THE SCOOP", 1500
			Callout "lock_lit", True
		End If
		DropResetTimer.Enabled = True
	End If
	UpdateLights
End Sub

Sub ResetDrops()
	Dim i
	For i = 1 To 3 : DropDown(i) = False : Next
	Drop1.IsDropped = False : Drop2.IsDropped = False : Drop3.IsDropped = False
End Sub

Sub DropResetTimer_Timer()
	DropResetTimer.Enabled = False
	ResetDrops
	PlaySoundAt SoundFX("fx_resetdrop", DOFContactors), Drop2
End Sub

Sub Standup1_Hit() : StandupHit 1 : End Sub
Sub Standup2_Hit() : StandupHit 2 : End Sub

Sub StandupHit(n)
	PlaySoundAtBall "fx_target"
	If Not GameOn Then Exit Sub
	Switch
	AddScore 2500
	StandupLit(n) = True
	If StandupLit(1) And StandupLit(2) Then
		StandupLit(1) = False : StandupLit(2) = False
		If ActiveMode > 0 Then
			ModeTicksLeft = ModeTicksLeft + 100
			DMD_Message "+10 SECONDS", SegmentNames(ActiveMode), 1200
			Callout "more_time", True
		Else
			AddScore 15000
			DMD_Message "TARGETS", "15,000", 1000
		End If
	End If
End Sub

'------------------------------------------------------------------------------------------------ scoop

Sub Scoop_Hit()
	PlaySoundAt "fx_kicker_enter", Scoop
	If Not GameOn Or Tilted Then ScoopTimer.Enabled = True : Exit Sub
	Switch
	AddScore 5000
	If ExtraBallLit Then
		ExtraBallLit = False
		ExtraBallUsed(CurPlayer) = True
		ShootAgain = True
		DMD_Message "EXTRA BALL", "", 2000
		PlaySound "fx_extraball"
		Callout "extra_ball", True
	End If
	If WizardLit And Not Multiball Then
		StartFinale
	ElseIf LockLit Then
		LockBall
	ElseIf ModeLit And ActiveMode = 0 And Not WizardRunning Then
		StartMode
	End If
	UpdateLights
	ScoopTimer.Enabled = True
End Sub

Sub ScoopTimer_Timer()
	ScoopTimer.Enabled = False
	Scoop.Kick ScoopKickAngle, ScoopKickSpeed
	PlaySoundAt SoundFX("fx_kicker", DOFContactors), Scoop
End Sub

'------------------------------------------------------------------------------------------------ segments

Function NextMode()
	Dim m
	NextMode = 0
	For m = 1 To 5
		If Not ModeDone(CurPlayer, m) Then NextMode = m : Exit Function
	Next
End Function

Function AllModesDone()
	AllModesDone = (NextMode() = 0)
End Function

Sub StartMode()
	ActiveMode = NextMode()
	If ActiveMode = 0 Then Exit Sub
	ModeLit = False
	ModeHits = 0
	ModeGoal = ModeGoals(ActiveMode)
	ModeValue = ModeValues(ActiveMode)
	ModeTicksLeft = ModeSeconds * 10
	DMD_Message SegmentNames(ActiveMode), SegmentHints(ActiveMode), 2500
	PlaySound "fx_modestart"
	Callout "segment_" & ActiveMode, True
End Sub

Sub ModeProgress(shot)
	If ActiveMode <> shot Then Exit Sub
	ModeHits = ModeHits + 1
	AddScore ModeValue
	If ModeHits >= ModeGoal Then
		EndMode True
	ElseIf shot <> 3 And shot <> 5 Then
		DMD_Message SegmentNames(ActiveMode), (ModeGoal - ModeHits) & " MORE", 1000
	End If
End Sub

Sub EndMode(completed)
	Dim m
	m = ActiveMode
	ActiveMode = 0
	If m = 0 Then Exit Sub
	If completed Then
		ModeDone(CurPlayer, m) = True
		AddScore ModeCompleteAward
		AddBonus 10000
		DMD_Message SegmentNames(m), "COMPLETE", 2500
		PlaySound "fx_modecomplete"
		FlashLights 10
		Callout "segment_done", True
		If AllModesDone() Then
			WizardLit = True
			DMD_Message WizardName, "IS LIT", 2500
			Callout "finale_lit", True
		End If
	Else
		DMD_Message SegmentNames(m), "OVER", 1500
		Callout "segment_over", False
	End If
	UpdateLights
	DMD_Refresh
End Sub

'------------------------------------------------------------------------------------------------ locks and multiball

Sub LockBall()
	LockLit = False
	Locks(CurPlayer) = Locks(CurPlayer) + 1
	If Locks(CurPlayer) >= LocksForMultiball Then
		Locks(CurPlayer) = 0
		StartMultiball LocksForMultiball - 1
		DMD_Message MultiballName, "MULTIBALL - HIT RAMPS", 2500
		Callout "multiball", True
	Else
		DMD_Message "BALL " & Locks(CurPlayer) & " LOCKED", "", 1500
		PlaySound "fx_lock"
		Callout "lock", True
	End If
End Sub

Sub StartMultiball(extraBalls)
	Multiball = True
	JackpotValue = 100000
	JackpotCount = 0
	GiveBallSave MultiballSaveSeconds
	LaunchBalls extraBalls
	PlaySound "fx_multiball"
	FlashLights 16
	UpdateLights
End Sub

Sub EndMultiball()
	Dim m
	Multiball = False
	If WizardRunning Then
		WizardRunning = False
		WizardLit = False
		For m = 1 To 5 : ModeDone(CurPlayer, m) = False : Next
		ModeLit = True
		DMD_Message WizardName, "TOTAL " & FormatScore(Score(CurPlayer)), 2500
		Callout "finale_end", True
	End If
	UpdateLights
End Sub

Sub StartFinale()
	WizardLit = False
	WizardRunning = True
	ModeLit = False
	DMD_Message WizardName, "EVERY SHOT 100,000", 3000
	Callout "finale", True
	StartMultiball 2
End Sub

' During the finale the ramp and orbits score big; everything else scores a little extra.
Sub FinaleShot(value)
	If Not WizardRunning Then Exit Sub
	If value > 0 Then
		AddScore value
		DMD_Message WizardName, FormatScore(value), 800
	Else
		AddScore 5000
	End If
End Sub

'------------------------------------------------------------------------------------------------ lights

Sub SetLight(l, lit, blinking)
	If Not lit Then
		l.State = 0
	ElseIf blinking Then
		l.State = 2
	Else
		l.State = 1
	End If
End Sub

Sub UpdateLights()
	If ShowFlashLeft > 0 Then Exit Sub
	If Not GameOn Or Tilted Then AllLightsOff : Exit Sub
	SetLight TopLaneLight1, TopLane(1) Or (SkillShotActive And SkillLane = 1), SkillShotActive
	SetLight TopLaneLight2, TopLane(2) Or (SkillShotActive And SkillLane = 2), SkillShotActive
	SetLight TopLaneLight3, TopLane(3) Or (SkillShotActive And SkillLane = 3), SkillShotActive
	SetLight ModeLight1, ModeDone(CurPlayer, 1) Or ActiveMode = 1, ActiveMode = 1
	SetLight ModeLight2, ModeDone(CurPlayer, 2) Or ActiveMode = 2, ActiveMode = 2
	SetLight ModeLight3, ModeDone(CurPlayer, 3) Or ActiveMode = 3, ActiveMode = 3
	SetLight ModeLight4, ModeDone(CurPlayer, 4) Or ActiveMode = 4, ActiveMode = 4
	SetLight ModeLight5, ModeDone(CurPlayer, 5) Or ActiveMode = 5, ActiveMode = 5
	SetLight ScoopLight, WizardLit Or LockLit Or (ModeLit And ActiveMode = 0) Or ExtraBallLit, True
	SetLight LockLight, LockLit, True
	SetLight ExtraBallLight, ExtraBallLit, True
	SetLight RampArrow, Multiball Or ActiveMode = 1 Or WizardRunning, True
	SetLight RightRampArrow, Multiball Or ActiveMode = 1 Or WizardRunning, True
	SetLight LeftOrbitArrow, ActiveMode = 2 Or WizardRunning, True
	SetLight RightOrbitArrow, ActiveMode = 2 Or WizardRunning, True
	SetLight ShootAgainLight, ShootAgain Or BallSaveActive, BallSaveActive
	SetLight BonusXLight2, BonusX >= 2, False
	SetLight BonusXLight3, BonusX >= 3, False
	SetLight BonusXLight4, BonusX >= 4, False
	SetLight BonusXLight5, BonusX >= 5, False
End Sub

Sub AllLightsOff()
	Dim l
	For Each l In Array(TopLaneLight1, TopLaneLight2, TopLaneLight3, ModeLight1, ModeLight2, ModeLight3, _
			ModeLight4, ModeLight5, ScoopLight, LockLight, ExtraBallLight, RampArrow, RightRampArrow, LeftOrbitArrow, _
			RightOrbitArrow, ShootAgainLight, BonusXLight2, BonusXLight3, BonusXLight4, BonusXLight5)
		l.State = 0
	Next
End Sub
