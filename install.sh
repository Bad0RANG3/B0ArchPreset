#!/usr/bin/env bash
#
# Bad0RANG3 Arch-like Linux bootstrap
# Target: fresh Arch / Arch-based distro -> Shorin DMS + niri desktop matching this machine.
#
# Usage:
#   sudo bash install.sh
#   sudo TARGET_USER=bad0rang3 bash install.sh
#   sudo TARGET_HOSTNAME=Bad0RANG3CachyOS bash install.sh
#

set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
STATE_DIR="/var/lib/bad0rang3-shorin-niri"
STATE_FILE="$STATE_DIR/state"
LOG_FILE="/var/log/bad0rang3-shorin-niri-install.log"
CURRENT_STAGE="startup"

TARGET_USER="${TARGET_USER:-}"
TARGET_HOSTNAME="${TARGET_HOSTNAME:-archlinux}"
TARGET_TIMEZONE="${TARGET_TIMEZONE:-Asia/Shanghai}"
TARGET_LOCALE="${TARGET_LOCALE:-zh_CN.UTF-8}"
TARGET_SHELL="${TARGET_SHELL:-/usr/bin/fish}"
PRIMARY_OUTPUT_NAME="${PRIMARY_OUTPUT_NAME:-auto}"
PRIMARY_OUTPUT_MODE="${PRIMARY_OUTPUT_MODE:-}"
PRIMARY_OUTPUT_SCALE="${PRIMARY_OUTPUT_SCALE:-1}"
AUR_HELPER="${AUR_HELPER:-yay}"
OS_ID="unknown"
OS_ID_LIKE=""
OS_NAME="unknown"

KEY_SHORIN_FPR="8ED9ABE61CDBAABAC4B6A694C9218E60C13B4BA8"
KEY_SHORIN_SETUP_URL="https://repo.shorin.xyz/archlinux/gpgsetup"

RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'
NC=$'\033[0m'

CORE_PACKAGES=(
  base base-devel sudo git curl wget rsync reflector pacman-contrib
  vim nano less bat eza fd fzf ripgrep jq pv inotify-tools usbutils pciutils
  networkmanager iwd dnsmasq systemd-resolvconf
  grub efibootmgr os-prober
  xdg-user-dirs xdg-utils xdg-terminal-exec
  flatpak flatseal
)

DRIVER_BASE_PACKAGES=(
  linux-firmware
  vulkan-icd-loader lib32-vulkan-icd-loader vulkan-headers mesa-utils
  sof-firmware alsa-firmware alsa-ucm-conf
  pipewire lib32-pipewire pipewire-pulse pipewire-alsa pipewire-jack wireplumber
)

CPU_DRIVER_PACKAGES=()
GPU_DRIVER_PACKAGES=()

DESKTOP_PACKAGES=(
  niri sddm kitty fuzzel imv slurp satty wf-recorder xdg-desktop-portal-gnome
  xdg-desktop-portal-gtk xdotool xorg-xhost wl-clipboard grim
  fcitx5 fcitx5-chinese-addons fcitx5-configtool fcitx5-gtk fcitx5-qt
  fcitx5-rime fcitx5-mozc
  noto-fonts noto-fonts-cjk noto-fonts-emoji otf-font-awesome
  ttf-jetbrains-mono ttf-jetbrains-mono-nerd ttf-liberation terminus-font
  wqy-zenhei adw-gtk-theme qt5-wayland qt6-wayland starship
  fastfetch btop yazi zoxide fish gdu imagemagick timg
  thunar thunar-archive-plugin thunar-volman tumbler ffmpegthumbnailer
  webp-pixbuf-loader poppler-glib libgsf icoextract nautilus file-roller
  libnotify sound-theme-freedesktop playerctl brightnessctl
  gnome-keyring nm-connection-editor pavucontrol easyeffects
  power-profiles-daemon bluez bluez-utils
  gvfs gvfs-mtp gvfs-smb gvfs-gphoto2 exfat-utils ntfs-3g ntfsprogs
  gst-libav gst-plugins-base gst-plugins-good gst-plugins-ugly
  lib32-gst-plugins-base-libs lib32-giflib lib32-libjpeg-turbo lib32-mpg123
  lib32-openal lib32-gtk3
  btrfs-progs python python-pip neovim firefox
)

OPTIONAL_DESKTOP_PACKAGES=(
  gnome-calendar gnome-clocks gnome-font-viewer baobab
  mpv obs-studio cups system-config-printer bluetui mousepad
  btrfs-assistant snapper grub-btrfs
  qemu-full virt-manager virt-viewer swtpm edk2-ovmf
  wine wine-mono mangohud transmission-gtk gparted mission-center
  mokutil sbsigntools python-pillow python-black python-flake8 python-pytest
  ipython jupyter-notebook nodejs npm cmake lolcat cmatrix sl
)

SHORIN_CORE_PACKAGES=(
  quickshell-git shorin-dms-niri-git shorin-contrib-git niri-sidebar-git
  shorin-screenrec-menu-git shorin-proton-wrapper-git fcitx5-shorin-patched-git
  chwd-arch-git
  echo-sddm-git sddm-sugar-candy-git sddm-kcm ttf-jetbrains-maple-mono-nf-xx-xx
  wl-screenrec-git matugen python-pywalfox
)

SHORIN_OPTIONAL_PACKAGES=(
  linuxqq linuxqq-clipsync-git wechat-appimage netease-cloud-music-gtk-bin
  yesplaymusic visual-studio-code-bin microsoft-edge-stable-bin miyu opencode
  gslapper localsend protonplus rime-ice-git rime-llm-translator-git
  rime-wanxiang-gram-zh-hans rime-wubi nautilus-open-any-terminal upscaler
  pins-git impala mangojuice reshade-shaders-git gearlever cc-switch lact
  flclash dxvk-mingw-git bazaar zulu-17-bin zulu-21-bin zulu-8-bin zulu-jdk-fx-bin
)

log() {
  printf '[%s] [%s] %s\n' "$(date '+%F %T')" "$CURRENT_STAGE" "$*" >> "$LOG_FILE"
}

info() {
  printf '%s[INFO]%s %s\n' "$CYAN" "$NC" "$*"
  log "INFO $*"
}

ok() {
  printf '%s[OK]%s %s\n' "$GREEN" "$NC" "$*"
  log "OK $*"
}

warn() {
  printf '%s[WARN]%s %s\n' "$YELLOW" "$NC" "$*"
  log "WARN $*"
}

die() {
  local msg="$1"
  printf '\n%s[ERROR]%s 安装在环节「%s」失败。\n' "$RED" "$NC" "$CURRENT_STAGE" >&2
  printf '%s\n' "$msg" >&2
  printf '日志文件: %s\n' "$LOG_FILE" >&2
  printf '把“失败环节 + 上面这段提示 + 日志最后 80 行”发给 AI，就能继续定位。\n\n' >&2
  log "ERROR $msg"
  exit 1
}

on_error() {
  local line="$1"
  local command="$2"
  die "失败命令: ${command} (行 ${line})"
}

trap 'on_error "$LINENO" "$BASH_COMMAND"' ERR

run() {
  log "RUN $*"
  "$@"
}


retry() {
  local max_attempts="${1:-3}"
  local delay_secs="${2:-10}"
  local description="${3:-}"
  shift 3

  local attempt=0
  local rc=0
  while (( attempt < max_attempts )); do
    (( ++attempt ))
    log "RETRY $description attempt $attempt/$max_attempts"
    if "${@}"; then
      if (( attempt > 1 )); then
        ok "$description 重试 ${attempt}/${max_attempts} 成功"
      fi
      return 0
    fi
    rc=$?
    warn "$description 第 ${attempt}/${max_attempts} 次失败 (exit $rc)"
    if (( attempt < max_attempts )); then
      info "$description 等待 ${delay_secs}s 后重试..."
      sleep "$delay_secs"
    fi
  done
  return $rc
}

retry_run() {
  local max_attempts="${1:-3}"
  local delay_secs="${2:-10}"
  local description="${3:-}"
  shift 3

  retry "$max_attempts" "$delay_secs" "$description" run "${@}"
}

