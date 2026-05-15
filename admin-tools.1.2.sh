#!/usr/bin/env bash
set -eE
trap 'echo "Error on line $LINENO. Returning to menu."' ERR

# =========================
# COLORS
# =========================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

# =========================
# CONFIG
# =========================

SSH_CONFIG="/etc/ssh/sshd_config"

# =========================
# UTILS
# =========================

require_root() {
  if [ "$EUID" -ne 0 ]; then
    echo "Run as root"
    exit 1
  fi
}

user_exists() {
  id "$1" >/dev/null 2>&1
}

user_home_dir() {
  getent passwd "$1" | cut -d: -f6
}

is_valid_port() {
  [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -ge 1 ] && [ "$1" -le 65535 ]
}

is_valid_ssh_public_key() {
  [[ "$1" =~ ^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521|sk-ssh-ed25519@openssh.com|sk-ecdsa-sha2-nistp256@openssh.com)[[:space:]]+[A-Za-z0-9+/=]+([[:space:]].*)?$ ]]
}

ensure_curl() {
  if ! command -v curl >/dev/null 2>&1; then
    apt update
    apt install -y curl
  fi
}

backup_ssh_config() {
  if [ -f "$SSH_CONFIG" ]; then
    cp "$SSH_CONFIG" "${SSH_CONFIG}.bak.$(date +%Y%m%d%H%M%S)"
    echo -e "${GREEN}✔${NC} SSH config backed up"
  fi
}

