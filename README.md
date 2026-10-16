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
| 1 2 3 4 / scrollhjul | Växla mellan vapen du har plockat upp |
| Q | Föregående vapen |
| Tab | Poängtavla |
| Esc | Paus: känslighet, lämna spelet |

## Movement-tips
- **Rocket jump:** hoppa, titta rakt ner och skjut en raket. Du tappar lite hälsa men flyger högt.
- **Strafe jump:** håll inne hopp, håll A eller D och dra musen åt samma håll i luften. Farten (`ups` längst ner) ökar.
- **Hopp-paddar** (rostfärgade med ljus markering) skjuter upp dig till de övre gångarna.

## Pickups
Du börjar varje liv med maskingeväret. Hagelgevär, raketgevär och railgun ligger alltid på samma platser och kommer tillbaka efter att någon har tagit dem.

- **Hagelgevär:** sydvästra rummet nära en ramp.
- **Raketgevär:** öppet i mitten.
- **Railgun:** övre norra gången, nåbar via ramp eller hopp-padd.
- **Grönt kors:** +25 HP. **Blå sfär:** +100 HP, upp till 200. **Gul armor:** +50 armor.

Kartan har ett öppet mittparti, fyra sidorrum, övre gångar och flera vägar upp. Ammunitionsregler och slutliga tider för återkomst bestäms senare.

## Var saker finns (för den som vill pilla)
- `scripts/player.gd`: rörelsekänsla (konstanterna högst upp)
- `scripts/weapons.gd`: skada, eldhastighet och spridning per vapen
- `scripts/arena.gd`: banan
- `scripts/bot_brain.gd`: bot-AI och svårighetsgrader
- `tools/gen_sfx.py`: genererar ljudeffekterna (`python3 tools/gen_sfx.py assets/sfx`)
