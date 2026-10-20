# Deep Defense

3rd-Person-Koop-Roguelike-Tower-Defense für 1–4 Spieler (Arbeitstitel). Das komplette Konzept steht im
[Game Design Document](./Deep%20Defense%20%E2%80%93%20Game%20Design%20Document.md).

## Projekt öffnen

1. [Godot 4.7](https://godotengine.org/download) (Standard-Version, kein .NET) installieren.
2. Im Projektmanager „Importieren“ wählen und `project.godot` in diesem Ordner öffnen.
3. Mit F5 starten. Im Startmenü „Spiel hosten“ wählen (gilt auch für Solo); Esc beendet.
   Optional einen Seed eingeben (Zahl oder Text, auch per `--seed=…`): Mit demselben Seed kommen dieselben
   Erzstellen, Shop-Angebote (auch nach gleich vielen Rerolls) und Wellen. Der Seed steht im Esc-Menü.

Gespielt wird in der Kenney-Mine (`scenes/world/cave/KenneyMine.tscn`), von Hand aus Höhlenmodulen zusammengesetzt:
Aufzugshalle mit Shop in der Mitte, 8 m breite Gänge nach Westen, Osten und Norden mit je einem Erzraum und einem
Gegner-Eingang am Ende, im Süden ein Schlitz zu einer Erztasche, in die nur Spieler passen. Erz gibt es nur in der
Kampfphase: Zu ihrem Beginn brechen auf den Erzstellen (Marker in der Gruppe `ore_spawn_points`) neue Adern auf, am
Ende stürzen sie ein. Was wo erscheint, steht in `data/run/ore_spawn.tres`. Die alte Testmine aus CSG
(`TestMine.tscn`) und der Testraum (`TestRoom.tscn`) lassen sich in `Main.tscn` als Instanz für „World“ wieder
einsetzen.

### Höhlenmodule

Grafik: Kenney-Packs unter `assets/` (CC0). Das Cave Kit wird in Originalgröße genutzt: Ein Tile ist 4 m, also
2 × 2 Baufelder. Über jedes Teil kommt eine senkrecht gespiegelte Kopie; so ist die Höhle 8 m hoch, der gespiegelte
Boden bildet die Decke. Wände stehen im Fels-Tile hinter der Kante und zeigen ihre Felsseite zum Raum; Innen-
ecken rundet das Eckteil des Kits ab (dahinter laufen die Wände bis ins diagonale Fels-Tile weiter, damit kein
Spalt bleibt), an Außenecken steht ein Eckpfeiler. Jedes Modul unter `scenes/world/cave/modules/` ist ein ASCII-Layout
(Eigenschaft `layout`, im Inspector editierbar), aus dem `CaveModule.gd` beim Laden Boden, Wände, abgerundete Ecken,
Schlitze, Marker, Shop, Aufzug, Deko und Licht aufbaut. Zeichen: `#` Fels, `.` Boden, `s` Schlitz (nur für Spieler),
`o` Erzstelle, `N` Gegner-Eingang, `E` Aufzug, `T` Würfel-Station, `P` zwei Shop-Stellplätze, `b`/`x`/`a`/`r` Deko,
`L` Licht. Boden am Modulrand ist ein Ausgang (Marker unter „Exits“, −Z zeigt hinaus); die Ausgänge benachbarter
Module müssen sich treffen. Die Kollision besteht aus einfachen Boxen (Bodenplatte, eine Box hinter jeder Wandkante,
drei entlang jeder Rundung, zwei pro Schlitz). Vorhanden: ElevatorHall, Tunnel, OreRoom, OreRoomLarge,
EnemyNest, SlitPocket. Das Kit ist oben offen; die Decke ist in der Karte eine dunkle Platte.

Bauen: Die Baufelder liegen genau auf den Tile-Kanten. Pro Feld steht höchstens ein Bauelement (auch keine Mauer auf
einer Falle); Mauern dürfen in den Fels ragen, solange ihre Mitte frei ist.

### Modelle

- Spielfiguren: Kenney Mini Characters (pro Spieler eine andere Figur, Animationen für Stehen, Laufen, Sprinten,
  Springen, Fallen, Tragen und Schlagen), Spitzhacke aus dem Survival Kit.
- Survival Kit: Erzadern (Fels), Erzbrocken, Kisten (Angebote als Truhe), Wand (Palisade), Würfel-Station
  (Werkbank), Deko in Halle und Räumen (mit einfacher Kollision).
- Factory Kit: Sockel des Geschützturms, Zahnrad des Klingenwirbels; die Förderbänder folgen mit Aufgabe 15.
- Noch ohne Modell: Gegner (in den Packs gibt es keine Kreaturen), Stachelfalle, Aufzug.
- `scripts/ModelTint.gd` färbt importierte Modelle ein (Erzfarbe, Schaden an Bauelementen).

### Verteidigungen

- Geschützturm: mit Eisen geladen voller Schaden, ohne Munition schwach.
- Klingenwirbel: Kohle nachlegen (E mit Kohle in der Hand) gibt 15 s volle Leistung, bis zu 30 s gespeichert; die
  Zeit läuft nur in der Kampfphase. Ohne Kohle dreht er langsamer und trifft schwächer.
- Stachelfalle: löst einmal mit hohem Schaden aus, danach R 3 s halten zum Neuspannen.
- Werte in `data/buildables/` (DefenseData).

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

Im Spiel zeigt das Esc-Menü die komplette Belegung (Tastatur & Maus und Controller); sie wird aus der
Input Map gelesen (`scripts/InputNames.gd`, auch für die HUD-Prompts).

Zusätzlich (nicht im GDD): `camera_switch_shoulder` – V / rechten Stick drücken wechselt die Kameraschulter;
`use_secondary` – R / RB halten: zweite Halte-Aktion, z. B. Shop-Angebote kaufen (liegend oder getragen) und
ausgelöste Stachelfallen neu spannen.

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
