# HARDSPAWN – projektbeslut och arbetsregler

**Det här är den gemensamma källan till sanning för projektet.** Både Claude och ChatGPT läser
filen innan de ändrar något, och skriver in nya beslut här så fort projektledaren (Patrik) har
bestämt något. Står något här gäller det, även om koden ännu inte följer det.

---

## 1. Roller
- **Patrik:** projektledare. Bestämmer allt om spelet. Kodar inte själv.
- **Claude** och **ChatGPT:** gör allt kodande, alla assets och alla tester. Båda arbetar i samma mapp.

## 2. Vision
Ett FPS-spel som påminner mycket om **Quake 4 multiplayer / Quake 3 Arena**: deathmatch,
alla mot alla, flest frags när tiden tar slut vinner.
**Känslan och flowet är viktigast.** Det ska vara tillfredsställande att hoppa runt och skjuta.
Realism är inte ett mål.

## 3. Beslut

| Datum | Beslut |
|---|---|
| 2026-10-16 | Motor: **Godot 4.7.2**, språk GDScript. Bara **macOS**. |
| 2026-10-16 | Multiplayer **bara på LAN** (samma nätverk). En spelare är **host**. Max **8 spelare** inklusive botar. |
| 2026-10-16 | **Botar** ska kunna väljas till (antal och svårighetsgrad). |
| 2026-10-16 | Spelläge: **Free-for-all deathmatch** med tidsgräns. |
| 2026-10-16 | Spelet ska vara snålt. FPS-taket är **30** som standard (kan ändras i menyn). |
| 2026-10-16 | Vapen: **maskingevär, hagelgevär, raketgevär och railgun.** Railgun och hagelgevär är favoriter. **Rocket jump** ska fungera. |
| 2026-10-16 | Rörelse i Quake-stil: bunny hop, strafe jumping och hopp-paddar. |
| 2026-10-16 | Startfil: `HARDSPAWN.app` i mappen startar spelet med Godot från `/Applications`. |
| 2026-10-16 | Logotyp och branding finns i `assets/branding/`. |
| 2026-10-16 | **Grafikstil: mörk och industriell som Quake 4.** Tung metall, rost, betong, galler och rör, dämpat varmt ljus. Neonlook och ren sci-fi ska bort. (Den nuvarande neonarenan är en tillfällig prototyp.) |
| 2026-10-16 | **Startvapen: bara maskingevär.** Övriga vapen ligger utplacerade på kartan och måste plockas upp. |
| 2026-10-16 | **Alla vapen, hälsa, armor och andra items ligger alltid på samma fasta platser** och kommer tillbaka på samma plats, så att man kan lära sig kartan och planera sina drag. |
| 2026-10-16 | Kartan ska bli en **riktig bana i stil med Quake 3 Arena / Quake 4 multiplayer** (flera våningar, korridorer och rum). |
| 2026-10-16 | Versionshantering med **git**. Commits görs med e-postadressen **larson.patrik@gmail.com**. |
| 2026-10-16 | Koden ligger på Patriks **privata** GitHub: **https://github.com/Larssown/HARDSPAWN** (privat repo). Jobbkontot (patrik-turbin / turbin.se) ska **aldrig** användas för det här projektet. |
| 2026-10-16 | Patrik har sagt **kör** för den nya kartan och vapenpickups på fasta platser. Ammunitionens regler och slutliga respawntider är fortfarande öppna frågor. |
| 2026-10-16 | Kartan ska påminna om **Q3DM6:s känsla med tak, rum och korridorer**. Den öppna, fyrkantiga och symmetriska arenan ska ersättas av en egen, sluten och osymmetrisk layout. |
| 2026-10-16 | Kartan ska vara **lätt att orientera sig i**. Patrik tycker att den första rumsbanan är för mörk; rummen och vägarna framåt ska bli tydligare belysta utan att tappa den industriella stilen. |
| 2026-10-16 | Patrik har sagt **kör på** för nästa steg: förbättra vapenkänslan med railgun och hagelgevär först, och justera rocket jump och botarnas beteende i den nya kartan. Ammunition väntar fortsatt. |
| 2026-10-16 | Patrik har lagt 15 nedladdade texturpaket i `assets/textures/` och bett oss välja passande material till spelet. Fyra 1K-material används i kartan; originalpaketen ligger kvar lokalt. |
| 2026-10-17 | Patrik har lagt Quaternius Sci-Fi Modular Gun Pack i `assets/Guns/` och `assets/Modular Parts/` och bett oss kontrollera och använda passande vapenmodeller. Fyra färdiga glTF-modeller används för spelets fyra vapen; originalpaketen ligger kvar lokalt. |
| 2026-10-17 | Vapnet i förstapersonsvyn ska hållas nere till höger, med kolven vid bildkanten och pipan snett framåt mot mitten enligt Patriks referensbild. |
| 2026-10-17 | Patrik vill att vapnen ska vara större i bild och sikta mer rakt fram. Raketgeväret ska fylla mer av nedre högra hörnet, som i den nya referensbilden. |
| 2026-10-17 | Patrik vill satsa fullt på spelets grafik. Den industriella stilen och banans läsbarhet ska styra arbetet, med fortsatt hänsyn till målet om ett lättdrivet spel. |
| 2026-10-18 | Den slutna prototypbanan ersätts av en egen öppen, kompakt arena i tre nivåer för snabba 1v1- och 2v2-strider. Den tar inspiration från Q3DM17:s vertikalitet och Facing Worlds utsatta höjder utan att kopiera deras layout. Markväg runt en avgrund, övre gångar, två torn, railgun på högsta nivån och Mega Health på en exponerad bro. |
| 2026-10-18 | Hoppplattor ska vara Area3D med inställbar höjd och riktning. Lava/avgrund ska ge omedelbar död och åskådarläge under respawntiden. Maskingevärsammo ligger på marknivån; vapnen får begränsad ammunition. Slutlig ammunitionsbalans kan finjusteras. |

