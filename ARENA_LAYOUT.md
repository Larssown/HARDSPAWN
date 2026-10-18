# The Crucible – banans koordinater

`scripts/arena.gd` genererar hela banan vid matchstart. Den är redan inkopplad i
`scripts/world.gd`; ingen scen behöver byggas för hand. Alla spelbara CSGBox3D
och CSGCylinder3D har `use_collision = true` på kollisionslager 1. Separata
kollisionsformer på lager 4 används enbart när botarnas gångvägar bakas.

Koordinaterna nedan är i Godots meter. Y är höjd. Lådor anges som **centrum / storlek**.

| Del | Centrum | Storlek |
|---|---|---|
| Mark, norr | `(0, -1, -18.5)` | `(46, 2, 23)` |
| Mark, söder | `(0, -1, 18.5)` | `(46, 2, 23)` |
| Mark, väster | `(-18.5, -1, 0)` | `(23, 2, 44)` |
| Mark, öster | `(18.5, -1, 0)` | `(23, 2, 44)` |
| Fyra korta yttervingar | `(0,-1,±32)`, `(±32,-1,0)` | `(14,2,5)` respektive `(5,2,14)` |
| Gång, norr/söder | `(0, 4.65, ±11)` | `(28, 0.7, 4.2)` |
| Gång, väster/öster | `(±11, 4.65, 0)` | `(4.2, 0.7, 22)` |
| Utsatt mittbro | `(0, 4.65, 0)` | `(22, 0.7, 2.8)` |
| Norra tornets plattform | `(-17, 9.65, -18)` | `(10.5, 0.7, 8.5)` |
| Södra tornets plattform | `(17, 9.65, 18)` | `(10.5, 0.7, 8.5)` |

De två markramperna går från `(-11.5,0,-25)` till `(-11.5,5,-11)` och från
`(11.5,0,25)` till `(11.5,5,11)`. Tornramperna fortsätter till
`(-17,10,-18)` respektive `(17,10,18)`. Ramperna är gångbara; hoppplattorna
är snabbare alternativ. `NavigationLink3D` kopplar rampändarna för botarna.

Fyrkantens mitt saknar golv. En mörk bottenyta ligger på Y = -4 utan kollision.
En `KillZone` täcker fallet i mitten och en större zon fångar fall vid ytterkanten.
Mega Health finns på mittbron `(0,5,0)`, armor på södra gången `(0,5,11)` och
railgun på norra tornet `(-17,10,-18)`.

Hoppplattorna är `Area3D` i `scripts/jump_pad.gd`. Varje platta får en riktning,
höjd och horisontell fart från sitt mål i `arena.gd`. Fallzonerna använder
`scripts/kill_zone.gd`, som låter värden besluta om död och startar spelets
vanliga poäng- och respawnflöde. Den döde spelaren får åskådarkamera tills
respawn.

## Visuell läsbarhet

Banan använder släta material i vitt, svart och grått i stället för texturpaket.
Ljus marknivå skiljer sig från mörkare höjdgångar och nästan svart avgrund.
Mörka linjer markerar stup på marknivå; vita linjer följer kanterna på broar,
gångar, torn och yttervingar. Pickupföremålens färger är kvar som spelinformation.
Ljuset är neutralt och bakgrunden mörk, så banans silhuett syns tydligt.
