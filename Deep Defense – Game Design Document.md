# Deep Defense – Game Design Document

Oct 14, 2026 · @Tim

## Überblick

Deep Defense ist ein 3rd-Person-Koop-Roguelike-Tower-Defense für 1–4 Spieler in Godot 4: Ihr baut Erz in einer Mine ab, schickt es mit dem Aufzug nach oben und verteidigt die Mine gegen Wellen von Gegnern aus der Tiefe. "Deep Defense" ist ein Arbeitstitel.

| Eigenschaft | Festlegung |
| --- | --- |
| Genre | Koop-Roguelike, Tower Defense, Action |
| Perspektive | 3rd Person, Kamera hinter der Spielfigur |
| Spieler | 1–4, Online-Koop (Solo spielbar) |
| Engine | Godot 4.7 (Standard-Version, kein .NET), typisiertes GDScript; Umstieg auf 4.8 erst, wenn stabil und GodotSteam kompatibel |
| Grafikstil | Low-Poly, flache Farben, Fokus auf Performance |
| Plattform | PC (Steam), Controller- und Maus/Tastatur-Steuerung |
| Run-Länge | 30–45 Minuten |
| Vorbilder | PlateUp (Run-Struktur, zufällige Bau-Auswahl), Dungeon Defenders (Klassen, Gegner-Fähigkeiten, Action-TD) |

### Design-Säulen

1. **Gier gegen Sicherheit:** Jede Minute, die ein Spieler Erz abbaut, fehlt er bei der Verteidigung. Diese Spannung ist der Kern jeder Runde.
2. **Kein Run gleicht dem anderen:** Zufällige Shop-Auswahl, Erzvorkommen und Gegner-Mischungen zwingen zur Anpassung.
3. **Koop durch Rollen:** Merkmale ergänzen sich; ein gutes Team teilt Abbau, Transport und Kampf sinnvoll auf.
4. **Lesbares Chaos:** Gegner-Fähigkeiten sind auf einen Blick erkennbar (Silhouette, Farbe, Sound), damit Entscheidungen fair bleiben.

## Core Gameplay Loop

Ein Run besteht aus 15 Runden ("Schichten"); jede Schicht hat eine Bauphase und eine Kampfphase, und nach Runde 5, 10 und 15 kommt ein Boss.

### Ablauf einer Schicht

1. **Schichtbeginn – Auszahlung:** Der Aufzug fährt hoch und zahlt das Geld für alle Erze aus, die in der letzten Runde abgeliefert wurden.
2. **Bauphase (ohne Zeitlimit, Ready-Check):** Der Shop zeigt eine zufällige Auswahl. Spieler kaufen, platzieren und verschieben Bauelemente, rüsten Ausrüstung um und sehen eine Vorschau der nächsten Welle (Gegnertypen, Eingänge). Sobald die Welle startet, schließen beide Shops bis zur nächsten Bauphase.
3. **Kampfphase (ca. 2–3 Minuten):** Gegner strömen aus den Schächten. Gleichzeitig wachsen Erzvorkommen nach und können abgebaut werden. Bauen, Verschieben und Upgraden ist jederzeit erlaubt, auch mitten im Kampf; nur der Shop ist geschlossen.
4. **Abbau und Transport:** Erz wird auf Förderbändern oder in den Händen zum Aufzug gebracht. Erz, das bis Wellenende nicht im Aufzug liegt, bleibt liegen und kann von Gegnern gestohlen werden.
5. **Wellenende:** Sind alle Gegner besiegt, startet die nächste Schicht.

### Verlust- und Siegbedingung

- **Niederlage:** Der Aufzug (Kern der Mine) hat Lebenspunkte. Erreichen Gegner ihn, verliert er HP. Bei 0 HP ist der Run vorbei.
- **Sieg:** Runde 15 inklusive Endboss überstehen. Danach optional "Endlos-Modus" wie in PlateUp.
- **Gefallene Spieler** respawnen nach 10 Sekunden am Aufzug; Teamkameraden können sie schneller wiederbeleben.

### Die zentrale Entscheidung

In der Kampfphase muss das Team ständig abwägen: Abbauen bringt Geld für stärkere Verteidigung in der nächsten Runde, Kämpfen sichert die aktuelle Runde. Türme sollten deshalb allein nie ganz ausreichen, damit aktive Spieler gebraucht werden.

## Wirtschaft & Bergbau

Geld entsteht durch Ressourcen, die am Aufzug oder an einem Erzankauf abgegeben werden; wertvolleres Erz liegt tiefer in der Mine und damit näher an den Gegner-Eingängen.

### Erzarten (Startwerte zum Balancieren)

| Erz | Wert pro Brocken | Abbau-Schläge | Gewicht | Vorkommen |
| --- | --- | --- | --- | --- |
| Kohle | 5 $ | 2 | leicht (2 tragbar) | überall, häufig |
| Eisen | 12 $ | 4 | mittel | mittlere Tiefe |
| Gold | 30 $ | 6 | schwer (verlangsamt) | tief, selten |
| Kristall | 60 $ | 8 | sehr schwer, verlangsamt stark | nahe Gegner-Eingängen, ab Runde 6 |

### Abbau und Transport

- **Abbau:** Spieler schlagen mit der Spitzhacke auf ein Vorkommen. Jeder Treffer gibt Feedback (Funken, Sound); nach X Schlägen fällt ein Brocken heraus.
- **Tragen:** Ein Brocken wird physisch getragen und blockiert die Waffe. Schwere Erze verlangsamen den Spieler.
- **Logistik:** Förderbänder, Weichen, Sortierer, Magnete und Schleudern automatisieren den Transport (Details unter Shop & Bauelemente). Gegner können Förderbänder beschädigen und Items darauf stehlen.
- **Bohrer:** Baut ein Vorkommen automatisch ab und legt das Erz auf ein angrenzendes Förderband oder in eine Lagertruhe.
- **Lagertruhen:** Zwischenlager in der Mine. Inhalt ist vor Erzdieben sicher.

