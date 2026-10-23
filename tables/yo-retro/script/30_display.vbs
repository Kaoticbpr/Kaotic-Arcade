'*****************************************************************************************************
' DISPLAY: FlexDMD score display (128x32, shown on the 4KP's DMD screen)
' Falls back to the playfield text box when FlexDMD is not available (desktop testing).
'*****************************************************************************************************

Dim FlexDMD, UseFlex, MessageShowing, AttractPage, AttractCount

Sub DMD_Setup()
	Dim scene, fontBig, fontSmall
	UseFlex = False
	On Error Resume Next
	Set FlexDMD = CreateObject("FlexDMD.FlexDMD")
	If Err.Number = 0 Then UseFlex = IsObject(FlexDMD)
	Err.Clear
	On Error Goto 0
	If Not UseFlex Then Exit Sub

	FlexDMD.GameName = cGameName
	FlexDMD.TableFile = Table1.Filename & ".vpx"
	FlexDMD.RenderMode = FlexDMD_RenderMode_DMD_RGB
	FlexDMD.Width = 128
	FlexDMD.Height = 32
	FlexDMD.Clear = True
	FlexDMD.Run = True

	Set fontBig = FlexDMD.NewFont("FlexDMD.Resources.udmd-f7by13.fnt", RGB(255, 255, 255), RGB(0, 0, 0), 0)
	Set fontSmall = FlexDMD.NewFont("FlexDMD.Resources.udmd-f5by7.fnt", RGB(0, 200, 255), RGB(0, 0, 0), 0)
	Set scene = FlexDMD.NewGroup("Scene")
	scene.AddActor FlexDMD.NewLabel("Top", fontSmall, "")
	scene.AddActor FlexDMD.NewLabel("Big", fontBig, "")
	scene.AddActor FlexDMD.NewLabel("Bottom", fontSmall, "")

	FlexDMD.LockRenderThread
	FlexDMD.Stage.RemoveAll
	FlexDMD.Stage.AddActor scene
	FlexDMD.Show = True
	FlexDMD.UnlockRenderThread
End Sub

Sub DMD_Close()
	If UseFlex Then FlexDMD.Run = False
End Sub

Sub DMD_Set(topText, bigText, bottomText)
	If Not UseFlex Then
		ScoreText.Text = topText & vbNewLine & bigText & vbNewLine & bottomText
		Exit Sub
	End If
	FlexDMD.LockRenderThread
	With FlexDMD.Stage
		.GetLabel("Top").Text = topText
		.GetLabel("Top").SetAlignedPosition 64, 0, FlexDMD_Align_Top
		.GetLabel("Big").Text = bigText
		.GetLabel("Big").SetAlignedPosition 64, 16, FlexDMD_Align_Center
		.GetLabel("Bottom").Text = bottomText
		.GetLabel("Bottom").SetAlignedPosition 64, 32, FlexDMD_Align_Bottom
	End With
	FlexDMD.UnlockRenderThread
End Sub

' The normal in-game view: player and ball, score, and the running segment with its clock.
Sub DMD_Refresh()
	Dim topText, bottomText, p
	If MessageShowing Then Exit Sub
	If Not GameOn Then ShowAttractPage : Exit Sub
	topText = "PLAYER " & CurPlayer & "   BALL " & BallNum
	bottomText = ""
	If ActiveMode > 0 Then
		bottomText = SegmentNames(ActiveMode) & "  " & Int((ModeTicksLeft + 9) / 10)
	ElseIf NumPlayers > 1 Then
		For p = 1 To NumPlayers
			If p <> CurPlayer Then bottomText = bottomText & "P" & p & " " & FormatScore(Score(p)) & "  "
		Next
	End If
	DMD_Set topText, FormatScore(Score(CurPlayer)), Trim(bottomText)
End Sub

' A short full-screen message, then back to the score.
Sub DMD_Message(bigText, bottomText, ms)
	MessageShowing = True
	DMD_Set "", bigText, bottomText
	MessageTimer.Enabled = False
	MessageTimer.Interval = ms
	MessageTimer.Enabled = True
End Sub

Sub MessageTimer_Timer()
	MessageTimer.Enabled = False
	MessageShowing = False
	DMD_Refresh
End Sub

'------------------------------------------------------------------------------------------------ attract

Sub StartAttract()
	AttractPage = 0
	AttractTimer.Enabled = True
	If Not MessageShowing Then ShowAttractPage
End Sub

Sub StopAttract()
	AttractTimer.Enabled = False
	MessageTimer.Enabled = False
	MessageShowing = False
End Sub

Sub AttractTimer_Timer()
	AttractPage = (AttractPage + 1) Mod 4
	If Not MessageShowing Then ShowAttractPage
	AttractCount = AttractCount + 1
	If AttractCount Mod 12 = 0 Then Callout "attract", True     ' a host quip about every 36 seconds
End Sub

Sub ShowAttractPage()
	Select Case AttractPage
		Case 0 : DMD_Set "", ShowName, ShowTagline
		Case 1 : DMD_Set "FREE PLAY", "PRESS START", ""
		Case 2 : DMD_Set "HIGH SCORE", FormatScore(HighScore), ""
		Case 3 : DMD_Set "HOSTED BY", "KAOTICBPR", "+ HALF-A-DOZEN"
	End Select
End Sub
