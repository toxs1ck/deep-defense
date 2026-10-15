# Hinweise für KI-Sitzungen

- Konzept und Werte: `Deep Defense – Game Design Document.md`. Vor jeder Aufgabe den passenden Abschnitt lesen.
- Godot 4.7, typisiertes GDScript (Tabs zum Einrücken). Keine `class_name` in Autoload-Skripten.
- Ein System pro Aufgabe, in der Reihenfolge des Prototyp-Plans; Fortschritt in `README.md` abhaken.
- „Call down, signal up“: Kommunikation nach oben über Signale.
- Balancing-Werte gehören in Resources unter `data/`, nicht in den Code.
- Host-autoritativ: Spielrelevante Änderungen (Schaden, Geld, Zufall) laufen über den Host; Zufall über `GameState.rng`.
- Kommentare und Texte im Spiel auf Deutsch, Bezeichner auf Englisch.
