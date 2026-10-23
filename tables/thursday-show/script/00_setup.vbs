Option Explicit
Randomize

'*****************************************************************************************************
' THURSDAY SHOW - an original table by KaoticBPR, version @@VERSION@@
'
' This script is generated: edit the files in tables/thursday-show/script/ and run tools/build.py.
'
' Built on the Visual Pinball X starter table by fuzzel, jimmyfingers, jpsalas, toxie & unclewilly,
' flipper primitives by zany, ball shadow by ninuzzu, positional sound helpers by djrobx.
'*****************************************************************************************************

' ---- Show text: everything the player reads lives here so the theme is one edit away ----------------
Const cGameName = "thursdayshow"          ' also the folder name for saved high scores
Const ShowName = "THURSDAY SHOW"
Const ShowTagline = "EVERY THURSDAY"
Dim SegmentNames : SegmentNames = Array("", "SEGMENT ONE", "SEGMENT TWO", "SEGMENT THREE", "SEGMENT FOUR", "SEGMENT FIVE")
Const WizardName = "SEASON FINALE"
Const MultiballName = "MULTIBALL"

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
Dim Multiball, WizardRunning, JackpotValue
Dim LastLeftOrbitTick, LastRightOrbitTick
