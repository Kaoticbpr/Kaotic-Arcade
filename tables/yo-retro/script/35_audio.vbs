'*****************************************************************************************************
' VOICE AND MUSIC
'
' Callouts are sounds named vo_<event>_<n> (n = 1, 2, 3 ...), one file per take, so both hosts can
' record their own version of a line and the table picks one at random. The build counts the takes
' and writes VoiceVariants() at the end of the script; an event with no takes stays silent.
' The theme song is the sound music_theme, looped under gameplay.
'*****************************************************************************************************

Dim LastVoice, LastVoiceTick

' important = False lines (ramps, orbits, ...) are skipped if a host spoke in the last 3 seconds.
Sub Callout(evt, important)
	Dim n
	n = VoiceVariants(evt)
	If n = 0 Then Exit Sub
	If Not important And Ticks - LastVoiceTick < 30 Then Exit Sub
	If LastVoice <> "" Then StopSound LastVoice
	LastVoice = "vo_" & evt & "_" & (Int(Rnd * n) + 1)
	LastVoiceTick = Ticks
	PlaySound LastVoice, 0, VoiceVolume
End Sub

Sub StartMusic()
	If HasThemeMusic Then PlaySound "music_theme", -1, MusicVolume
End Sub

Sub StopMusic()
	If HasThemeMusic Then StopSound "music_theme"
End Sub
