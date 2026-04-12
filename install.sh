#!/usr/bin/env bash
# RetroMi — Standalone Installer
# Installs RetroMi (RetroPie + EmulationStation) from pre-compiled packages.
# Compatible: Armbian Bookworm (Debian 12), armhf (SmartPi One / AllWinner H3)
#
# Usage: curl -fsSL https://raw.githubusercontent.com/Yumi-Lab/RetroPie-Setup/installer/install.sh | sudo bash

set -e

PACKAGES_URL="https://github.com/Yumi-Lab/RetroMi-packages/releases/latest/download"
RETROPI_DIR="/home/pi/RetroPie"
RETROPIE_SETUP_DIR="/home/pi/Retropie-Setup"
BASE_USER="pi"

# Colors
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
log()  { echo -e "${GREEN}[RetroMi]${NC} $*"; }
warn() { echo -e "${RED}[WARN]${NC} $*"; }

if [[ "${EUID}" -ne 0 ]]; then
    echo "Run as root: sudo bash install.sh"
    exit 1
fi

log "=== RetroMi Installer ==="
log "Target user: ${BASE_USER}"

# Runtime dependencies
log "Installing runtime dependencies..."
apt-get update -qq
apt-get install -y --no-install-recommends \
    wget ca-certificates dialog xmlstarlet git \
    wireless-tools wpasupplicant network-manager \
    libfreeimage3 \
    libsdl2-2.0-0 libsdl2-mixer-2.0-0 libsdl2-ttf-2.0-0 \
    libvlc5 \
    joystick

# Download and extract pre-compiled package groups
log "Downloading pre-compiled packages..."
mkdir -p /opt/retropie

GROUPS="retroarch arcade arcade-compat nintendo n64 sega sony psp misc openbor scummvm dosbox portables computers amiga japan-computers heavy emulationstation"

for group in ${GROUPS}; do
    url="${PACKAGES_URL}/packages-${group}-armhf.tar.gz"
    log "  → ${group}"
    if wget -q --show-progress --tries=3 --timeout=60 \
        --retry-on-http-error=502,503,504 \
        -O "/tmp/packages-${group}-armhf.tar.gz" "${url}"; then
        tar -xzf "/tmp/packages-${group}-armhf.tar.gz" -C /
        rm -f "/tmp/packages-${group}-armhf.tar.gz"
    else
        warn "packages-${group}-armhf.tar.gz not available — skipping"
        rm -f "/tmp/packages-${group}-armhf.tar.gz"
    fi
done

# Clone RetroPie-Setup fork for post-install configuration
log "Cloning RetroPie-Setup..."
if [ -d "${RETROPIE_SETUP_DIR}/.git" ]; then
    git -C "${RETROPIE_SETUP_DIR}" pull --ff-only
else
    git clone --depth=1 -b master \
        https://github.com/Yumi-Lab/RetroPie-Setup.git \
        "${RETROPIE_SETUP_DIR}"
fi
chown -R "${BASE_USER}:${BASE_USER}" "${RETROPIE_SETUP_DIR}"

export __platform="armv7-mali"
export __user="${BASE_USER}"

cd "${RETROPIE_SETUP_DIR}"

# Post-install configuration
log "Configuring RetroPie services..."
bash retropie_packages.sh runcommand
bash retropie_packages.sh bluetooth depends
bash retropie_packages.sh usbromservice || true

# Configure EmulationStation FIRST (generates per-system retroarch.cfg)
log "Configuring EmulationStation..."
bash retropie_packages.sh emulationstation configure || true
bash retropie_packages.sh retropiemenu configure || true

# Register all installed libretro cores
log "Registering emulators..."
for core_dir in /opt/retropie/libretrocores/lr-*/; do
    [ -d "${core_dir}" ] || continue
    core_name=$(basename "${core_dir}")
    bash retropie_packages.sh "${core_name}" configure || true
done

# Register standalone ports
for port in openbor; do
    if [ -d "/opt/retropie/ports/${port}" ]; then
        log "  → ${port} (port)"
        bash retropie_packages.sh "${port}" configure || true
    fi
done

# Configure EmulationStation auto-start
log "Setting up autostart..."
AUTOSTART_SCRIPT="/opt/retropie/configs/all/autostart.sh"
mkdir -p "$(dirname "${AUTOSTART_SCRIPT}")"

cat > /etc/profile.d/10-retropie.sh << PROFILE
# Auto-start RetroPie on tty1
if [ "\$(tty)" = "/dev/tty1" ] && [ -z "\${DISPLAY}" ] && [ "\${USER}" = "${BASE_USER}" ]; then
    bash "${AUTOSTART_SCRIPT}"
fi
PROFILE

rm -f /etc/profile.d/10-emulationstation.sh
touch "${AUTOSTART_SCRIPT}"
sed -i '/#auto/d' "${AUTOSTART_SCRIPT}"
echo "emulationstation #auto" >> "${AUTOSTART_SCRIPT}"
chown "${BASE_USER}:${BASE_USER}" "${AUTOSTART_SCRIPT}"

mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << GETTY
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin ${BASE_USER} --noclear %I \$TERM
GETTY

# Create ROM directories
log "Creating ROM directories..."
ROM_DIR="${RETROPI_DIR}/roms"
mkdir -p "${ROM_DIR}"
for sys in \
    nes snes megadrive mastersystem gamegear genesis sega32x segacd sg-1000 \
    gb gbc gba nds n64 psx psp \
    atari2600 atari5200 atari7800 atarilynx atarist \
    pcengine ngp ngpc wonderswan wonderswancolor \
    mame-libretro fba arcade neogeo \
    scummvm dosbox c64 msx zxspectrum amstradcpc amiga \
    dreamcast saturn 3do jaguar vectrex coleco intellivision \
    ports/openbor; do
    mkdir -p "${ROM_DIR}/${sys}"
done
chown -R "${BASE_USER}:${BASE_USER}" "${RETROPI_DIR}"

# Fix paths in es_systems.cfg
ES_CFG="/etc/emulationstation/es_systems.cfg"
if [ -f "${ES_CFG}" ]; then
    sed -i "s|/home/runner/RetroPie|/home/${BASE_USER}/RetroPie|g;
            s|/root/RetroPie|/home/${BASE_USER}/RetroPie|g" "${ES_CFG}"
fi

# sudoers — allow pi to run RetroPie scripts without password
SUDOERS_FILE="/etc/sudoers.d/retromi-nopasswd"
cat > "${SUDOERS_FILE}" << SUDOEOF
${BASE_USER} ALL=(ALL) NOPASSWD: /usr/sbin/armbian-config
${BASE_USER} ALL=(ALL) NOPASSWD: /usr/bin/nmcli *
${BASE_USER} ALL=(ALL) NOPASSWD: /usr/sbin/nmtui
${BASE_USER} ALL=(ALL) NOPASSWD: /home/${BASE_USER}/Retropie-Setup/retropie_packages.sh *
${BASE_USER} ALL=(ALL) NOPASSWD: /home/${BASE_USER}/Retropie-Setup/retropie_setup.sh
SUDOEOF
chmod 440 "${SUDOERS_FILE}"

chown -R "${BASE_USER}:${BASE_USER}" /opt/retropie/configs 2>/dev/null || true

log "=== Installation complete ==="
log "Reboot to start EmulationStation: sudo reboot"
