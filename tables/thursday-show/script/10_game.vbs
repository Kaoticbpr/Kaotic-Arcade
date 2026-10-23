'*****************************************************************************************************
' GAME FLOW: start, balls, ball save, multiball launching, tilt, bonus, high score
'*****************************************************************************************************

Sub Table1_Init()
	Dim xx
	For Each xx In GI : xx.State = 1 : Next
	HighScore = LoadHighScore()
	GameOn = False
	BallsOnPF = 0
	BallsToLaunch = 0
	DMD_Setup
	AllLightsOff
	StartAttract
	GameTimer.Enabled = True
End Sub

Sub Table1_Exit()
	DMD_Close
End Sub

Sub Table1_KeyDown(ByVal keycode)
	If keycode = StartGameKey Then
		If Not GameOn Then
			StartGame
		ElseIf BallNum = 1 And NumPlayers < MaxPlayers And Not Tilted Then
			NumPlayers = NumPlayers + 1
			DMD_Message "PLAYER " & NumPlayers, "ADDED", 1500
			PlaySound "fx_start"
		End If
	End If

	If keycode = PlungerKey Then
		Plunger.PullBack
		PlaySoundAt "plungerpull", Plunger
	End If

	If keycode = LeftFlipperKey Then
		If GameOn And Not Tilted Then
			LeftFlipper.RotateToEnd
			PlaySoundAt SoundFX("fx_flipperup", DOFFlippers), LeftFlipper
			RotateLanes -1
		End If
	End If

	If keycode = RightFlipperKey Then
		If GameOn And Not Tilted Then
			RightFlipper.RotateToEnd
			PlaySoundAt SoundFX("fx_flipperup", DOFFlippers), RightFlipper
			RotateLanes 1
		End If
	End If

	If keycode = LeftTiltKey Then Nudge 90, 2 : AddTilt 1
	If keycode = RightTiltKey Then Nudge 270, 2 : AddTilt 1
	If keycode = CenterTiltKey Then Nudge 0, 2 : AddTilt 1
	If keycode = MechanicalTilt Then TiltWarning
End Sub

Sub Table1_KeyUp(ByVal keycode)
	If keycode = PlungerKey Then
		Plunger.Fire
		PlaySoundAt "plunger", Plunger
	End If

	If keycode = LeftFlipperKey Then
		LeftFlipper.RotateToStart
		If GameOn And Not Tilted Then PlaySoundAt SoundFX("fx_flipperdown", DOFFlippers), LeftFlipper
	End If

	If keycode = RightFlipperKey Then
		RightFlipper.RotateToStart
		If GameOn And Not Tilted Then PlaySoundAt SoundFX("fx_flipperdown", DOFFlippers), RightFlipper
	End If
End Sub

' DOF is not used on the 4KP, but the starter table's sound calls expect these.
Const DOFFlippers = 101, DOFContactors = 102
Function SoundFX(name, dof) : SoundFX = name : End Function

'------------------------------------------------------------------------------------------------ game

Sub StartGame()
	Dim p, m
	GameOn = True
	NumPlayers = 1
	CurPlayer = 1
	BallNum = 1
	ShootAgain = False
	For p = 1 To MaxPlayers
		Score(p) = 0
		Locks(p) = 0
		ExtraBallUsed(p) = False
		For m = 1 To 5 : ModeDone(p, m) = False : Next
	Next
	StopAttract
	PlaySound "fx_start"
	StartBall
End Sub

Sub StartBall()
	Dim i
	Tilted = False
	TiltWarn = 0
	TiltSens = 0
	SetTiltPhysics True
	Bonus = 0
	BonusX = 1
	RampsThisBall = 0
	ExtraBallLit = False
	LockLit = False
	WizardLit = AllModesDone()
	ModeLit = Not WizardLit
	ActiveMode = 0
	Multiball = False
	WizardRunning = False
	JackpotValue = 100000
	LastLeftOrbitTick = -100
	LastRightOrbitTick = -100
	For i = 1 To 3 : TopLane(i) = False : Next
	For i = 1 To 2 : StandupLit(i) = False : Next
	ResetDrops
	SkillLane = 2
	SkillShotActive = True
	BallSaveActive = True
	BallSaveStarted = False
	BallSaveTimer.Interval = BallSaveSeconds * 1000
	TiltDecayTimer.Enabled = True
	UpdateLights
	DMD_Message "PLAYER " & CurPlayer, "BALL " & BallNum, 1500
	ServeBall
End Sub

' Player ball: drops into the shooter lane for the player to plunge.
Sub ServeBall()
	BallRelease.CreateBall
	BallRelease.Kick 90, 7
	BallsOnPF = BallsOnPF + 1
	PlaySoundAt SoundFX("ballrelease", DOFContactors), BallRelease
End Sub

' Extra balls (multiball, ball save) are launched automatically from the shooter lane.
Sub LaunchBalls(n)
	BallsToLaunch = BallsToLaunch + n
	AutoLaunchTimer.Enabled = True
End Sub

Sub AutoLaunchTimer_Timer()
	If BallsToLaunch <= 0 Then AutoLaunchTimer.Enabled = False : Exit Sub
	BallsToLaunch = BallsToLaunch - 1
	AutoKick.Enabled = True
	AutoKick.CreateBall
	AutoKick.Kick 0, AutoKickSpeed
	AutoKick.Enabled = False
	BallsOnPF = BallsOnPF + 1
	PlaySoundAt "plunger", Plunger
End Sub

' The ball save clock starts on the first scoring switch, not while the ball sits in the shooter lane.
Sub StartBallSaveClock()
	If BallSaveActive And Not BallSaveStarted Then
		BallSaveStarted = True
		BallSaveTimer.Enabled = False
		BallSaveTimer.Enabled = True
		UpdateLights
	End If