menu_header() {
  local title="$1"
  local len=${#title}
  local line=$(printf '─%.0s' $(seq 1 $((len + 4))))
  echo ""
  echo -e "${YELLOW}┌${line}┐${NC}"
  echo -e "${YELLOW}│  ${title}  │${NC}"
  echo -e "${YELLOW}└${line}┘${NC}"
}

pause() {
  echo ""
  echo -en "${DIM}Press Enter to continue...${NC}"
  read
}

confirm() {
  local prompt="$1"
  local yn
  echo -en "${YELLOW}$prompt [y/N]: ${NC}"
  read yn
  [[ "$yn" =~ ^[Yy]$ ]]
}

# =========================
# SSH CORE
# =========================

ssh_set_option() {
  local key="$1"
  local value="$2"

  if grep -Eqr "^[[:space:]]*${key}([[:space:]]|$)" /etc/ssh/sshd_config.d/ 2>/dev/null; then
    echo -e "${YELLOW}⚠ Warning:${NC} active ${key} found in sshd_config.d/"
  fi

  if grep -Eq "^[[:space:]#]*${key}([[:space:]]|$)" "$SSH_CONFIG"; then
    sed -i -E "s|^[[:space:]#]*${key}([[:space:]].*)?$|${key} ${value}|" "$SSH_CONFIG"
  else
    echo "${key} ${value}" >> "$SSH_CONFIG"
  fi
}

ssh_restart() {
  if [ ! -x /usr/sbin/sshd ]; then
    echo -e "${RED}❌ /usr/sbin/sshd not found"
    return 1
  fi

  if ! sshd -t -f "$SSH_CONFIG"; then
    echo -e "${RED}❌ sshd config error, restart aborted"
    return 1
  fi

  if systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null; then
    echo -e "${GREEN}✔${NC} SSH restarted"
  else
    echo -e "${RED}❌ Failed to restart SSH service"
    return 1
  fi
}

ssh_change_port() {
  read -rp "New SSH port: " PORT

  if ! is_valid_port "$PORT"; then
    echo -e "${RED}❌ Invalid port"
    return
  fi

  if ss -tlnp 2>/dev/null | grep -q ":$PORT "; then
    echo -e "${RED}❌ Port $PORT is already in use"
    return
  fi

  backup_ssh_config
  ssh_set_option "Port" "$PORT"
  ssh_restart
}

ssh_root_prohibit_password() {
  backup_ssh_config
  ssh_set_option "PermitRootLogin" "prohibit-password"
  ssh_restart
}

ssh_pubkey_enable() {
  backup_ssh_config
  ssh_set_option "PubkeyAuthentication" "yes"
  ssh_restart
}

ssh_pubkey_disable() {
  backup_ssh_config
  ssh_set_option "PubkeyAuthentication" "no"
  ssh_restart
}

ssh_password_disable() {
  backup_ssh_config
  ssh_set_option "PasswordAuthentication" "no"
  ssh_restart
}

ssh_edit_conf_d() {
  local dir="/etc/ssh/sshd_config.d"

  echo "Available files:"
  ls "$dir" 2>/dev/null || echo "(empty)"

  read -rp "Enter filename: " FILE

  if [[ "$FILE" =~ \.\. ]] || [[ "$FILE" =~ / ]]; then
    echo -e "${RED}❌ Invalid filename"
    return
  fi

  if [ -f "$dir/$FILE" ]; then
    nano "$dir/$FILE"
    ssh_restart
  else
    echo -e "${RED}❌ File not found"
  fi
}

ssh_show_config() {
  echo "===== CURRENT SSH SETTINGS ====="
  sshd -T -f "$SSH_CONFIG" 2>/dev/null | grep -E "^(port|permitrootlogin|pubkeyauthentication|passwordauthentication) " || true
}

ssh_reference() {
  cat <<'EOF'
===== SSH REFERENCE =====
sudo nano /etc/ssh/sshd_config
sudo sshd -t -f /etc/ssh/sshd_config
sudo systemctl restart sshd
sudo systemctl status sshd
sudo grep -E '^(Port|PermitRootLogin|PubkeyAuthentication|PasswordAuthentication)' /etc/ssh/sshd_config
sudo sshd -T | grep -E '^(port|permitrootlogin|pubkeyauthentication|passwordauthentication) '
sudo passwd root
sudo usermod -aG sudo username
EOF
}

ssh_backup_list() {
  echo "===== SSH CONFIG BACKUPS ====="
  ls -la /etc/ssh/sshd_config.bak.* 2>/dev/null || echo "(no backups)"
}

# =========================
# SSH MENU
# =========================

ssh_menu() {
  while true; do
    clear
    menu_header "SSH Settings"
    echo ""
    print_menu_item "1" "Change SSH port" "$GREEN"
    print_menu_item "2" "Root: prohibit-password" "$GREEN"
    print_menu_item "3" "Enable PubkeyAuthentication" "$GREEN"
    print_menu_item "4" "Disable PubkeyAuthentication" "$RED"
    print_menu_item "5" "Disable PasswordAuthentication" "$RED"
    echo ""
    print_menu_item "6" "Edit sshd_config.d" "$YELLOW"
    print_menu_item "7" "Show config" "$CYAN"
    print_menu_item "8" "Restart SSH" "$YELLOW"
    print_menu_item "9" "Backup list" "$CYAN"
    echo ""
    print_menu_item "r" "Reference" "$DIM"
    print_menu_item "0" "Back" "$GRAY"
    echo ""

    read -rp "Select: " c

    case $c in
      1) ssh_change_port ;;
      2) ssh_root_prohibit_password ;;
      3) ssh_pubkey_enable ;;
      4) ssh_pubkey_disable ;;
      5) ssh_password_disable ;;
      6) ssh_edit_conf_d ;;
      7) ssh_show_config ;;
      8) ssh_restart ;;
      9) ssh_backup_list ;;
      r) ssh_reference && pause ;;
      0) break ;;
      *) echo -e "${RED}Invalid option${NC}" ;;
    esac
  done
}

# =========================
# USERS
# =========================

user_add() {
  read -rp "Username: " U

  if user_exists "$U"; then
    echo -e "${RED}❌ User already exists"
    return
  fi

  adduser --disabled-password --gecos "" "$U"
  usermod -aG sudo "$U"

  echo -e "${GREEN}✔ User created${NC}"
}

