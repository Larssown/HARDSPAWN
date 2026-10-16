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

## 4. Väntar (beslutat men inte påbörjat)
Patrik har sagt **"avvakta"** om dessa. Börja inte på dem innan Patrik säger till.
- Den nya kartan i Quake-stil.
- Vapenpickups, ammunition och fasta platser för items.

## 5. Öppna frågor (Patrik har inte bestämt)
- Hur ska ammunitionen fungera (ammolådor, hur mycket ammo vapen ger)?
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
5. **Testa innan du säger att något är klart.** Helst headless, så att ingen spelruta tar över
   Patriks mus och tangentbord:
   `godot --headless --path . -- --host --bots=4 --quit=15`
   (test av klient: `-- --join=127.0.0.1 --quit=10` i en andra instans).
6. Skriv till Patrik **på svenska och utan programmeringsjargong.**

## 7. Teknisk översikt (för AI:erna)
- `scripts/game.gd` (autoload `Game`): inställningar, LAN (ENet port 7777, upptäckt via UDP-broadcast på 7778), poäng, skada och matchflöde. **Hosten (peer 1) bestämmer** över hälsa, kills, pickups och botar.
- `scripts/world.gd`: den pågående matchen. Ligger på `/root/World` hos alla så att RPC-sökvägarna stämmer.
- `scripts/player.gd`: rörelse, vapen och nätsynk. Varje människa simulerar sin egen spelare. Botar simuleras på hosten.
- `scripts/bot_brain.gd`: bot-AI som använder navmesh.
- `scripts/arena.gd`: banan (byggd av lådor i kod; prototyp).
- `scripts/weapons.gd`: vapendata. `scripts/viewmodel.gd`: vapnet i förstapersonsvy.
- `scripts/hud.gd`, `scripts/menu.gd`: gränssnitt. `scripts/fx.gd`: effekter. `scripts/sfx.gd`: ljud.
- `tools/gen_sfx.py`: genererar platshållarljuden i `assets/sfx/`.
- Testflaggor efter `--`: `--host`, `--join=IP`, `--bots=N`, `--time=SEK`, `--name=X`, `--quit=SEK`, `--shot=fil.png`.
