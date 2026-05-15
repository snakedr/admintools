# Admin Tools

Universal script for configuring and managing a Linux server through a convenient menu.

## Features

- **SSH** — port configuration, security, key management
- **Users** — user creation, SSH key setup
- **Docker** — Docker installation
- **UFW** — firewall management
- **Fail2Ban** — brute force protection
- **Apps** — install OpenCode, Open WebUI, Ollama
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

The main menu will open. Select the desired section by entering the number and pressing Enter.

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

SSH server settings management.

**What each option does:**

1. **Change SSH port** — change SSH port

SSH runs on port 22 by default. This is the first port attackers check. Changing to another port (e.g., 2222 or 443) hides SSH from random scanners.

2. **Root: prohibit-password** — allow root login only by key

Allows root login, but only with SSH key, without password. Safe if root has no password or password is not used.

3. **Enable PubkeyAuthentication** — enable key authentication

Enables SSH key login. Recommended to do right after system installation.

4. **Disable PubkeyAuthentication** — disable key authentication

Disables key login. Rarely used, usually when switching to password-only.

5. **Disable PasswordAuthentication** — disable password authentication

Disables password login. AFTER THIS, YOU CAN ONLY LOG IN BY KEY.

This is the most important security option. After enabling:
- Passwords are no longer accepted
- Login only by SSH key
- Make sure the key is configured BEFORE enabling this option

6. **Edit sshd_config.d** — edit additional config files

In Debian, SSH configuration can be split into files in /etc/ssh/sshd_config.d/. This option lets you edit these files via nano.

7. **Show config** — show current SSH settings

Shows the actual SSH settings currently applied. Useful for verification.

8. **Restart SSH** — restart SSH service

Restarts SSH service to apply changes. Current connection won't be interrupted.

9. **Backup list** — show config backup list

Shows all created backups of /etc/ssh/sshd_config. Filenames contain creation date and time.

**Important warnings:**

- When changing port or disabling passwords, make sure you have SSH key access
- The script automatically backs up SSH config before each change
- NEVER disable passwords until key login is configured

**Recommended SSH setup sequence:**

1. SSH → 2 (Root: prohibit-password) — if root login is needed
2. SSH → 3 (Enable PubkeyAuthentication) — enable keys
3. SSH → 5 (Disable PasswordAuthentication) — disable passwords
4. SSH → 8 (Restart SSH) — apply changes

**How to verify the key works:**

Before disabling passwords, open a second terminal and try to connect:
```bash
ssh -p your_port root@server_ip
```
If connection works by key — you can disable passwords.

### 2. Users

User and SSH key management.

---

#### What are SSH Keys

SSH keys are a pair of files:

* **private key** — stored on your computer
* **public key** — added to the server in `~/.ssh/authorized_keys`

The private key is used for login and should never be shared with others.

The public key can be safely copied to the server.

---

#### Why it's better than passwords

- passwords can be guessed or stolen
- SSH keys are practically impossible to brute force
- no need to enter password each time you connect

---

#### How it works

1. You connect to the server from your computer
2. Server checks the `authorized_keys` file
3. If your public key is there — access is granted

---

#### Where keys are stored

| Where         | What's stored                              |
| ------------- | ------------------------------------------ |
| Your computer | private + public key                      |
| Server        | only `authorized_keys` (public keys)       |

Important:
the server does not store your private key.

---

#### Key types

* **ed25519** — modern and recommended
* **RSA** — old, but still supported

---

#### Menu options

### 1. Add sudo user

Creates a new user and adds them to the sudo group.
Recommended to not work as root permanently.

---

### 2. Prepare .ssh + authorized_keys

Creates:

* `~/.ssh` directory
* `authorized_keys` file
* correct permissions

---

### 3. Add client public key to authorized_keys

Main scenario.

You add the public key from your computer to the server.
After that, you can connect without password.

---

#### How to get your public key

On your computer:

Linux / macOS:

```bash
cat ~/.ssh/id_ed25519.pub
```

Windows (PowerShell):

```powershell
Get-Content ~/.ssh/id_ed25519.pub
```

Example key:

```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB3Lw... user@computer
```

Copy the entire line and paste into option 3.

---

#### SSH access setup step by step

1. Users → 1 — create user
2. Users → 2 — prepare `.ssh`
3. Get public key on your computer
4. Users → 3 — add key to server
5. Connect:

```bash
ssh user@server-ip
```

### 3. Docker

Docker installation.

**Menu options:**

1. **Install Docker** — install Docker + Docker Compose
2. **Reference commands** — show basic Docker commands

### 4. UFW

UFW (Uncomplicated Firewall) management.

UFW is a simple Linux firewall. It controls which connections are allowed and which are blocked.

**What is a firewall and why it's needed:**

A firewall is a program that controls incoming and outgoing network traffic. It works as a filter: lets allowed connections through and blocks unwanted ones.

Without a firewall, your server is open to the world. Attackers can:
- Scan ports
- Brute force SSH passwords
- Exploit service vulnerabilities

**Menu options:**

1. **Install/Remove** — install or remove UFW

Installs UFW from repository or removes it.

2. **Ports** — port management

Allows opening (allowing) or closing (denying) network ports.

- Allow port — open a port. Examples:
  - 80 — HTTP server
  - 443 — HTTPS server
  - 22/tcp — SSH (if port not changed)
  - 2222/tcp — SSH (if changed to 2222)
