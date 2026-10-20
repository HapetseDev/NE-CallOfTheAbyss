# JSON-Beispiele für Attribute, Talente und Regeln

Hier liegen 32 zusammenhängende Beispieldateien zum Experimentieren. Einstieg und
Formatbeschreibung: [Anleitung](../../../docs/CHARAKTERREGELN_JSON_BEISPIELE.md).

**Entwurf, noch kein aktives Spielformat.** Es gibt derzeit keinen Importer für
diesen Ordner. Keine Datei verändert bestehende Figuren, Dialoge oder Kämpfe.
Alle Dateien tragen deshalb `status: "example_draft"`. Das Entfernen dieses
Feldes aktiviert nichts. Zahlen und zusätzliche Mechaniken sind Vorschläge.

- `attributes/`: sieben Attribute.
- `skills/`: sieben Talente mit Höchststufe 20.
- `conditions/`: sechs wiederverwendbare, kombinierte Voraussetzungen.
- `actions/`: sechs Aktionen mit Kosten, Reichweite und Effekten.
- `rules/`: sechs Zuordnungen von Voraussetzungen zu angebotenen oder ersetzten Aktionen/Dialogoptionen.

Eine Datei pro Definition; Dateiname und `id` stimmen überein. Beim Kopieren
beides ändern und danach alle gewünschten Verweise anpassen. JSON erlaubt keine
Kommentare; Erklärungen stehen in `description` und in der Anleitung.
