# Roze Koek Clicker 🍪

Humoristische incremental idle game voor Android en iOS, gebouwd met **Godot 4.7** en GDScript.

## Starten
1. Installeer [Godot 4.7](https://godotengine.org/download) (standaardversie, niet .NET).
2. Open Godot → *Importeren* → kies `project.godot` in deze map.
3. Druk op **F5** om te spelen. Het venster opent in portretformaat.

## Tests
```
godot --headless --path . res://tests/test_runner.tscn
```
Test economie, prijzen, upgrades, kliks, offline-berekening, opslaan/laden, kapotte saves en prestige (141 checks).

## Content aanpassen
- Gebouwen en upgrades: pas `tools/gen_data.py` aan en draai `python3 tools/gen_data.py` (schrijft `data/*.json`).
- Vrienden: kopieer `data/characters/_template.json` naar `data/characters/<id>.json`. Geen code nodig.

## Spelen en delen
- Startpagina met browserversie en Android-download: https://nielsclerinx.github.io/roze-koek-clicker/
- Bouwen: `tools/build_release.sh` (web + Android-APK in `export/`). De webversie staat op de branch `gh-pages`.

## Status: v0.3 (prestaties, uitdagingen, Roze Hemel)
- **Prestaties**: 27 medailles (3 geheim), elk +1% productie, blijven na herglazuren.
- **Dagelijkse uitdagingen**: elke dag 3 opdrachten (zelfde soort voor iedereen, doelen schalen mee).
  Beloning: Roze Lintjes. 7 dagen op rij alles voltooid = bonus. Lintjes besteed je aan een productieboost.
- **Roze Hemel**: 10 permanente upgrades voor Fondantkristallen (startgebouwen, langer offline, gouden koeken, ...).

### v0.2 (vrienden)
Vier vrienden (Niels de Koekbaas, Tim de Proever, Kapitein Jordi, De Woudbaron) met eigen figuur,
bonus en vaardigheid. Rekruteren in de Vrienden-tab; tik op een vriend naast de koek voor zijn vaardigheid.

### v0.1 (kernloop)
Klikken met kritieke klikken, 15 gebouwen, 104 upgrades, mijlpaalbonussen, x1/x10/x100/Max kopen,
gouden roze koek met 3 beloningen, autosave met back-up, offline inkomsten, herglazuren (basis),
getalnotatie tot 10^63, responsieve portret-UI, één geheime upgrade.

Zie `docs/ARCHITECTURE.md` voor de opbouw.