### Aufzug und Auszahlung

- Erz und Barren werden in den Aufzugskorb gelegt. Die Ladung wird zu Beginn der nächsten Bauphase ausgezahlt.
- **Kapazitätslimit:** Der Aufzug fasst anfangs 20 Items pro Runde und kann aufgerüstet werden. Das verhindert, dass Spieler nur Kohle farmen, und macht veredelte Barren attraktiver.
- **Bonus:** Volle Ladung oder gemischte Ladung gibt einen kleinen Bonus (z. B. +10 %).
- **Erzankauf:** Zusätzlicher Verkaufspunkt tief in der Mine. Zahlt sofort aus, auch mitten in der Welle, aber nur 75 % des Werts. Gut für schnelles Geld, schlecht als Hauptquelle.

### Crafting

Rohstoffe lassen sich direkt in der Mine weiterverarbeiten. Daraus entsteht eine zweite Entscheidung: Erz sofort verkaufen oder veredeln und für Verteidigung nutzen.

| Ergebnis | Zutaten | Station | Dauer | Nutzen |
| --- | --- | --- | --- | --- |
| Lichtquelle (Fackel) | 1 Kohle | Hand, keine Station | 2 s | Platzierbar, deckt Grubengas-Geister auf, Licht für 3 Runden |
| Eisenbarren | 1 Eisen + 1 Kohle | Schmelzofen | 6 s | Verkauf 30 $ (statt 17 $ roh), Grundstoff für Munition und Upgrades |
| Goldbarren | 1 Gold + 1 Kohle | Schmelzofen | 10 s | Verkauf 55 $ (statt 35 $ roh), Grundstoff für hohe Upgrade-Stufen |
| Geschützmunition (30 Schuss) | 1 Eisenbarren | Munitionswerkbank | 4 s | Munition für Geschütztürme |
| Mörsergranaten (5 Stück) | 1 Eisenbarren + 2 Kohle | Munitionswerkbank | 8 s | Munition für Mörser |
| Upgrade Stufe 2 | 3 Eisenbarren | Amboss | 10 s | Bauelement oder Ausrüstung: +30 % Werte |
| Upgrade Stufe 3 | 2 Goldbarren + 1 Kristall | Amboss | 15 s | Bauelement oder Ausrüstung: +60 % Werte und Spezialeffekt |

**Regeln:**

- Stationen haben Eingangs- und Ausgangs-Slots. Sie können von Hand befüllt oder per Förderband beliefert werden, sodass sich Produktionsketten automatisieren lassen.
- Der Schmelzofen verbrennt Kohle als Brennstoff; ohne Kohle steht er still.
- **Munition:** Geschütztürme und Mörser schießen auch ohne Munition, aber nur mit etwa 25 % Schaden und halber Feuerrate. Erst mit Munition entfalten sie ihre volle Wirkung, inklusive Spezialmunition aus späteren Rezepten (z. B. Brand- oder Frostmunition). Ein Munitionsbalken über dem Turm zeigt den Füllstand.
- Stationen arbeiten auch während der Kampfphase und sind damit lohnende Ziele für Gegner.
- Rezepte liegen als eigene Resources (`RecipeData`) vor, damit neue Rezepte ohne Code-Änderung dazukommen.

### Balancing-Ansatz

Alle Werte (Preise, HP, Schaden, Erzwerte) liegen in Godot-Resource-Dateien (`.tres`), damit man sie ohne Code-Änderung anpassen kann. Zielwert: Ein durchschnittliches Team verdient pro Runde genug für 2–3 Käufe.

## Shop & Bauelemente

In jeder Runde bieten zwei Shops zusammen 6 zufällige Angebote, bezahlt aus einer gemeinsamen Teamkasse; das Team kann für steigende Kosten neu würfeln, und gekaufte Elemente bleiben für den ganzen Run.

### Shop-Regeln (angelehnt an PlateUp)

- **Angebote:** Der Bauelemente-Shop zeigt 4 Bauelemente, der Ausrüstungsshop 2 Gegenstände (Rüstungen, Waffen). Beide werden jede Runde neu ausgewürfelt und schließen, sobald die Welle startet.
- **Reroll:** Jeder Shop kann einzeln neu gewürfelt werden. Erster Reroll 20 $, jeder weitere +10 $ in derselben Runde.
- **Seltenheit:** Gewöhnlich (60 %), Selten (30 %), Episch (10 %). Die Chancen steigen mit der Rundenzahl.
- **Blaupausen-Kisten:** Wie in PlateUp erscheinen Käufe als Kiste am Aufzug, die ein Spieler zum Bauplatz trägt.
- **Teamkasse:** Alles Geld landet in einer gemeinsamen Kasse, aus der beide Shops bezahlt werden. Das erzwingt Absprachen: Bekommt das Bollwerk die neue Rüstung oder baut das Team lieber einen zweiten Schmelzofen?
- **Synergien:** Manche Elemente erscheinen erst, wenn ein passendes Element gekauft wurde (z. B. Weiche und Sortierer erst nach dem ersten Förderband, Munitionswerkbank erst nach dem ersten Schmelzofen).

### Kategorien

