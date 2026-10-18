# Megastrukturer bakom arenan

Bakgrunden byggs automatiskt när arenan startar. `Arena._backdrop()` lägger till
`MegastructureBackdrop`, vars skript finns i `scripts/megastructure_backdrop.gd`.
Du behöver alltså inte lägga till en nod manuellt i HARDSPAWN.

Skriptet skapar **32** mörka `MeshInstance3D` med `BoxMesh`, utan kollision och
utan skuggor över spelbanan. De står i en ring med centrumavstånd **80–350 m**.
Bredd och djup varierar **15–50 m**. Alla byggnader går ned till **Y = -1000**,
med varierande toppar vid **Y = 50–300**. Nederkanterna hamnar därmed långt
utanför kamerans synfält. De använder ett gemensamt, mörkt, obelyst material. Ett fast
slumptal gör att alla LAN-spelare ser samma siluetter. Ändra skriptets
`@export`-värden om du vill justera antalet eller dimensionerna.

## Dimma

`Arena._environment()` sätter följande värden i `WorldEnvironment`:

| Inställning | Värde |
|---|---|
| Fog Enabled | På |
| Fog Mode | Depth |
| Fog Light Color | `Color.BLACK` |
| Fog Density | `1.0` |
| Fog Depth Begin | `95 m` |
| Fog Depth End | `340 m` |
| Fog Depth Curve | `1.4` |
| Fog Height | `Y = -50 m` |
| Fog Height Density | `0.2` |
| Volumetric Fog | Av |

Spelområdet är mindre än dimmans startavstånd, så banans kanter och motståndare
förblir tydliga. Monoliterna längre bort bleknar gradvis in i den svarta
bakgrunden. Höjddimman tätnar snabbt under Y = -50 och döljer det som ligger
långt nedanför banan. Något separat golv i avgrunden behövs inte eftersom
boxarnas faktiska nederkanter ligger vid Y = -1000. Vanlig dimma används i
stället för volymetrisk dimma för att hålla spelet lättdrivet.

För att använda generatorn i en annan scen: lägg till en `Node3D`, koppla
`megastructure_backdrop.gd` till den och starta scenen. Noderna skapas i
`_ready()`.