run_as_user() {
  local home_dir
  home_dir="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
  run runuser -u "$TARGET_USER" -- env HOME="$home_dir" USER="$TARGET_USER" "$@"
}

mark_done() {
  mkdir -p "$STATE_DIR"
  grep -Fxq "$1" "$STATE_FILE" 2>/dev/null || printf '%s\n' "$1" >> "$STATE_FILE"
}

is_done() {
  grep -Fxq "$1" "$STATE_FILE" 2>/dev/null
}

step() {
  local name="$1"
  shift
  CURRENT_STAGE="$name"
  if is_done "$name"; then
    ok "跳过已完成环节: $name"
    return 0
  fi
  printf '\n%s==> %s%s\n' "$CYAN" "$name" "$NC"
  log "STEP_START $name"
  "$@"
  mark_done "$name"
  ok "$name 完成"
}

need_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    die "请用 root 运行: sudo bash $SCRIPT_NAME"
  fi
}

detect_distro() {
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    set +u
    source /etc/os-release 2>/dev/null || true
    set -u
    OS_ID="${ID:-unknown}"
    OS_ID_LIKE="${ID_LIKE:-}"
    OS_NAME="${PRETTY_NAME:-${NAME:-unknown}}"
  fi

  local arch_like=" $OS_ID $OS_ID_LIKE "
  case "$arch_like" in
    *arch*|*manjaro*|*cachyos*|*endeavouros*|*garuda*)
      ;;
    *)
      die "当前系统看起来不是 Arch 系发行版: $OS_NAME。此脚本只支持 Arch Linux 及其 systemd 衍生版。"
      ;;
  esac

  if ! command -v pacman >/dev/null 2>&1; then
    die "未找到 pacman。此脚本需要 Arch 系 pacman 包管理器。"
  fi

  if ! command -v systemctl >/dev/null 2>&1; then
    die "未找到 systemctl。此脚本目前只支持 systemd 的 Arch 系发行版。"
  fi
}

detect_target_user() {
  if [[ -n "$TARGET_USER" ]]; then
    return 0
  fi

  if [[ -n "${SUDO_USER:-}" && "${SUDO_USER:-}" != root ]] && id "$SUDO_USER" >/dev/null 2>&1; then
    TARGET_USER="$SUDO_USER"
    return 0
  fi

  local uid1000
  uid1000="$(awk -F: '$3 == 1000 {print $1; exit}' /etc/passwd)"
  if [[ -n "$uid1000" ]]; then
    TARGET_USER="$uid1000"
    return 0
  fi

  printf '%s没有发现普通用户。请输入要创建的用户名: %s' "$YELLOW" "$NC"
  read -r TARGET_USER
  [[ "$TARGET_USER" =~ ^[a-z_][a-z0-9_-]*$ ]] || die "用户名格式不合法: $TARGET_USER"
}

prepare_log() {
  mkdir -p "$STATE_DIR"
  touch "$STATE_FILE" "$LOG_FILE"
  chmod 600 "$LOG_FILE"
  log "Installer started"
}

existing_group_csv() {
  local groups=("$@")
  local existing=()
  local group

  for group in "${groups[@]}"; do
    if getent group "$group" >/dev/null 2>&1; then
      existing+=("$group")
    else
      warn "系统组不存在，跳过加入: $group"
    fi
  done

  local IFS=,
  printf '%s' "${existing[*]}"
}

preflight() {
  need_root
  prepare_log
  detect_distro
  detect_target_user

  if ! ping -c 1 -W 3 archlinux.org >/dev/null 2>&1; then
    if ! ping -c 1 -W 3 mirrors.ustc.edu.cn >/dev/null 2>&1; then
      die "网络不可用，请先确认能访问 Arch Linux 或 USTC 镜像。"
    fi
  fi

  info "目标用户: $TARGET_USER"
  info "发行版: $OS_NAME (ID=$OS_ID, ID_LIKE=${OS_ID_LIKE:-none})"
  info "主机名: $TARGET_HOSTNAME"
  info "时区: $TARGET_TIMEZONE"
  info "桌面组合: Shorin DMS + niri"
}

ensure_user() {
  local base_groups
  base_groups="$(existing_group_csv wheel storage power input video audio lp)"

  if id "$TARGET_USER" >/dev/null 2>&1; then
    [[ -n "$base_groups" ]] && run usermod -aG "$base_groups" "$TARGET_USER"
  else
    if [[ -n "$base_groups" ]]; then
      run useradd -m -G "$base_groups" -s /bin/bash "$TARGET_USER"
    else
      run useradd -m -s /bin/bash "$TARGET_USER"
    fi
    warn "请为新用户 $TARGET_USER 设置密码。"
    run passwd "$TARGET_USER"
  fi

  if grep -q '^# %wheel ALL=(ALL:ALL) ALL' /etc/sudoers; then
    run sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
  elif ! grep -q '^%wheel ALL=(ALL:ALL) ALL' /etc/sudoers; then
    printf '%%wheel ALL=(ALL:ALL) ALL\n' >> /etc/sudoers
  fi

  cat > /etc/sudoers.d/10-bad0rang3-install <<'EOF'
%wheel ALL=(ALL:ALL) NOPASSWD: /usr/bin/pacman, /usr/bin/systemctl, /usr/bin/mkinitcpio, /usr/bin/grub-mkconfig, /usr/bin/env
EOF
  run chmod 440 /etc/sudoers.d/10-bad0rang3-install
  run pacman -S --needed --noconfirm xdg-user-dirs
  run_as_user xdg-user-dirs-update --force
}

enable_pacman_options() {
  sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
  sed -i 's/^#Color/Color/' /etc/pacman.conf
  sed -i 's/^#VerbosePkgLists/VerbosePkgLists/' /etc/pacman.conf
  grep -q '^ILoveCandy' /etc/pacman.conf || sed -i '/^# Misc options/a ILoveCandy' /etc/pacman.conf

  if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
    sed -i '/^\#\[multilib\]/,/^\#Include = \/etc\/pacman.d\/mirrorlist/s/^#//' /etc/pacman.conf
  fi
}

ensure_repo_block() {
  local repo="$1"
  local block="$2"
  if ! grep -q "^\[$repo\]" /etc/pacman.conf; then
    printf '\n%s\n' "$block" >> /etc/pacman.conf
  fi
}

pacman_pkg_available() {
  pacman -Si "$1" >/dev/null 2>&1
}

