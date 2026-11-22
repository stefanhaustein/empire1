# Empire1

A real-time, single-player terminal strategy game inspired by classic *Empire*, written in Turbo Pascal 3.0-compatible Pascal for **PASTA/80** (CP/M / Z80) and **Free Pascal**.

![Empire1 gameplay](gameplay.png)

## Gameplay

Conquer a 30-planet sector against the computer in real time:

- **Planets & fleets:** Capture neutral and computer planets while defending your own. In-transit fleets move in real time, with travel times measured in days (1 second = 1 day) and ship production measured per week.
- **Difficulty levels** (chosen at startup, default 0):
  - 0 (**Easy**): Enemy fleets are visible on the map.
  - 1 (**Normal**): Enemy fleets are hidden until detected by your planets' sensors.
  - 2 (**Hard**): Hidden enemy fleets and smarter computer strategy.
- **Victory & defeat:** Eliminating all computer planets and in-transit fleets wins the match (and vice versa). After a match ends, the board stays active so you can stay on it, restart with `R`, or quit with `Q`.

## Controls

- `P` Select a planet to inspect its details on the right panel.
- `S` Send a fleet between planets. Press `Enter` at the ship-count prompt to send all available ships, or `Esc` to cancel.
- `M` Toggle between the star chart and recent message history (`Esc` also closes messages).
- `R` Start a new match (confirms while a match is still in progress).
- `Q` Exit the game (confirms while a match is still in progress).

## Building & Running

Runs in an 80×24 color terminal.

### CP/M / Z80 (PASTA/80 & tnylpo)

Compile `empire.com` with [PASTA/80](https://github.com/pleumann/pasta80):

```sh
pasta80 empire.pas
```

Run it on Unix/macOS in the `tnylpo` CP/M-80 emulator:

```sh
tnylpo -o y -s empire
```

- `-s`: enables VT52 support 
- `-o y`: enables color output

You can also transfer `empire.com` directly to CP/M-80 hardware or another CP/M emulator configured for an 80×24 terminal.

### Native (Free Pascal)

```sh
fpc empire.pas
./empire
```

## Source Files

- empire.pas — Main loop, player commands, and sensor alerts
- model.pas — Galaxy generation, planets, fleets, production, and combat
- ai.pas — Computer expansion and reinforcement logic
- ui.pas — Terminal UI, star chart, and message log
- str.pas — String formatting and conversion helpers

## License

Copyright (C) 2026 Stefan Haustein

This project is licensed under the GNU General Public License v3.0. See [LICENSE](LICENSE) for details.