| Kategorie | Bauelement | Funktion |
| --- | --- | --- |
| Transport | Förderband | Transportiert Items in eine Richtung |
| Transport | Weiche | Teilt einen Item-Strom auf 2–3 Ausgänge auf |
| Transport | Sortierer | Lässt nur eine gewählte Ressource geradeaus durch, den Rest zur Seite |
| Transport | Magnet | Zieht lose Items im Umkreis an und legt sie auf ein Förderband |
| Transport | Schleuder | Wirft Items über Lücken und Hindernisse zu einem Zielpunkt |
| Werkstätten | Schmelzofen | Schmilzt Erz mit Kohle zu Barren |
| Werkstätten | Munitionswerkbank | Stellt aus Barren Munition für Geschütztürme und Mörser her |
| Werkstätten | Amboss | Verbessert Bauelemente und Ausrüstung mit Barren und Kristallen |
| Verteidigung | Geschützturm | Fernkampf gegen Einzelziele; voller Effekt nur mit Munition, ohne Munition 25 % Schaden |
| Verteidigung | Klingenwirbel | Rotierender Flächenschaden auf kurze Distanz |
| Verteidigung | Frostwerfer | Verlangsamt oder friert Gegner im Bereich ein |
| Verteidigung | Mörser | Flächenschaden auf große Distanz, Mindestreichweite; voller Effekt nur mit Granaten, ohne nur kleine Explosion |
| Verteidigung | Mauer | Blockiert Wege und lenkt Gegner um |
| Verteidigung | Fallen | Bodenfallen mit Schaden oder Effekt (Stacheln, Teer, Sprengladung) |
| Lager & Abbau | Lagertruhe | Lagert Items, schützt sie vor Diebstahl |
| Lager & Abbau | Bohrer | Baut ein Erzvorkommen automatisch ab |
| Lager & Abbau | Erzankauf | Kauft sofort an, zu 75 % des Werts |
| Ausrüstung | Rüstung | Mehr Lebenspunkte und Resistenzen für die Spielfigur |
| Ausrüstung | Waffen | Waffen und Spitzhacken mit unterschiedlichem Schaden, Tempo und Reichweite |

### Platzierung

Bauelemente werden auf einem Raster platziert (z. B. 2-m-Zellen), damit Wegfindung und Kollision einfach bleiben. Ein Platzierungslimit pro Bereich verhindert das Zubauen ganzer Gänge, oder Gegner zerstören Mauern, wenn der Weg komplett blockiert ist.

## Merkmale, Fähigkeiten & Skillbäume

Jeder Spieler geht mit einer aktiven Fähigkeit und einem passiven Merkmal in einen Run; jedes Merkmal bringt einen Vorteil und einen Nachteil, und weitere Fähigkeiten, Merkmale und Slots werden über drei Skillbäume zwischen Runs freigeschaltet.

| Merkmal | Vorteil | Nachteil | Status |
| --- | --- | --- | --- |
| Hauer | +40 % Abbaugeschwindigkeit | −25 % Angriffstempo | Gesetzt |
| Raufbold | +40 % Nahkampfschaden | −30 % Fernkampfschaden | Gesetzt |
| Scharfschütze | Schaden steigt mit der Entfernung (+2 % pro Meter ab 10 m, max. +50 %) | −30 % Schaden unter 5 m | Gesetzt |
| Schmied | +50 % Crafting-Geschwindigkeit | −30 % Abbaugeschwindigkeit | Gesetzt |
| Flinkfuß | +25 % Laufgeschwindigkeit | −20 % Abbau- und Crafting-Geschwindigkeit | Gesetzt |
| Bollwerk | +50 % Lebenspunkte | −15 % Laufgeschwindigkeit | Gesetzt |
| Packesel | Trägt 2 Brocken mehr, schwere Erze verlangsamen nicht | −20 % Schaden | Vorschlag |
| Mechaniker | Repariert Bauelemente doppelt so schnell, Geschütztürme in 6 m Umkreis +15 % Feuerrate | −20 % eigener Schaden | Vorschlag |
| Sanitäter | Belebt doppelt so schnell wieder, heilt Mitspieler in der Nähe langsam | −20 % Lebenspunkte | Vorschlag |
| Späher | Sieht unsichtbare Gegner im Umkreis, größerer Lichtradius der Helmlampe | −20 % Lebenspunkte | Vorschlag |
| Sprengmeister | Explosionen und Fallen +30 % Schaden | Eigene Explosionen verletzen auch einen selbst | Vorschlag |
| Händler | Vom Spieler abgegebenes Erz bringt +15 % Geld | −25 % Abbaugeschwindigkeit | Vorschlag |
| Berserker | Bis zu +50 % Schaden bei niedrigen Lebenspunkten | Keine Heilung durch Mitspieler | Vorschlag |
| Glückspilz | Höhere Chance auf seltene Shop-Angebote für das Team | −15 % auf alle eigenen Werte | Vorschlag |

### Regeln

- **Ausrüstung zum Start:** 1 aktive Fähigkeit + 1 Merkmal. Ab Charakter-Level 5 gibt es einen zweiten Merkmal-Slot, ab Level 15 einen zweiten Fähigkeiten-Slot.
- **Aktive Fähigkeiten** liegen auf einer eigenen Taste (z. B. Q bzw. Schultertaste) und haben einen Cooldown.
- Gegensätzliche Merkmale lassen sich nicht kombinieren, z. B. Flinkfuß + Bollwerk oder Raufbold + Scharfschütze.
- Merkmale und Fähigkeiten aus verschiedenen Bäumen dürfen frei kombiniert werden.
- Mehrere Spieler dürfen dieselben Merkmale und Fähigkeiten wählen.
- Zum Start sind die Start-Knoten aller drei Bäume freigeschaltet: Hauer, Raufbold und Flinkfuß sowie Erzrausch, Bodenstampfer und Schichtruf.
- Während eines Runs gibt es alle 5 Runden eine Verbesserung zur Auswahl (1 aus 3 Karten), z. B. "Scharfschütze: Kopftreffer betäuben kurz" oder "Dynamitwurf hinterlässt Feuer".

