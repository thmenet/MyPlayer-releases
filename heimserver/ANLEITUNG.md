# MyPlayer-Heimserver einrichten (Proxmox + Synology)

Der Heimserver ist derselbe MyPlayer wie auf dem PC – nur ohne Fenster, dauernd laufend und für alle Geräte im Heimnetz.
Die Hörbücher (und später die Musik) liest er **nur** vom NAS; verändert wird dort nichts.

```
Synology (NFS, nur lesen) ──▶ Proxmox-Host (bindet den NAS-Ordner ein) ──▶ Container «myplayer» (MyPlayer läuft hier)
                                                                              └──▶ Browser auf PC/Handy: http://myplayer:48219
```

Dauer: etwa 20 Minuten. Platzhalter in `<spitzen Klammern>` durch deine Werte ersetzen.

## 1. Synology: Ordner per NFS freigeben

1. **Systemsteuerung → Dateidienste → NFS**: «NFS-Dienst aktivieren» ankreuzen, Übernehmen.
2. **Systemsteuerung → Freigegebener Ordner** → Ordner mit den Hörbüchern (z. B. `Hoerbuecher`) → **Bearbeiten → NFS-Berechtigungen → Erstellen**:
   - Hostname oder IP: **IP-Adresse des Proxmox** (z. B. `192.168.1.10`)
   - Berechtigung: **Schreibgeschützt**
   - Squash: **Alle Benutzer zu admin zuordnen** (damit Proxmox alle Dateien lesen darf)
   - Sicherheit: `sys` · Asynchron: ja
3. Unten im Fenster steht der **Einhängepfad**, z. B. `/volume1/Hoerbuecher` – notieren.
4. Für die Musik (FLAC) später dasselbe mit dem Musik-Ordner.

## 2. Proxmox-Host: NAS-Ordner einbinden

Im Proxmox-Webinterface links den **Host** (nicht den Container) wählen → **Shell**:

```bash
apt install -y nfs-common
mkdir -p /mnt/nas/hoerbuecher
echo "<NAS-IP>:/volume1/Hoerbuecher /mnt/nas/hoerbuecher nfs ro,soft,_netdev 0 0" >> /etc/fstab
systemctl daemon-reload && mount -a
ls /mnt/nas/hoerbuecher | head      # hier müssen deine Hörbücher erscheinen
```

(Warum auf dem Host? Ein normaler, «unprivilegierter» Container darf selbst keine NFS-Freigaben einbinden – der Host reicht den Ordner weiter.)

## 3. Container anlegen

1. **local → CT-Vorlagen → Vorlagen**: `debian-13-standard` herunterladen (falls noch nicht vorhanden).
2. Oben rechts **CT erstellen**:
   - Hostname: `myplayer` · Passwort setzen · «Unprivilegierter Container» angekreuzt lassen
   - Vorlage: debian-13-standard
   - Disk: 8 GB · CPU: 1 Kern · Speicher: 1024 MB
   - Netzwerk: DHCP (oder feste IP, dann ist die Adresse immer gleich)
3. **Noch nicht starten.** In der Host-Shell den NAS-Ordner in den Container reichen (`<ID>` = Nummer des Containers, z. B. 105):

```bash
pct set <ID> -mp0 /mnt/nas/hoerbuecher,mp=/mnt/hoerbuecher,ro=1
pct start <ID>
```

   Später für Musik: `pct set <ID> -mp1 /mnt/nas/musik,mp=/mnt/musik,ro=1` · für einen eigenen Podcast-Ordner `…,mp=/mnt/podcasts,ro=1`.

## 4. MyPlayer installieren

Container wählen → **Konsole** → als `root` anmelden → diesen einen Befehl:

```bash
apt update && apt install -y curl && bash <(curl -fsSL https://raw.githubusercontent.com/thmenet/MyPlayer-releases/main/heimserver/installieren.sh)
```

Am Schluss steht die Adresse, z. B. `http://192.168.1.50:48219`. Das Skript richtet einen Dienst ein: MyPlayer startet mit dem Container
und nach jedem Update von selbst. `/mnt/hoerbuecher` ist bereits als Bibliothek eingetragen.

## 5. Benutzen

- Im Browser die Adresse öffnen → **«Wer hört?»** → für jede Person ein Profil anlegen (ohne PIN).
- **Auf dem Handy:** Adresse in Safari öffnen → Teilen → «Zum Home-Bildschirm».
- **player.menet.ch verbinden** (für unterwegs): im eigenen Profil → Zahnrad → player.menet.ch → Code eingeben
  (Code auf player.menet.ch → Geräte → «Code erzeugen»). Jedes Profil verbindet sein eigenes Konto.
- **Updates:** wie beim PC-Player über den Hinweis «Neue Version» in der Oberfläche – oder das Installations-Skript nochmals ausführen.

## Hilfe

| Was | Befehl in der Container-Konsole |
|---|---|
| Läuft der Dienst? | `systemctl status myplayer` |
| Protokoll ansehen | `journalctl -u myplayer -n 50` |
| Neu starten | `systemctl restart myplayer` |
| Sieht der Container die Hörbücher? | `ls /mnt/hoerbuecher` |

- **Seite lädt nicht:** Läuft der Dienst? Stimmt die Adresse (IP des Containers, Port 48219)?
- **Bibliothek leer:** `ls /mnt/hoerbuecher` zeigt nichts → Schritt 2/3 prüfen (NFS-Berechtigung für die Proxmox-IP, `mount -a` auf dem Host).
- **«Zugriff verweigert» beim Lesen:** Squash in Schritt 1.2 auf «Alle Benutzer zu admin zuordnen» stellen.
- **Aufruf über einen eigenen Namen** (z. B. `myplayer.fritz.box`) wird abgelehnt: der Heimserver nimmt aus Sicherheitsgründen nur IP-Adressen und
  seinen eigenen Namen an. Weitere Namen in `/etc/systemd/system/myplayer.service` ergänzen: `Environment=MYPLAYER_HOSTS=myplayer.fritz.box`,
  dann `systemctl daemon-reload && systemctl restart myplayer`.