End Sub

Sub BallSaveTimer_Timer()
	BallSaveTimer.Enabled = False
	BallSaveActive = False
	UpdateLights
End Sub

Sub GiveBallSave(seconds)
	BallSaveActive = True
	BallSaveStarted = True
	BallSaveTimer.Enabled = False
	BallSaveTimer.Interval = seconds * 1000
	BallSaveTimer.Enabled = True
	UpdateLights
End Sub

Sub Drain_Hit()
	Drain.DestroyBall
	BallsOnPF = BallsOnPF - 1
	PlaySoundAt "drain", Drain
	If Not GameOn Then Exit Sub

	If Tilted Then
		If BallsOnPF <= 0 And BallsToLaunch = 0 Then EndOfBall
		Exit Sub
	End If

	If BallSaveActive Then
		DMD_Message "BALL SAVED", "", 1500
		If Not Multiball Then BallSaveActive = False : BallSaveTimer.Enabled = False
		LaunchBalls 1
		UpdateLights
		Exit Sub
	End If

	If Multiball And BallsOnPF + BallsToLaunch <= 1 Then EndMultiball
	If BallsOnPF <= 0 And BallsToLaunch = 0 Then EndOfBall
End Sub

Sub EndOfBall()
	Dim total
	LeftFlipper.RotateToStart
	RightFlipper.RotateToStart
	If ActiveMode > 0 Then EndMode False
	TiltDecayTimer.Enabled = False
	If Tilted Then
		DMD_Message "TILT", "NO BONUS", 2500
	Else
		total = Bonus * BonusX
		Score(CurPlayer) = Score(CurPlayer) + total
		DMD_Message "BONUS " & FormatScore(Bonus) & " X" & BonusX, FormatScore(total), 2500
	End If
	EndBallTimer.Enabled = True
End Sub

Sub EndBallTimer_Timer()
	EndBallTimer.Enabled = False
	If ShootAgain Then
		ShootAgain = False
		DMD_Message "SHOOT AGAIN", "", 1500
		StartBall
		Exit Sub
	End If
	CurPlayer = CurPlayer + 1
	If CurPlayer > NumPlayers Then
		CurPlayer = 1
		BallNum = BallNum + 1
	End If
	If BallNum > BallsPerGame Then
		GameOver
	Else
		StartBall
	End If
End Sub

Sub GameOver()
	Dim p, best
	GameOn = False
	best = 0
	For p = 1 To NumPlayers
		If Score(p) > Score(best) Or best = 0 Then best = p
	Next
	AllLightsOff
	If Score(best) > HighScore Then
		HighScore = Score(best)
		SaveHighScore HighScore
		DMD_Message "NEW HIGH SCORE", FormatScore(HighScore), 4000
	Else
		DMD_Message "GAME OVER", "", 3000
	End If
	StartAttract
End Sub

'------------------------------------------------------------------------------------------------ scoring

Sub AddScore(points)
	If Not GameOn Or Tilted Then Exit Sub
	Score(CurPlayer) = Score(CurPlayer) + points
	DMD_Refresh
End Sub

Sub AddBonus(points)
	If Not GameOn Or Tilted Then Exit Sub
	Bonus = Bonus + points
End Sub

Function FormatScore(n)
	FormatScore = FormatNumber(n, 0, -1, 0, -1)
End Function

Function LoadHighScore()
	Dim v
	v = LoadValue(cGameName, "HighScore")
	If v = "" Then LoadHighScore = 1000000 Else LoadHighScore = CDbl(v)
End Function

Sub SaveHighScore(n)
	SaveValue cGameName, "HighScore", n
End Sub

'------------------------------------------------------------------------------------------------ tilt

Sub AddTilt(amount)
	If Not GameOn Or Tilted Then Exit Sub
	TiltSens = TiltSens + amount
	If TiltSens >= 4 Then
		TiltSens = 0
		TiltWarning
	End If
End Sub

Sub TiltDecayTimer_Timer()
	If TiltSens > 0 Then TiltSens = TiltSens - 1
End Sub

Sub TiltWarning()
	If Not GameOn Or Tilted Then Exit Sub
	TiltWarn = TiltWarn + 1
	If TiltWarn >= 3 Then
		Tilt
	Else
		DMD_Message "DANGER", "WARNING " & TiltWarn, 1500
		PlaySound "fx_warning"
	End If
End Sub

Sub Tilt()
	Tilted = True
	BallSaveActive = False
	LeftFlipper.RotateToStart
	RightFlipper.RotateToStart
	SetTiltPhysics False
	AllLightsOff
	DMD_Message "TILT", "", 3000
	PlaySound "fx_tilt"
End Sub

' Bumpers and slings go dead while tilted.
Sub SetTiltPhysics(alive)
	Dim f, s
	If alive Then f = 12 : s = 40 Else f = 0 : s = 0
	Bumper1.Force = f : Bumper2.Force = f : Bumper3.Force = f
	LeftSlingShot.SlingshotStrength = s
	RightSlingShot.SlingshotStrength = s
End Sub

'------------------------------------------------------------------------------------------------ timing

' 10 ticks a second: mode clock and orbit combos.
Sub GameTimer_Timer()
	Ticks = Ticks + 1
	If GameOn And ActiveMode > 0 And Not Tilted Then
		ModeTicksLeft = ModeTicksLeft - 1
		If ModeTicksLeft Mod 10 = 0 Then DMD_Refresh
		If ModeTicksLeft <= 0 Then EndMode False
	End If
End Sub