### Skillbäume (Entwurf)

Nach jedem Run erhält jeder Spieler Charakter-XP für erreichte Runde, abgeliefertes Erz und besiegte Gegner. Pro Level gibt es einen Skillpunkt. Jeder Knoten kostet 1 Punkt; eine Stufe öffnet sich, wenn im selben Baum genug Punkte stecken (Stufe 1: sofort, Stufe 2: 2 Punkte, Stufe 3: 4, Stufe 4: 6). Pro Stufe gibt es ein Merkmal und eine aktive Fähigkeit, die einzeln gekauft werden.

**Arbeit** – Abbau, Transport, Crafting

| Stufe | Merkmal (passiv) | Aktive Fähigkeit (Cooldown) |
| --- | --- | --- |
| Start | Hauer | **Erzrausch:** 10 s doppelte Abbaugeschwindigkeit (45 s) |
| 1 | Schmied | **Sprengung:** Ein Vorkommen zerfällt sofort in alle Brocken (60 s) |
| 2 | Packesel | **Schnellschmiede:** Eine Station in der Nähe arbeitet 15 s dreimal so schnell (60 s) |
| 3 | Händler | **Erzsinn:** Zeigt 20 s alle Vorkommen und liegenden Items durch Wände (40 s) |
| 4 · Meister | Merkmal-Stufe 2 für alle Arbeits-Merkmale (kleinerer Nachteil) | **Expresslieferung:** Getragene Brocken landen sofort im Aufzug (90 s) |

**Kampf** – Schaden, Überleben, Kontrolle

| Stufe | Merkmal (passiv) | Aktive Fähigkeit (Cooldown) |
| --- | --- | --- |
| Start | Raufbold | **Bodenstampfer:** Stoßwelle wirft Gegner im Umkreis zurück (15 s) |
| 1 | Scharfschütze | **Dynamitwurf:** Explosion mit Flächenschaden (12 s) |
| 2 | Bollwerk | **Spott:** Zieht 6 s alle Gegner im Umkreis auf sich, −50 % erlittener Schaden (25 s) |
| 3 | Sprengmeister | **Durchschuss:** Der nächste Schuss durchdringt alle Gegner in einer Linie (20 s) |
| 4 · Meister | Berserker + Merkmal-Stufe 2 für alle Kampf-Merkmale | **Einsturz:** Die Decke über einem Zielbereich bricht ein, schwerer Schaden und Betäubung (120 s) |

**Unterstützung** – Team, Bauen, Übersicht

| Stufe | Merkmal (passiv) | Aktive Fähigkeit (Cooldown) |
| --- | --- | --- |
| Start | Flinkfuß | **Schichtruf:** Das Team erhält 8 s +20 % Tempo (30 s) |
| 1 | Mechaniker | **Schnellreparatur:** Repariert Bauelemente im Umkreis um 40 % (30 s) |
| 2 | Sanitäter | **Leuchtfackel:** Geworfenes Licht deckt 15 s unsichtbare Gegner auf (20 s) |
| 3 | Späher | **Rettungsseil:** Belebt einen gefallenen Mitspieler sofort aus der Ferne wieder (90 s) |
| 4 · Meister | Glückspilz + Merkmal-Stufe 2 für alle Unterstützungs-Merkmale | **Überstunden:** Alle Bauelemente feuern und arbeiten 10 s doppelt so schnell (120 s) |

Alle Bäume zusammen kosten 24 Punkte, also etwa 24 Charakter-Level. Dauerhafte Stärke-Boni bleiben klein (max. +10 % auf einen Wert), damit Runs fair bleiben und neue Spieler mit erfahrenen mithalten können. Kosmetik wie Helme und Spitzhacken-Skins gibt es zusätzlich über Erfolge.

## Gegner

Gegner kommen aus der Tiefe und haben je ein klares Ziel – Aufzug, Erz, Bauelemente oder Spieler –, damit jeder Typ eine andere Verteidigung verlangt.

### Gegnertypen

| Gegner | Ziel | Fähigkeit | Konter | Ab Runde |
| --- | --- | --- | --- | --- |
| Höhlenkrabbler | Aufzug | Schnell, schwach, kommt in Schwärmen | Flächenschaden, Fallen | 1 |
| Steingolem | Aufzug | Viel HP, ignoriert Verlangsamung | Fokus-Feuer, Sprengstoff | 3 |
| Erzdieb (Kobold) | Liegendes Erz, Items auf Förderbändern | Stiehlt nur Materialien und flieht zurück zum Schacht; beschädigt Bauelemente nur, wenn kein direkter Weg zum Aufzug besteht | Erz schnell abliefern, Lagertruhen, Raufbold | 2 |
| Grubengas-Geist | Spieler | Unsichtbar außerhalb von Lichtquellen | Lichtquellen, Späher | 4 |
| Wühler | Bauelemente | Gräbt sich unter Mauern hindurch, taucht hinter der Verteidigung auf | Fallen in der Tiefe, Klingenwirbel | 5 |
| Schamane | Andere Gegner | Heilt und schildet Gegner in der Nähe | Priorisieren, Fernkampf | 6 |
| Säurespucker | Türme | Fernkampf, zersetzt Bauelemente | Mauern als Deckung, Nahkampf | 7 |
| Sprengkäfer | Mauern | Explodiert bei Kontakt, großer Schaden an Gebäuden | Geschütztürme, Mörser | 8 |

### Bosse

