# nixtv-install: erase a disk and install NixTV on it. Run as root from the
# NixTV ISO. NIXTV_SRC (this repo), NIXOS_RELEASE and ZONEINFO are set by
# iso/default.nix.

# Answers, filled in by `ask` (printf -v).
choice="" hostName="" user="" timeZone="" keyboardLayout="" osk="" apkUrl="" sshKey=""

bold=$'\e[1m' dim=$'\e[2m' red=$'\e[31m' green=$'\e[32m' reset=$'\e[0m'

say() { printf '\n%s==>%s %s%s%s\n' "$green" "$reset" "$bold" "$*" "$reset"; }
note() { printf '    %s%s%s\n' "$dim" "$*" "$reset"; }
die() { printf '\n%sError:%s %s\n' "$red" "$reset" "$*" >&2; exit 1; }

# ask <variable> <question> <default>
ask() {
  local answer
  read -r -p "    $2 [$3]: " answer
  printf -v "$1" '%s' "${answer:-$3}"
}

# yesno <question> <y|n>: succeeds on yes.
yesno() {
  local answer hint="y/N"
  [ "$2" = y ] && hint="Y/n"
  while true; do
    read -r -p "    $1 [$hint]: " answer
    case "${answer:-$2}" in
      [yY]*) return 0 ;;
      [nN]*) return 1 ;;
    esac
  done
}

# askmatch <variable> <question> <default> <regex>: ask until the answer fits
# (answers end up in Nix strings, so no quotes or other surprises).
askmatch() {
  while true; do
    ask "$1" "$2" "$3"
    [[ "${!1}" =~ $4 ]] && return
    note "That doesn't look right, try again."
  done
}

# bool <question> <y|n>: prints true or false.
bool() { if yesno "$1" "$2"; then echo true; else echo false; fi; }

[ "$(id -u)" -eq 0 ] || die "run it as root: sudo nixtv-install"
[ -d /sys/firmware/efi ] || die "this machine booted without UEFI. NixTV needs UEFI: turn off legacy/CSM boot in the firmware settings."

printf '\n%sNixTV installer%s\n' "$bold" "$reset"
note "Erases a disk, installs NixTV on it and sets it up for you."

say "Checking the internet connection"
if ! curl -fsS --max-time 15 -o /dev/null https://cache.nixos.org/nix-cache-info; then
  die "no internet. Plug in a network cable, or connect to Wi-Fi with \`nmtui\`, then run this again."
fi
note "Online."

# --- Disk -------------------------------------------------------------------
say "Which disk should NixTV go on? Everything on it will be erased."
if [ -n "${NIXTV_DISK:-}" ]; then # for testing, e.g. on a loop device
  disk=$NIXTV_DISK
  note "Using $disk (NIXTV_DISK)."
else
  boot_disk=$(lsblk -no PKNAME "$(findmnt -no SOURCE /iso 2>/dev/null || true)" 2>/dev/null || true)
  mapfile -t disks < <(lsblk -dnpo NAME,TYPE | awk -v skip="/dev/$boot_disk" '$2 == "disk" && $1 != skip && $1 !~ /zram|loop/ { print $1 }')
  [ "${#disks[@]}" -gt 0 ] || die "found no disk to install on."
  for i in "${!disks[@]}"; do
    printf '    %d) %s\n' "$((i + 1))" "$(lsblk -dno NAME,SIZE,MODEL "${disks[$i]}" | sed 's/  */ /g')"
  done
  while true; do
    ask choice "Disk number" 1
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#disks[@]}" ]; then
      disk=${disks[$((choice - 1))]}
      break
    fi
  done
fi

# --- Questions --------------------------------------------------------------
say "About this TV"
askmatch hostName "Name on the network" nixos-tv '^[a-zA-Z0-9][a-zA-Z0-9-]{0,62}$'
askmatch user "User name" tv '^[a-z_][a-z0-9_-]{0,31}$'
while true; do
  ask timeZone "Time zone (e.g. Europe/Stockholm, America/New_York)" UTC
  [ -f "$ZONEINFO/$timeZone" ] && break
  note "Unknown time zone. Names are like Region/City."
done
askmatch keyboardLayout "Keyboard layout (for a physical keyboard)" us '^[a-z0-9_,-]+$'
askmatch osk "On-screen keyboard languages, comma-separated (e.g. en_US,sv_SE)" en_US '^[a-zA-Z_]+( *, *[a-zA-Z_]+)*$'
oskList=$(printf '%s' "$osk" | tr -d ' ' | sed 's/,/" "/g')

note "To manage the TV from another computer over SSH without a password, paste a public"
note "key (e.g. ~/.ssh/id_ed25519.pub). You can also add one later in config.nix."
askmatch sshKey "SSH public key (optional)" "" '^((ssh-[a-z0-9-]+|ecdsa-sha2-nistp[0-9]+|sk-[a-z0-9@.-]+) [A-Za-z0-9+/=]+( [^"\\$]*)?)?$'

say "Apps (you can change all of this later in /etc/nixos/config.nix)"
youtube=$(bool "YouTube (Red, ad-free)" y)
iptv=$(bool "IPTV (iptvs; built from source, adds a while to the install)" y)
stremio=$(bool "Stremio (Android app in Waydroid)" y)
librewolf=$(bool "LibreWolf, the web browser" y)
svtplay=false
if yesno "SVT Play (Swedish public TV, Android app in Waydroid)" n; then
  note "SVT Play can't be downloaded automatically (see docs/apps/svtplay.md)."
  note "Give a URL to your own copy of the APK bundle, or leave it empty to add it later."
  askmatch apkUrl "APK bundle URL" "" '^(https?://[^"\\$ ]+)?$'
  if [ -n "$apkUrl" ]; then svtplay=true; fi