## 4. Pågående
- Den öppna tredelade banan **The Crucible** byggs av CSG-former med kollision: markperimeter, övre ring och bro, två tornplattformar, gångbara ramper, hoppplattor och dödliga fall. Layouten ska speltestas och justeras efter Patriks feedback.
- Vapenpickups på fasta platser finns på kartan. Alla andra items behåller fasta platser.
- Första passet för vapenkänsla är på plats: kraftigare träffrespons för rail och hagel, tydligare hagelspridning, rocket jump med sneda markskott och botar som väljer vapen efter avstånd.
- Kartan använder nu utvalda texturer för golv, väggar, metall och innertak. Ljusa väggar och markerade passager ska fortsatt göra rummen lättlästa.
- Färdiga lågpolyvapen ersätter de enkla lådmodellerna i spelarens händer och på kartans vapenplatser. Hagelgevär och railgun använder närliggande former ur paketet.
- Förstapersonsvapnen ritas nu i en separat transparent vy (`scripts/viewmodel_overlay.gd`) så att större modeller syns framför väggar. Skottens mynning räknas fortfarande om till spelkamerans position.
- Den nya banan behåller rostig metall, betong, varma armaturer och tydliga varningsmarkeringar kring stupen. Föregående rumsbana finns kvar i git-historiken.
- Maskingeväret startar med 120 skott. Fasta ammolådor på marknivån ger 60 skott, andra vapen får ammunition vid pickup och alla vapen har en maxgräns. Mängder och respawntider är första spelbara balansen.

### Föreslagen plan för kartan och pickups (förslag från Claude, INTE beslutat av Patrik)
Det här är tidigare idéer. Patrik har godkänt att arbetet med karta och vapenpickups börjar,
men har inte beslutat om alla detaljer i detta förslag.
- **Ordning:** kartan och vapenplaceringen byggs tillsammans, eftersom placeringen är en del av kartans design. Grafiken (texturer, ljus) görs när banans form är klar, så att inget texturerat behöver byggas om.
- **Startvapen:** bara maskingevär, med begränsad ammo.
- **Ammunition:** varje vapen ger lite ammo när man plockar upp det. Ammolådor per vapentyp ligger utspridda.
- **Respawntider (förslag):** vapen 5 s, ammo 15 s, hälsa 20 s, armor 25 s, Mega Health 35 s. Alltid samma plats och tid, så att man kan lära sig timingen.
- **Placering, risk mot belöning:**
  - Railgun på en utsatt hög plats som man når via hopp-padd eller rocket jump.
  - Raketgeväret i kartans hetaste korsning.
  - Hagelgeväret nära en spawnpunkt, för att kunna försvara sig direkt.
  - Mega Health och tung armor på var sin sida av kartan, så att man behöver röra sig runt.
