# Den svarta solen i 3D

Förmörkelsen skapas automatiskt av `Arena._black_sun()` och behöver inte
byggas manuellt i HARDSPAWN. Den gamla 2D-bildplanen används inte längre.
Originalbilden ligger kvar i `assets/sky/black_sun.jpg` som visuell referens.

## Noder

```text
Arena
├── WorldEnvironment          # svag volymdimma och glow
├── MegastructureBackdrop    # BoxMesh utan kollision, med skuggor
└── BlackSun (Node3D)        # position (0, 245, -160)
    ├── BlackMoon (MeshInstance3D / SphereMesh)
    ├── CoronaSphere (MeshInstance3D / SphereMesh)
    └── EclipseBacklight (DirectionalLight3D)
```

`scripts/black_sun.gd` skapar två lågdetaljerade sfärer. Den främre är
ogenomskinligt svart, har radie **55 m** och kastar skugga. Bakom den ligger
en större sfär med radie **72 m** och orange emission **10**, som ger en smal
ljusring via scenens befintliga glow. Den flyttas varsamt uppåt för att båda
sfärernas skivor ska sammanfalla sett från spelområdet. Koronans storlek och
emission varierar svagt under **7,5 sekunder**. Inga externa texturer behövs.
Månens yta undantas från dimmans färg så att skivan förblir svart; den har
fortfarande verkligt djup och kastar skugga i volymdimman.

Motljuset har varm färg, energi **0,9**, volymdimmeenergi **6**, två
skuggdelningar och skuggavstånd **320 m**. `DirectionalLight3D` använder sin
**rotation**, inte sin position, för ljusriktningen. Den ljusande sfären gör
själva koronan synlig; motljuset och skuggorna från månen och monoliterna
gör dimljuset synligt. Monoliterna saknar fortfarande kollision.

`Arena._environment()` använder tunn volymdimma: densitet **0,0005**,
anisotropi **0,65**, längd **300 m** och svart avståndsdimma från **95 till
340 m**. Spelområdet behåller sin skärpa. Djupupplösningen för volymdimman
är **48** för att hålla kostnaden nere. Effekten kräver Godots Forward+
rendering, som spelet använder. Ljuset är avsiktligt subtilt så att lava,
pickups och spelare förblir lätta att se.

Om förmörkelsen ska användas i en annan scen: lägg till ett `Node3D`, koppla
`scripts/black_sun.gd` till det, sätt positionen till `(0, 245, -160)`,
aktivera glow och volymdimma i `WorldEnvironment`, och låt avlägsna byggnader
kasta skuggor. Sfärerna använder vanlig djupprövning: när en byggnad ligger
framför solen skymmer den solen.
