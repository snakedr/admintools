# Admin Tools

Universal script for configuring and managing a Linux server through an easy-to-use menu.

## Features

- **SSH** — port configuration, security, key management
- **Users** — user creation, SSH key setup
- **Docker** — Docker installation
- **UFW** — firewall management
- **Fail2Ban** — brute-force protection
- **Apps** — installation of OpenCode, Open WebUI, Ollama
- **System Monitor** — CPU, RAM, disk, process monitoring
- **Network Tools** — IP addresses, ports, network tests
- **Service Manager** — service management

## Requirements

- Linux server (tested on Debian)
- Root access
- Bash 4.0+

## Installation

Download the script and make it executable:

```bash
wget https://raw.githubusercontent.com/snakedr/admintools/main/admintools.sh
chmod +x admintools.sh
sudo ./admintools.sh
```

Or clone the repository:

```bash
git clone https://github.com/snakedr/admintools.git
cd admintools
chmod +x admintools.sh
sudo ./admintools.sh
```

## Usage

Run the script as root:

```bash
sudo ./admintools.sh
```

The main menu will open. Select the desired section by entering the menu item number and pressing Enter.

### Main Menu

```
ADMIN TOOLS v1.0 (Public)
User: root@hostname
IP:   xxx.xxx.xxx.xxx

━━━ Main Menu ━━━

[1] SSH
[2] Users
[3] Docker
[4] UFW
[5] Fail2Ban
[6] Apps

━━━ Monitor ━━━
[7] System Monitor
[8] Network Tools
[9] Service Manager

[0] Exit
```

## Menu Sections

### 1. SSH

Manage SSH server settings.

**Menu Items:**

1. **Change SSH port** — change SSH port (default 22)
2. **Root: prohibit-password** — allow root login only with key
3. **Enable PubkeyAuthentication** — enable key-based authentication
4. **Disable PubkeyAuthentication** — disable key-based authentication
5. **Disable PasswordAuthentication** — disable password authentication
6. **Edit sshd_config.d** — edit additional config files
7. **Show config** — show current SSH settings
8. **Restart SSH** — restart SSH service
9. **Backup list** — show backup list of SSH config

**Important Warnings:**

- When changing port or disabling passwords, make sure you have SSH key access
- The script automatically backs up the SSH config before each change
- NEVER disable passwords until key-based access is configured

**Recommended SSH Setup Sequence:**

1. SSH → 2 (Root: prohibit-password) — if root login is needed
2. SSH → 3 (Enable PubkeyAuthentication) — enable keys
3. SSH → 5 (Disable PasswordAuthentication) — disable passwords
4. SSH → 8 (Restart SSH) — apply changes

### 2. Users

Manage users and SSH keys.

**What are SSH keys and why are they needed:**

SSH keys are a pair of files (private and public) used for authentication instead of a password. The private key is stored on your computer, the public key — on the server. This is more secure than a password because:
- Passwords can be brute-forced or stolen
- SSH keys are virtually impossible to hack
- No need to enter password every time

**Key Types:**

- **ed25519** — modern and most secure key type (recommended)
- **RSA** — older type, still works, but less preferred

**Menu Items:**

1. **Add sudo user** — create new user with sudo privileges
2. **Prepare .ssh + authorized_keys** — prepare .ssh directory for user
3. **Generate server-side ed25519 keypair** — generate ed25519 keypair on server
4. **Add client public key to authorized_keys** — add client public key
5. **Show generated public key** — show generated public key
6. **Authorize generated public key** — add generated key to authorized_keys

**Step-by-step: How to set up SSH key login**

1. Create user (if needed): Users → 1
2. Prepare directory: Users → 2 (enter username)
3. Get public key from your computer:
   - Linux/Mac: `cat ~/.ssh/id_ed25519.pub`
   - Windows (PowerShell): `Get-Content ~/.ssh/id_ed25519.pub`
4. Add key to server: Users → 4
   - Enter username
   - Paste public key (single line)
5. Connect:
   ```bash
   ssh user@server-ip
   ```

### 3. Docker

Docker installation.

**Menu Items:**

1. **Install Docker** — install Docker
2. **Reference commands** — show main Docker commands

### 4. UFW

UFW firewall management (Uncomplicated Firewall).

UFW is a simple firewall for Linux. It allows controlling which connections are allowed and which are blocked.

**What is a firewall and why is it needed:**

