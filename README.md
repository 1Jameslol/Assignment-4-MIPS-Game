# MIPS Arcade

Three MIPS assembly games, each with a graphical window:

| Game | Start directly | Controls |
| --- | --- | --- |
| Doom-style shooter | `doom/play.command` | W/S move, A/D turn, Z/C strafe, Space fire, M map |
| Tic-tac-toe | `tic-tac-toe/launch.command` | Click a square or press 1–9; two local players |
| Blackjack | `blackjack/launch.command` | Hit/Stand buttons or H/S; play against the dealer |

Double-click **`launch.command` in this folder** to choose a game. All windows
start at 512×512 game pixels; display and keyboard connections are automatic.
Click the game image to focus keyboard input. R restarts; Q closes the game.
To switch games, close the window and open the launcher again.

The launcher uses the existing `/Applications/Mars.jar` and Java 11 or newer
(tested here on Java 25). For another MARS location, set `MARS_JAR`.
`common/Arcade.java` only connects MARS memory to a window and keyboard/mouse
input; all game rules and all game graphics execute in the `.asm` files.

## Rules

Tic-tac-toe: X starts. Keys 1,2,3 are the top row, 4,5,6 the middle, and 7,8,9
the bottom. Three in a row wins; a full board without a winner is a draw.
Occupied squares and invalid keys cannot change the turn. Play freezes after
a win/draw until restart.

Blackjack: a freshly shuffled 52-card deck each round. Aces count as 1 or 11;
face cards count as 10. Dealer stands on every 17, including soft 17. The
dealer's second card stays hidden until the round ends. A two-card 21 is a
natural; two naturals push. Reaching 21 on a hit automatically stands. Equal
totals push; a bust loses unless the dealer is the one busting. This is a
no-wager version without splits, doubles, or insurance. Card abbreviations:
T = ten; S/H/D/C = spades/hearts/diamonds/clubs. R deals a new round at any time.

Doom: defeat five demons, two hits each. Start with 100 health and 50 shots.
See `doom/README.md` for its full controls and implementation notes.

## Run inside the MARS IDE instead

Open the desired `.asm` file, assemble, and use the Default memory configuration
with pseudo instructions enabled and delayed branching disabled. Set Bitmap
Display to **512×512**, unit size **4×4**, base **0x10010000**. Connect both Bitmap
Display and Keyboard and Display MMIO Simulator before running. Type in the
keyboard tool's input area. The IDE version uses keyboard controls only.
Keep `common/` beside the game folders: the two new games include its GUI code.
Normal play must have no program arguments; an argument invokes the self-tests.

## Tests

Run `python3 verify_all.py` from this folder. No Python packages are needed.

- Doom: movement/collision, blocked shots, damage/death, empty ammunition,
  victory, game-over input, reset, all viewing angles and close-up rendering.
- Tic-tac-toe: all eight winning lines for both marks, draw, ninth-move win,
  invalid/occupied input, game-over input and reset.
- Blackjack: multiple aces, both/one-sided naturals, ties, both kinds of bust,
  soft 17, automatic stand on 21, ordinary dealer wins, post-game input,
  shuffled-deck uniqueness, exhausted-deck/hand limits and restart.
- Actual framebuffer output is checked and exported as each game's
  `preview.png`. All three GUI adapters are exercised headlessly for framebuffer
  updates, keyboard delivery, restart and quit. These checks do not replace a
  manual macOS window/mouse interaction test.

The existing Doom IDE launcher is retained at `doom/launch.command`.
