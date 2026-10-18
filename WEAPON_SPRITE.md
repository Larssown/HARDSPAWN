# Holografiskt 2D-vapen i HARDSPAWN

Patriks `weapon1.png` är i själva verket en JPEG. En kopia ligger därför som
`assets/sprites/holo_machinegun.jpg`. Maskingevärets förstapersonsvy använder
den bilden; hagelgevär, raketgevär och railgun visar sina tidigare 3D-modeller.

## Nodstruktur

Spelaren skapar noderna automatiskt i `scripts/player.gd` och
`scripts/viewmodel_overlay.gd`. Under en pågående match syns de i Godots
**Remote**-sceneträd:

```text
Player (CharacterBody3D)
├── Head
│   └── Camera3D
│       └── AimRay (RayCast3D)
└── ViewmodelOverlay (CanvasLayer, lager 5)
    ├── WeaponViewport (SubViewport; de andra vapnens 3D-modeller)
    ├── WeaponImage (TextureRect; visar SubViewport)
    └── SpriteRoot (Control, hela skärmen)
        └── WeaponSprite (TextureRect; maskingevärsbilden)
```

`WeaponSprite` sätts till hela skärmens storlek med `EXPAND_IGNORE_SIZE` och
`STRETCH_SCALE`. Den har `mouse_filter = IGNORE`, så musen fortsätter skjuta.
`CanvasItemMaterial` skapas i `scripts/weapon_sprite.gd` och sätts på nodens
`material` med `blend_mode = BLEND_MODE_ADD`. Svarta pixlar bidrar då inte till
bilden bakom; de ljusa neonlinjerna adderas ovanpå världen. För att göra samma
sak i editorn: markera **WeaponSprite → Material → New CanvasItemMaterial →
Blend Mode → Add**. Någon separat alfamask behövs inte för denna bild.

## Animation och skott

`weapon_sprite.gd` läser spelarens gånghastighet för en liten åttarörelse,
musens förflyttning för svaj och ett `kick()`-anrop för rekyl. `flash()` ger en
kort ljuspuls. `viewmodel_overlay.gd` växlar mellan spriten och den tidigare
3D-vyn när spelaren byter vapen. När spriten visas pausas den extra 3D-vyn,
vilket sparar renderingstid.

Vänsterklick går fortfarande via `Player._fire()`: ammo, eldhastighet, skada,
träffbekräftelse och nätverk påverkas inte av bildens placering. Den nya
`AimRay` sitter i mitten av `Camera3D` och används för exakta skott med railgun
och hagelgevärets mittpellet. Övriga pellets och maskingevärets spridning
fortsätter använda separata fysikstrålar från samma kamerariktning. Raketvapen
använder projektiler som tidigare.

## Fler 2D-vapen senare

Lägg nya bilder i `assets/sprites/` och välj rätt bild i `WeaponSprite` för
respektive vapen. Koppla sedan vapentypen i `ViewmodelOverlay.show_weapon()`.
Bilder med svart bakgrund kan använda samma additiva material; genomskinliga
PNG-bilder kan vid behov använda vanlig `Mix`-blandning.
