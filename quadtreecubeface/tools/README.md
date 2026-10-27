# Screenshot-Werkzeug

Startet `game_world.tscn`, setzt Kamera und LOD-Fokus per Kommandozeile und speichert ein PNG.
Damit kann Claude (oder du) den Planeten ohne Editor prüfen, vor allem die Übergänge zwischen LOD-Stufen.

Das Spiel läuft dafür kurz in einem normalen Fenster (nicht `--headless`, sonst gibt es kein Bild).

```bash
godot --path . --resolution 1280x720 res://tools/shot.tscn -- --out=C:/Temp/bild.png --cam=0,95,28 --look=0,67,0 --focus=0,67,0 --wire
```

| Option | Bedeutung | Standard |
|---|---|---|
| `--out=` | Zieldatei (PNG, absoluter Pfad) | Pflicht |
| `--cam=x,y,z` | Kameraposition | `0,0,200` |
| `--look=x,y,z` | Blickpunkt | `0,0,0` |
| `--focus=x,y,z` | LOD-Fokus (Spielerposition); bestimmt, wo der Planet fein aufgelöst wird | Position aus der Szene |
| `--fov=` | Sichtfeld in Grad | `70` |
| `--wire` | Drahtgitter statt Fläche (Lücken und Übergänge erkennen) | aus |
| `--frames=` | Frames bis zum Foto, damit der Quadtree fertig aufgebaut ist | `8` |
| `--scene=res://...` | Andere Szene statt game_world.tscn, z. B. `res://test_planet.tscn` (braucht einen Knoten `Camera` und `Planet`) | game_world.tscn |
| `--noise` | Testgebirge einschalten (ohne Rauschen ist der Planet eine glatte Kugel) | aus |
| `--check` | Rissprüfer: zählt Randpunkte von Chunks, die nicht auf dem Rand eines Nachbarn liegen | aus |
| `--bench` | Misst die Zeit pro LOD-Aktualisierung beim Wandern über die Oberfläche | aus |

Die Ausgabe nennt Chunk-Anzahl, Fokus, Kamera und Höhenbereich. Der Planet hat Radius 67.

## Rissprüfer

`--check` arbeitet nur mit den fertigen Meshes. Eine Zeile wie

```
check: chunks=156 randpunkte=1408 luecken=0 max_abstand=0.000
```

heißt: Jeder Randpunkt liegt auf dem Rand eines anderen Chunks, der Planet ist an den
LOD-Grenzen dicht. `luecken` größer als 0 bedeutet sichtbare Risse. Gute Ansichten zum Prüfen:
Fokus auf einer Würfelkante (`--focus=47.38,47.38,0`) oder einer Würfelecke
(`--focus=38.68,38.68,38.68`), weil dort mehrere Würfelseiten aufeinandertreffen.

## Testplanet zum Ausprobieren

`test_planet.tscn` im Projektordner ist ein Planet mit Meeren, Inseln und Gebirgen und einer Flugkamera.
Im Godot-Editor öffnen und mit **F6** starten. Steuerung steht oben in `test_planet.gd` und links oben im Bild.
Mit dem Screenshot-Werkzeug: `--scene=res://test_planet.tscn --cam=... --look=...`.

Die LOD-Tabelle der Testszene geht bis auf Chunks von etwa 0,2 Einheiten Kantenlänge (rund 2,5 cm Punktabstand)
um den Spieler (Spieler = ca. 1 Einheit hoch). Die Tabelle steht im Inspektor unter *Planet > Planet Data > Lod Levels*.
Der Neuaufbau läuft auf mehrere Frames verteilt (`Planet.build_budget_ms`, in der Testszene 8 ms), der alte
Planet bleibt bis zum Umschalten sichtbar. Beim Schweben (G / H) liegt der Neuaufbau etwa 0,3 bis 0,5 s hinter der
Kamera, die Frames bleiben bei 60 fps.

Der Weg über `res://tools/shot.tscn` braucht keine Änderung an `project.godot`.