install_available_keyrings() {
  local candidates=(archlinux-keyring)

  case "$OS_ID" in
    manjaro)
      candidates+=(manjaro-keyring)
      ;;
    cachyos)
      candidates+=(cachyos-keyring)
      ;;
    endeavouros)
      candidates+=(endeavouros-keyring)
      ;;
    garuda)
      candidates+=(garuda-keyring chaotic-keyring)
      ;;
  esac

  local to_install=()
  local pkg
  retry_run 3 10 "pacman db 刷新" pacman -Sy --noconfirm
  for pkg in "${candidates[@]}"; do
    if pacman_pkg_available "$pkg"; then
      to_install+=("$pkg")
    else
      warn "当前发行版源中未找到 keyring 包，跳过: $pkg"
    fi
  done

  if ((${#to_install[@]} > 0)); then
    retry_run 3 15 "keyring 安装" pacman -S --needed --noconfirm "${to_install[@]}"
  fi
}

setup_repositories() {
  enable_pacman_options

  ensure_repo_block "archlinuxcn" "[archlinuxcn]
Server = https://mirrors.ustc.edu.cn/archlinuxcn/\$arch
Server = https://mirrors.tuna.tsinghua.edu.cn/archlinuxcn/\$arch
Server = https://repo.archlinuxcn.org/\$arch"

  ensure_repo_block "shorin-arch" "[shorin-arch]
Server = https://repo.shorin.xyz/archlinux/\$arch"

  install_available_keyrings

  retry_run 3 15 "archlinuxcn-keyring 安装" pacman -S --needed --noconfirm archlinuxcn-keyring || {
    retry_run 2 5 "pacman-key init" pacman-key --init
    retry_run 2 5 "pacman-key populate" pacman-key --populate archlinux archlinuxcn || retry_run 2 5 "pacman-key populate archlinuxcn" pacman-key --populate archlinuxcn || true
    retry_run 3 15 "archlinuxcn-keyring 安装" pacman -S --needed --noconfirm archlinuxcn-keyring
  }

  if ! pacman-key --list-keys "$KEY_SHORIN_FPR" >/dev/null 2>&1; then
    if ! retry_run 3 15 "Shorin GPG 导入" curl -fsSL "$KEY_SHORIN_SETUP_URL" | bash; then
      warn "Shorin gpgsetup 失败，尝试 keyserver 导入。"
      run pacman-key --keyserver hkp://keys.openpgp.org --recv-keys "$KEY_SHORIN_FPR"
      retry_run 3 5 "keyserver 密钥签名" pacman-key --lsign-key "$KEY_SHORIN_FPR"
    fi
  fi

  retry_run 3 30 "系统全量更新" pacman -Syyu --noconfirm
}

install_pacman_packages() {
  local label="$1"
  shift
  local failed=()

  info "pacman 安装 $label: $# 个包 (使用 retry)"
  if retry_run 2 30 "$label 批量安装" pacman -S --needed --noconfirm "$@"; then
    return 0
  fi

  warn "$label 批量安装失败，改为逐个安装以定位具体包。"
  for pkg in "$@"; do
    if pacman -Q "$pkg" >/dev/null 2>&1; then
      continue
    fi
    if ! pacman -S --needed --noconfirm "$pkg"; then
      failed+=("$pkg")
      warn "$label 中包安装失败: $pkg"
    fi
  done

  if ((${#failed[@]} > 0)); then
    die "$label 安装失败包: ${failed[*]}"
  fi
}

install_optional_pacman_packages() {
  local label="$1"
  shift
  local failed=()
  local pkg

  info "pacman 安装可选包 $label: $# 个包"
  for pkg in "$@"; do
    if pacman -Q "$pkg" >/dev/null 2>&1; then
      continue
    fi
    if ! pacman -S --needed --noconfirm "$pkg"; then
      failed+=("$pkg")
      warn "$label 可选包安装失败，已跳过: $pkg"
    fi
  done

  if ((${#failed[@]} > 0)); then
    warn "$label 有可选包未安装: ${failed[*]}"
  fi
}

install_aur_helper() {
  if command -v "$AUR_HELPER" >/dev/null 2>&1; then
    ok "$AUR_HELPER 已存在"
    return 0
  fi

  if retry_run 3 15 "yay/paru 仓库安装" pacman -S --needed --noconfirm yay paru; then
    AUR_HELPER="yay"
    return 0
  fi

  warn "仓库安装 yay/paru 失败，改为从 AUR 构建 yay。"
  retry_run 3 15 "base-devel/git/sudo" pacman -S --needed --noconfirm base-devel git sudo
  local build_dir="/tmp/yay-build"
  rm -rf "$build_dir"
  retry_run 3 15 "yay AUR 克隆" run_as_user git clone --depth=1 https://aur.archlinux.org/yay.git "$build_dir"
  retry_run 2 30 "yay AUR 构建" run_as_user bash -lc "cd '$build_dir' && makepkg -si --noconfirm"
  AUR_HELPER="yay"
}

detect_driver_packages() {
  CPU_DRIVER_PACKAGES=()
  GPU_DRIVER_PACKAGES=(mesa lib32-mesa)

  local cpu_vendor
  cpu_vendor="$(awk -F': ' '/vendor_id/ {print $2; exit}' /proc/cpuinfo 2>/dev/null || true)"
  case "$cpu_vendor" in
    AuthenticAMD|AMD)
      CPU_DRIVER_PACKAGES+=(amd-ucode)
      ;;
    GenuineIntel)
      CPU_DRIVER_PACKAGES+=(intel-ucode)
      ;;
    *)
      warn "未识别 CPU vendor_id: ${cpu_vendor:-unknown}，跳过 CPU 微码包。"
      ;;
  esac

  local display_devices
  display_devices="$(lspci | grep -Ei 'VGA|3D|Display' || true)"

  if [[ -n "$display_devices" ]]; then
    if grep -qi 'NVIDIA' <<<"$display_devices"; then
      local nvidia_kernel_pkg="nvidia-dkms"
      if grep -Eqi 'RTX|GTX 16|GTX 1650|GTX 1660|Quadro RTX|T[0-9]{3,4}|A[0-9]{3,4}|L[0-9]{3,4}' <<<"$display_devices"; then
        nvidia_kernel_pkg="nvidia-open-dkms"
      elif ! pacman -Si nvidia-dkms >/dev/null 2>&1; then
        warn "仓库中未找到 nvidia-dkms，NVIDIA 旧卡分支临时回退到 nvidia-open-dkms；chwd 会继续尝试补齐更合适的驱动。"
        nvidia_kernel_pkg="nvidia-open-dkms"
      fi
      info "NVIDIA 显卡检测结果: 使用 $nvidia_kernel_pkg"
      GPU_DRIVER_PACKAGES+=(
        "$nvidia_kernel_pkg" nvidia-utils nvidia-settings opencl-nvidia
        lib32-nvidia-utils lib32-opencl-nvidia libva-nvidia-driver
      )
    fi

    if grep -Eqi 'AMD|ATI|Radeon|Advanced Micro Devices' <<<"$display_devices"; then
      GPU_DRIVER_PACKAGES+=(vulkan-radeon lib32-vulkan-radeon)
    fi

    if grep -qi 'Intel' <<<"$display_devices"; then
      GPU_DRIVER_PACKAGES+=(vulkan-intel lib32-vulkan-intel intel-media-driver libva-intel-driver)
    fi
  else
    warn "没有从 lspci 识别到显卡设备，仅安装通用 Mesa/Vulkan 基础包。"
  fi

  mapfile -t CPU_DRIVER_PACKAGES < <(printf '%s\n' "${CPU_DRIVER_PACKAGES[@]}" | awk 'NF && !seen[$0]++')
  mapfile -t GPU_DRIVER_PACKAGES < <(printf '%s\n' "${GPU_DRIVER_PACKAGES[@]}" | awk 'NF && !seen[$0]++')

  info "CPU 驱动包: ${CPU_DRIVER_PACKAGES[*]:-无}"
  info "GPU 驱动包: ${GPU_DRIVER_PACKAGES[*]:-无}"
}

install_aur_packages() {
  local label="$1"
  shift
  local failed=()

  info "$AUR_HELPER 安装 $label: $# 个包"
  if retry_run 2 30 "$label 批量安装" run_as_user "$AUR_HELPER" -S --needed --noconfirm --answerdiff=None --answerclean=None "$@"; then
    return 0
  fi

  warn "$label 批量安装失败，改为逐个安装以定位具体包。"
  for pkg in "$@"; do
    if pacman -Q "$pkg" >/dev/null 2>&1; then
      continue
    fi
    if ! retry_run 2 30 "AUR 单包安装 $pkg" run_as_user "$AUR_HELPER" -S --needed --noconfirm --answerdiff=None --answerclean=None "$pkg"; then
      failed+=("$pkg")
      warn "$label 安装失败: $pkg"
    fi
  done

  if ((${#failed[@]} > 0)); then
    die "$label 安装失败包: ${failed[*]}"
  fi
}

install_optional_aur_packages() {
  local label="$1"
  shift
  local failed=()
  local pkg

  info "$AUR_HELPER 安装可选包 $label: $# 个包"
  for pkg in "$@"; do
    if pacman -Q "$pkg" >/dev/null 2>&1; then
      continue
    fi
    if ! retry_run 2 30 "AUR 单包安装 $pkg" run_as_user "$AUR_HELPER" -S --needed --noconfirm --answerdiff=None --answerclean=None "$pkg"; then
      failed+=("$pkg")
      warn "$label 可选包安装失败，已跳过: $pkg"
    fi
  done

  if ((${#failed[@]} > 0)); then
    warn "$label 有可选包未安装: ${failed[*]}"
  fi
}

run_hardware_autodetect() {
  if command -v chwd >/dev/null 2>&1; then
    info "运行 chwd -a 自动检测并补齐硬件驱动..."
    if retry_run 2 15 "chwd 硬件检测" chwd -a; then
      ok "chwd 硬件自动检测完成"
    else
      warn "chwd -a 返回失败；已保留前面的 CPU/GPU 手写检测驱动。若硬件异常，请查看日志中的“硬件自动检测驱动”环节。"
    fi
  else
    warn "未找到 chwd，跳过额外硬件自动检测；已使用脚本内置 CPU/GPU 检测安装驱动。"
  fi
}

configure_system() {
  run hostnamectl set-hostname "$TARGET_HOSTNAME"
  printf '%s\n' "$TARGET_HOSTNAME" > /etc/hostname
  grep -q "127.0.1.1[[:space:]]\+$TARGET_HOSTNAME" /etc/hosts || printf '127.0.1.1 %s\n' "$TARGET_HOSTNAME" >> /etc/hosts

  run ln -sf "/usr/share/zoneinfo/$TARGET_TIMEZONE" /etc/localtime
  run timedatectl set-ntp true

  sed -i 's/^#\s*en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
  sed -i 's/^#\s*zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen
  run locale-gen
  printf 'LANG=%s\n' "$TARGET_LOCALE" > /etc/locale.conf
  printf 'FONT=ter-v28n\n' > /etc/vconsole.conf
  printf 'EDITOR=vim\n' > /etc/environment

  mkdir -p /etc/NetworkManager/conf.d
  cat > /etc/NetworkManager/conf.d/wifi-backend.conf <<'EOF'
[device]
wifi.backend=iwd
EOF

  run systemctl enable NetworkManager
  run systemctl enable iwd
  run systemctl enable systemd-resolved
  run systemctl enable bluetooth || true
  run systemctl enable cups || true
  run systemctl enable power-profiles-daemon || true
  run systemctl enable paccache.timer || true
  run systemctl enable libvirtd || true
  run systemctl enable grub-btrfsd || true

  if getent group libvirt >/dev/null 2>&1; then
    run usermod -aG libvirt "$TARGET_USER"
  fi
}

configure_bootloader_and_drivers() {
  if grep -qi nvidia < <(lspci); then
    mkdir -p /etc/modprobe.d
    printf 'blacklist nouveau\n' > /etc/modprobe.d/nouveau.conf
    if grep -q '^MODULES=' /etc/mkinitcpio.conf; then
      sed -i 's/^MODULES=(/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm /' /etc/mkinitcpio.conf
    fi
  fi

  if command -v mkinitcpio >/dev/null 2>&1; then
    run mkinitcpio -P
  elif command -v dracut >/dev/null 2>&1; then
    run dracut --regenerate-all --force
  else
    warn "未找到 mkinitcpio 或 dracut，跳过 initramfs 重建；如果驱动未生效，需要按发行版文档手动重建。"
  fi

  if [[ -f /etc/default/grub ]] && command -v grub-mkconfig >/dev/null 2>&1 && [[ -d /boot/grub ]]; then
    if grep -qi nvidia < <(lspci); then
      if ! grep -q 'nvidia_drm.modeset=1' /etc/default/grub; then
        sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="nvidia_drm.modeset=1 nvidia_drm.fbdev=1 /' /etc/default/grub
      fi
    fi
    sed -i 's/^#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
    run env LANG=en_US.UTF-8 grub-mkconfig -o /boot/grub/grub.cfg
  elif command -v bootctl >/dev/null 2>&1 && bootctl status >/dev/null 2>&1; then
    warn "检测到 systemd-boot 或非 GRUB 引导，已跳过 grub-mkconfig。NVIDIA 内核参数如需写入，请按该发行版 boot loader 配置追加 nvidia_drm.modeset=1 nvidia_drm.fbdev=1。"
  else
    warn "未检测到可更新的 GRUB 配置，跳过 grub-mkconfig。"
  fi
}

configure_sddm() {
  run systemctl disable gdm lightdm ly ly@tty1 greetd 2>/dev/null || true
  run systemctl enable sddm

  mkdir -p /etc/sddm.conf.d
  cat > /etc/sddm.conf.d/10-bad0rang3-niri.conf <<EOF
[Autologin]
Relogin=false
Session=niri
User=$TARGET_USER

[General]
HaltCommand=/usr/bin/systemctl poweroff
RebootCommand=/usr/bin/systemctl reboot

[Theme]
Current=sugar-candy
CursorTheme=Adwaita
Font=Noto Sans,10
EOF
}

install_packages() {
  install_pacman_packages "基础系统包" "${CORE_PACKAGES[@]}"
  install_aur_helper
  detect_driver_packages
  install_pacman_packages "基础驱动与多媒体包" "${DRIVER_BASE_PACKAGES[@]}"
  ((${#CPU_DRIVER_PACKAGES[@]} > 0)) && install_pacman_packages "CPU 微码包" "${CPU_DRIVER_PACKAGES[@]}"
  ((${#GPU_DRIVER_PACKAGES[@]} > 0)) && install_pacman_packages "GPU 驱动包" "${GPU_DRIVER_PACKAGES[@]}"
  install_pacman_packages "桌面基础包" "${DESKTOP_PACKAGES[@]}"
  install_optional_pacman_packages "桌面体验包" "${OPTIONAL_DESKTOP_PACKAGES[@]}"
  install_aur_packages "Shorin DMS 核心包" "${SHORIN_CORE_PACKAGES[@]}"
  install_optional_aur_packages "用户常用 AUR/Shorin 包" "${SHORIN_OPTIONAL_PACKAGES[@]}"
}

write_user_file() {
  local path="$1"
  local dir
  dir="$(dirname "$path")"
  run_as_user mkdir -p "$dir"
  cat > "$path"
  chown "$TARGET_USER:$TARGET_USER" "$path"
}

write_user_file_if_missing() {
  local path="$1"
  if [[ -s "$path" ]]; then
    chown "$TARGET_USER:$TARGET_USER" "$path"
    return 0
  fi
  write_user_file "$path"
}

configure_shorin_dms() {
  local home_dir
  home_dir="$(getent passwd "$TARGET_USER" | cut -d: -f6)"

  run_as_user mkdir -p \
    "$home_dir/.config/niri/dms" \
    "$home_dir/.config/niri/scripts" \
    "$home_dir/.config/DankMaterialShell" \
    "$home_dir/.config/kitty" \
    "$home_dir/.config/fish" \
    "$home_dir/.config/fuzzel" \
    "$home_dir/.config/fastfetch" \
    "$home_dir/.config/btop/themes" \
    "$home_dir/.config/yazi" \
    "$home_dir/.config/gtk-3.0" \
    "$home_dir/.config/gtk-4.0" \
    "$home_dir/.config/qt5ct" \
    "$home_dir/.config/matugen" \
    "$home_dir/.config/fcitx5/conf" \
    "$home_dir/.config/autostart" \
    "$home_dir/.local/bin" \
    "$home_dir/Pictures/Wallpapers/api-random-download" \
    "$home_dir/Pictures/Screenshots/Niri-screenshots"

  if command -v shorindms >/dev/null 2>&1; then
    retry_run 2 15 "shorindms init" run_as_user shorindms init || warn "shorindms init 失败，继续写入本机覆盖配置。"
  else
    warn "未找到 shorindms 命令，可能 shorin-dms-niri-git 包未正确安装。"
  fi

  write_user_file "$home_dir/.config/niri/config.kdl" <<'EOF'
include "layout.kdl"
include "animations.kdl"
screenshot-path "~/Pictures/Screenshots/Niri-screenshots/%Y-%m-%d_%H-%M-%S.png"

environment {
    LANGUAGE "zh_CN.UTF-8"
    LANG "zh_CN.UTF-8"
    XMODIFIERS "@im=fcitx"
    QT_IM_MODULES "wayland;fcitx"
    QT_QPA_PLATFORMTHEME "gtk3"
    QT_QPA_PLATFORMTHEME_QT6 "gtk3"
    QS_ICON_THEME "Adwaita"
    EDITOR "vim"
}

input {
    keyboard { repeat-delay 250; repeat-rate 35 }
    touchpad { tap; natural-scroll }
    mouse { accel-speed -0.15; accel-profile "flat" }
}

spawn-sh-at-startup "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=niri & /usr/lib/xdg-desktop-portal-gnome"
spawn-sh-at-startup "systemctl --user set-environment XDG_SESSION_CLASS=user"
spawn-at-startup "fcitx5"
spawn-at-startup "~/.config/niri/scripts/screenshot-sound.sh"
spawn-at-startup "xhost" "+si:localuser:root"
spawn-at-startup "dsearch" "serve"
spawn-at-startup "systemctl" "--user" "start" "linuxqq-clipsync"

hotkey-overlay { skip-at-startup }
prefer-no-csd

window-rule { match app-id=r#"^org\.gnome\."# draw-border-with-background false geometry-corner-radius 12 clip-to-geometry true }
window-rule { match app-id=r#"^gnome-control-center$"# match app-id=r#"^pavucontrol$"# match app-id=r#"^nm-connection-editor$"# default-column-width { proportion 0.5; } open-floating false }
window-rule { match app-id=r#"^gnome-calculator$"# match app-id=r#"^galculator$"# match app-id=r#"^blueman-manager$"# match app-id=r#"^xdg-desktop-portal$"# open-floating true }
window-rule { match app-id=r#"^org\.wezfurlong\.wezterm$"# match app-id="Alacritty" match app-id="zen" match app-id="com.mitchellh.ghostty" match app-id="kitty" draw-border-with-background false }
window-rule { match app-id=r#"firefox$"# title="^Picture-in-Picture$" match app-id="zoom" open-floating true }
window-rule { match app-id=r#"org.quickshell$"# open-floating true }

include "dms/binds.kdl"
include "dms/alttab.kdl"
include "dms/supertab.kdl"
include optional=true "shorin-windowrules.kdl"
include optional=true "dms/windowrules.kdl"
include "dms/cursor.kdl"
include "dms/outputs.kdl"
include "dms/colors.kdl"
EOF

  write_user_file "$home_dir/.config/niri/layout.kdl" <<'EOF'
layout {
    gaps 8
    center-focused-column "never"
    preset-column-widths {
        proportion 0.33333
        proportion 0.5
        proportion 0.66667
    }
    default-column-width { proportion 0.5; }
    focus-ring { width 3 }
    border { off; width 4; active-color "#ffc87f"; inactive-color "#505050"; urgent-color "#9b0000" }
    shadow { on; softness 20; spread 2; offset x=-4 y=-4; color "rgba(0, 0, 0, 0.7)" }
    struts {}
}
EOF

  write_user_file "$home_dir/.config/niri/animations.kdl" <<'EOF'
animations {
    slowdown 0.98114514
    workspace-switch { spring damping-ratio=0.82 stiffness=400 epsilon=0.0001 }
    horizontal-view-movement { spring damping-ratio=0.84 stiffness=400 epsilon=0.0001 }
    window-open { spring damping-ratio=1.0 stiffness=1000 epsilon=0.0001 }
    window-close { spring damping-ratio=0.8 stiffness=400 epsilon=0.0001 }
    window-movement { spring damping-ratio=1.0 stiffness=800 epsilon=0.0001 }
    window-resize { spring damping-ratio=0.9 stiffness=500 epsilon=0.0001 }
    screenshot-ui-open { duration-ms 300 curve "ease-out-quad" }
    overview-open-close { spring damping-ratio=1.0 stiffness=900 epsilon=0.0001 }
}
EOF

  # auto-detect primary output if not explicitly set
  if [[ "$PRIMARY_OUTPUT_NAME" == "auto" || -z "$PRIMARY_OUTPUT_NAME" ]]; then
    local detect_out detect_mode detect_name
    detect_name=""
    detect_mode=""
    while IFS= read -r detect_out; do
      if [[ "$detect_out" =~ ^([A-Za-z0-9_-]+):\ (.+)$ ]]; then
        detect_name="${BASH_REMATCH[1]}"
        detect_mode="${BASH_REMATCH[2]}"
        break
      fi
    done < <(wlr-randr 2>/dev/null || true)
    if [[ -n "$detect_name" ]]; then
      PRIMARY_OUTPUT_NAME="$detect_name"
      PRIMARY_OUTPUT_MODE="${PRIMARY_OUTPUT_MODE:-$detect_mode}"
      ok "自动探测到显示器: ${PRIMARY_OUTPUT_NAME} ${PRIMARY_OUTPUT_MODE}"
    else
      warn "未能通过 wlr-randr 自动探测显示器，回退为 DP-3。等 niri 启动后 DMS 会修正此配置。"
      PRIMARY_OUTPUT_NAME="DP-3"
      PRIMARY_OUTPUT_MODE="${PRIMARY_OUTPUT_MODE:-preferred}"
    fi
  fi

  write_user_file "$home_dir/.config/niri/dms/outputs.kdl" <<EOF
output "$PRIMARY_OUTPUT_NAME" {
    mode "$PRIMARY_OUTPUT_MODE"
    scale $PRIMARY_OUTPUT_SCALE
    position x=0 y=0
}
EOF

  write_user_file "$home_dir/.config/niri/dms/cursor.kdl" <<'EOF'
cursor { xcursor-theme "Adwaita"; xcursor-size 24; hide-when-typing }
EOF

  write_user_file_if_missing "$home_dir/.config/niri/dms/colors.kdl" <<'EOF'
layout {
    background-color "transparent"
    focus-ring { active-color "#a1cafd"; inactive-color "#8d9199"; urgent-color "#ffb4ab" }
    border { active-color "#a1cafd"; inactive-color "#8d9199"; urgent-color "#ffb4ab" }
    shadow { color "#00000070" }
    tab-indicator { active-color "#a1cafd"; inactive-color "#8d9199"; urgent-color "#ffb4ab" }
    insert-hint { color "#a1cafd80" }
}
recent-windows { highlight { active-color "#1a4975"; urgent-color "#ffb4ab" } }
EOF

  write_user_file_if_missing "$home_dir/.config/niri/dms/alttab.kdl" <<'EOF'
// Generated fallback: shorindms init normally owns this file.
EOF

  write_user_file_if_missing "$home_dir/.config/niri/dms/supertab.kdl" <<'EOF'
// Generated fallback: shorindms init normally owns this file.
EOF

  write_user_file_if_missing "$home_dir/.config/niri/dms/windowrules.kdl" <<'EOF'
// Generated fallback: shorindms init normally owns this file.
EOF

  write_user_file_if_missing "$home_dir/.config/niri/dms/binds.kdl" <<'EOF'
binds {
    Mod+Shift+Slash hotkey-overlay-title="快捷键教程" { spawn "~/.config/niri/scripts/niri-binds"; }
    Mod+F1 hotkey-overlay-title="开关输入法" { spawn-sh "pkill fcitx5 || fcitx5"; }
    Mod+F2 hotkey-overlay-title="设置" { spawn-sh "dms ipc call settings focusOrToggle || true"; }
    Mod+Slash hotkey-overlay-title="临时终端" { spawn "kitty" "--single-instance" "--class" "quickterminal"; }
    Mod+Return hotkey-overlay-title="终端" { spawn "kitty"; }
    Mod+B hotkey-overlay-title="浏览器" { spawn "firefox"; }
    Mod+E hotkey-overlay-title="文件管理器" { spawn-sh "thunar || env GSK_RENDERER=gl nautilus --new-window"; }
    Mod+Z hotkey-overlay-title="应用菜单" { spawn-sh "dms ipc call spotlight toggle || fuzzel"; }
    Mod+O hotkey-overlay-title="总览" repeat=false { toggle-overview; }
    Mod+Q hotkey-overlay-title="关闭窗口" repeat=false { close-window; }
    Alt+F4 hotkey-overlay-title="强制关闭" repeat=false { close-window; }
    Mod+V hotkey-overlay-title="切换浮动" { toggle-window-floating; }
    Mod+F hotkey-overlay-title="最大化" { maximize-column; }
    Mod+Alt+F hotkey-overlay-title="全屏" { fullscreen-window; }
    Mod+R hotkey-overlay-title="切换宽度" { switch-preset-column-width; }
    Mod+Shift+R { switch-preset-window-height; }
    Mod+C { center-column; }

    Mod+Left { focus-column-left; }
    Mod+Down { focus-window-down; }
    Mod+Up { focus-window-up; }
    Mod+Right { focus-column-right; }
    Mod+H { focus-column-left; }
    Mod+J { focus-window-down; }
    Mod+K { focus-window-up; }
    Mod+L { focus-column-right; }
    Mod+Ctrl+Left { move-column-left; }
    Mod+Ctrl+Down { move-window-down; }
    Mod+Ctrl+Up { move-window-up; }
    Mod+Ctrl+Right { move-column-right; }
    Mod+Ctrl+H { move-column-left; }
    Mod+Ctrl+J { move-window-down; }
    Mod+Ctrl+K { move-window-up; }
    Mod+Ctrl+L { move-column-right; }

    Mod+1 { focus-workspace 1; }
    Mod+2 { focus-workspace 2; }
    Mod+3 { focus-workspace 3; }
    Mod+4 { focus-workspace 4; }
    Mod+5 { focus-workspace 5; }
    Mod+6 { focus-workspace 6; }
    Mod+7 { focus-workspace 7; }
    Mod+8 { focus-workspace 8; }
    Mod+9 { focus-workspace 9; }
    Mod+Ctrl+1 { move-column-to-workspace 1; }
    Mod+Ctrl+2 { move-column-to-workspace 2; }
    Mod+Ctrl+3 { move-column-to-workspace 3; }
    Mod+Ctrl+4 { move-column-to-workspace 4; }
    Mod+Ctrl+5 { move-column-to-workspace 5; }
    Mod+Ctrl+6 { move-column-to-workspace 6; }
    Mod+Ctrl+7 { move-column-to-workspace 7; }
    Mod+Ctrl+8 { move-column-to-workspace 8; }
    Mod+Ctrl+9 { move-column-to-workspace 9; }

    Print { spawn-sh "niri msg action screenshot --show-pointer false && pkill -f -USR1 screenshot-sound.sh"; }
    Ctrl+Print { spawn-sh "niri msg action screenshot-window --show-pointer false && pkill -f -USR1 screenshot-sound.sh"; }
    Shift+Print { spawn-sh "niri msg action screenshot-screen --show-pointer false && pkill -f -USR1 screenshot-sound.sh"; }
    Mod+Shift+S hotkey-overlay-title="编辑截图" { spawn-sh "wl-paste | satty -f -"; }

    Super+X hotkey-overlay-title="电源菜单" { spawn-sh "dms ipc call powermenu toggle || systemctl poweroff"; }
    Mod+Alt+V hotkey-overlay-title="剪贴板" { spawn-sh "dms ipc call clipboard toggle || true"; }
    Mod+Shift+N hotkey-overlay-title="记事本" { spawn-sh "dms ipc call notepad toggle || true"; }
    Mod+Alt+L hotkey-overlay-title="锁屏" { spawn-sh "dms ipc call lock lock || true"; }
    Mod+Alt+W hotkey-overlay-title="壁纸" { spawn-sh "dms ipc call dankdash wallpaper || true"; }

    XF86AudioRaiseVolume allow-when-locked=true { spawn-sh "dms ipc call audio increment 3 || wpctl set-volume @DEFAULT_AUDIO_SINK@ 3%+"; }
    XF86AudioLowerVolume allow-when-locked=true { spawn-sh "dms ipc call audio decrement 3 || wpctl set-volume @DEFAULT_AUDIO_SINK@ 3%-"; }
    XF86AudioMute allow-when-locked=true { spawn-sh "dms ipc call audio mute || wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"; }
    XF86AudioPlay allow-when-locked=true { spawn-sh "dms ipc call mpris playPause || playerctl play-pause"; }
    XF86AudioPrev allow-when-locked=true { spawn-sh "dms ipc call mpris previous || playerctl previous"; }
    XF86AudioNext allow-when-locked=true { spawn-sh "dms ipc call mpris next || playerctl next"; }
    XF86MonBrightnessUp allow-when-locked=true { spawn-sh "dms ipc call brightness increment 5 '' || brightnessctl set 5%+"; }
    XF86MonBrightnessDown allow-when-locked=true { spawn-sh "dms ipc call brightness decrement 5 '' || brightnessctl set 5%-"; }

    Mod+Shift+E hotkey-overlay-title="退出 niri" { quit; }
}
EOF

  write_user_file "$home_dir/.config/niri/shorin-windowrules.kdl" <<'EOF'
window-rule { geometry-corner-radius 8 clip-to-geometry true draw-border-with-background false }
layer-rule { match namespace="dms:blurwallpaper" place-within-backdrop true }
window-rule { match app-id="imv" open-floating true }
window-rule { match app-id="quickterminal" open-floating true default-floating-position x=20 y=20 relative-to="top" }
window-rule { match app-id="bluetui" match app-id="impala" default-column-width { fixed 800; } default-window-height { fixed 800; } open-floating true }
window-rule { match app-id="com.gabm.satty" match app-id="media_info" match app-id="video2gif" match app-id="floating-term" match app-id="nm-connection-editor" match app-id="niri-quick-switch" match app-id=r#"firefox$"# title="^Picture-in-Picture$" match app-id="steam" title="Friends List" match app-id="blueman-manager" match app-id="org.pulseaudio.pavucontrol" title="音量控制" match app-id="org.gnome.clocks" title="时钟" match app-id="fcitx" title="Fcitx5 Input Window" match app-id="org.gnome.FileRoller" match app-id="thunar" title="文件操作进度" match app-id="btrfs-assistant" open-floating true }
EOF

  write_user_file "$home_dir/.config/niri/scripts/screenshot-sound.sh" <<'EOF'
#!/usr/bin/env bash
SOUND="/usr/share/sounds/freedesktop/stereo/camera-shutter.oga"
TRIGGER_FILE="/dev/shm/niri_screenshot_armed"
TIMEOUT_SEC=15
command -v pw-play >/dev/null || exit 0
arm_trigger() { touch "$TRIGGER_FILE"; }
trap arm_trigger SIGUSR1
wl-paste --watch bash -c '
if wl-paste --list-types 2>/dev/null | grep -q "image/"; then
  if [ -f "'"$TRIGGER_FILE"'" ]; then
    now=$(date +%s)
    ft=$(stat -c %Y "'"$TRIGGER_FILE"'")
    if [ $((now - ft)) -lt '"$TIMEOUT_SEC"' ]; then
      pw-play "'"$SOUND"'" &
      rm -f "'"$TRIGGER_FILE"'"
    fi
  fi
fi' &
watcher_pid=$!
trap "kill $watcher_pid 2>/dev/null; exit" INT TERM EXIT
while true; do sleep infinity & wait $!; done
EOF
  run chmod +x "$home_dir/.config/niri/scripts/screenshot-sound.sh"

  write_user_file "$home_dir/.config/niri/scripts/niri-binds" <<'EOF'
#!/usr/bin/env bash
cat <<'HELP'
Niri 快捷键速查

Mod+Return  终端
Mod+B       浏览器
Mod+E       文件管理器
Mod+Z       应用菜单
Mod+Q       关闭窗口
Mod+F       最大化
Mod+V       切换浮动
Mod+H/J/K/L 聚焦窗口
Mod+Ctrl+H/J/K/L 移动窗口
Print       截图
Super+X     电源菜单
HELP
read -r -p "按回车关闭..."
EOF
  run chmod +x "$home_dir/.config/niri/scripts/niri-binds"

  write_user_file "$home_dir/.config/kitty/kitty.conf" <<'EOF'
include dank-tabs.conf
include dank-theme.conf
window_padding_width 5
hide_window_decorations yes
background_opacity 0.8
font_family JetBrains Maple Mono
font_size 13.5
remember_window_size no
confirm_os_window_close 0
shell fish
cursor_trail 1
cursor_shape block
shell_integration no-cursor
EOF

  write_user_file "$home_dir/.config/kitty/dank-theme.conf" <<'EOF'
cursor #e1e2e8
cursor_text_color #c3c6cf
foreground #e1e2e8
background #111418
selection_foreground #253140
selection_background #bbc7db
url_color #a1cafd
color0 #111418
color1 #ff729b
color2 #7efd8f
color3 #fff772
color4 #87b6f0
color5 #274975
color6 #a1cafd
color7 #eff6ff
color8 #989da4
color9 #ff9fbb
color10 #a5ffb2
color11 #fffaa5
color12 #b0d3ff
color13 #bedbff
color14 #d5e7ff
color15 #f8fbff
EOF

  write_user_file "$home_dir/.config/kitty/dank-tabs.conf" <<'EOF'
tab_bar_edge top
tab_bar_style powerline
tab_powerline_style slanted
tab_bar_align left
tab_bar_min_tabs 2
tab_bar_margin_width 0.0
tab_bar_margin_height 2.5 1.5
tab_bar_background #111418
active_tab_foreground #003259
active_tab_background #a1cafd
active_tab_font_style bold
inactive_tab_foreground #c3c6cf
inactive_tab_background #111418
inactive_tab_font_style normal
tab_activity_symbol " ● "
tab_title_template "{fmt.fg.red}{bell_symbol}{activity_symbol}{fmt.fg.tab}{title[:30]} [{index}]"
active_tab_title_template "{fmt.fg.red}{bell_symbol}{activity_symbol}{fmt.fg.tab}{title[:30]} [{index}]"
EOF

  write_user_file "$home_dir/.config/fish/config.fish" <<'EOF'
set fish_greeting ""
set -p PATH ~/.local/bin
starship init fish | source
zoxide init fish --cmd cd | source
function y; set tmp (mktemp -t "yazi-cwd.XXXXXX"); yazi $argv --cwd-file="$tmp"; if read -z cwd < "$tmp"; and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]; builtin cd -- "$cwd"; end; rm -f -- "$tmp"; end
function cat; command bat $argv; end
function ls; command eza --icons $argv; end
function lt; command eza --icons --tree $argv; end
abbr grub 'LANGUAGE=en_US.UTF-8 LANG=en_US.UTF-8 sudo grub-mkconfig -o /boot/grub/grub.cfg'
abbr fa fastfetch
abbr reboot 'systemctl reboot'
function sl; command sl | lolcat; end
EOF
  cat >> "$home_dir/.config/fish/config.fish" <<EOF
function 安装; command $AUR_HELPER -S \$argv; end
function 卸载; command $AUR_HELPER -Rns \$argv; end
EOF
  chown "$TARGET_USER:$TARGET_USER" "$home_dir/.config/fish/config.fish"

  if [[ -x "$TARGET_SHELL" ]]; then
    grep -Fxq "$TARGET_SHELL" /etc/shells || printf '%s\n' "$TARGET_SHELL" >> /etc/shells
    run chsh -s "$TARGET_SHELL" "$TARGET_USER" || true
  fi

  write_user_file "$home_dir/.config/starship.toml" <<'EOF'
"$schema" = 'https://starship.rs/config-schema.json'
format = """[](color_orange)$os$username[](bg:color_yellow fg:color_orange)$directory[](fg:color_yellow bg:color_aqua)$git_branch$git_status[](fg:color_aqua bg:color_blue)$c$cpp$rust$golang$nodejs$php$java$kotlin$haskell$python[](fg:color_blue bg:color_bg3)$docker_context$conda$pixi[](fg:color_bg3 bg:color_bg1)$time[ ](fg:color_bg1)$line_break$character"""
palette = 'colors'
[palettes.colors]
color_orange = '#a1cafd'
color_fg0 = '#003259'
color_fg1 = '#e1e2e8'
color_bg3 = '#bbc7db'
color_green = '#003259'
color_bg1 = '#3b4858'
color_blue = '#36618e'
color_red = '#a1cafd'
color_aqua = '#d7e3f8'
color_yellow = '#d7bee4'
[os]
disabled = false
style = "bg:color_orange fg:color_fg0"
[username]
show_always = true
style_user = "bg:color_orange fg:color_fg0"
style_root = "bg:color_orange fg:color_fg0"
format = '[ $user ]($style)'
[directory]
style = "fg:color_fg0 bg:color_yellow"
format = "[ $path ]($style)"
truncation_length = 3
truncation_symbol = "…/"
[git_branch]
symbol = ""
style = "bg:color_aqua"
format = '[[ $symbol $branch ](fg:color_fg0 bg:color_aqua)]($style)'
[git_status]
style = "bg:color_aqua"
format = '[[($all_status$ahead_behind )](fg:color_fg0 bg:color_aqua)]($style)'
[nodejs]
symbol = ""
style = "bg:color_blue"
format = '[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)'
[c]
symbol = " "
style = "bg:color_blue"
format = '[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)'
[rust]
symbol = ""
style = "bg:color_blue"
format = '[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)'
[python]
symbol = ""
style = "bg:color_blue"
format = '[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)'
[time]
disabled = false
time_format = "%R"
style = "bg:color_bg1"
format = '[[  $time ](fg:color_fg1 bg:color_bg1)]($style)'
[character]
disabled = false
success_symbol = '[](bold fg:color_green)'
error_symbol = '[](bold fg:color_red)'
EOF

  write_user_file "$home_dir/.config/fuzzel/fuzzel.ini" <<'EOF'
[main]
include = "~/.config/fuzzel/colors.ini"
font=adwaita sans:size=13
terminal=kitty -e
lines=9
width=35
horizontal-pad=40
vertical-pad=15
inner-pad=5
line-height=25
[border]
width=2
radius=8
EOF

  write_user_file "$home_dir/.config/fuzzel/colors.ini" <<'EOF'
[colors]
background=1d2024cc
text=e1e2e8ff
prompt=bbc7dbff
input=a1cafdff
match=d7bee4ff
selection=bbc7dbe6
selection-text=253140ff
border=bbc7dbff
EOF

  write_user_file "$home_dir/.config/fastfetch/config.jsonc" <<'EOF'
{
  "logo": { "width": 25, "color": { "1": "#a1cafd", "2": "#a1cafd" }, "padding": { "top": 1, "left": 2, "right": 2 } },
  "display": { "separator": " ", "color": { "title": "#c3c6cf", "output": "#c3c6cf" } },
  "modules": [
    "break",
    { "type": "os", "key": "OS", "keyColor": "#a1cafd" },
    { "type": "kernel", "key": " ├   KER ", "keyColor": "#a1cafd" },
    { "type": "packages", "key": " ├   PAK ", "format": "{all}", "keyColor": "#a1cafd" },
    { "type": "title", "key": " └   USR ", "keyColor": "#a1cafd" },
    "break",
    { "type": "wm", "key": "WM", "keyColor": "#d7bee4" },
    { "type": "shell", "key": " ├   SHE ", "keyColor": "#d7bee4" },
    { "type": "terminal", "key": " ├   TER ", "keyColor": "#d7bee4" },
    { "type": "terminalfont", "key": " └   TFO ", "keyColor": "#d7bee4" },
    "break",
    { "type": "host", "key": "PC ", "keyColor": "#d7e3f8" },
    { "type": "cpu", "key": " ├   CPU ", "keyColor": "#d7e3f8" },
    { "type": "memory", "key": " ├   MEM ", "keyColor": "#d7e3f8" },
    { "type": "gpu", "key": " ├ 󰢮  GPU ", "format": "{1} {2}", "keyColor": "#d7e3f8" },
    { "type": "display", "key": " ├   MON ", "format": "{name} {width}x{height}@{refresh-rate} ", "keyColor": "#d7e3f8" },
    { "type": "disk", "key": " └ 󰋊  DIS ", "keyColor": "#d7e3f8" },
    "break",
    "colors"
  ]
}
EOF

  write_user_file "$home_dir/.config/btop/btop.conf" <<'EOF'
color_theme = "matugen.theme"
theme_background = False
truecolor = True
rounded_corners = True
graph_symbol = "braille"
shown_boxes = "cpu mem net proc"
update_ms = 2000
proc_sorting = "cpu direct"
proc_colors = True
proc_gradient = True
proc_mem_bytes = True
proc_cpu_graphs = True
show_uptime = True
check_temp = True
show_cpu_freq = True
clock_format = "%X"
mem_graphs = True
show_swap = True
show_disks = True
io_mode = True
net_auto = True
show_battery = True
EOF

  write_user_file "$home_dir/.config/btop/themes/matugen.theme" <<'EOF'
theme[main_bg]="#111418"
theme[main_fg]="#e1e2e8"
theme[title]="#a1cafd"
theme[hi_fg]="#a1cafd"
theme[selected_bg]="#253140"
theme[selected_fg]="#eff6ff"
theme[inactive_fg]="#8d9199"
theme[graph_text]="#bbc7db"
theme[meter_bg]="#1d2024"
theme[proc_misc]="#d7bee4"
theme[cpu_box]="#a1cafd"
theme[mem_box]="#d7bee4"
theme[net_box]="#d7e3f8"
theme[proc_box]="#bbc7db"
EOF

  write_user_file "$home_dir/.config/yazi/theme.toml" <<'EOF'
[mgr]
cwd = { fg = "#e1e2e8" }
[tabs]
active = { fg = "#a1cafd", bold = true, bg = "#111418" }
inactive = { fg = "#bbc7db", bg = "#111418" }
[mode]
normal_main = { bg = "#a1cafd", fg = "#003259", bold = true }
[which]
cand = { fg = "#a1cafd" }
rest = { fg = "#003259" }
[filetype]
rules = [
  { mime = "image/*", fg = "#94e2d5" },
  { mime = "{audio,video}/*", fg = "#f9e2af" },
  { url = "*", fg = "#e1e2e8" },
  { url = "*/", fg = "#a1cafd" }
]
EOF

  for gtk_ver in 3.0 4.0; do
    write_user_file "$home_dir/.config/gtk-$gtk_ver/settings.ini" <<'EOF'
[Settings]
gtk-application-prefer-dark-theme=true
gtk-cursor-theme-name=Adwaita
gtk-cursor-theme-size=24
gtk-decoration-layout=menu:minimize,maximize,close
gtk-enable-animations=true
gtk-font-name=Noto Sans, 10
gtk-icon-theme-name=Adwaita
gtk-im-module=fcitx
gtk-primary-button-warps-slider=true
gtk-sound-theme-name=freedesktop
gtk-xft-dpi=98304
EOF
    write_user_file "$home_dir/.config/gtk-$gtk_ver/gtk.css" <<'EOF'
@define-color accent_bg_color #a1cafd;
@define-color accent_fg_color #003259;
@define-color window_bg_color #111418;
@define-color window_fg_color #e1e2e8;
@define-color view_bg_color #111418;
@define-color view_fg_color #e1e2e8;
@define-color card_bg_color #1d2024;
@define-color card_fg_color #e1e2e8;
EOF
  done

  write_user_file "$home_dir/.config/qt5ct/qt5ct.conf" <<'EOF'
[Appearance]
icon_theme=Adwaita
style=Adwaita-Dark
EOF

  write_user_file "$home_dir/.config/matugen/config.toml" <<'EOF'
[config]
[templates.btop]
input_path = '~/.config/matugen/templates/btop.theme'
output_path = '~/.config/btop/themes/matugen.theme'
post_hook = 'killall -SIGUSR1 btop 2>/dev/null; killall -SIGUSR2 btop 2>/dev/null &'
[templates.starship]
input_path = '~/.config/matugen/templates/starship-colors.toml'
output_path = '~/.config/starship.toml'
[templates.fastfetch]
input_path = '~/.config/matugen/templates/fastfetch-config.jsonc'
output_path = '~/.config/fastfetch/config.jsonc'
[templates.fuzzel]
input_path = '~/.config/matugen/templates/fuzzel.ini'
output_path = '~/.config/fuzzel/colors.ini'
EOF

  write_user_file "$home_dir/.config/fcitx5/profile" <<'EOF'
[Groups/0]
Name=Default
Default Layout=us
DefaultIM=rime
[Groups/0/Items/0]
Name=keyboard-us
Layout=
[Groups/0/Items/1]
Name=rime
Layout=
[GroupOrder]
0=Default
EOF

  write_user_file "$home_dir/.config/fcitx5/config" <<'EOF'
[Hotkey/TriggerKeys]
0=Super+space
1=Zenkaku_Hankaku
2=Hangul
[Hotkey/AltTriggerKeys]
0=Shift_L
[Hotkey/EnumerateGroupForwardKeys]
0=Super+space
[Hotkey/EnumerateGroupBackwardKeys]
0=Shift+Super+space
[Behavior]
ActiveByDefault=False
DefaultPageSize=5
PreeditEnabledByDefault=True
ShowInputMethodInformation=True
CompactInputMethodInformation=True
PreloadInputMethod=True
AllowInputMethodForPassword=False
EOF

  write_user_file "$home_dir/.config/autostart/fcitx5.desktop" <<'EOF'
[Desktop Entry]
Name=fcitx5
Comment=Start fcitx5
Exec=fcitx5
Icon=fcitx
Terminal=false
Type=Application
Categories=System;Utility;
EOF

  write_user_file "$home_dir/.config/systemd/user/gslapper.service" <<'EOF'
[Unit]
Description=gslapper
PartOf=graphical-session.target
After=graphical-session.target
[Service]
ExecStart=gslapper
[Install]
WantedBy=graphical-session.target
EOF

  run_as_user mkdir -p "$home_dir/.config/systemd/user/graphical-session.target.wants"
  [[ -f /usr/lib/systemd/user/dms.service ]] && run_as_user ln -sf /usr/lib/systemd/user/dms.service "$home_dir/.config/systemd/user/graphical-session.target.wants/dms.service"
  run_as_user ln -sf "$home_dir/.config/systemd/user/gslapper.service" "$home_dir/.config/systemd/user/graphical-session.target.wants/gslapper.service"

  write_user_file "$home_dir/.local/bin/random-anime-wallpaper-dms" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
api_url="https://t.alcy.cc/pc/"
save_dir="$HOME/Pictures/Wallpapers/api-random-download"
mkdir -p "$save_dir"
raw="$save_dir/wall_$(date +%s)_raw.tmp"
final="${raw%_raw.tmp}.png"
curl -L -s -A "Mozilla/5.0" --connect-timeout 10 -m 120 -o "$raw" "$api_url"
[[ -s "$raw" ]] || { notify-send "Wallpaper" "Download failed"; exit 1; }
file --mime-type -b "$raw" | grep -q '^image/' || { rm -f "$raw"; notify-send "Wallpaper" "Not an image"; exit 1; }
magick "$raw" "$final"
rm -f "$raw"
dms ipc call wallpaper set "$final" 2>/dev/null || true
notify-send "Wallpaper" "Wallpaper updated"
EOF
  run chmod +x "$home_dir/.local/bin/random-anime-wallpaper-dms"

  run chown -R "$TARGET_USER:$TARGET_USER" "$home_dir/.config" "$home_dir/.local" "$home_dir/Pictures"
}

finalize_install() {
  local home_dir docs_dir
  home_dir="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
  docs_dir="$home_dir/Documents"
  mkdir -p "$docs_dir"
  cp "$LOG_FILE" "$docs_dir/log-bad0rang3-shorin-niri-install.txt" || true
  chown -R "$TARGET_USER:$TARGET_USER" "$docs_dir"

  rm -f /etc/sudoers.d/10-bad0rang3-install
  rm -f "$STATE_FILE"

  printf '\n%s安装完成。%s\n' "$GREEN" "$NC"
  printf '重启后应进入 SDDM，并可选择 niri 会话；系统组合为 Shorin DMS + niri。\n'
  printf '日志已保存到: %s/log-bad0rang3-shorin-niri-install.txt\n' "$docs_dir"
  printf '%s现在请重启: systemctl reboot%s\n' "$YELLOW" "$NC"
}

main() {
  case "${1:-}" in
    --help|-h)
      sed -n '1,18p' "$0"
      exit 0
      ;;
    --force)
      rm -f "$STATE_FILE"
      ;;
    "")
      ;;
    *)
      printf '未知参数: %s\n' "$1" >&2
      exit 2
      ;;
  esac

  CURRENT_STAGE="前置检查"
  preflight

  step "配置 pacman / archlinuxcn / shorin-arch 源" setup_repositories
  step "用户与权限" ensure_user
  step "安装软件包" install_packages
  step "硬件自动检测驱动" run_hardware_autodetect
  step "系统参数与服务" configure_system
  step "驱动与引导配置" configure_bootloader_and_drivers
  step "SDDM 登录管理器" configure_sddm
  step "Shorin DMS + niri 用户配置" configure_shorin_dms

  CURRENT_STAGE="完成与重启提示"
  finalize_install
}

main "$@"