A firewall is a program that controls incoming and outgoing network traffic. It works as a filter: allows permitted connections and blocks unwanted ones.

Without a firewall, your server is open to the world. Attackers can:
- Scan ports
- Brute-force SSH passwords
- Exploit service vulnerabilities

**Menu Items:**

1. **Install/Remove** — install or remove UFW
2. **Ports** — port management:
   - Allow port — open port
   - Delete port — close port
   - Show numbered rules — show rules with numbers
3. **Defaults** — default policy settings:
   - Default deny incoming — deny all incoming
   - Default allow outgoing — allow all outgoing
   - Set both — apply both policies
4. **Status** — show firewall status and rules
5. **Reset** — reset all rules (with confirmation)
6. **Enable** — enable firewall
7. **Disable** — disable firewall
8. **Reference commands** — UFW command reference

**Recommended Setup Sequence:**

1. UFW → 1 → 1 (Install)
2. UFW → 2 → 1 → enter your SSH port (e.g., 22/tcp or 2222/tcp)
3. UFW → 3 → 3 (Set both — deny incoming, allow outgoing)
4. UFW → 6 (Enable)

### 5. Fail2Ban

Fail2Ban installation and setup for brute-force protection.

**What is Fail2Ban and why is it needed:**

Fail2Ban is a program that automatically blocks IP addresses after multiple failed login attempts. It monitors logs and bans attackers trying to brute-force SSH, FTP, web servers, and other services.

**How it works:**

1. Fail2Ban reads system logs
2. If it detects multiple failed login attempts (e.g., 5 failed attempts within 10 minutes)
3. It blocks the attacker's IP address for a certain time (usually 10 minutes)
4. After the ban expires, the block is removed

**Menu Items:**

1. **Install Fail2Ban** — install Fail2Ban
2. **Reference commands** — command reference

**After installing Fail2Ban:**

- SSH protection is enabled automatically
- No additional configuration required
- Check status: `fail2ban-client status sshd`

### 6. Apps

Application installation.

**Menu Items:**

1. **OpenCode** — install OpenCode (AI programming assistant)

OpenCode is an AI coding assistant that works in the terminal. It helps write code, fix errors, explain code, create files, and more.

After installation, run with:
```bash
opencode
```

2. **Open WebUI** — install Open WebUI (web interface for AI)

Open WebUI is a web interface for working with AI models (including Ollama). Allows interacting with AI through a browser.

After installation, accessible at: http://your_ip:3000

Requires Docker.

3. **Ollama** — install Ollama (local LLM)

Ollama is a platform for running large language models (LLM) locally on the server. Supports many models: llama2, mistral, codellama, and others.

After installation:
```bash
ollama serve  # start server
ollama run llama2  # run model
```

4. **Status** — show status of installed applications

5. **Reference** — installation command reference

### 7. System Monitor

Real-time system monitoring.

Shows:

- Uptime and Load Average
- Memory usage (free -h)
- Disk usage (df -h)
- Top 10 processes by CPU usage

Press r to refresh, 0 to exit.

### 8. Network Tools

Network diagnostic tools.

**Shows:**

- Public IP address
- Local IP address
- Listening ports
- Total TCP connections

**Menu Items:**

1. **Test ping** — ping to google.com
2. **Test curl** — test curl to google.com
3. **Check DNS** — check DNS

### 9. Service Manager

System service management.

Services are programs that run in the background and provide system functionality: web server, SSH, databases, etc.

**Checked services:**

- ssh — SSH server
- docker — container platform
- fail2ban — brute-force protection
- nginx — web server
- apache2 — web server

**Color indication:**

- Green (active) — service is running
- Yellow (inactive) — service is installed but stopped
- Gray (not found) — service is not installed

**Menu Items:**

1. **Restart all services** — restart all installed services
2. **Stop all services** — stop all installed services

## Warning

This script makes system-level changes:
- modifies SSH configuration
- manages firewall rules (UFW)
- installs system packages

Use at your own risk.
Always ensure you have SSH access before applying changes.

## Compatibility

Tested on Debian.
Other distributions are not guaranteed to work.

## Security

Some recommendations when using the script:

1. **SSH** — after configuration, always verify you can connect with new settings
2. **UFW** — before enabling, make sure SSH port is open
3. **Passwords** — do not store passwords in scripts, use SSH keys
4. **Backups** — script automatically backs up SSH configs

## License

MIT License

## Author

snakedr
