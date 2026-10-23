Option Explicit
Randomize

'*****************************************************************************************************
' YO! RETRO - an original table by KaoticBPR, hosted by KaoticBPR and Half-A-Dozen, version @@VERSION@@
'
' This script is generated: edit the files in tables/yo-retro/script/ and run tools/build.py.
'
' Built on the Visual Pinball X starter table by fuzzel, jimmyfingers, jpsalas, toxie & unclewilly,
' flipper primitives by zany, ball shadow by ninuzzu, positional sound helpers by djrobx.
'*****************************************************************************************************

' ---- Show text: everything the player reads lives here so the theme is one edit away ----------------
' Big DMD text fits about 16 characters, the small lines about 21.
Const cGameName = "yoretro"               ' also the key for saved high scores
Const ShowName = "YO! RETRO"
Const ShowTagline = "EVERY THURSDAY"
' The five segments of an episode, in the order they're played (shots: see 20_rules.vbs)
Dim SegmentNames : SegmentNames = Array("", "UNBOXING", "FIRST FLIPS", "CHAT ATTACK", "BUG HUNT", "THE VERDICT")
Dim SegmentHints : SegmentHints = Array("", "RAMPS RIP IT OPEN", "SHOOT THE ORBITS", "HIT THE POP BUMPERS", "SQUASH 6 DROP TARGETS", "SPIN TO RATE IT")
Const WizardName = "YO! RETRO LIVE"
Const MultiballName = "HALF-A-DOZEN"     ' "HALF-A-DOZEN MULTIBALL": every 6th jackpot is a super jackpot

' ---- Game settings -----------------------------------------------------------------------------------
Const MaxPlayers = 4
Const BallsPerGame = 3
Const BallSaveSeconds = 10
Const MultiballSaveSeconds = 15
Const ModeSeconds = 40
Const ExtraBallRamps = 5          ' ramps in one ball that light the extra ball
Const LocksForMultiball = 3
Const AutoKickSpeed = 45          ' tune on the cabinet if auto-launched balls fall short or overshoot
Const ScoopKickAngle = 190
Const ScoopKickSpeed = 9
Const VoiceVolume = 1.0
Const MusicVolume = 0.5           ' theme song under the gameplay

' ---- FlexDMD constants -------------------------------------------------------------------------------
Const FlexDMD_RenderMode_DMD_RGB = 2
Const FlexDMD_Align_TopLeft = 0, FlexDMD_Align_Top = 1, FlexDMD_Align_TopRight = 2
Const FlexDMD_Align_Center = 4
Const FlexDMD_Align_BottomLeft = 6, FlexDMD_Align_Bottom = 7, FlexDMD_Align_BottomRight = 8

' ---- Game state --------------------------------------------------------------------------------------
Dim GameOn, Tilted, NumPlayers, CurPlayer, BallNum
Dim Score(4), Locks(4), ExtraBallUsed(4), ModeDone(4, 5)
Dim BallsOnPF, BallsToLaunch, ShootAgain
Dim BallSaveActive, BallSaveStarted
Dim Bonus, BonusX, TiltWarn, TiltSens
Dim HighScore, Ticks

' Per-ball state
Dim TopLane(3), SkillLane, SkillShotActive
Dim DropDown(3), StandupLit(2)
Dim RampsThisBall, ExtraBallLit, LockLit, ModeLit, WizardLit
Dim ActiveMode, ModeTicksLeft, ModeHits, ModeGoal, ModeValue
Dim Multiball, WizardRunning, JackpotValue, JackpotCount
Dim LastLeftOrbitTick, LastRightOrbitTick