- **Runde 5 – Felsenwurm:** Taucht an zufälligen Stellen auf und bricht neue Gänge in die Mine.
- **Runde 10 – Koboldkönig:** Ruft Erzdiebe, plündert gezielt den Aufzug.
- **Runde 15 – Der Uralte:** Mehrphasig; verdunkelt die Mine, lässt Decken einstürzen.

### Wellen-Design

- Wellen werden aus einem Punkte-Budget erzeugt, das pro Runde wächst (z. B. Budget = 20 × Runde^1,2). Jeder Gegner hat Kosten.
- Jede Welle hat 1–2 Haupttypen, damit sie lesbar bleibt, und kommt aus 1–3 Schächten.
- Die Vorschau in der Bauphase zeigt Typen und Eingänge, aber nicht die genaue Anzahl.
- **Modifikatoren** ab Runde 6 (zufällig): "Gepanzert", "Schnell", "Explodiert beim Tod" – vergleichbar mit Mutatoren in Dungeon Defenders.

## Roguelike-Progression & Meta-Progression

Innerhalb eines Runs wächst die Mine; zwischen Runs wächst vor allem die Auswahl und nur leicht die rohe Stärke, damit jeder Run fair bleibt.

### Im Run

- Bauelemente, Ausrüstung und Merkmal-Verbesserungen sammeln sich über 15 Runden an.
- Nach jeder Boss-Runde wählt das Team eine von drei **Minen-Erweiterungen** (z. B. neuer Stollen mit Kristall-Vorkommen, aber zusätzlichem Gegner-Eingang).
- Nach dem Run ist alles weg.

### Zwischen Runs (Meta)

- **Skillbäume:** Charakter-XP gibt Skillpunkte für drei Skillbäume mit Merkmalen und aktiven Fähigkeiten (siehe Merkmale, Fähigkeiten & Skillbäume).
- **Freischaltungen über Erfolge:** Neue Bauelemente kommen in den Pool (z. B. "Besiege 100 Erzdiebe" → Erzfalle).
- **Minen-Auswahl:** Mehrere Minen-Biome (Kohlemine, Eishöhle, Lavastollen) mit eigenen Gegnern und Erzen.
- **Mutationen:** Vor jedem Run stellt das Team Mutationen ein, die den Run leichter oder schwerer machen. Schwerere Runs geben mehr Charakter-XP (siehe Mutationen).
- Optional ein **Hub** (Bergarbeiter-Siedlung) wie das Franchise-Haus in PlateUp, in dem Spieler sich zwischen Runs treffen.

### Mutationen

Mutationen sind Modifikatoren, die das Team vor dem Run in der Lobby auswählt. Jede hat einen Schwierigkeitswert; die Summe aller gewählten Mutationen ergibt die Schwierigkeit des Runs und damit den XP-Bonus (z. B. +10 % Charakter-XP pro Punkt, bei negativer Summe entsprechend weniger).

| Mutation | Effekt | Schwierigkeit |
| --- | --- | --- |
| Horden | +50 % Gegner pro Welle | +3 |
| Ruhige Schicht | −25 % Gegner pro Welle | −2 |
| Dicke Haut | +30 % Gegner-Lebenspunkte | +2 |
| Erzarm | −30 % Erzvorkommen | +2 |
| Reiche Adern | +30 % Erzvorkommen | −2 |
| Zerbrechlich | −25 % Spieler-Lebenspunkte | +2 |
| Robuster Aufzug | +50 % Aufzug-Lebenspunkte | −2 |
| Stechuhr | Bauphase hat ein Zeitlimit von 60 s | +3 |
| Feierabend | Bauen nur in der Bauphase | +2 |
| Teure Würfel | Rerolls kosten das Doppelte | +1 |
| Knappe Auswahl | Bauelemente-Shop zeigt nur 3 Angebote | +1 |
| Dunkle Stollen | Lichtquellen brennen nur halb so lange | +1 |

- Zum Start ist nur ein Teil der Mutationen verfügbar; weitere werden über Erfolge freigeschaltet.
- Voreinstellungen wie "Entspannt", "Normal" und "Hart" sind vorgefertigte Kombinationen für Spieler, die nicht selbst basteln wollen.
- Die gewählten Mutationen und der Schwierigkeitswert werden am Run-Ende angezeigt, damit Teams ihre Bestleistungen vergleichen können.

## Koop & Multiplayer

Das Spiel nutzt Godots High-Level-Multiplayer mit Host-Client-Modell (ein Spieler ist Server), und Multiplayer wird ab dem ersten Prototyp mitgebaut, nicht nachträglich.

### Skalierung nach Spielerzahl

| Spieler | Gegner-HP | Gegner-Anzahl | Erz-Vorkommen |
| --- | --- | --- | --- |
| 1 | 100 % | 100 % | 100 % |
| 2 | 115 % | 150 % | 130 % |
| 3 | 130 % | 200 % | 160 % |
| 4 | 145 % | 250 % | 190 % |

Solo-Spieler erhalten zusätzlich einen kleinen Helfer (z. B. einen Grubenpony-Transporter), damit Abbau und Kampf allein machbar bleiben.

### Netzwerk-Architektur

- **Server-autoritativ:** Der Host berechnet Gegner-KI, Schaden, Geld und Shop-Zufall. Clients senden nur Eingaben und Kaufwünsche.
- **Synchronisierung:** `MultiplayerSpawner` für Gegner, Bauelemente und Erzbrocken; `MultiplayerSynchronizer` für Positionen und HP.
- **Spielerbewegung:** Client-seitige Vorhersage für die eigene Figur, damit sich Steuerung direkt anfühlt.
- **Verbindung:** ENet zum Testen im LAN; für Steam später GodotSteam (Lobbys, Freundes-Einladungen, P2P-Relay).
- **Seed:** Der Run nutzt einen gemeinsamen Zufalls-Seed, den der Host bestimmt.

