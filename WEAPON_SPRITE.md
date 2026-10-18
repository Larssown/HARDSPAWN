# Holografiska händer som förstapersonsvapen

**Nuvarande spelbeslut:** förstapersonsvapnen är helt dolda. Endast siktet
visas i mitten av spelbilden. Bilderna nedan ligger kvar i projektet men ritas
inte; `WeaponSprite.show_weapon()` håller spriten dold även efter vapenbyte och
respawn.

Patriks fyra filer hette `hand1.png` till `hand4.png`, men innehåller JPEG-data.
De ligger därför i `assets/sprites/` med `.jpg` som filändelse:

| Bild | Vapen i spelet |
|---|---|
| `hand_machinegun.jpg` (hand1) | Maskingevär, startvapen |
| `hand_shotgun.jpg` (hand2) | Hagelgevär |
| `hand_rocket.jpg` (hand3) | Raketgevär |
| `hand_rail.jpg` (hand4) | Railgun |

Modellerna som ligger på kartan och syns hos andra spelare ändras inte.
Skottens skada, ammunition, eldhastighet och LAN-flöde är samma som tidigare.

## Nodstruktur

Spelaren skapar noderna automatiskt i `scripts/player.gd` och
`scripts/viewmodel_overlay.gd`. Under en match syns de i Godots
**Remote**-sceneträd:

```text
Player (CharacterBody3D)
├── Head
│   └── Camera3D
│       └── AimRay (RayCast3D)
└── ViewmodelOverlay (CanvasLayer, lager 5)
    ├── WeaponViewport (SubViewport; pausad 3D-vy för mynningsposition)
    ├── WeaponImage (TextureRect; dold)
    └── SpriteRoot (Control, hela skärmen)
        └── WeaponSprite (TextureRect; rätt handbild för valt vapen)
```

`WeaponSprite` fyller skärmen och ignorerar musinmatning. `CanvasItemMaterial`
skapas i `scripts/weapon_sprite.gd` med `blend_mode = BLEND_MODE_ADD`. Svarta
pixlar bidrar då inte till bilden bakom; de ljusa neonlinjerna adderas ovanpå
spelvärlden. I Godots editor motsvarar detta **WeaponSprite → Material → New
CanvasItemMaterial → Blend Mode → Add**.

## Rörelse och skott

`weapon_sprite.gd` använder spelarens hastighet för en liten åttarörelse och
musens rörelse för svaj. `kick()` ger en snabb rekyl med mjuk återgång och
`flash()` ger en kort ljuspuls. `show_weapon()` byter bild vid vapenbyte.

Vänsterklick går genom `Player._fire()`. `AimRay` sitter i mitten av `Camera3D`
för exakta skott med railgun och hagelgevärets mittpellet. Andra pellets och
maskingevärets spridning använder egna fysikstrålar. Raketgevärets projektil
fungerar som tidigare.