- **Kartlayout:** medelstor för 4–8 spelare. Flera våningar, korridorer som binder ihop rum, ett öppet mittparti, hopp-paddar, teleporter och några smygvägar. Inspirerad av klassiska Quake-banor men med egen layout (ingen kopia av befintliga banor).
- **Grafik (Quake 4-stil):**
  - Riktiga PBR-texturer: metallpaneler, galler, rost och betong.
  - Förberäknad belysning (LightmapGI), som ger snygga mjuka skuggor och är snålt för datorn.
  - Riktiga modeller för spelare och vapen.
  - Gratis CC0-assets används när Patrik godkänt nedladdning (se öppna frågor).

## 5. Öppna frågor (Patrik har inte bestämt)
- Vilka slutliga ammomängder och respawntider ger bäst duellbalans?
- Hur lång tid tar det innan vapen och items kommer tillbaka?
- Får vi ladda ner gratis assets (texturer och modeller med CC0-licens, t.ex. ambientCG, Poly Haven, Quaternius och Kenney)?

## 6. Arbetsregler för AI:erna
1. **Läs den här filen först** vid varje ny uppgift.
2. **Läs alltid den aktuella filen innan du ändrar den.** Den andra AI:n kan ha ändrat den.
   Skriv aldrig över eller backa någon annans ändringar utan att Patrik bett om det.
3. **Skriv in nya beslut i tabellen ovan** (med datum) direkt när Patrik bestämt något.
   Flytta saker från "Väntar" och "Öppna frågor" när de blir aktuella.
4. **Committa ofta med git** och skriv i commit-meddelandet vilken AI som gjort ändringen,
   t.ex. `[Claude] Lägg till ammolådor` eller `[ChatGPT] Ny menybakgrund`.
   Kör `git status` och `git log` innan du börjar, så att du vet vad som ändrats.
5. **Ladda upp till GitHub** med `git push`. Repot är redan inställt att använda en egen SSH-nyckel
   (`~/.ssh/hardspawn_github`, en deploy key som bara gäller detta repo, via `core.sshCommand`).
   Ändra inte de inställningarna och använd inte `gh` eller jobbkontot. Kör `git pull` innan du börjar.
6. **Testa innan du säger att något är klart.** Helst headless, så att ingen spelruta tar över
   Patriks mus och tangentbord:
   `godot --headless --path . -- --host --bots=4 --quit=15`
   (test av klient: `-- --join=127.0.0.1 --quit=10` i en andra instans).
7. Skriv till Patrik **på svenska och utan programmeringsjargong.**

## 7. Teknisk översikt (för AI:erna)
- `scripts/game.gd` (autoload `Game`): inställningar, LAN (ENet port 7777, upptäckt via UDP-broadcast på 7778), poäng, skada och matchflöde. **Hosten (peer 1) bestämmer** över hälsa, kills, pickups och botar.
- `scripts/world.gd`: den pågående matchen. Ligger på `/root/World` hos alla så att RPC-sökvägarna stämmer.
- `scripts/player.gd`: rörelse, vapen och nätsynk. Varje människa simulerar sin egen spelare. Botar simuleras på hosten.
- `scripts/bot_brain.gd`: bot-AI som använder navmesh.
- `scripts/arena.gd`: den procedurgenererade tredelade CSG-banan. `scripts/jump_pad.gd` och `scripts/kill_zone.gd`: launch och fallzoner.
- `scripts/weapons.gd`: vapendata. `scripts/viewmodel.gd`: vapnet i förstapersonsvy.
- `scripts/hud.gd`, `scripts/menu.gd`: gränssnitt. `scripts/fx.gd`: effekter. `scripts/sfx.gd`: ljud.
- `tools/gen_sfx.py`: genererar platshållarljuden i `assets/sfx/`.
- Testflaggor efter `--`: `--host`, `--join=IP`, `--bots=N`, `--time=SEK`, `--name=X`, `--quit=SEK`, `--shot=fil.png`.
