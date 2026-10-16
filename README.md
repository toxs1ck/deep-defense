# Deep Defense

3rd-Person-Koop-Roguelike-Tower-Defense für 1–4 Spieler (Arbeitstitel). Das komplette Konzept steht im
[Game Design Document](./Deep%20Defense%20%E2%80%93%20Game%20Design%20Document.md).

## Projekt öffnen

1. [Godot 4.7](https://godotengine.org/download) (Standard-Version, kein .NET) installieren.
2. Im Projektmanager „Importieren“ wählen und `project.godot` in diesem Ordner öffnen.
3. Mit F5 starten. Im Startmenü „Spiel hosten“ wählen (gilt auch für Solo); Esc beendet.

Gespielt wird in der Testmine (`scenes/world/TestMine.tscn`): Halle mit Aufzug und Shop, drei Schächte nach
Westen, Osten und Norden mit je einem Erzraum und einem Gegner-Eingang am Ende. Erz gibt es nur in der Kampfphase:
Zu ihrem Beginn brechen auf den Erzstellen (Marker in der Gruppe `ore_spawn_points`) neue Adern auf, am Ende stürzen
sie ein. Was wo erscheint, steht in `data/run/ore_spawn.tres`. Der alte Testraum
(`TestRoom.tscn`) lässt sich in `Main.tscn` als Instanz für „World“ wieder einsetzen.

## Multiplayer auf einem PC testen

1. Im Editor **Debug → Laufende Instanzen anpassen…** (*Customize Run Instances*) öffnen.
2. „Mehrere Instanzen aktivieren“ einschalten und 2 Instanzen einstellen.
3. Bei Instanz 1 unter *Arguments* `-- --host` eintragen, bei Instanz 2 `-- --join`.
4. F5: Beide Fenster starten direkt im Spiel, ohne Menü.

Alternativ im Menü des einen Fensters hosten und im anderen mit `127.0.0.1` beitreten. Im LAN die IP des
Hosts eintragen; der Host muss UDP-Port 7777 freigeben.

## Ordnerstruktur

| Ordner | Inhalt |
| --- | --- |
| `autoload/` | Globale Systeme: `GameState`, `RunManager`, `Economy`, `NetworkManager` |
| `data/` | Balancing-Werte als `.tres`: `player/`, `run/`, `elevator/`, `ores/`, `enemies/`, `buildables/`, `traits/`, `buildables/`, `enemies/`, `traits/`, `items/`, `recipes/` |
| `scenes/` | `Main.tscn` sowie `player/`, `enemies/`, `buildables/`, `world/`, `ui/` |
| `components/` | Wiederverwendbare Kind-Nodes: `InteractableComponent`, `CarryComponent`, `HealthComponent`, `BuildComponent`, später Health, Hitbox, Carry, Ability … |
| `scripts/` | Hilfsklassen und Resource-Klassen (`resources/`), z. B. `WaveGenerator.gd`, `MineGenerator.gd` |

## Input Map

Alle Aktionen aus der Steuerungstabelle im GDD sind in der Input Map angelegt (Maus/Tastatur und Controller):
`move_forward/back/left/right`, `camera_left/right/up/down` (rechter Stick; die Maus läuft über
`InputEventMouseMotion`), `jump`, `sprint`, `attack`, `aim`, `interact`, `build_mode`,
`build_rotate_left/right`, `ability`, `ping`, `ready`, `show_info`, `menu`.

Zusätzlich (nicht im GDD): `camera_switch_shoulder` – V / rechten Stick drücken wechselt die Kameraschulter;
`purchase_carried` – R / RB halten kauft ein getragenes Shop-Angebot.

## Fortschritt (Prototyp-Plan)

- [x] 1 – Projektgerüst
- [x] 2 – Spielfigur & Kamera
- [x] 3 – Netzwerk-Basis
- [x] 4 – Interaktion
- [x] 5 – Erzvorkommen & Abbau
- [x] 6 – Tragen & Ablegen
- [x] 7 – Aufzug & Teamkasse
- [x] 8 – Runden-Ablauf
- [x] 9 – Gegner-Basis
- [x] 10 – Spieler-Kampf
- [x] 11 – Bausystem
- [x] 12 – Verteidigung
- [x] 13 – Wellen & Erzdieb
- [x] 14 – Shop & Merkmale
- [ ] 15 – Technik-Test Förderband
