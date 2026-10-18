# Den svarta solen

`Arena._black_sun()` lägger automatiskt till noden **BlackSun** när banan byggs.
Du behöver inte montera den för hand i HARDSPAWN.

## Nod och placering

`BlackSun` är en `MeshInstance3D` med ett enda `QuadMesh` på **180 × 180 m**.
Den placeras vid **`Vector3(0, 220, -220)`**. Spelkamerans bortre gräns är
**450 m**, vilket lämnar marginal för koronans yttersta strålar. Den föreslagna
placeringen `(0, 150, -500)` hade klippts bort utan en betydligt större gräns.
`scripts/black_sun.gd` vänder bildplanet mot den aktiva kameran varje bildruta.
Bildplanet saknar kollision, skuggor och påverkan på global belysning.

Bildfilen hette `solar.png` men innehåller JPEG-data och ligger därför i
`assets/sky/black_sun.jpg`.

## Material och ljus

`shaders/black_sun.gdshader` använder **Unshaded**, **Alpha/Mix**,
**No Depth Test**, **No Depth Draw** och **Fog Disabled**. Materialets
`render_priority` är **100**. Det ritas därför ovanpå de avlägsna tornen.

En enkel mask i shadern gör bildens yttre svarta bakgrund genomskinlig men håller
mittskivan ogenomskinligt svart. Den ljusa koronan får emission med grundvärde
**1,25** och glöder via arenans redan aktiva `WorldEnvironment.glow`.
Ren additiv blandning på hela bilden hade gjort även den svarta mittskivan
genomskinlig; därför används alfa här.

Skriptet låter solen andas över **7,5 sekunder**: storleken varierar **±1,2 %**
och emissionen **±0,08**. Inga partiklar eller extra ljuskällor används.

## I en annan Godot-scen

1. Lägg till en `MeshInstance3D` och koppla `scripts/black_sun.gd` till den.
2. Sätt positionen till `Vector3(0, 220, -220)` eller en plats inom kamerans
   `far`-avstånd. Skriptet skapar `QuadMesh` och material automatiskt.
3. Aktivera **Glow** i scenens `WorldEnvironment` (HARDSPAWN har redan gjort det).