## Level-Design

Jede Mine wird aus handgebauten Raum-Modulen zusammengesetzt, die pro Run zufällig angeordnet werden; der Aufzug steht immer im Zentrum oder oben.

### Aufbau

- **Aufzugshalle:** Startpunkt, Shop-Kisten erscheinen hier, letzter Verteidigungspunkt.
- **Stollen:** Gänge mit Bauplätzen und Erzvorkommen. Engstellen sind gute Fallen-Standorte.
- **Kammern:** Größere Räume mit vielen Erzvorkommen, aber mehreren Zugängen.
- **Schächte:** Gegner-Eingänge am Rand der Mine. Neue Schächte öffnen sich im Laufe des Runs.

### Prozedurale Generierung (einfacher Ansatz)

1. Module (z. B. 10×10 m) als eigene Godot-Szenen mit markierten Anschlusspunkten bauen.
2. Ein Generator setzt vom Aufzug aus Module an freie Anschlüsse, bis eine Zielgröße erreicht ist.
3. Endpunkte werden zu Schächten oder Erzkammern.
4. Danach die `NavigationRegion3D` neu backen, damit Gegner die Wege kennen.

Für den Prototyp reicht eine einzige, handgebaute Mine. Die Generierung kommt erst, wenn der Loop Spaß macht.

### Atmosphäre

Dunkelheit ist eine Mechanik: Licht kommt von Laternen, Helmlampen und Lava. Der Low-Poly-Stil mit flachen Farben und starken Lichtkontrasten hält Aufwand und Performance im Rahmen (siehe Performance-Ziele).

## Technische Umsetzung in Godot 4

Die Architektur trennt Daten (Resources), Logik (Komponenten-Szenen) und globalen Spielzustand (Autoloads), damit KI-generierter Code in kleinen, unabhängigen Teilen entstehen kann.

### Ordnerstruktur

```
res://
  autoload/        GameState.gd, RunManager.gd, Economy.gd, NetworkManager.gd
  data/            .tres-Dateien: ores/, buildables/, enemies/, traits/, items/
  scenes/
    player/        Player.tscn, PlayerCamera.tscn
    enemies/       EnemyBase.tscn + Varianten
    buildables/    TowerBase.tscn, TrapBase.tscn, Barricade.tscn
    world/         Elevator.tscn, OreDeposit.tscn, OreChunk.tscn, mine_modules/
    ui/            HUD.tscn, Shop.tscn, TraitSelect.tscn
  components/      HealthComponent, HitboxComponent, CarryComponent, AbilityComponent
  scripts/         Hilfsklassen, WaveGenerator.gd, MineGenerator.gd
```

### Kern-Systeme

| System | Godot-Bausteine | Aufgabe |
| --- | --- | --- |
| Spielfigur | `CharacterBody3D`, `SpringArm3D` + `Camera3D` | 3rd-Person-Bewegung, Kamera, Interaktion |
| Daten | Eigene `Resource`-Klassen (`OreData`, `EnemyData`, `BuildableData`, `TraitData`, `RecipeData`) | Alle Werte ohne Code änderbar |
| Komponenten | Kind-Nodes mit eigenem Skript | Lebenspunkte, Tragen, Fähigkeiten wiederverwendbar |
| Gegner-KI | `NavigationAgent3D`, einfache State Machine | Ziel suchen, laufen, angreifen, Fähigkeit nutzen |
| Runden-Ablauf | `RunManager`-Autoload, Signale | Phasen wechseln, Wellen starten, Shops schließen, Auszahlung |
| Shop | `Economy`-Autoload, gewichteter Zufall mit Seed | Angebote, Reroll, Kauf |
| Bauen | Raster-Vorschau mit Raycast, `NavigationRegion3D`-Rebake | Platzieren, Wege aktualisieren |
| Logistik | Ein `BeltManager` mit reinen Daten, Darstellung über `MultiMeshInstance3D` | Items bewegen, aufteilen, filtern – ohne Physik |
| Crafting | `ItemSlot`-Komponente (Ein-/Ausgang), Timer pro Station | Rezepte verarbeiten, an Förderbänder übergeben |
| Multiplayer | `MultiplayerSpawner`, `MultiplayerSynchronizer`, RPCs | Host-autoritative Synchronisierung |

### Regeln für sauberen Code

- Kommunikation über **Signale** statt direkter Verweise ("Call down, signal up").
- Jeder Gegner, jeder Turm erbt von einer Basis-Szene und unterscheidet sich vor allem über seine Resource.
- Typisiertes GDScript (`var hp: int = 100`) verwenden; das hilft auch der KI, Fehler zu vermeiden.
- Versionskontrolle mit Git von Tag 1 an.

### Performance-Ziele

Ziel sind stabile 60 FPS mit 4 Spielern, vielen Gegnern und vollen Förderbändern auf einem Mittelklasse-PC.

- **Modelle:** Low-Poly mit wenigen Materialien; Farben über eine gemeinsame Palette-Textur, damit viele Objekte dasselbe Material teilen.
- **Viele gleiche Objekte:** Items auf Förderbändern und Projektile über `MultiMeshInstance3D` statt einzelner Nodes darstellen.
- **Licht:** Dunkelheit ist eine Mechanik, aber dynamische Schatten sind teuer. Nur wenige Lichtquellen werfen Schatten, Fackeln und Laternen leuchten ohne Schatten.
- **Sichtweite:** `visibility_range` an Objekten nutzen, damit entfernte Details in langen Stollen nicht gezeichnet werden.
- **Simulation:** Förderbänder, Crafting und Gegner-KI laufen in festen Ticks (z. B. 10–20 pro Sekunde) statt jeden Frame.
- **Netzwerk:** Items auf Förderbändern nicht einzeln synchronisieren, sondern nur den Zustand der Bänder; jeder Client simuliert den Rest selbst.
- **Früh messen:** Ab dem Prototyp regelmäßig mit dem Godot-Profiler und einer Stress-Szene (200 Gegner, 500 Items) testen.

