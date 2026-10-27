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

Die Ausgabe nennt Chunk-Anzahl, Fokus, Kamera und Höhenbereich. Der Planet hat Radius 67.

Der Weg über `res://tools/shot.tscn` braucht keine Änderung an `project.godot`.
