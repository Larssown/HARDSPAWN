# Vapenmodeller

Modellerna är valda ur [Quaternius Sci-Fi Modular Gun Pack](https://quaternius.com/packs/scifimodularguns.html), som publiceras under CC0. Paketet innehåller både färdiga vapen och lösa delar i flera format. Spelet använder bara fyra färdiga glTF-filer; de är små, har inbyggda färgmaterial och behöver inga externa texturfiler.

| Spelvapen | Modell | Användning |
|---|---|---|
| Maskingevär | `AR_4.gltf` | Färdigt automatvapen |
| Hagelgevär | `Grenade_3.gltf` | Kort, kraftig form från paketet; paketet saknar färdigt hagelgevär |
| Raketgevär | `Grenade_2.gltf` | Färdig avfyrningsmodell |
| Railgun | `Sniper_1.gltf` | Lång precisionsmodell; paketet saknar färdig railgun |

Modellerna pekar mot lokal +X. `scripts/weapon_visual.gd` använder samma geometri för förstapersonsvy och vapenpickups, med mörkare material som passar kartan. Originalnedladdningarna i `assets/Guns/` och `assets/Modular Parts/` ligger kvar lokalt men ingår inte i spelbygget.