### Förderbänder ohne Physik

Förderbänder simulieren Items als reine Daten und zeigen ihre Bewegung nur visuell an. Kein Item auf einem Förderband hat einen `RigidBody3D`, eine `Area3D` oder eine eigene Node.

1. **Daten:** Ein `BeltManager` (Autoload oder Node in der Mine) speichert alle Förderbänder als Stränge auf dem Raster. Jedes Item ist nur ein Eintrag aus Item-Typ und Fortschritt (0,0 bis 1,0) auf seiner Zelle.
2. **Simulation:** In festen Ticks (z. B. 10 pro Sekunde) rücken Items vor. Ist die nächste Zelle voll, bleibt das Item stehen, und es entsteht ein Stau. Weichen, Sortierer und Stationen sind nur Regeln an Zellübergängen.
3. **Darstellung:** Pro Item-Typ zeichnet eine `MultiMeshInstance3D` alle Items in einem einzigen Draw Call. Jeden Frame wird die Position zwischen zwei Ticks interpoliert, damit die Bewegung flüssig aussieht.
4. **Übergänge:** Hebt ein Spieler ein Item auf oder fällt eines vom Band, entsteht erst dann eine echte Node. Magnete und Schleudern bewegen Items über eine Tween-Kurve statt über Physik.
5. **Netzwerk:** Nur Bau-Aktionen und Eingriffe (Aufheben, Diebstahl) werden synchronisiert. Weil die Simulation deterministisch ist, rechnet jeder Client die Bewegung selbst; der Host schickt alle paar Sekunden einen Abgleich.

## Arbeiten mit KI

KI liefert die besten Ergebnisse, wenn jede Anfrage ein kleines, klar abgegrenztes System betrifft und dieses Dokument als Kontext mitbekommt.

### Workflow

1. Dieses Dokument (oder den passenden Abschnitt) zu Beginn jeder KI-Sitzung mitgeben.
2. Ein System pro Anfrage, z. B. "HealthComponent" oder "Erz tragen", nie "baue das ganze Spiel".
3. Code in Godot testen, Fehlermeldungen vollständig zurück an die KI geben.
4. Funktionierende Stände sofort mit Git sichern.
5. Bei größeren Projekten ein Coding-Tool mit Zugriff auf den Projektordner nutzen (z. B. Claude Code), damit die KI mehrere Dateien gleichzeitig sieht und bearbeiten kann.

### Gute Prompts

- Godot-Version nennen ("Godot 4.7, GDScript, typisiert"), da sich Godot 3 und 4 stark unterscheiden.
- Node-Struktur der Szene beschreiben oder mitschicken.
- Gewünschte Schnittstellen nennen: "Sendet Signal `died`, liest Werte aus `EnemyData`".
- Um Erklärungen bitten, damit du den Code verstehst und später selbst anpassen kannst.

### Was die KI gut kann, was du selbst machen solltest

| KI übernimmt gut | Selbst machen oder eng prüfen |
| --- | --- |
| Skripte, State Machines, UI-Logik | Szenen im Editor zusammenklicken |
| Wellen-Formeln, Balancing-Tabellen | Spielgefühl testen und tunen |
| Shader-Grundlagen, Hilfsfunktionen | Multiplayer-Bugs (genau testen) |
| Ideen für Gegner, Items, Namen | Finale Design-Entscheidungen |

3D-Modelle lassen sich für den Anfang aus freien Paketen (z. B. Kenney, Quaternius) oder mit KI-3D-Tools erzeugen; Lizenz jeweils prüfen.

## Roadmap

&#91;embedded content: Roadmap · 4 Phasen, 3 Gates\]

Phase 1 ist der aktuelle Fokus: Erst wenn Testspieler freiwillig eine zweite Runde wollen, lohnt sich mehr Inhalt.

## Prototyp-Plan

Der Prototyp (Phase 1 der Roadmap) entsteht in 15 Aufgaben; jede ist ein abgegrenztes System, das sich in einer KI-Sitzung umsetzen und sofort testen lässt, und Multiplayer ist ab Aufgabe 3 immer dabei.

### Aufgaben