user_prepare_ssh() {
  local U HOME_DIR USER_GROUP

  read -rp "Username: " U

  if ! user_exists "$U"; then
    echo -e "${RED}❌ User does not exist"
    return
  fi

  HOME_DIR="$(user_home_dir "$U")"
  if [ -z "$HOME_DIR" ]; then
    echo -e "${RED}❌ Could not determine home directory"
    return
  fi

  USER_GROUP="$(id -gn "$U" 2>/dev/null)"
  if [ -z "$USER_GROUP" ]; then
    echo -e "${RED}❌ Could not determine user primary group"
    return
  fi

  mkdir -p "$HOME_DIR/.ssh"
  touch "$HOME_DIR/.ssh/authorized_keys"
  chmod 700 "$HOME_DIR/.ssh"
  chmod 600 "$HOME_DIR/.ssh/authorized_keys"
  chown "$U:$USER_GROUP" "$HOME_DIR/.ssh"
  chown "$U:$USER_GROUP" "$HOME_DIR/.ssh/authorized_keys"

  echo -e "${GREEN}✔ SSH directory prepared${NC}"
}

ssh_add_key() {
  local U HOME_DIR KEY USER_GROUP

  read -rp "Username: " U

  if ! user_exists "$U"; then
    echo -e "${RED}❌ User does not exist"
    return
  fi

  HOME_DIR="$(user_home_dir "$U")"
  if [ -z "$HOME_DIR" ]; then
    echo -e "${RED}❌ Could not determine home directory"
    return
  fi

  USER_GROUP="$(id -gn "$U" 2>/dev/null)"
  if [ -z "$USER_GROUP" ]; then
    echo -e "${RED}❌ Could not determine user primary group"
    return
  fi

  mkdir -p "$HOME_DIR/.ssh"
  touch "$HOME_DIR/.ssh/authorized_keys"
  chmod 700 "$HOME_DIR/.ssh"
  chmod 600 "$HOME_DIR/.ssh/authorized_keys"
  chown "$U:$USER_GROUP" "$HOME_DIR/.ssh"
  chown "$U:$USER_GROUP" "$HOME_DIR/.ssh/authorized_keys"

  echo "Paste public key in one line:"
  echo "Example: ssh-ed25519 AAAAC3Nza... comment"
  read -r KEY

  KEY=$(echo "$KEY" | tr -d '\r')

  if [ -z "$KEY" ]; then
    echo -e "${RED}❌ Key cannot be empty"
    return
  fi

  local TEMP_KEY
  TEMP_KEY=$(mktemp)
  trap 'rm -f "$TEMP_KEY"' EXIT

  echo "$KEY" > "$TEMP_KEY"
  if ! ssh-keygen -l -f "$TEMP_KEY" >/dev/null 2>&1; then
    rm -f "$TEMP_KEY"
    trap - EXIT
    echo -e "${RED}❌ Invalid SSH public key format"
    return
  fi

  if grep -Fqx "$KEY" "$HOME_DIR/.ssh/authorized_keys" 2>/dev/null; then
    rm -f "$TEMP_KEY"
    trap - EXIT
    echo -e "${YELLOW}⚠ Key already exists in authorized_keys${NC}"
    return
  fi

  printf '%s\n' "$KEY" >> "$HOME_DIR/.ssh/authorized_keys"
  chown "$U:$USER_GROUP" "$HOME_DIR/.ssh/authorized_keys"

  rm -f "$TEMP_KEY"
  trap - EXIT

  echo -e "${GREEN}✔ Key added${NC}"
}

