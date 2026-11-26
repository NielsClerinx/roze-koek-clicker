# Architectuur

## Principes
- **Eén centraal economiemodel** (`autoload/economy.gd`): elke formule (prijzen, KPS, klikwaarde,
  kritiek, offline, prestige) staat daar en nergens anders.
- **Modifiers**: systemen beslissen niets over getallen. Ze leveren een lijst modifiers
  (`{"type", "value", "target"}`) via `get_modifiers()` en registreren zich met
  `Economy.register_provider(self, temporary)`. Economy combineert ze en cachet het resultaat
  tot `EventBus.modifiers_changed` (of een aankoop) de cache ongeldig maakt.
- **Data-gedreven content**: gebouwen, upgrades en vrienden zijn JSON in `data/`.
- **EventBus**: systemen communiceren via signalen; de UI luistert alleen.
- **UI bevat geen spelregels**: `scripts/ui/main.gd` roept systemen aan en toont resultaten.

## Autoloads (laadvolgorde)
| Autoload | Verantwoordelijkheid |
|---|---|
| EventBus | Signalen |
| GameData | Laden en valideren van JSON-content |
| GameState | Op te slaan toestand, `to_dict`/`from_dict` met validatie en migratie |
| Economy | Alle formules, modifier-aggregatie |
| UpgradeSystem | Voorwaarden, aankoop, geheime upgrades → modifiers |
| CharacterSystem | Vrienden rekruteren, bonussen per level → modifiers (UI in v0.2) |
| RandomEventSystem | Gouden koek, tijdelijke buffs → tijdelijke modifiers |
| ProductionSystem | Productie per frame, gebouwen kopen |
| ClickSystem | Tikken, kritieke klikken |
| PrestigeSystem | Herglazuren, Fondantkristallen |
| SaveManager | Autosave (30 s), atomair schrijven, `.bak`-vangnet |
| OfflineSystem | Offline opbrengst bij opstart en terugkeer uit achtergrond |

## Opslaan
`user://save.json`, geschreven via `.tmp` + hernoemen; de vorige versie blijft als `.bak`.
Een onleesbare save valt terug op de back-up. Onbekende gebouwen/upgrades en NaN-waarden
worden genegeerd. `version` in de save maakt migraties mogelijk (`GameState._migrate`).

## Offline
`opbrengst = KPS_permanent × min(tijd, limiet) × efficiëntie` (start 25%, 3 uur).
Tijdelijke boosts tellen niet mee. Een klok die achteruit staat levert niets op.

## Een vriend toevoegen
1. Kopieer een bestaand bestand in `data/characters/` naar `<id>.json`.
2. Pas naam, rol, teksten, `unlock_cost`, `unlock_condition`, `passive_bonus` en `ability` aan.
3. Stel het uiterlijk in onder `look` (haar, baard, hoed, kleren, bril, huisdier, pose ...).
   `scripts/ui/characters/friend_figure.gd` tekent en animeert de figuur daaruit.
4. Bekijk het resultaat: `godot --path . res://tools/character_preview.tscn -- <id> <map>`.

Geen codewijziging nodig. Nieuwe bonustypes voeg je toe in `Economy._recalculate`,
nieuwe vaardigheidstypes in `CharacterSystem.use_ability`, nieuwe uiterlijke kenmerken in `friend_figure.gd`.

De UI voor vrienden staat in `scripts/ui/friends_ui.gd`: Vrienden-tab, figuren naast de koek
(max. 4: twee vooraan, twee achter de koek) en de welkomstpop-up.
