#!/usr/bin/env bash
set -eu

# ==================================================
#            AUTO INSTALLER BY DEMS
# ==================================================

GREEN="\033[0;32m"
CYAN="\033[0;36m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
BOLD="\033[1m"
RESET="\033[0m"

# =============================
# Spinner helper
# =============================
run_with_spinner() {
  msg="$1"; shift
  log="/tmp/dems_installer_$$.log"

  printf "%s " "$msg"
  ( "$@" ) >"$log" 2>&1 &
  pid=$!

  spin='|/-\'
  i=0
  bar=""

  while kill -0 "$pid" 2>/dev/null; do
    i=$(( (i+1) % 4 ))
    if [ ${#bar} -ge 30 ]; then bar=""; else bar="${bar}█"; fi
    printf "\r%s %c [% -30s]" "$msg" "${spin:$i:1}" "$bar"
    sleep 0.15
  done

  wait "$pid"
  rc=$?

  if [ "$rc" -eq 0 ]; then
    printf "\r%s ✓ [% -30s]\n" "$msg" "$(printf '█%.0s' $(seq 1 30))"
    rm -f "$log" 2>/dev/null || true
    return 0
  fi

  printf "\r%s ✗\n" "$msg"
  echo "---- ERROR LOG (tail) ----"
  tail -n 80 "$log" || true
  echo "--------------------------"
  exit 1
}

# =============================
# Banner
# =============================
print_banner() {
  clear || true
  echo -e "${GREEN}${BOLD}"
  cat <<'EOF'
 █████╗ ██╗   ██╗████████╗ ██████╗     ██╗███╗   ██╗███████╗████████╗ █████╗ ██╗     ██╗     ███████╗██████╗
██╔══██╗██║   ██║╚══██╔══╝██╔═══██╗    ██║████╗  ██║██╔════╝╚══██╔══╝██╔══██╗██║     ██║     ██╔════╝██╔══██╗
███████║██║   ██║   ██║   ██║   ██║    ██║██╔██╗ ██║███████╗   ██║   ███████║██║     ██║     █████╗  ██████╔╝
██╔══██║██║   ██║   ██║   ██║   ██║    ██║██║╚██╗██║╚════██║   ██║   ██╔══██║██║     ██║     ██╔══╝  ██╔══██╗
██║  ██║╚██████╔╝   ██║   ╚██████╔╝    ██║██║ ╚████║███████║   ██║   ██║  ██║███████╗███████╗███████╗██║  ██║
╚═╝  ╚═╝ ╚═════╝    ╚═╝    ╚═════╝     ╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝╚═╝  ╚═╝

                         AUTO INSTALLER BY DEMS
EOF
  echo -e "${RESET}"
}

# =============================
# Docker auto install
# =============================
install_docker() {
  echo -e "${YELLOW}Docker belum terinstall. Menginstall Docker...${RESET}"

  run_with_spinner "Updating apt repository" apt update
  run_with_spinner "Installing prerequisites" apt install -y ca-certificates curl gnupg lsb-release
  run_with_spinner "Downloading get.docker.com" bash -c 'curl -fsSL https://get.docker.com -o /tmp/get-docker.sh'
  run_with_spinner "Installing Docker engine" sh /tmp/get-docker.sh

  if command -v systemctl >/dev/null 2>&1; then
    run_with_spinner "Enabling Docker service" systemctl enable docker
    run_with_spinner "Starting Docker service" systemctl start docker
  fi

  echo -e "${GREEN}Docker berhasil diinstall.${RESET}"
}

preflight() {
  if ! command -v docker >/dev/null 2>&1; then
    install_docker
  else
    echo -e "${GREEN}Docker sudah terinstall.${RESET}"
  fi

  if ! docker compose version >/dev/null 2>&1; then
    echo -e "${YELLOW}Docker Compose plugin belum ada. Menginstall...${RESET}"
    mkdir -p /usr/lib/docker/cli-plugins
    run_with_spinner "Installing Docker Compose plugin" \
      curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
      -o /usr/lib/docker/cli-plugins/docker-compose
    chmod +x /usr/lib/docker/cli-plugins/docker-compose
  fi
}

# =============================
# Windows menu
# =============================
WIN_NAME=(
  "" "Windows 11 Pro" "Windows 11 Enterprise" "Windows 10 Pro"
  "Windows 10 LTSC" "Windows 10 Enterprise" "Windows 8.1 Enterprise"
  "Windows 7 Ultimate" "Windows Vista Ultimate" "Windows XP Professional"
  "Windows Server 2025" "Windows Server 2022" "Windows Server 2019" "Windows Server 2016"
)

WIN_VERSION=(
  "" "11" "11e" "10" "10l" "10e" "8e" "7u" "vu" "xp" "2025" "2022" "2019" "2016"
)

print_menu() {
  echo -e "${CYAN}┌────┬───────────────────────────────┐${RESET}"
  echo -e "${CYAN}│ No │ Version                       │${RESET}"
  echo -e "${CYAN}├────┼───────────────────────────────┤${RESET}"
  i=1
  while [ "$i" -le 13 ]; do
    printf "${CYAN}│${RESET} %2d ${CYAN}│${RESET} %-29s ${CYAN}│${RESET}\n" "$i" "${WIN_NAME[$i]}"
    i=$((i+1))
  done
  echo -e "${CYAN}└────┴───────────────────────────────┘${RESET}"
}

read_default() {
  prompt="$1"; def="$2"
  read -r -p "$prompt [$def]: " val
  echo "${val:-$def}"
}

write_compose() {
  cat > docker-compose.yml <<EOF
services:
  windows:
    image: dockurr/windows
    container_name: windows
    environment:
      VERSION: "$1"
      RAM_SIZE: "$2"
      CPU_CORES: "$3"
      DISK_SIZE: "$4"
      USERNAME: "$5"
      PASSWORD: "$6"
    devices:
      - /dev/kvm
      - /dev/net/tun
    cap_add:
      - NET_ADMIN
    ports:
      - 8006:8006
      - 3389:3389/tcp
      - 3389:3389/udp
    volumes:
      - ./windows:/storage
    restart: always
    stop_grace_period: 2m
EOF
}

# =============================
# Main
# =============================
main() {
  print_banner
  preflight
  mkdir -p windows

  print_menu
  read -r -p "Pilih Windows (1-13): " pick

  ram="$(read_default 'Input size RAM' '4G')"
  cpu="$(read_default 'Input CPU core' '2')"
  disk="$(read_default 'Input storage/disk' '64G')"
  user="$(read_default 'Input username' 'Administrator')"
  pass="$(read_default 'Input password' 'DemsWindows26')"

  echo
  echo -e "${CYAN}Ringkasan:${RESET}"
  echo " Windows  : ${WIN_NAME[$pick]}"
  echo " RAM      : $ram"
  echo " CPU      : $cpu core"
  echo " Disk     : $disk"
  echo " Username : $user"
  echo " Password : $pass"
  echo

  write_compose "${WIN_VERSION[$pick]}" "$ram" "$cpu" "$disk" "$user" "$pass"

  echo -e "${GREEN}Menjalankan Windows container...${RESET}"
  docker compose up -d

  echo
  echo -e "${GREEN}Installer berjalan.${RESET}"
  echo "Akses via browser: http://{ip-vps-kamu}:8006"
}

main
