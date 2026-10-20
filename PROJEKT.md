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
| 2026-10-18 | Patrik vill behålla den tredelade arenan men göra den ren, lättöverskådlig och så nära svartvitt som möjligt. Kartan använder därför släta gråskalefärger utan nedladdade texturer; ljusa golv, mörkare höjdvägar och kontrastmarkerade farliga kanter. Färg på pickups och vapen behålls för att de ska synas snabbt. Detta ersätter det tidigare beslutet om rostig, varm industrigrafik för den aktuella arenan. |
| 2026-10-18 | Mittgropen ska vara en starkt lysande, röd/orange animerad lava som kontrasterar mot resten av den svartvita banan. Lavan har en texturfri shader, glödande kant, glödpartiklar och varmt ljus. Beröring ger omedelbar död via värdens vanliga döds- och åskådarflöde. |
| 2026-10-18 | **Konceptbild från Patrik (Gemini) är slutmålet för grafiken** och ersätter tidigare stilbeslut där de krockar. Stilen: **svart tomrum runt banan, svart golv med tunt grått rutnät, mellangrå kantiga block med tunna ljusa/vita kantlinjer**, kraftigt orange-röd glödande lavagrop i mitten som lyser upp omgivningen, guldglödande hoppplattor med gnistor, portalbågar, trappor, broar och höga pelare. Gränssnittet: siffror i enkla rundade rutor (hälsa nere till vänster, frags uppe till höger). Banans layout (The Crucible) behålls; det är utseendet som ska matcha bilden. Bilden finns i `docs/concept_target.jpg`. |
| 2026-10-18 | Buggfix i banan (Claude, efter Patriks begäran om buggtest): den övre trappan till tornen gick in under tornplattformen och man fastnade halvvägs. Den går nu rakt upp från höjdgångens kant till en avsats som leder runt till tornplattformen. Den nedre trappan slutar vid höjdgångens kant. Railgun, spawnar och pickups ligger kvar på samma platser. |
| 2026-10-18 | Patrik vill prova sin neonbild som ett 2D-vapen i förstapersonsvyn. Maskingeväret använder bilden med additiv blandning, mjuk rörelse, mussvaj och rekyl. Övriga vapen behåller sina 3D-modeller tills de får egna bilder. Träffar och LAN-regler ska fungera som tidigare. |
| 2026-10-18 | Patrik har valt fyra holografiska handbilder som förstapersonsvapen: hand1 för startvapnet/maskingeväret, hand2 för hagelgeväret, hand3 för raketgeväret och hand4 för railgun. De ersätter de tidigare förstapersonsmodellerna och den första neonvapenbilden. Skjutlogik, pickups och nätverk behålls. |
| 2026-10-18 | Patrik vill nu dölja alla förstapersonsvapen och handbilder helt. I mitten av spelbilden ska endast siktet synas. Vapenfunktion, vapenpickups och övrig HUD behålls; handbilderna får ligga kvar som inaktiva resurser. |
| 2026-10-18 | Bakom arenan ska 20–40 enorma brutalistiska monoliter och pelare ge världen djup. De ska ligga långt utanför spelområdet, vara dekorativa BoxMesh utan kollision och tona bort i nästan svart distansdimma. Spelområdet ska förbli skarpt och lättläst. |
| 2026-10-18 | Monoliternas nederkanter får inte synas när spelaren tittar ner. Varje bakgrundsbox ska gå ned till Y = -1000 med varierande toppar mellan Y = 50 och 300. Tät svart höjddimma från Y = -50 ska dölja djupet utan att grumla spelbanan. |
| 2026-10-18 | Patriks bild `solar.png` ska bli en enorm svart solförmörkelse högt över arenan. Den mörka mittskivan ska förbli ogenomskinlig, bildens svarta bakgrund ska vara osynlig och koronan ska glöda och pulsera mycket långsamt. Effekten ska vara lättdriven och inte skymmas av bakgrundstornen. |
| 2026-10-18 | Patrik vill ersätta solförmörkelsens 2D-bildplan med en riktig 3D-förmörkelse som samverkar med dimma och bakgrundsbyggnader. Den byggs av en svart skuggkastande sfär framför en större emissiv sfär och ett riktat motljus. Bakgrundspelarna kastar skuggor i tunn volymdimma. Byggnader får nu skymma solen naturligt; detta ersätter bildplanets tidigare regel om att alltid synas över tornen. |
| 2026-10-18 | Patrik gillar det varma ljuset men vill inte se några cirklar i himlen. Den svarta månen och den orange sfären tas därför bort helt. Det riktade motljuset, den tunna volymdimman och skuggorna från bakgrundstornen behålls. |
| 2026-10-18 | Patrik har gett en ny grafikreferens i `docs/graphics_reference_2026-10-18.jpg`. Den är nu målbilden där den skiljer sig från tidigare koncept: en bred gyllene ljusöppning bakom mörka monoliter, mjukt varmt dis, mörkt brungrått rutnätsgolv, tunna lysande vita kanter och lava som stark färgaccent. Förmörkelsens svarta skiva ska inte återkomma. Banans spelbara geometri behålls. |
| 2026-10-19 | Patrik har lagt tio utropsljud i `sound/`. `321` spelas vid varje matchstart; spelare och botar står stilla och kan inte skjuta under de första tre sekunderna, men människor kan se sig omkring. `First blood`, `1minute` och `30seconds` hörs av alla. `terminated` hörs bara av den som dödar med ett huvudskott. `dualelimination`, `tripple`, `overkill`, `insanity` och `monsterkill` hörs bara av den som uppnår 2–6 kills i följd utan att dö. |
| 2026-10-19 | Spelet ska spela Patriks `movie/intro.mp4` vid start och visa menyn när filmen är slut. En spelklar Ogg Theora-kopia används i Godot, med originalets ljud och bild; Enter, mellanslag eller Escape kan hoppa över introt. |
| 2026-10-19 | Patriks `image/IMG_1617.JPG` ska vara startmenyns bild. Bilden har redan HARDSPAWN-symbol och logotyp; menyn byggs om med tydliga knappar under loggan och separata, kompakta ytor för att vara värd, gå med och ändra inställningar. |
| 2026-10-20 | **Musik (klippt i Patriks DaVinci-projekt, tidslinjerna "meny" och "ingame").** Låten går i **160 BPM**; en takt = 1,5 s = exakt 36 bildrutor i 24 fps, och fraserna är 6 takter långa. Menyn: Patriks loop på 6 takter (9 s), godkänd. Ingame: loop från takt 36 (54,3 s i låten) i **114 takter = 171 s**, med en överton på en fras (6 takter) i slutet. Loopen är kontrollerad: inget klick i skarven och samma takt och volym på båda sidor. Filerna ligger i `assets/music/menu_loop.wav` och `assets/music/ingame_loop.wav` (vanlig PCM-WAV; Godot importerar dem med loop påslagen och QOA-komprimering). Patriks ursprungliga ingame-version finns kvar som tidslinjen "ingame (original)". Musiken spelas via autoload `Music` (`scripts/music.gd`): menyloopen i menyn, ingame-loopen under matcher, med mjuk övertoning mellan dem och egen volymreglage "Music" i inställningarna (egen ljudbuss). |
| 2026-10-20 | **Ammunition förenklas (Patrik):** maskingeväret har alltid oändligt med skott och alla ammolådor tas bort från banan. Första upplockningen ger 10 skott till hagelgeväret, 6 raketer och 5 railskott (som tidigare). Går man på samma vapen igen fylls det tillbaka till de mängderna. |
| 2026-10-20 | Två låga block flyttades till (0, ±20): en hälsa och en spawnplats låg inuti dem. Alla spawnar och pickups kontrolleras nu mot kollision. |
| 2026-10-20 | **Ny grafikriktning (Patrik): vit, sprucken betong i ljus, dammig dis**, enligt konceptbilden `docs/concept_white_dust.jpg`. Ersätter tidigare stilbeslut (svart/neon och varm/mörk) där de krockar. Banans layout är oförändrad. Sprickorna genereras i shadern `shaders/block.gdshader` (inga texturer); räcker de inte till kan vi byta till en riktig betongtextur. Lavan i mitten behålls tills vidare som färgklick. Utseendet: ljus disig himmel (`shaders/arena_sky.gdshader`), mjukt mulet solljus med mjuka skuggor, avståndsdimma och tunn volymdimma, vit dimma under banan, ljusa monoliter i fjärran och svävande damm runt kameran (`scripts/dust_field.gd`). |
| 2026-10-20 | Lavan görs starkare (Patrik): lavan glöder i HDR och ignorerar dimman, gropväggarna är brända och glöder orange närmare lavan, fler glöd-gnistor och orange värmedis över gropen. Ny inställning **Fog: ON / OFF (FASTER)** i menyn (`Game.settings.fog`, `Arena.apply_fog`). Mätning visade att sprickmaterialet var den största prestandakostnaden, inte dimman; shadern optimerades (ca 50 % snabbare i stresstest) och SSAO-kvaliteten sänktes något. |
| 2026-10-20 | Patriks fyra animerade neonvapen används i HUD:en nere till höger. Endast det aktiva vapnets film spelas och loopas i färg; övriga vapens symboler visas stilla i svartvitt. Vapen som ännu inte plockats upp visas nedtonade. Förstapersonsvapnen förblir dolda. |
| 2026-10-20 | När förstapersonsvapnen är dolda ska skottspår och hagelsmäll utgå från siktets linje, inte från den gamla dolda 3D-pipan. Träffberäkningen och raketernas riktning följer fortsatt siktet. |
| 2026-10-20 | Patrik tycker att skottspåren från mitten stör sikte och rörelse. Vanliga skotts visuella startpunkt flyttas därför lite nedåt och åt sidan; det egna maskingeväret får glesare, kortare spår. Träffar och raketer fortsätter följa siktet. |