user_menu() {
  while true; do
    clear
    menu_header "User Management"
    echo ""
    echo -e "${DIM}Tips:${NC}"
    echo -e "${GRAY}• For SSH login: paste client public key into authorized_keys${NC}"
    echo ""
    print_menu_item "1" "Add sudo user" "$GREEN"
    print_menu_item "2" "Prepare .ssh + authorized_keys" "$GREEN"
    print_menu_item "3" "Add client public key to authorized_keys" "$CYAN"
    echo ""
    print_menu_item "0" "Back" "$GRAY"
    echo ""

    read -rp "Select: " c

    case $c in
      1) user_add; pause ;;
      2) user_prepare_ssh; pause ;;
      3) ssh_add_key; pause ;;
      0) break ;;
      *) echo -e "${RED}Invalid${NC}" ;;
    esac
  done
}

# =========================
# DOCKER
# =========================

docker_install() {
  if command -v docker >/dev/null 2>&1; then
    echo -e "${GREEN}✔ Docker already installed"
    return
  fi

  if ! grep -qi debian /etc/os-release; then
    echo -e "${RED}❌ Debian required"
    return
  fi

  local CODENAME
  CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME")
  if [ -z "$CODENAME" ]; then
    echo -e "${RED}❌ Could not detect Debian codename"
    return
  fi

  apt update
  apt install -y ca-certificates curl

  install -m 0755 -d /etc/apt/keyrings

  curl -fsSL https://download.docker.com/linux/debian/gpg \
    -o /etc/apt/keyrings/docker.asc

  chmod a+r /etc/apt/keyrings/docker.asc

  cat > /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $CODENAME
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

  apt update
  apt install -y docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin

  usermod -aG docker "${SUDO_USER:-$USER}"

  echo -e "${GREEN}✔ Docker installed"
}

docker_reference() {
  cat <<'EOF'
===== DOCKER REFERENCE =====
sudo apt update
sudo apt install -y ca-certificates curl
sudo systemctl status docker
sudo docker ps
sudo docker ps -a
sudo docker images
sudo docker logs container_name
sudo usermod -aG docker username
EOF
}

docker_menu() {
  while true; do
    clear
    menu_header "Docker"
    echo ""
    print_menu_item "1" "Install Docker" "$GREEN"
    print_menu_item "2" "Reference commands" "$DIM"
    echo ""
    print_menu_item "0" "Back" "$GRAY"
    echo ""

    read -rp "Select: " c

    case $c in
      1) docker_install ;;
      2) docker_reference && pause ;;
      0) break ;;
      *) echo -e "${RED}Invalid${NC}" ;;
    esac
  done
}

# =========================
# UFW
# =========================

ufw_install() { apt install -y ufw; }
ufw_remove() { apt remove -y ufw; }
ufw_enable() { ufw --force enable; }
ufw_disable() { ufw disable; }
ufw_reset() { ufw --force reset; }
ufw_default_deny_incoming() { ufw default deny incoming; }
ufw_default_allow_outgoing() { ufw default allow outgoing; }
ufw_logging_on() { ufw logging on; }
ufw_logging_off() { ufw logging off; }

ufw_status() {
  echo "===== UFW STATUS ====="
  ufw status || true
  echo ""
  echo "===== UFW STATUS VERBOSE ====="
  ufw status verbose || true
}

ufw_status_numbered() {
  echo "===== UFW STATUS NUMBERED ====="
  ufw status numbered || true
}

ufw_reference() {
  cat <<'EOF'
===== UFW REFERENCE =====
sudo apt install ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 80
sudo ufw allow 2222/tcp
sudo ufw delete allow 80
sudo ufw delete allow 22/tcp
sudo ufw status
sudo ufw status numbered
sudo ufw status verbose
sudo ufw logging off
sudo ufw enable
sudo ufw disable
sudo ufw --force reset
EOF
}

ufw_allow() {
  read -rp "Port (e.g. 80 or 2222/tcp): " P

  if [[ ! "$P" =~ ^[0-9]+(/tcp|/udp)?$ ]]; then
    echo -e "${RED}❌ Invalid port"
    return
  fi

  ufw allow "$P"
}

