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

### Variante: Windows-Freigabe (SMB) statt NFS

Geht ohne Einstellungen auf der Synology – mit einem normalen NAS-Benutzer, der die Ordner lesen darf (z. B. so, wie du sie unter Windows als
`\\MenetStation\music` siehst). Dann Schritt 1 und 2 durch das hier ersetzen (in der **Host**-Shell):

```bash
apt install -y cifs-utils
mkdir -p /mnt/nas/hoerbuecher /mnt/nas/musik
nano /root/.smb-nas
```

In den Editor diese zwei Zeilen schreiben, dann speichern mit **Strg+O, Enter, Strg+X**:

```
username=<NAS-Benutzer>
password=<Passwort>
```

```bash
chmod 600 /root/.smb-nas
OPT="credentials=/root/.smb-nas,ro,vers=3.0,iocharset=utf8,file_mode=0444,dir_mode=0555,_netdev,nofail"
echo "//MenetStation/Hoerbuecher /mnt/nas/hoerbuecher cifs $OPT 0 0" >> /etc/fstab
echo "//MenetStation/music       /mnt/nas/musik       cifs $OPT 0 0" >> /etc/fstab
systemctl daemon-reload && mount -a
ls /mnt/nas/hoerbuecher | head      # hier müssen deine Hörbücher erscheinen
```

- Findet der Proxmox den Namen `MenetStation` nicht («could not resolve address»): statt `MenetStation` die **IP-Adresse** der Synology einsetzen.
- Das Passwort steht nur auf dem Proxmox-Host (`/root/.smb-nas`, nur für root lesbar). Sauberer ist später ein eigener NAS-Benutzer
  «myplayer» mit nur Leserechten – dafür braucht es den Admin-Zugang.
- Dann bei Schritt 3 die Ordner `/mnt/nas/hoerbuecher` und `/mnt/nas/musik` in den Container reichen.

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
- **Meine Musik:** Zahnrad → «Musik-Ordner» → `/mnt/musik` hinzufügen → Speichern (bei einer neuen Installation schon eingetragen).
  Das erste Einlesen einer grossen Sammlung dauert einige Minuten; danach unter **Musik → Meine Musik**.
- **Auf dem Handy:** Adresse in Safari öffnen → Teilen → «Zum Home-Bildschirm».
- **Sonos:** Knopf «Lautsprecher» (im Player oder in der Leiste unten) → Raum wählen. Die Boxen werden im Heimnetz von selbst gefunden;
  falls nicht (z. B. Boxen in einem anderen Netz): Zahnrad → Sonos → IP-Adresse einer Box eintragen.
- **player.menet.ch verbinden** (für unterwegs): im eigenen Profil → Zahnrad → player.menet.ch → Code eingeben
  (Code auf player.menet.ch → Geräte → «Code erzeugen»). Jedes Profil verbindet sein eigenes Konto.
- **Updates:** wie beim PC-Player über den Hinweis «Neue Version» in der Oberfläche – oder das Installations-Skript nochmals ausführen.

## 6. Tailscale: sichere Adresse (https) und Zugriff von unterwegs

Damit Apple Music auch auf dem Heimserver geht (Apple gibt die Anmeldung nur an Seiten mit **https** weiter)
und damit «Meine Musik» auch unterwegs erreichbar ist. Tailscale verbindet eure Geräte verschlüsselt miteinander –
der Heimserver bleibt trotzdem **nicht** offen im Internet.

**6.1 Konto:** auf <https://tailscale.com> ein Konto anlegen (z. B. mit der Apple-ID oder Microsoft), Plan «Personal» (gratis).

**6.2 Im Container** (Proxmox → Container 105 → Console, als root):

```bash
apt-get install -y curl
curl -fsSL https://tailscale.com/install.sh | sh
# Der Container darf kein eigenes Netzwerkgerät anlegen – darum läuft Tailscale im «Userspace»-Modus:
sed -i 's/^FLAGS=.*/FLAGS="--tun=userspace-networking"/' /etc/default/tailscaled
systemctl restart tailscaled
tailscale up --hostname=myplayer
```

`tailscale up` zeigt einen Link → im Browser öffnen und mit dem Tailscale-Konto bestätigen.

**6.3 https einschalten:** auf <https://login.tailscale.com/admin/dns> → **MagicDNS** einschalten (falls nicht schon an)
und weiter unten bei **HTTPS Certificates** auf «Enable HTTPS» klicken.

**6.4 MyPlayer über https anbieten** (wieder in der Container-Console):

```bash
tailscale serve --bg 48219
tailscale serve status
```

Die zweite Zeile zeigt die neue Adresse, z. B. `https://myplayer.tail1234.ts.net`. Der erste Aufruf kann ein paar Sekunden dauern
(das Zertifikat wird geholt).

**6.5 Geräte:** auf dem iPhone/iPad die App **Tailscale** aus dem App Store, auf dem PC von <https://tailscale.com/download> –
jeweils mit demselben Konto anmelden (Familienmitglieder: im Tailscale-Admin unter «Users» einladen). Dann die neue
`https://…ts.net`-Adresse öffnen und auf dem Handy wieder «Zum Home-Bildschirm» – diese Adresse geht zu Hause **und** unterwegs.

- **Gäste** brauchen kein Tailscale: Der QR-Code der Jukebox zeigt immer die Adresse im Heimnetz.
- **Sonos** läuft unverändert über das Heimnetz.
- Prüfen: `tailscale status` (ist der Container verbunden?), `tailscale serve status` (Adresse).

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
