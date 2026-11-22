#!/usr/bin/env bash
# MyPlayer-Heimserver installieren oder auf die neueste Version bringen.
# Im Proxmox-Container (Debian) als root ausführen:
#   bash <(curl -fsSL https://raw.githubusercontent.com/thmenet/MyPlayer-releases/main/heimserver/installieren.sh)
# Ein zweites Mal ausführen schadet nicht (aktualisiert nur).
set -euo pipefail

ZIEL="${MYPLAYER_ZIEL:-/opt/myplayer}"          # Programm
DATEN="${MYPLAYER_DATEN:-/var/lib/myplayer}"     # Profile, Hörstand, Einstellungen, Cover
PORT="${MYPLAYER_PORT:-48219}"
BENUTZER="${MYPLAYER_BENUTZER:-myplayer}"
REPO="thmenet/MyPlayer-releases"

echo "== MyPlayer-Heimserver =="
if [ "${MYPLAYER_OHNE_APT:-}" != "1" ]; then
  echo "-> Pakete installieren (Python, …)"
  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq python3 python3-venv ca-certificates curl unzip >/dev/null
fi

if [ "${MYPLAYER_OHNE_SYSTEMD:-}" != "1" ] && ! id "$BENUTZER" >/dev/null 2>&1; then
  echo "-> Benutzer «$BENUTZER» anlegen (der Dienst läuft nicht als root)"
  useradd --system --home "$DATEN" --shell /usr/sbin/nologin "$BENUTZER"
fi

echo "-> Neueste Version von GitHub holen"
TMP=$(mktemp -d)
ZIP_URL=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" | python3 -c 'import sys,json; print(next(a["browser_download_url"] for a in json.load(sys.stdin)["assets"] if a["name"].endswith(".zip")))')
curl -fsSL "$ZIP_URL" -o "$TMP/myplayer.zip"
unzip -q "$TMP/myplayer.zip" -d "$TMP/neu"
QUELLE=$(dirname "$(find "$TMP/neu" -name app.py -path '*Hoerbuchplayer*' | head -1)")
mkdir -p "$ZIEL" "$DATEN/Hoerbuchplayer"
cp -a "$QUELLE/." "$ZIEL/"
rm -rf "$TMP"
echo "   Version: $(python3 -c "import re;print(re.search(r'VERSION = \"(.+?)\"', open('$ZIEL/hoerbuch/__init__.py').read()).group(1))")"

echo "-> Python-Umgebung und Pakete"
[ -x "$ZIEL/.venv/bin/python" ] || python3 -m venv "$ZIEL/.venv"
"$ZIEL/.venv/bin/python" -m pip install -q --disable-pip-version-check -r "$ZIEL/requirements.txt"
cp "$ZIEL/requirements.txt" "$ZIEL/.venv/requirements.installed"

# Beim ersten Mal: Bibliotheksordner vorschlagen (eingebundene NAS-Ordner)
EINST="$DATEN/Hoerbuchplayer/settings.json"
if [ ! -f "$EINST" ]; then
  python3 - "$EINST" <<'PY'
import json, os, sys
s = {"folders": [d for d in ("/mnt/hoerbuecher",) if os.path.isdir(d)],
     "podcast_folders": [d for d in ("/mnt/podcasts",) if os.path.isdir(d)],
     "music_folders": [d for d in ("/mnt/musik",) if os.path.isdir(d)]}
s["folders"] += s["podcast_folders"]
json.dump(s, open(sys.argv[1], "w"), indent=1)
print("   Bibliothek:", ", ".join(s["folders"]) or "noch keine – später in den Einstellungen eintragen")
print("   Musik:", ", ".join(s["music_folders"]) or "keine – später in den Einstellungen unter «Musik-Ordner»")
PY
fi

if [ "${MYPLAYER_OHNE_SYSTEMD:-}" != "1" ]; then
  chown -R "$BENUTZER:$BENUTZER" "$ZIEL" "$DATEN"
  echo "-> Dienst einrichten (startet mit dem Container und nach jedem Update von selbst)"
  cat > /etc/systemd/system/myplayer.service <<UNIT
[Unit]
Description=MyPlayer Heimserver
After=network-online.target remote-fs.target
Wants=network-online.target

[Service]
User=$BENUTZER
WorkingDirectory=$ZIEL
Environment=HOERBUCH_DATA=$DATEN
Environment=MYPLAYER_PORT=$PORT
ExecStart=$ZIEL/.venv/bin/python $ZIEL/app.py --server
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
UNIT
  systemctl daemon-reload
  systemctl enable -q myplayer
  systemctl restart myplayer
  sleep 3
  systemctl is-active --quiet myplayer && echo "   läuft ✓" || { echo "   startet nicht – Protokoll: journalctl -u myplayer -n 50"; exit 1; }
fi

IP=$(hostname -I 2>/dev/null | awk '{print $1}')
echo
echo "Fertig! Im Browser öffnen:  http://${IP:-<IP-Adresse>}:$PORT   (oder http://$(hostname):$PORT)"