fi

say "Privacy"
note "Tailscale is a VPN. With an exit node (yours, or Mullvad's), all traffic leaves from there."
tailscale=$(bool "Tailscale" n)
killswitch=false
if [ "$tailscale" = true ]; then
  note "The kill switch blocks the internet except through an exit node. Until you log in to"
  note "Tailscale and pick one, the TV has no internet (apps finish installing after that)."
  killswitch=$(bool "Kill switch" n)
fi

say "Ready to install"
note "Disk:      $disk ($(lsblk -dno SIZE "$disk" | tr -d ' ')), will be ERASED"
note "Name/user: $hostName / $user, time zone $timeZone"
note "Apps:      youtube=$youtube iptv=$iptv stremio=$stremio svtplay=$svtplay librewolf=$librewolf"
note "Privacy:   tailscale=$tailscale killswitch=$killswitch"
read -r -p "    Type ERASE to erase $disk and install: " confirm
[ "$confirm" = ERASE ] || die "cancelled, nothing was changed."

# --- Partition and mount ------------------------------------------------------
say "Partitioning $disk"
umount -R /mnt 2>/dev/null || true
mkdir -p /mnt
wipefs -af "$disk" >/dev/null
parted -s "$disk" -- mklabel gpt \
  mkpart ESP fat32 1MiB 1GiB \
  set 1 esp on \
  mkpart root ext4 1GiB 100%
udevadm settle
part=$disk
[[ "$disk" =~ [0-9]$ ]] && part="${disk}p" # nvme0n1 -> nvme0n1p1, sda -> sda1
mkfs.fat -F 32 -n BOOT "${part}1" >/dev/null
mkfs.ext4 -q -F -L nixos "${part}2"
mount "${part}2" /mnt
mkdir -p /mnt/boot
mount -o umask=077 "${part}1" /mnt/boot

# --- Configuration ------------------------------------------------------------
say "Writing the configuration to /etc/nixos"
mkdir -p /mnt/etc
cp -rL "$NIXTV_SRC" /mnt/etc/nixos
chmod -R u+w /mnt/etc/nixos
nixos-generate-config --root /mnt --show-hardware-config \
  > /mnt/etc/nixos/hosts/nixtv/hardware-configuration.nix
host=/mnt/etc/nixos/hosts/nixtv/default.nix
sed -i "s/system.stateVersion = \"[^\"]*\";/system.stateVersion = \"$NIXOS_RELEASE\";/" "$host"
grep -q "system.stateVersion = \"$NIXOS_RELEASE\";" "$host" || die "couldn't set system.stateVersion in $host."

sshLine=""
if [ -n "$sshKey" ]; then sshLine=$'\n'"    sshKeys = [ \"$sshKey\" ];"; fi

apkLine=""
if [ -n "$apkUrl" ]; then apkLine=$'\n'"      svtplay.apkUrl = \"$apkUrl\";"; fi
cat > /mnt/etc/nixos/config.nix <<EOF
# Your TV box: who it's for and what's on it. Turn a feature off by setting
# its \`enable\` to false and rebuilding:
#
#   sudo nixos-rebuild switch --flake /etc/nixos#nixtv
#
# Every app is documented in docs/apps/. Written by nixtv-install.
{
  nixtv = {
    hostName = "$hostName";
    user = "$user";
    timeZone = "$timeZone";
    locale = "en_US.UTF-8";
    keyboardLayout = "$keyboardLayout";$sshLine
    onScreenKeyboard.locales = [ "$oskList" ];

    apps = {
      youtube.enable = $youtube;
      iptv.enable = $iptv;
      stremio.enable = $stremio;
      svtplay.enable = $svtplay;$apkLine
      librewolf.enable = $librewolf;
    };

    tailscale.enable = $tailscale;
    tailscale.killswitch.enable = $killswitch;
  };
}
EOF

# --- Install ------------------------------------------------------------------
say "Installing (downloads a few GB; this takes a while)"
if ! nixos-install --no-root-passwd --flake "path:/mnt/etc/nixos#nixtv"; then
  die "the install failed (see above). Fix it, then run: nixos-install --no-root-passwd --flake path:/mnt/etc/nixos#nixtv"
fi

say "Set a password for $user (for sudo, and SSH without a key)"
passwordSet=false
for _ in 1 2 3 4 5; do
  if nixos-enter --root /mnt -c "passwd $user"; then passwordSet=true; break; fi
done
if [ "$passwordSet" = false ]; then
  note "${red}No password set.${reset} The TV still logs in by itself, but sudo won't work until"
  note "you set one: \`nixos-enter --root /mnt -c 'passwd $user'\` (before rebooting)."
fi

say "NixTV is installed"
note "Remove the USB stick and run \`reboot\`. The TV starts straight into its home screen."
if [ "$stremio" = true ] || [ "$svtplay" = true ]; then
  note "Android (~1 GB) downloads by itself on the first boot, then the Android apps install."
fi
if [ "$tailscale" = true ]; then
  note "Log in to Tailscale from the Trayscale app; open the login link on your phone."
fi
note "Apps from Flathub install in the background after the first boot."