ufw_delete() {
  echo "===== CURRENT UFW RULES ====="
  ufw status numbered || true
  echo ""

  read -rp "Delete rule number or port (e.g. 3 or 80/tcp): " P

  if [ -z "$P" ]; then
    echo -e "${RED}❌ No input"
    return
  fi

  if [[ "$P" =~ ^[0-9]+$ ]]; then
    ufw delete "$P"
  elif [[ "$P" =~ ^[0-9]+(/tcp|/udp)?$ ]]; then
    ufw delete allow "$P"
  else
    echo -e "${RED}❌ Invalid input"
  fi
}

ufw_ports_menu() {
  while true; do
    echo ""
    echo "===== UFW PORTS ====="
    echo "1) Allow port"
    echo "2) Delete port"
    echo "3) Show numbered rules"
    echo "0) Back"

    read -rp "Select: " c

    case $c in
      1) ufw_allow ;;
      2) ufw_delete ;;
      3) ufw_status_numbered ;;
      0) break ;;
      *) echo "Invalid" ;;
    esac
  done
}

ufw_defaults_menu() {
  while true; do
    echo ""
    echo "===== UFW DEFAULTS ====="
    echo "1) Default deny incoming"
    echo "2) Default allow outgoing"
    echo "3) Set both (deny in + allow out)"
    echo "0) Back"

    read -rp "Select: " c

    case $c in
      1) ufw_default_deny_incoming ;;
      2) ufw_default_allow_outgoing ;;
      3) ufw_default_deny_incoming && ufw_default_allow_outgoing ;;
      0) break ;;
      *) echo "Invalid" ;;
    esac
  done
}

ufw_install_menu() {
  while true; do
    echo ""
    echo "===== UFW INSTALL/REMOVE ====="
    echo "1) Install"
    echo "2) Remove"
    echo "0) Back"

    read -rp "Select: " c

    case $c in
      1) ufw_install ;;
      2) ufw_remove ;;
      0) break ;;
      *) echo "Invalid" ;;
    esac
  done
}

ufw_menu() {
  while true; do
    clear
    menu_header "UFW Firewall"
    echo ""
    print_menu_item "1" "Install/Remove" "$GREEN"
    print_menu_item "2" "Ports (allow/delete)" "$CYAN"
    print_menu_item "3" "Defaults (deny/allow)" "$YELLOW"
    print_menu_item "4" "Status" "$CYAN"
    print_menu_item "5" "Reset" "$RED"
    print_menu_item "6" "Enable" "$GREEN"
    print_menu_item "7" "Disable" "$RED"
    echo ""
    print_menu_item "8" "Reference" "$DIM"
    print_menu_item "0" "Back" "$GRAY"
    echo ""

    read -rp "Select: " c

    case $c in
      1) ufw_install_menu ;;
      2) ufw_ports_menu ;;
      3) ufw_defaults_menu ;;
      4) ufw_status && pause ;;
      5) confirm "Reset UFW? All rules will be deleted" && ufw_reset ;;
      6) ufw_enable ;;
      7) ufw_disable ;;
      8) ufw_reference && pause ;;
      0) break ;;
      *) echo -e "${RED}Invalid${NC}" ;;
    esac
  done
}

# =========================
# FAIL2BAN
# =========================

fail2ban_install() {
  if systemctl is-active --quiet fail2ban 2>/dev/null; then
    echo -e "${GREEN}✔ Fail2Ban already running"
    return
  fi

  apt install -y fail2ban
  systemctl enable fail2ban
  systemctl start fail2ban

  echo -e "${GREEN}✔ Fail2Ban installed"
}

fail2ban_reference() {
  cat <<'EOF'
===== FAIL2BAN REFERENCE =====
sudo apt install fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
sudo systemctl status fail2ban
sudo fail2ban-client status
sudo fail2ban-client status sshd
sudo nano /etc/fail2ban/jail.local
sudo systemctl restart fail2ban
EOF
}

