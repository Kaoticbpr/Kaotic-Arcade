# Yo! Retro: voice-over script

Lines for **KaoticBPR (K)** and **Half-A-Dozen (H)** to record, or to clip from episodes. The lines below
are starters: say them your way, ad-lib, and swap in the show's real catchphrases.

## How to name and deliver the files

- One take per file: `vo_<event>_<n>.wav` (or `.ogg`), numbered 1, 2, 3 ... with no gaps.
  Example: `vo_jackpot_1.wav` (K), `vo_jackpot_2.wav` (H), `vo_jackpot_3.wav` (both).
- Drop them in `sounds/voice/` and rebuild. The table picks a random take each time, so more takes
  means less repetition. 2 to 4 per event is plenty; an event with no takes just stays quiet.
- Keep them short (under 3 seconds for anything that happens mid-play), trimmed tight at both ends,
  mono, 44.1 kHz, peaks around -3 dB, with no music under them (the theme plays separately).
- Episode clips work the same way: cut the moment, export it with the event's name.
- The theme song goes in `sounds/music/music_theme.ogg` (OGG keeps the table small). It loops under
  gameplay, so a version that loops cleanly is ideal. Volume is `MusicVolume` in `script/00_setup.vbs`.

## Game flow

| Event | When | Starter lines |
|---|---|---|
| `start` | game starts | K: "Yo! Welcome to Yo! Retro!" / H: "It's Thursday, let's flip!" / both: "Yo! Retro!" |
| `player_added` | another player joins | K: "Oh, we got company." / H: "Pull up a chair!" |
| `next_ball` | next ball / next player | K: "Next ball, let's go." / H: "Back at it." |
| `shoot_again` | extra ball is played | K: "Shoot again!" / H: "Run it back!" |
| `ball_saved` | ball save | K: "Saved! You're welcome." / H: "Didn't count, didn't count!" |
| `drain` | ball lost | K: "Ohhh, straight down the middle." / H: "That's a bug, report it." |
| `tilt_warning` | tilt warning | K: "Easy on the cabinet!" / H: "Hey hey, that's a review unit!" |
| `tilt` | tilted | K: "Tilt. Yeah, that's going in the review." / H: "And that's a zero out of ten." |
| `game_over` | game over | K: "That's the show, folks." / H: "Like, subscribe, and play again!" |
| `high_score` | new high score | K: "New high score! Put it in the description!" / H: "Leaderboard, baby!" |
| `attract` | every ~36 s while idle | K: "Yo! Come play some pinball." / H: "Press start, we don't bite." / K: "New episode every Thursday!" |

## Shots and awards

| Event | When | Starter lines |
|---|---|---|
| `skill_shot` | skill shot | K: "Yo! Skill shot!" / H: "Called it." |
| `ramp` | ramp (not in multiball) | K: "Ramp!" / H: "Up and over!" |
| `orbit` | orbit | K: "Around the world!" / H: "Loop de loop." |
| `bonus_x` | bonus multiplier up | K: "Bonus going up." / H: "Multiplied!" |
| `extra_ball_lit` | extra ball lit | K: "Extra ball is lit, shoot the scoop!" |
| `extra_ball` | extra ball collected | K: "Extra ball!" / H: "Bonus content!" |

## Segments (modes)

Placeholder segment names; tell me the real ones and I'll rename them on the table too.

| Event | Segment / hot shot | Starter lines |
|---|---|---|
| `segment_1` | UNBOXING / ramps | K: "Let's unbox this thing! Hit the ramps!" / H: "Careful with the box, I'm keeping it." |
| `segment_2` | FIRST FLIPS / orbits | K: "First flips, let's see how it plays!" / H: "Loop those orbits!" |
| `segment_3` | CHAT ATTACK / pop bumpers | K: "Chat's going crazy, hit those bumpers!" / H: "Read the chat! Read the chat!" |
| `segment_4` | BUG HUNT / drop targets | K: "Bug hunt! Squash 'em!" / H: "There's always a bug." |
| `segment_5` | THE VERDICT / spinner | K: "Time for the verdict, spin it!" / H: "What we giving it?" |
| `more_time` | standups add 10 s | K: "More time on the clock!" / H: "Overtime!" |
| `segment_done` | segment complete | K: "That's a wrap on that segment!" / H: "Nailed it." |
| `segment_over` | segment timed out | K: "Out of time, moving on." / H: "We'll fix it in post." |

## Multiball and the finale

| Event | When | Starter lines |
|---|---|---|
| `lock_lit` | lock is lit | K: "Lock is lit!" / H: "Shoot the scoop!" |
| `lock` | ball locked | K: "Ball locked!" / H: "That's one in the bag." |
| `multiball` | Half-A-Dozen Multiball | H: "It's Half-A-Dozen Multiball!" / K: "Let him cook!" |
| `jackpot` | jackpot | K: "Jackpot!" / H: "Jackpot, baby!" |
| `half_a_dozen` | every 6th jackpot: super jackpot | H: "HALF! A! DOZEN!" / K: "Six of 'em! Super jackpot!" |
| `finale_lit` | all five segments done | K: "Yo! Retro Live is lit!" / H: "We're going live!" |
| `finale` | wizard mode starts | both: "We're LIVE! Everything's worth a hundred grand!" |
| `finale_end` | wizard mode ends | K: "What a show!" / H: "Same time next Thursday!" |
