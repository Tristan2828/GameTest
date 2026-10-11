# Medieval Survival: audio brief

**The game:** a dark fantasy pixel-art survivor in the style of Vampire Survivors. You only move; your weapons fire by themselves at hordes of undead. It's co-op for 1–4 players, and a run goes through 3 stages, each about 4 minutes of waves and then a boss. The current audio is all chiptune-style synth made in code (square, saw, sine, triangle and noise waves). New audio should fit dark medieval pixel art: retro and gritty, not orchestral and glossy.

**Tracking:** `assets.yaml` (repo root) lists every ID below with its size, frames, source, status and license; this brief says what each one should be. Keep the two in step.

## Technical requirements (all files)
- **Format:** OGG Vorbis for music, WAV (16-bit) for sound effects. 44.1 kHz.
- **Where to put them:** `assets/audio/music/<id>.ogg` and `assets/audio/sfx/<id>.wav`, named with the IDs from the tables below (e.g. `crypt.ogg`, `metal_crypt.ogg`, `hit.wav`).
- **Music must loop seamlessly**: no silence at the start or end, and the tail must lead back into bar 1. Godot loops the whole file. The game crossfades over 1.2 s when it switches tracks, so a track doesn't need its own intro or ending.
- **Loudness:** music at about −16 LUFS integrated, all tracks matched to each other. Sound effects peak at −3 dBFS. The game has separate Music and SFX volume sliders.
- **Mono is fine for SFX.** Stereo for music.
- You can deliver a few files at a time: any ID without a file keeps its current synth sound.

## Music: 2 soundtracks

The player picks a soundtrack in the custom game settings: Classic, Metal, Metal boss fights only, or Shuffle (classic or metal picked per stage). That means **every stage and boss track needs a classic version and a metal version in the same role**. The menu track exists only as a classic version; the game never plays a metal menu track.

**Length:** today's loops are 8 bars (10–27 s), which gets repetitive over a 4-minute stage. **New tracks should be 60–120 s loops** with an A section and a B section, so the loop point isn't obvious.

### Classic soundtrack (chiptune / dark synth)
| ID | Plays during | Tempo | Key | Mood / instruments |
|---|---|---|---|---|
| `menu` | Title, lobby, shop, run summary | 70 BPM | D minor | Slow and sparse. Sine arpeggio, triangle lead, soft pad, **no drums**. Calm but ominous. |
| `crypt` | Stage 1, The Crypt | 100 BPM | A minor | Driving but not frantic. Square-wave arpeggio, triangle lead, pad. Simple kick and snare, steady 8th-note hats. |
| `marsh` | Stage 2, The Bone Marsh | 84 BPM | E Phrygian | Swampy, uneasy, half-time feel. Triangle arpeggio, sine lead, pad, sparse drums. Lean on the flat 2nd (F). |
| `cathedral` | Stage 3, The Burning Cathedral | 112 BPM | C harmonic minor | Grand and urgent, a gothic organ feel. Saw arpeggio, square lead, busy 16th-note hats. |
| `boss` | Every boss fight (all stages) | 140 BPM | D harmonic minor | Fast and relentless. Saw lead, square arpeggio, 8th-note kicks, 16th-note hats, no pad. |

### Metal soundtrack (distorted guitars over the same game roles)
| ID | Plays during | Tempo | Key | Style |
|---|---|---|---|---|
| `metal_crypt` | Stage 1 | 150 BPM | E minor | Galloping palm-muted riff, a howling lead, double-kick gallop, crash cymbals at section starts. |
| `metal_marsh` | Stage 2 | 76 BPM | D Phrygian | Slow, crushing doom. Ringing power chords, sparse chugs, heavy crashes. |
| `metal_cathedral` | Stage 3 | 168 BPM | C harmonic minor | Fast neoclassical thrash. Harmonic-minor lead runs, driving 8th-note riffs. |
| `metal_boss` | Every boss fight | 190 BPM | D harmonic minor | Tremolo-picked riffs over a blast beat. Shares its lead melody with the classic `boss`. |