fail2ban_menu() {
  while true; do
    clear
    menu_header "Fail2Ban"
    echo ""
    print_menu_item "1" "Install Fail2Ban" "$GREEN"
    print_menu_item "2" "Reference commands" "$DIM"
    echo ""
    print_menu_item "0" "Back" "$GRAY"
    echo ""

    read -rp "Select: " c

    case $c in
      1) fail2ban_install ;;
      2) fail2ban_reference && pause ;;
      0) break ;;
      *) echo -e "${RED}Invalid${NC}" ;;
    esac
  done
}

# =========================
# APPS
# =========================

apps_install_opencode() {
  ensure_curl
  echo -e "${YELLOW}Warning: This will execute code from opencode.ai${NC}"
  read -p "Continue? [y/N]: " CONFIRM
  [[ "$CONFIRM" =~ ^[Yy]$ ]] || return
  curl -fsSL https://opencode.ai/install | bash
}

apps_install_ollama() {
  ensure_curl
  echo -e "${YELLOW}Warning: This will execute code from ollama.com${NC}"
  read -p "Continue? [y/N]: " CONFIRM
  [[ "$CONFIRM" =~ ^[Yy]$ ]] || return
  curl -fsSL https://ollama.com/install.sh | sh
}

apps_install_webui() {
  if ! command -v docker >/dev/null 2>&1; then
    echo -e "${RED}❌ Docker is required. Install Docker first."
    return
  fi

  if ss -lnt 2>/dev/null | grep -q ':3000 '; then
    echo -e "${RED}❌ Port 3000 already in use"
    return
  fi

  docker volume create open-webui >/dev/null
  docker rm -f open-webui >/dev/null 2>&1 || true
  docker run -d \
    --name open-webui \
    -p 3000:8080 \
    -v open-webui:/app/backend/data \
    --restart unless-stopped \
    ghcr.io/open-webui/open-webui:main

  echo -e "${GREEN}✔ Open WebUI started on port 3000"
}

apps_status() {
  echo "===== APPS STATUS ====="

  for app in opencode ollama docker; do
    if command -v "$app" >/dev/null 2>&1; then
      echo "$app: installed"
    else
      echo "$app: not installed"
    fi
  done

  if command -v docker >/dev/null 2>&1; then
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -qx 'open-webui'; then
      echo "open-webui: running"
    elif docker ps -a --format '{{.Names}}' 2>/dev/null | grep -qx 'open-webui'; then
      echo "open-webui: installed but stopped"
    else
      echo "open-webui: not installed"
    fi
  fi

  if systemctl list-unit-files 2>/dev/null | grep -q '^fail2ban.service'; then
    if systemctl is-active --quiet fail2ban 2>/dev/null; then
      echo "fail2ban: running"
    else
      echo "fail2ban: installed (stopped)"
    fi
  else
    echo "fail2ban: not installed"
  fi

  if command -v ufw >/dev/null 2>&1; then
    echo "ufw: $(ufw status | head -1)"
  else
    echo "ufw: not installed"
  fi
}

apps_reference() {
  cat <<'EOF'
===== APPS REFERENCE =====
curl -fsSL https://opencode.ai/install | bash           # install opencode
curl -fsSL https://ollama.com/install.sh | sh          # install ollama
docker run -d --name open-webui -p 3000:8080 \
  -v open-webui:/app/backend/data --restart unless-stopped \
  ghcr.io/open-webui/open-webui:main                   # run Open WebUI
EOF
}