## 4. Pågående
- **Vit dammig look (Claude, 2026-10-20):** alla bandelar använder `_concrete(...)` i `scripts/arena.gd` (färg, kantlinjernas styrka, mängd sprickor, sprickornas storlek). Fina sprickor och kornighet tonas automatiskt bort på avstånd för att inte flimra. Ljus och dimma ställs in i `_environment()` och `_lighting()`. Mätt: stadiga 60 fps i 1080p med 5 botar på Patriks Mac (M3 Max).
- **Konceptlooken (Claude, 2026-10-18):** banan ritas nu med `shaders/block.gdshader`: grå block med tunna glödande kantlinjer, svart rutnätsgolv och svart tomrum. Varje låda är `MeshInstance3D` + `StaticBody3D` (lager 1 och 4) och shadern behöver `box_size` som instansparameter (se `Arena._box`). Trappor är synliga steg ovanpå en osynlig ramp, så att rörelsen förblir mjuk. Hoppplattorna har guldringar, gnistor och en svävande ring. Silhuettblock står i tomrummet. HUD:en använder rundade rutor. Testkamera: `--view=x,y,z,tx,ty,tz[,fov]` tillsammans med `--shot=fil.png` tar en fast bild utan att röra musen. **Regel för kantlinjerna:** lådor får aldrig överlappa varandra med ytor i samma plan (det ger flimmer och felaktiga streck). Bygg sammanhängande ytor av bitar som bara nuddar varandra, via `_span(..., grupp)`. Inom en grupp döljs linjerna automatiskt där sidorna möts.
- Den öppna tredelade banan **The Crucible** byggs av CSG-former med kollision: markperimeter, övre ring och bro, två tornplattformar, gångbara ramper, hoppplattor och dödliga fall. Layouten ska speltestas och justeras efter Patriks feedback.
- Vapenpickups på fasta platser finns på kartan. Alla andra items behåller fasta platser.
- Första passet för vapenkänsla är på plats: kraftigare träffrespons för rail och hagel, tydligare hagelspridning, rocket jump med sneda markskott och botar som väljer vapen efter avstånd.
- Arenan använder fortsatt rena block utan nedladdade texturer, nu med varma brungrå material enligt den nya referensen. Marknivå, höjdgångar och farliga kanter har skilda ljushetsvärden.
- Mittgropens lava är det avsiktliga färgundantaget. Dess shader genererar brus i realtid utan bildfiler; effekt och träffzon byggs som egna barn under `LavaPit`.
- `scripts/megastructure_backdrop.gd` skapar 32 stora, kollisionfria bakgrundsblock i en ring 80–350 meter från arenans mitt. Alla når ned till Y = -1000; svart höjddimma tätnar under Y = -50. Distansdimma börjar vid 95 meter och tonar dem till svart fram till 340 meter. Tornen kastar nu skuggor i tunn volymdimma.
- `shaders/arena_sky.gdshader` gör en bred gyllene ljusövergång bakom monoliterna utan solskiva. `Arena._lighting()` riktar ett varmt motljus från samma håll; tunn volymdimma och monoliternas skuggor ger djup utan att dölja spelområdet. `scripts/black_sun.gd` och dess sfärer är borttagna.
- Färdiga lågpolyvapen ersätter de enkla lådmodellerna i spelarens händer och på kartans vapenplatser. Hagelgevär och railgun använder närliggande former ur paketet.
- Förstapersonsvapen och handbilder är nu dolda. Endast siktet visas där spelaren siktar; handbilderna ligger kvar som inaktiva resurser. Vapen på kartan och hos andra spelare ändras inte.
- Den tidigare separata 3D-vyn (`scripts/viewmodel_overlay.gd`) är dold och pausad vid rendering. Skottens synliga startpunkt ligger strax under siktet, utan beroende av den dolda pipan.
- Mittbrons kantmarkeringar följer nu själva bron; ramper och spawnplatser kontrolleras mot fysisk kollision. Synliga stolpar vid mittbron har också kollision. Föregående rumsbana finns kvar i git-historiken.
- Ammunition (beslut 2026-10-20): maskingeväret har oändligt med skott; inga ammolådor på banan. Hagelgevär, raketgevär och railgun ger 10 / 6 / 5 skott när man plockar upp dem första gången. Går man på samma vapen igen fylls det tillbaka till 10 / 6 / 5; har man redan minst så mycket ligger vapnet kvar.
- Utropsljuden i `sound/` har spelklara Ogg-versioner i `assets/sfx/announcer/`. Värden bestämmer när utrop ska spelas och vem som hör dem; de läggs i kö så att orden inte läggs ovanpå varandra. Matchuret börjar först efter tre sekunders startlås. Huvudträff för dödande skott mäts på träffpunkten på spelarens övre kropp.
- `scenes/intro.tscn` är nu projektets startscen. `movie/intro.ogv` är en 1080p/25 fps-kopia av `movie/intro.mp4` för Godots inbyggda videospelare; den spelas en gång före `scenes/menu.tscn`.
- Menyn använder `image/IMG_1617.JPG` som hel bakgrund utan dubblerad logotyp. De fyra huvudvalen ligger på en rad under bildens logga; endast den valda funktionens detaljer visas under raden.
- Vapenraden i `scripts/hud.gd` visar en 320×180-yta för det aktiva vapnet och tre små svartvita stillsymboler för de andra. Källfilmerna i `movie/*gun.mp4` har ljudfria, nedskalade 640×360/15 fps-versioner i Ogg Theora (`movie/*gun.ogv`), eftersom Godots inbyggda videospelare inte öppnar MP4 direkt. De fyra källbilderna i `image/` var JPEG-data med `.png`-namn och har lagrats om till riktig PNG så Godot kan läsa dem.

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