| Nr. | Aufgabe | Fertig, wenn … |
| --- | --- | --- |
| 1 | **Projektgerüst:** Ordnerstruktur, leere Autoloads, Input Map, Git | Projekt startet, Main-Szene lädt, erster Commit ist gepusht |
| 2 | **Spielfigur & Kamera:** `CharacterBody3D`, `SpringArm3D`, Maus und Controller | Figur läuft und springt durch einen Testraum, Kamera clippt nicht durch Wände |
| 3 | **Netzwerk-Basis:** `NetworkManager`, Host/Join über ENet, Spieler-Spawning | Zwei Instanzen auf einem PC sehen sich gegenseitig flüssig laufen |
| 4 | **Interaktion:** `InteractableComponent`, Raycast, Prompt im HUD | "E: Abbauen" erscheint vor Objekten, Aktion läuft über den Host |
| 5 | **Erzvorkommen & Abbau:** `OreDeposit` mit `OreData` | Nach X Schlägen fällt ein Brocken, bei beiden Spielern sichtbar |
| 6 | **Tragen & Ablegen:** `CarryComponent`, Gewicht | Brocken tragen, ablegen, werfen; schwere Erze verlangsamen |
| 7 | **Aufzug & Teamkasse:** `Elevator`, `Economy` | Abgelegte Brocken werden gezählt, Geld erscheint im HUD |
| 8 | **Runden-Ablauf:** `RunManager`, Bau- und Kampfphase, Ready-Check | Phasen wechseln sauber, Auszahlung zu Rundenbeginn |
| 9 | **Gegner-Basis:** `EnemyBase`, `NavigationAgent3D`, `HealthComponent` | Höhlenkrabbler laufen zum Aufzug und verursachen Schaden |
| 10 | **Spieler-Kampf:** Spitzhacke als Nahkampfwaffe, Trefferfeedback | Gegner sterben, Treffer fühlen sich wuchtig an |
| 11 | **Bausystem:** Rastervorschau, Platzieren, Navigation neu backen | Mauern lenken Gegner sichtbar um |
| 12 | **Verteidigung:** Geschützturm (mit/ohne Munition), Klingenwirbel, Stachelfalle | Alle drei wirken, Munitionsbalken funktioniert |
| 13 | **Wellen & Erzdieb:** Budget-Generator, zweiter Gegnertyp, Sieg/Niederlage | 5 Runden spielbar, Erzdieb stiehlt und flieht |
| 14 | **Shop & Merkmale:** 4 Zufallsangebote, Blaupausen-Kisten, Hauer und Raufbold | Kaufen, Kiste tragen, aufbauen; Merkmale vor dem Run wählbar |
| 15 | **Technik-Test Förderband:** `BeltManager` nach dem Konzept oben | 500 Items laufen mit 60 FPS und synchron bei zwei Spielern |

Aufgabe 15 gehört nicht zum spielbaren Prototyp, sondern prüft früh das größte technische Risiko. Sie kann parallel ab Aufgabe 7 laufen.

### Steuerung

| Aktion | Maus/Tastatur | Controller |
| --- | --- | --- |
| Bewegen | WASD | Linker Stick |
| Kamera | Maus | Rechter Stick |
| Springen | Leertaste | A |
| Sprinten | Shift | Linken Stick drücken |
| Abbauen / Angreifen | Linksklick | RT |
| Zielen / Fernkampf | Rechtsklick | LT |
| Interagieren (Aufheben, Ablegen, Station, Shop) | E | X |
| Baumodus an/aus | B | Y |
| Bauelement drehen (im Baumodus) | R / Mausrad | LB / RB |
| Aktive Fähigkeit | Q | LB (außerhalb des Baumodus) |
| Ping / Markieren | Mittlere Maustaste | Steuerkreuz unten |
| Bereit (Ready-Check) | F | Steuerkreuz oben |
| Wellenvorschau / Spielerliste | Tab gedrückt halten | Select / View |
| Menü | Esc | Start / Menu |

Alle Aktionen laufen über die Godot-Input-Map, damit Spieler später umbelegen können.

### Startwerte

| Wert | Startwert | Hinweis |
| --- | --- | --- |
| Laufgeschwindigkeit | 5 m/s | Sprint 7,5 m/s |
| Sprunghöhe | 1 m | Reicht für Stufen und Schienen, nicht über Mauern |
| Tragen | Schwer −30 %, sehr schwer −50 % Tempo | Kein Sprinten beim Tragen |
| Kamera | 4 m Abstand, 0,6 m Schulterversatz rechts, 75° Sichtfeld | Abstand im Baumodus 7 m |
| Rasterzelle | 2 m | Gilt für Bauen und Förderbänder |
| Interaktionsreichweite | 2,5 m |  |
| Spieler-Lebenspunkte | 100 | Respawn nach 10 s |
| Aufzug-Lebenspunkte | 500 |  |
| Höhlenkrabbler | 30 LP, 4 m/s, 5 Schaden am Aufzug |  |
| Spitzhacke | 15 Schaden, 1,5 Schläge/s | Auch zum Abbauen |
| Geschützturm | 15 m Reichweite, 10 Schaden, 2 Schuss/s | Ohne Munition 2,5 Schaden, 1 Schuss/s |
| Simulations-Tick | 20 pro Sekunde | Gegner-KI, Förderbänder, Stationen |

### Prototyp-Mine

Eine einzige handgebaute Mine reicht: Die Aufzugshalle liegt oben, der Schacht unten, und zwei etwa 30 m lange Stollen verbinden beide. Gegner wählen den kürzeren oder weniger verbauten Weg, deshalb muss das Team beide Stollen im Blick behalten.

&#91;embedded content: Prototyp-Mine · Draufsicht, nicht maßstabsgetreu\]

Gebaut wird mit `CSGBox3D`-Nodes oder einer `GridMap` aus einfachen Würfeln; jeder Stollen bekommt eine Engstelle als Fallen-Standort. Wertvolleres Erz liegt näher am Schacht, damit Gier gegen Sicherheit schon im Prototyp spürbar ist.

### Playtest am Gate

- **Tester:** 4–6 Personen, die das Spiel nicht kennen, in Zweiergruppen.
- **Ablauf:** Jede Gruppe spielt einen Run ohne Erklärung. Du schaust nur zu und notierst, wo sie hängen bleiben.
- **Fragen danach:** Wollt ihr noch eine Runde? Was war der spannendste Moment? Was war unklar oder nervig?
- **Gate erfüllt,** wenn mindestens die Hälfte der Gruppen freiwillig weiterspielen will.

## Offene Fragen

- [ ] Welche der vorgeschlagenen Merkmale kommen ins Spiel?
- [ ] Welche Mutationen sind zum Start verfügbar, und welche werden über Erfolge freigeschaltet?
- [ ] Wie viele Förderbänder und Items gleichzeitig verträgt der Multiplayer? Früh mit einem Stresstest prüfen.
- [ ] Endgültiger Spieltitel?