apps_menu() {
  while true; do
    clear
    menu_header "Apps Installation"
    echo ""
    echo -e "${WHITE}━━━ Install ━━━${NC}"
    print_menu_item "1" "OpenCode" "$GREEN"
    print_menu_item "2" "Open WebUI (AI interface)" "$GREEN"
    print_menu_item "3" "Ollama (LLM)" "$GREEN"
    echo ""
    echo -e "${WHITE}━━━ Tools ━━━${NC}"
    print_menu_item "4" "Status" "$CYAN"
    print_menu_item "5" "Reference" "$DIM"
    echo ""
    print_menu_item "0" "Back" "$GRAY"
    echo ""

    read -rp "Select: " c

    case $c in
      1) apps_install_opencode ;;
      2) apps_install_webui ;;
      3) apps_install_ollama ;;
      4) apps_status && pause ;;
      5) apps_reference && pause ;;
      0) break ;;
      *) echo -e "${RED}Invalid${NC}" ;;
    esac
  done
}

# =========================
# SYSTEM MONITOR
# =========================

sys_monitor() {
  while true; do
    clear
    menu_header "System Monitor"
    echo ""
    
    # CPU & Load
    echo -e "${WHITE}━━━ CPU & Load ━━━${NC}"
    uptime
    echo ""
    
    # Memory
    echo -e "${WHITE}━━━ Memory ━━━${NC}"
    free -h
    echo ""
    
    # Disk
    echo -e "${WHITE}━━━ Disk ━━━${NC}"
    df -h | grep -v tmpfs
    echo ""
    
    # Top processes
    echo -e "${WHITE}━━━ Top 10 Processes ━━━${NC}"
    ps aux --sort=-%cpu | head -11
    echo ""
    
    print_menu_item "r" "Refresh" "$GREEN"
    print_menu_item "0" "Back" "$GRAY"
    echo ""
    
    read -rp "Select: " c
    
    case $c in
      r) continue ;;
      0) break ;;
      *) echo -e "${RED}Invalid${NC}" ;;
    esac
  done
}

# =========================
# NETWORK TOOLS
# =========================

net_tools() {
  while true; do
    clear
    menu_header "Network Tools"
    echo ""
    
    # IPs
    echo -e "${WHITE}━━━ IP Addresses ━━━${NC}"
    echo -e "${GRAY}Public:${NC} $(curl -s --max-time 5 -4 https://api.ipify.org 2>/dev/null || echo 'N/A')"
    echo -e "${GRAY}Local:${NC}  $(hostname -I 2>/dev/null || echo 'N/A')"
    echo ""
    
    # Listening ports
    echo -e "${WHITE}━━━ Listening Ports ━━━${NC}"
    ss -tulnp 2>/dev/null | grep LISTEN || netstat -tulnp 2>/dev/null | grep LISTEN || echo "No ports found"
    echo ""
    
    # Network connections
    echo -e "${WHITE}━━━ Network Connections ━━━${NC}"
    ss -tan | wc -l | xargs -I {} echo "Total TCP connections: {}"
    echo ""
    
    print_menu_item "1" "Test ping (google.com)" "$CYAN"
    print_menu_item "2" "Test curl (google.com)" "$CYAN"
    print_menu_item "3" "Check DNS" "$CYAN"
    print_menu_item "r" "Refresh" "$GREEN"
    print_menu_item "0" "Back" "$GRAY"
    echo ""
    
    read -rp "Select: " c
    
    case $c in
      1) ping -c 3 google.com ;;
      2) curl -s --max-time 5 -I https://google.com | head -5 ;;
      3) nslookup google.com 8.8.8.8 ;;
      r) continue ;;
      0) break ;;
      *) echo -e "${RED}Invalid${NC}" ;;
    esac
  done
}

# =========================
# SERVICE MANAGER
# =========================

service_list="ssh docker fail2ban nginx apache2"

