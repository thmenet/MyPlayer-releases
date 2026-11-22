# MyPlayer – Downloads

Hörbuch- und Podcast-Player für Windows: Bibliothek mit Covern, Kapitel, Lesezeichen,
Favoriten, Archiv, Schlaf-Timer, Tempo 0.7–2.0 und automatisches Weiterhören.

**Download:** unter [Releases](https://github.com/thmenet/MyPlayer-releases/releases/latest)

1. `Hoerbuchplayer-x.y.z.zip` herunterladen und entpacken (Rechtsklick → «Alle extrahieren»).
2. `installieren.bat` doppelklicken. Danach im Startmenü unter «MyPlayer».
   Voraussetzung: Python von python.org.

Updates holt der Player selbst («Neue Version verfügbar» → «Jetzt aktualisieren»).
Fortschritt, Lesezeichen und Einstellungen bleiben auf dem eigenen Rechner (`%APPDATA%\Hoerbuchplayer`).

## Heimserver (Proxmox / Linux)

MyPlayer kann auch ohne Fenster dauernd im Heimnetz laufen (z. B. in einem Proxmox-Container) und die Hörbücher vom NAS lesen –
mit Profilen für jede Person. Anleitung: [heimserver/ANLEITUNG.md](heimserver/ANLEITUNG.md). Installation im Container als root:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/thmenet/MyPlayer-releases/main/heimserver/installieren.sh)
```
