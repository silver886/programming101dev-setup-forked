#!/usr/bin/env bash
# update-system.sh, unified updater for macOS, Linux distros, and FreeBSD

set -euo pipefail
IFS=$' \t\n'

die() { printf "Error: %s\n" "$*" >&2; exit 1; }

need_cmd() { command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"; }

update_macos() {
  echo "Detected macOS."
  if command -v brew >/dev/null 2>&1; then
    echo "Updating Homebrew packages..."
    brew update
    brew upgrade
  else
    echo "Homebrew not found, skipping."
  fi
  echo "Running macOS Software Update..."
  need_cmd sudo
  sudo softwareupdate --install --all
}

update_apt_like() {
  echo "Updating with APT..."
  need_cmd sudo
  sudo apt-get update
  sudo apt-get -y dist-upgrade
}

update_dnf_like() {
  echo "Updating with DNF..."
  need_cmd sudo
  sudo dnf upgrade --refresh -y
}

update_pacman_like() {
  echo "Updating with Pacman..."
  need_cmd sudo
  sudo pacman -Syu --noconfirm
}

update_manjaro() {
  echo "Detected Manjaro."
  update_pacman_like
  if command -v yay >/dev/null 2>&1; then
    echo "Updating AUR packages with yay..."
    yay -Syu --noconfirm
  fi
}

update_freebsd() {
  echo "Detected FreeBSD."
  need_cmd sudo
  echo "Updating FreeBSD base system..."
  sudo freebsd-update fetch install
  echo "Updating packages..."
  sudo pkg update
  sudo pkg upgrade -y
}

update_linux() {
  if [[ -f /etc/os-release ]]; then
    # shellcheck source=/dev/null
    . /etc/os-release
  else
    die "cannot detect Linux distribution, /etc/os-release missing"
  fi

  # Normalize IDs for routing.
  distro_id="${ID:-}"
  distro_like="${ID_LIKE:-}"

  case "$distro_id" in
    ubuntu|kali|debian)
      update_apt_like
      ;;
    fedora)
      update_dnf_like
      ;;
    manjaro)
      update_manjaro
      ;;
    arch)
      update_pacman_like
      ;;
    *)
      case "$distro_like" in
        *debian*) update_apt_like ;;
        *rhel*|*fedora*) update_dnf_like ;;
        *arch*) update_pacman_like ;;
        *)
          die "unsupported Linux distribution: ${distro_id:-unknown} (ID_LIKE='${distro_like:-unset}')"
          ;;
      esac
      ;;
  esac
}

main() {
  os="$(uname -s)"
  case "$os" in
    Darwin)  update_macos ;;
    Linux)   update_linux ;;
    FreeBSD) update_freebsd ;;
    *)       die "unsupported operating system: $os" ;;
  esac
}

main "$@"