service_manager() {
  while true; do
    clear
    menu_header "Service Manager"
    echo ""
    
    echo -e "${WHITE}━━━ Service Status ━━━${NC}"
    echo ""
    
    for svc in $service_list; do
      if systemctl is-active --quiet "$svc" 2>/dev/null; then
        echo -e "${GREEN}●${NC} $svc ${GREEN}active${NC}"
      elif systemctl list-unit-files 2>/dev/null | grep -q "^$svc.service"; then
        echo -e "${YELLOW}●${NC} $svc ${YELLOW}inactive${NC}"
      else
        echo -e "${DIM}●${NC} $svc ${DIM}not found${NC}"
      fi
    done
    
    echo ""
    print_menu_item "1" "Restart all services" "$YELLOW"
    print_menu_item "2" "Stop all services" "$RED"
    print_menu_item "0" "Back" "$GRAY"
    echo ""
    
    read -rp "Select: " c
    
    case $c in
      1) 
        for svc in $service_list; do
          if systemctl list-unit-files 2>/dev/null | grep -q "^$svc.service"; then
            systemctl restart "$svc" 2>/dev/null && echo -e "${GREEN}✔${NC} $svc restarted" || echo -e "${RED}❌${NC} $svc failed"
          fi
        done
        ;;
      2)
        for svc in $service_list; do
          if systemctl is-active --quiet "$svc" 2>/dev/null; then
            systemctl stop "$svc" 2>/dev/null && echo -e "${GREEN}✔${NC} $svc stopped" || echo -e "${RED}❌${NC} $svc failed"
          fi
        done
        ;;
      0) break ;;
      *) echo -e "${RED}Invalid${NC}" ;;
    esac
  done
}

# =========================
# MAIN MENU
# =========================

print_banner() {
  local h="$1"
  local len=${#h}
  local line=$(printf '=%.0s' $(seq 1 $((len + 4))))
  echo -e "${CYAN}${line}${NC}"
  echo -e "${CYAN}  ${h}${NC}"
  echo -e "${CYAN}${line}${NC}"
}

print_menu_item() {
  local num="$1"
  local desc="$2"
  local color="${3:-$WHITE}"
  printf "${color}[${num}]${NC} %s\n" "$desc"
}

main_menu() {
  require_root

  local HOSTNAME
  HOSTNAME=$(hostname)
  local USER_NAME
  USER_NAME=$(whoami)
  local IP_ADDR
  IP_ADDR=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "N/A")

  while true; do
    clear
    echo ""
    print_banner "ADMIN TOOLS v1.0 (Public)"
    echo ""
    echo -e "${GRAY}User:${NC} ${GREEN}$USER_NAME${NC} ${GRAY}@${NC} ${YELLOW}$HOSTNAME${NC}"
    echo -e "${GRAY}IP:${NC}   ${MAGENTA}$IP_ADDR${NC}"
    echo ""
    echo -e "${WHITE}━━━ Main Menu ━━━${NC}"
    echo ""
    print_menu_item "1" "SSH" "$CYAN"
    print_menu_item "2" "Users" "$CYAN"
    print_menu_item "3" "Docker" "$CYAN"
    print_menu_item "4" "UFW" "$CYAN"
    print_menu_item "5" "Fail2Ban" "$CYAN"
    print_menu_item "6" "Apps" "$MAGENTA"
    echo ""
    echo -e "${WHITE}━━━ Monitor ━━━${NC}"
    print_menu_item "7" "System Monitor" "$YELLOW"
    print_menu_item "8" "Network Tools" "$YELLOW"
    print_menu_item "9" "Service Manager" "$YELLOW"
    echo ""
    print_menu_item "0" "Exit" "$RED"
    echo ""

    read -rp "Select: " c

    case $c in
      1) ssh_menu ;;
      2) user_menu ;;
      3) docker_menu ;;
      4) ufw_menu ;;
      5) fail2ban_menu ;;
      6) apps_menu ;;
      7) sys_monitor ;;
      8) net_tools ;;
      9) service_manager ;;
      0) echo "Bye"; exit 0 ;;
      *) echo "Invalid" ;;
    esac
  done
}

main_menu