Metal tuning: the guitars sit low (E2 / D2 / C2 roots), with the bass quiet underneath. Keep the low end from getting muddy, because a lot of sound effects play on top of it.

## Sound effects (26 in use)

General rule: **the game is very busy.** Hundreds of enemies, constant hits and deaths. Frequent sounds must be **short, soft and not harsh**. The engine already adds ±5% random pitch to every play and limits how often each sound can repeat (the "Max rate" column).

### Combat (very frequent; keep these tiny)
| ID | What it is | Length | Max rate | Notes |
|---|---|---|---|---|
| `shoot` | Kael's Bolt Gun firing | ~0.06 s | every 0.06 s | Plays nonstop at −10 dB. A soft blip, never harsh. |
| `scythe` | Mortimer's Reaper's Scythe swing | ~0.14 s | every 0.1 s | Airy whoosh. |
| `zap` | Morwen's Chain Lightning | ~0.06 s | every 0.08 s | Bright, crackly zap. |
| `spear` | Vesper's Bone Spears | ~0.07 s | every 0.1 s | Dry crack of bone. |
| `hit` | A bullet hits an enemy | ~0.04 s | every 0.04 s | A tick plus a tiny thud. |
| `death` | An enemy dies | ~0.2 s | every 0.03 s | Crumbly burst with a low thump. |
| `enemy_shot` | An enemy fires | ~0.08 s | every 0.08 s | Low, dull, distinct from your own shots. |
| `gem` | XP gem picked up | ~0.07 s | every 0.03 s | High rising "tink". |
| `hurt` | You took damage | ~0.3 s | — | A falling, wobbling buzz. Must cut through the mix. |

### Weapons and pickups
| ID | What it is | Length | Notes |
|---|---|---|---|
| `bomb` | Grave Blast, Holy Bomb, boss death | ~0.8 s + echo | Deep boom, noise blast, rolling echo. |
| `hex` | Hex Snare roots enemies | ~0.45 s + echo | Eerie falling whistle with a wobble. |
| `effigy` | Bone Effigy rises | ~0.2 s | Dry clatter of bones. |
| `coin` | Coin picked up | ~0.2 s | Two-note "ding-ding" (B5 → E6). |
| `pickup` | Power-up picked up | ~0.4 s | Quick rising sparkle arpeggio. |
| `chest` | A chest opens | ~0.5 s | Wooden creak, then a sparkle. |

### Events and run flow
| ID | What it is | Length | Notes |
|---|---|---|---|
| `level_up` | The team levels up (card choice opens) | ~0.5 s | Bright major arpeggio (C–E–G–C). |
| `quest` | Shop quest complete | ~0.6 s | Short, bright fanfare. |
| `event` | A map event appears or wakes (champion lair, ritual, Grave Robbers) | ~1 s | Low toll with a shimmer on top. Should make you look around. |
| `boss` | The boss arrives | ~2.5 s | Heavy impact, tolling bell, dissonant swelling horn. The biggest sound in the game. |
| `downed` | A teammate goes down | ~0.9 s | Heavy falling groan with a bell ring. Must be heard over the action. |
| `revive` | A teammate is revived | ~0.5 s | Warm rising chime. |
| `countdown` | "3, 2, 1" before play resumes | ~0.12 s | One clean beep (C5). |
| `countdown_go` | "Go!" | ~0.3 s | Brighter beep an octave up (C6). |
| `victory` | Run won | ~1 s | Rising major fanfare. |
| `defeat` | Run lost | ~1.3 s | Three falling notes, sad and final. |
| `ui` | Menu button / navigation | ~0.03 s | Tiny soft click. Plays a lot in menus. |

### Optional: currently silent
Eight of the 11 auto weapons have no sound of their own (e.g. Storm Lantern, Bone Cleaver, Grave Spikes, Spirit Daggers), and there's nothing for crits, picking a card or rerolling. New sounds here are welcome, but each one needs a little code to hook up.

### Not needed
`dash` and `ability_ready` are still defined in code but nothing plays them since v0.22.0 (Dash and the ability button were removed). Don't make them.
