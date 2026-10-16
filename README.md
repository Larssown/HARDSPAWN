# HARDSPAWN

LAN-deathmatch i Quake-stil, byggt i Godot 4.7. Alla mot alla, flest frags när tiden tar slut vinner.

## Starta spelet
Dubbelklicka på **HARDSPAWN.app** i mappen. Godot måste ligga i Program-mappen (`/Applications/Godot.app`).
Första gången kan macOS säga att appen kommer från en okänd utvecklare: högerklicka → **Öppna** → **Öppna**.

(Från Godot-editorn går det också: öppna projektet och tryck **F5**.)

**HOST** startar en match på din Mac, med så många botar du valt.
   Kompisar på samma nätverk ser ditt spel under **JOIN GAME** (eller skriver din IP, som visas i Esc-menyn).

Första gången kan macOS fråga om Godot får ta emot inkommande anslutningar. Svara **Tillåt**, annars kan ingen ansluta.

**Testa multiplayer på en enda Mac:** I Godot, *Debug → Customize Run Instances…*, kör 2 instanser. Hosta i den ena och skriv `127.0.0.1` i den andra.

## Kontroller
| Tangent | Funktion |
|---|---|
| W A S D | Springa |
| Mellanslag | Hoppa (håll inne för bunny hop) |
| Vänster mus | Skjuta |
| Höger mus | Zooma (railgun-sikte) |
| 1 2 3 4 / scrollhjul | Maskingevär, hagelgevär, raketgevär, railgun |
| Q | Föregående vapen |
| Tab | Poängtavla |
| Esc | Paus: känslighet, lämna spelet |

## Movement-tips
- **Rocket jump:** hoppa, titta rakt ner och skjut en raket. Du tappar lite hälsa men flyger högt.
- **Strafe jump:** håll inne hopp, håll A eller D och dra musen åt samma håll i luften. Farten (`ups` längst ner) ökar.
- **Hopp-paddar** (gröna) skjuter upp dig till mittplattformen, där Mega Health finns.

## Pickups
Grönt kors = +25 HP. Blå sfär (mitten) = +100 HP, upp till 200. Gul = +50 armor.

## Var saker finns (för den som vill pilla)
- `scripts/player.gd`: rörelsekänsla (konstanterna högst upp)
- `scripts/weapons.gd`: skada, eldhastighet och spridning per vapen
- `scripts/arena.gd`: banan
- `scripts/bot_brain.gd`: bot-AI och svårighetsgrader
- `tools/gen_sfx.py`: genererar ljudeffekterna (`python3 tools/gen_sfx.py assets/sfx`)
