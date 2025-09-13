#!/bin/bash

# be new
apt-get update

# get software
apt-get install -y \
    unclutter \
    xorg \
    chromium \
    openbox \
    lightdm \
    locales \
    curl \
    unzip \
    screen

# dir
mkdir -p /home/kiosk/.config/openbox

# create group
groupadd -f kiosk

# create user if not exists
id -u kiosk &>/dev/null || useradd -m kiosk -g kiosk -s /bin/bash 

# rights
chown -R kiosk:kiosk /home/kiosk

# ------------------------------
# Network: iki ethernet aktif et
# ------------------------------
ip link set enp1s0 up
ip link set enp2s0 up

dhclient enp1s0
dhclient enp2s0

# ------------------------------
# disable sleep/hibernate
# ------------------------------
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

# ------------------------------
# create LightDM config
# ------------------------------
if [ -e "/etc/lightdm/lightdm.conf" ]; then
  mv /etc/lightdm/lightdm.conf /etc/lightdm/lightdm.conf.backup
fi
cat > /etc/lightdm/lightdm.conf << EOF
[Seat:*]
xserver-command=X -nocursor -nolisten tcp
autologin-user=kiosk
autologin-session=openbox
EOF

# ------------------------------
# create openbox autostart
# ------------------------------
if [ -e "/home/kiosk/.config/openbox/autostart" ]; then
  mv /home/kiosk/.config/openbox/autostart /home/kiosk/.config/openbox/autostart.backup
fi
cat > /home/kiosk/.config/openbox/autostart << EOF
#!/bin/bash

LOGFILE="/home/kiosk/bun.log"
KIOSK_URL="http://localhost:5173/terminal"
FRONTEND_PATH="/home/kiosk/frontend"
BACKEND_PATH="/home/kiosk/backend"

unclutter -idle 0.1 -grab -root &

# Backend başlat
if lsof -i :5000 > /dev/null; then
    echo "$(date) - Port 5000 already in use!" >> "$LOGFILE"
else
    echo "$(date) - Starting backend..." >> "$LOGFILE"
    screen -dmS backend bash -c "cd $BACKEND_PATH && ./backend >> $LOGFILE 2>&1"
fi

# Frontend başlat (Bun ile)
if lsof -i :5173 > /dev/null; then
    echo "$(date) - Port 5173 already in use!" >> "$LOGFILE"
else
    echo "$(date) - Starting frontend..." >> "$LOGFILE"
    screen -dmS frontend bash -c "cd $FRONTEND_PATH && bun run preview >> $LOGFILE 2>&1"
fi

# Backend ve frontend hazır olana kadar bekle
until curl -s --head $KIOSK_URL | grep "200 OK" > /dev/null; do
    sleep 1
done

# Chromium kiosk aç
chromium --noerrdialogs --no-memcheck --no-first-run --start-maximized \
  --disable --disable-translate --disable-infobars --disable-suggestions-service \
  --disable-save-password-bubble --disable-session-crashed-bubble \
  --incognito --kiosk $KIOSK_URL &
  
EOF

chown kiosk:kiosk /home/kiosk/.config/openbox/autostart
chmod +x /home/kiosk/.config/openbox/autostart

echo "Done!"