- Delete port — close a port. You can enter the number (80) or the rule number from the list.
- Show numbered rules — show all rules with numbers. Useful before deleting a rule.

3. **Defaults** — default policy settings

Default policy determines what to do with connections that don't match explicit rules.

- Default deny incoming — deny ALL incoming connections. Recommended for servers.
- Default allow outgoing — allow ALL outgoing connections. Usually should stay allowed.
- Set both — apply both policies at once.

4. **Status** — show firewall status and rules

Displays current UFW state and active rules.

5. **Reset** — reset all rules

Removes all UFW rules and resets settings. Requires confirmation.

6. **Enable** — enable firewall

Activates UFW. Only explicitly allowed ports will work after enabling.

7. **Disable** — disable firewall

Deactivates UFW. All connections will be allowed.

8. **Reference commands** — UFW command reference

Shows list of basic UFW commands for terminal use.

**Recommended sequence for basic setup:**

1. UFW → 1 → 1 (Install)
2. UFW → 2 → 1 → enter your SSH port (e.g., 22/tcp or 2222/tcp)
3. UFW → 3 → 3 (Set both — deny incoming, allow outgoing)
4. UFW → 6 (Enable)

**Usage examples:**

- Open port for web server:
  UFW → Ports → Allow port → 80

- Open port for HTTPS:
  UFW → Ports → Allow port → 443

- Close port:
  UFW → Ports → Delete port → enter port number

### 5. Fail2Ban

Fail2Ban installation and setup for brute force protection.

**What is Fail2Ban and why it's needed:**

Fail2Ban is a program that automatically blocks IP addresses after multiple failed login attempts. It monitors logs and bans attackers trying to brute force SSH, FTP, web servers, and other services.

**How it works:**

1. Fail2Ban reads system logs
2. If it detects multiple failed login attempts (e.g., 5 failed attempts in 10 minutes)
3. Blocks the attacker's IP address for a certain time (usually 10 minutes)
4. After the time expires, the ban is lifted

**Menu options:**

1. **Install Fail2Ban** — install Fail2Ban

Installs Fail2Ban from repository and enables it. After installation, it automatically starts protecting SSH.

2. **Reference commands** — command reference

Shows basic commands for manual Fail2Ban management.

**After installing Fail2Ban:**

- SSH protection is enabled automatically
- No additional configuration needed
- You can check status: `fail2ban-client status sshd`

### 6. Apps

Application installation.

This section lets you install popular apps for working with AI and containers.

**Menu options:**

1. **OpenCode** — install OpenCode

OpenCode is an AI programming assistant that works in the terminal. Helps write code, fix errors, explain code, create files, and more.

After installation, run with:
```bash
opencode
```

2. **Open WebUI** — install Open WebUI

Open WebUI is a web interface for working with AI models (including Ollama). Allows chatting with AI through a browser.

After installation, available at: http://your_ip:3000

Requires Docker to be installed.

3. **Ollama** — install Ollama

Ollama is a platform for running large language models (LLM) locally on the server. Supports many models: llama2, mistral, codellama, and others.

After installation:
```bash
ollama serve  # start server
ollama run llama2  # run model
```

4. **Status** — show status of installed apps

Shows which apps are installed and running.

5. **Reference** — installation command reference

Shows commands for manual app installation.

### 7. System Monitor

Real-time system monitoring.

Shows current server state:

- **Uptime** — how long the server has been running since last reboot
- **Load Average** — average load at 1, 5, and 15 minutes. If load exceeds CPU cores — server is overloaded
- **Memory** — RAM usage. Shows how much is used, free, and total
- **Disk** — disk space usage. Shows size and usage percentage for each partition
- **Top processes** — list of most resource-intensive processes. Shows PID, user, % CPU, % RAM, and process name

Press r to refresh data, 0 to exit.

### 8. Network Tools

Network tools for diagnostics and testing.

**What it shows:**

- **Public IP** — your IP address on the internet. Determined via external service.
- **Local IP** — IP address on local network (usually in 192.168.x.x or 10.x.x.x range)
- **Listening ports** — which ports are open and listening for connections. Useful for checking which services are running
- **TCP connections** — total number of TCP connections to the server

**Menu options:**

1. **Test ping** — ping to google.com

Checks internet availability and connection quality. Shows response time (ping).

2. **Test curl** — curl test to google.com

Checks HTTP connection. Shows response headers.

3. **Check DNS** — check DNS

Checks DNS server operation. Shows how google.com resolves.

### 9. Service Manager

System service management.

Services are programs that run in the background and ensure system operation. For example, web server, SSH, database.

**Checked services:**

- ssh/sshd — SSH server
- docker — container platform
- fail2ban — brute force protection
- nginx — web server
- apache2 — web server

**Color indication:**

- Green (active) — service is running
- Yellow (inactive) — service is installed but not running
- Gray (not found) — service is not installed

**Menu options:**

1. **Restart all services** — restart all installed services

Starts and restarts all services from the list. Used after configuration changes.

2. **Stop all services** — stop all installed services

Stops all services. Rarely used, e.g., for maintenance.

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

Several recommendations when using the script:

1. **SSH** — after setup, always verify you can connect with new settings
2. **UFW** — before enabling, make sure SSH port is open
3. **Passwords** — don't store passwords in scripts, use SSH keys
4. **Backups** — script automatically backs up SSH configs

## License

MIT License

## Author

snakedr
