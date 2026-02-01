# tteck Proxmox Helper Scripts UI/UX Pattern Analysis

**Task**: T013
**Date**: 2026-02-01
**Status**: complete

---

## Summary

This document analyzes the UI/UX patterns used in the tteck Proxmox Helper Scripts project (github.com/tteck/Proxmox). The patterns include whiptail-based interactive dialogs, color-coded status messages, spinner animations, storage selection from available pools, and a dual-mode (Default/Advanced) settings approach. These patterns can be adapted to improve the OpenClaw LXC installer.

---

## 1. Architecture Overview

### File Structure

The tteck project uses a modular architecture:

```
tteck/Proxmox/
  ct/                    # Container scripts (one per app)
    homeassistant.sh     # Sources build.func, defines app-specific vars
    jellyfin.sh
    ...
  misc/
    build.func           # Core functions library (652 lines)
    install.func         # Installation functions
    create_lxc.sh        # Container creation logic
  install/
    homeassistant-install.sh  # Post-creation setup script
```

### Script Flow

```
ct/app.sh
   |
   v
source build.func    --> Loads all common functions
   |
   v
header_info()        --> Display ASCII art banner
   |
   v
Define app vars      --> var_disk, var_cpu, var_ram, var_os
   |
   v
start()              --> Whiptail confirmation + install_script()
   |
   v
install_script()     --> Checks + settings selection
   |
   v
build_container()    --> create_lxc.sh + app-install.sh
   |
   v
description()        --> Set container description with logo
```

---

## 2. Color System

### ANSI Color Definitions

```bash
color() {
  YW=$(echo "\033[33m")      # Yellow - info messages, prompts
  BL=$(echo "\033[36m")      # Blue/Cyan - highlights, URLs
  RD=$(echo "\033[01;31m")   # Red (bold) - errors
  BGN=$(echo "\033[4;92m")   # Green underlined - setting values
  GN=$(echo "\033[1;92m")    # Green (bold) - success messages
  DGN=$(echo "\033[32m")     # Dark green - setting labels
  CL=$(echo "\033[m")        # Reset/clear
  CM="${GN}checkmark${CL}"   # Checkmark symbol
  CROSS="${RD}cross${CL}"    # Cross/X symbol
  BFR="\\r\\033[K"           # Backspace + clear line
  HOLD=" "                   # Indent spacing
}
```

### Message Display Functions

```bash
# Informational message with spinner
msg_info() {
  local msg="$1"
  echo -ne " ${HOLD} ${YW}${msg}   "
  spinner &
  SPINNER_PID=$!
}

# Success message - stops spinner, shows checkmark
msg_ok() {
  if [ -n "$SPINNER_PID" ] && ps -p $SPINNER_PID > /dev/null; then
    kill $SPINNER_PID > /dev/null
  fi
  printf "\e[?25h"  # Show cursor
  local msg="$1"
  echo -e "${BFR} ${CM} ${GN}${msg}${CL}"
}

# Error message - stops spinner, shows X
msg_error() {
  if [ -n "$SPINNER_PID" ] && ps -p $SPINNER_PID > /dev/null; then
    kill $SPINNER_PID > /dev/null
  fi
  printf "\e[?25h"  # Show cursor
  local msg="$1"
  echo -e "${BFR} ${CROSS} ${RD}${msg}${CL}"
}
```

### Spinner Animation

```bash
spinner() {
    local chars="/-\|"
    local spin_i=0
    printf "\e[?25l"  # Hide cursor
    while true; do
        printf "\r \e[36m%s\e[0m" "${chars:spin_i++%${#chars}:1}"
        sleep 0.1
    done
}
```

---

## 3. Storage Selection Pattern

### Dual Storage Classes

tteck queries both container storage and template storage separately:

```bash
function select_storage() {
  local CLASS=$1
  local CONTENT
  local CONTENT_LABEL

  case $CLASS in
  container)
    CONTENT='rootdir'
    CONTENT_LABEL='Container'
    ;;
  template)
    CONTENT='vztmpl'
    CONTENT_LABEL='Container template'
    ;;
  esac

  # Query storage with specific content type
  local -a MENU
  while read -r line; do
    local TAG=$(echo $line | awk '{print $1}')
    local TYPE=$(echo $line | awk '{printf "%-10s", $2}')
    local FREE=$(echo $line | numfmt --field 4-6 --from-unit=K --to=iec --format %.2f | awk '{printf( "%9sB", $6)}')
    local ITEM="  Type: $TYPE Free: $FREE "

    # Track max length for dialog sizing
    if [[ $((${#ITEM} + 2)) -gt ${MSG_MAX_LENGTH:-} ]]; then
      MSG_MAX_LENGTH=$((${#ITEM} + 2))
    fi
    MENU+=("$TAG" "$ITEM" "OFF")
  done < <(pvesm status -content $CONTENT | awk 'NR>1')

  # Auto-select if only one option
  if [ $((${#MENU[@]}/3)) -eq 1 ]; then
    printf ${MENU[0]}
  else
    # Show whiptail radiolist
    local STORAGE
    while [ -z "${STORAGE:+x}" ]; do
      STORAGE=$(whiptail --backtitle "Proxmox VE Helper Scripts" \
        --title "Storage Pools" \
        --radiolist "Which storage pool for ${CONTENT_LABEL,,}?\nUse Spacebar to select.\n" \
        16 $(($MSG_MAX_LENGTH + 23)) 6 \
        "${MENU[@]}" 3>&1 1>&2 2>&3) || exit
    done
    printf $STORAGE
  fi
}
```

### Usage in create_lxc.sh

```bash
# Get template storage (for .tar.zst files)
TEMPLATE_STORAGE=$(select_storage template) || exit
msg_ok "Using ${BL}$TEMPLATE_STORAGE${CL} ${GN}for Template Storage."

# Get container storage (for rootfs)
CONTAINER_STORAGE=$(select_storage container) || exit
msg_ok "Using ${BL}$CONTAINER_STORAGE${CL} ${GN}for Container Storage."
```

---

## 4. Container ID Auto-Detection

### Getting Next Available ID

```bash
# In build.func
NEXTID=$(pvesh get /cluster/nextid)
```

### User Override in Advanced Settings

```bash
if CT_ID=$(whiptail --backtitle "Proxmox VE Helper Scripts" \
    --inputbox "Set Container ID" 8 58 $NEXTID \
    --title "CONTAINER ID" 3>&1 1>&2 2>&3); then
  if [ -z "$CT_ID" ]; then
    CT_ID="$NEXTID"
    echo -e "${DGN}Using Container ID: ${BGN}$CT_ID${CL}"
  else
    echo -e "${DGN}Container ID: ${BGN}$CT_ID${CL}"
  fi
else
  exit
fi
```

### Validation in create_lxc.sh

```bash
# Test if ID is valid
[ "$CTID" -ge "100" ] || exit "ID cannot be less than 100."

# Test if ID is in use
if pct status $CTID &>/dev/null; then
  echo -e "ID '$CTID' is already in use."
  unset CTID
  exit "Cannot use ID that is already in use."
fi
```

---

## 5. Default vs Advanced Settings Pattern

### Entry Point Decision

```bash
install_script() {
  pve_check
  shell_check
  root_check
  arch_check
  ssh_check

  NEXTID=$(pvesh get /cluster/nextid)
  timezone=$(cat /etc/timezone)

  header_info
  if (whiptail --backtitle "Proxmox VE Helper Scripts" \
      --title "SETTINGS" \
      --yesno "Use Default Settings?" \
      --no-button Advanced 10 58); then
    header_info
    echo -e "${BL}Using Default Settings${CL}"
    default_settings
  else
    header_info
    echo -e "${RD}Using Advanced Settings${CL}"
    advanced_settings
  fi
}
```

### Default Settings Echo

```bash
echo_default() {
  echo -e "${DGN}Using Distribution: ${BGN}$var_os${CL}"
  echo -e "${DGN}Using $var_os Version: ${BGN}$var_version${CL}"
  echo -e "${DGN}Using Container Type: ${BGN}$CT_TYPE${CL}"
  echo -e "${DGN}Using Root Password: ${BGN}Automatic Login${CL}"
  echo -e "${DGN}Using Container ID: ${BGN}$NEXTID${CL}"
  echo -e "${DGN}Using Hostname: ${BGN}$NSAPP${CL}"
  echo -e "${DGN}Using Disk Size: ${BGN}$var_disk${CL}${DGN}GB${CL}"
  echo -e "${DGN}Allocated Cores ${BGN}$var_cpu${CL}"
  echo -e "${DGN}Allocated Ram ${BGN}$var_ram${CL}"
  echo -e "${DGN}Using Bridge: ${BGN}vmbr0${CL}"
  echo -e "${DGN}Using Static IP Address: ${BGN}dhcp${CL}"
  # ... more settings ...
  echo -e "${BL}Creating a ${APP} LXC using the above default settings${CL}"
}
```

---

## 6. Whiptail Dialog Patterns

### Yes/No Dialog

```bash
if (whiptail --backtitle "Proxmox VE Helper Scripts" \
    --title "${APP} LXC" \
    --yesno "This will create a New ${APP} LXC. Proceed?" 10 58); then
  # User clicked Yes
else
  clear
  echo -e "User exited script \n"
  exit
fi
```

### Input Box with Default Value

```bash
if DISK_SIZE=$(whiptail --backtitle "Proxmox VE Helper Scripts" \
    --inputbox "Set Disk Size in GB" 8 58 $var_disk \
    --title "DISK SIZE" 3>&1 1>&2 2>&3); then
  if [ -z "$DISK_SIZE" ]; then
    DISK_SIZE="$var_disk"  # Use default if empty
  else
    # Validate integer input
    if ! [[ $DISK_SIZE =~ ^[0-9]+([.][0-9]+)?$ ]]; then
      echo -e "${RD}DISK SIZE MUST BE AN INTEGER!${CL}"
      advanced_settings  # Restart settings
    fi
  fi
else
  exit-script  # User cancelled
fi
```

### Radio List Selection

```bash
CT_TYPE=""
while [ -z "$CT_TYPE" ]; do
  if CT_TYPE=$(whiptail --backtitle "Proxmox VE Helper Scripts" \
      --title "CONTAINER TYPE" \
      --radiolist "Choose Type" 10 58 2 \
      "1" "Unprivileged" OFF \
      "0" "Privileged" OFF \
      3>&1 1>&2 2>&3); then
    if [ -n "$CT_TYPE" ]; then
      echo -e "${DGN}Using Container Type: ${BGN}$CT_TYPE${CL}"
    fi
  else
    exit-script
  fi
done
```

### Password Input with Validation

```bash
while true; do
  if PW1=$(whiptail --backtitle "Proxmox VE Helper Scripts" \
      --passwordbox "\nSet Root Password" 9 58 \
      --title "PASSWORD (leave blank for auto login)" 3>&1 1>&2 2>&3); then
    if [[ ! -z "$PW1" ]]; then
      # Check for spaces
      if [[ "$PW1" == *" "* ]]; then
        whiptail --msgbox "Password cannot contain spaces." 8 58
      # Check minimum length
      elif [ ${#PW1} -lt 5 ]; then
        whiptail --msgbox "Password must be at least 5 characters." 8 58
      else
        # Verify password
        if PW2=$(whiptail --passwordbox "\nVerify Password" 9 58 \
            --title "VERIFICATION" 3>&1 1>&2 2>&3); then
          if [[ "$PW1" == "$PW2" ]]; then
            PW="-password $PW1"
            break
          else
            whiptail --msgbox "Passwords do not match." 8 58
          fi
        fi
      fi
    else
      PW=""  # Empty = auto login
      break
    fi
  else
    exit-script
  fi
done
```

### IP Address Validation

```bash
while true; do
  NET=$(whiptail --backtitle "Proxmox VE Helper Scripts" \
      --inputbox "Set Static IPv4 CIDR (/24)" 8 58 dhcp \
      --title "IP ADDRESS" 3>&1 1>&2 2>&3)
  exit_status=$?

  if [ $exit_status -eq 0 ]; then
    if [ "$NET" = "dhcp" ]; then
      echo -e "${DGN}Using IP Address: ${BGN}$NET${CL}"
      break
    else
      # Validate CIDR format
      if [[ "$NET" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/([0-9]|[1-2][0-9]|3[0-2])$ ]]; then
        echo -e "${DGN}Using IP Address: ${BGN}$NET${CL}"
        break
      else
        whiptail --msgbox "$NET is invalid. Use CIDR format or 'dhcp'" 8 58
      fi
    fi
  else
    exit-script
  fi
done
```

---

## 7. Pre-flight Checks

### Root Check

```bash
root_check() {
  if [[ "$(id -u)" -ne 0 || $(ps -o comm= -p $PPID) == "sudo" ]]; then
    clear
    msg_error "Please run this script as root."
    echo -e "\nExiting..."
    sleep 2
    exit
  fi
}
```

### Proxmox Version Check

```bash
pve_check() {
  if ! pveversion | grep -Eq "pve-manager/8.[1-3]"; then
    msg_error "This version of Proxmox VE is not supported"
    echo -e "Requires Proxmox VE Version 8.1 or later."
    echo -e "Exiting..."
    sleep 2
    exit
  fi
}
```

### Architecture Check

```bash
arch_check() {
  if [ "$(dpkg --print-architecture)" != "amd64" ]; then
    echo -e "\n ${CROSS} This script will not work with PiMox! \n"
    echo -e "\n Visit https://github.com/asylumexp/Proxmox for ARM64 support. \n"
    exit
  fi
}
```

### SSH Warning

```bash
ssh_check() {
  if command -v pveversion >/dev/null 2>&1 && [ -n "${SSH_CLIENT:+x}" ]; then
    if whiptail --backtitle "Proxmox VE Helper Scripts" \
        --defaultno --title "SSH DETECTED" \
        --yesno "It's advisable to use Proxmox shell rather than SSH. Proceed?" 10 72; then
      whiptail --msgbox "Proceeding with SSH. Run in Proxmox shell if issues arise." 10 72
    else
      clear
      echo "Exiting due to SSH. Please use Proxmox shell."
      exit
    fi
  fi
}
```

---

## 8. Error Handling

### Global Error Trap

```bash
catch_errors() {
  set -Eeuo pipefail
  trap 'error_handler $LINENO "$BASH_COMMAND"' ERR
}

error_handler() {
  # Stop spinner if running
  if [ -n "$SPINNER_PID" ] && ps -p $SPINNER_PID > /dev/null; then
    kill $SPINNER_PID > /dev/null
  fi
  printf "\e[?25h"  # Show cursor

  local exit_code="$?"
  local line_number="$1"
  local command="$2"
  local error_message="${RD}[ERROR]${CL} in line ${RD}$line_number${CL}: exit code ${RD}$exit_code${CL}: while executing command ${YW}$command${CL}"
  echo -e "\n$error_message\n"
}
```

### Exit Script Handler

```bash
exit-script() {
  clear
  echo -e "User exited script \n"
  exit
}
```

---

## 9. Recommended Improvements for OpenClaw install.sh

### Current State Analysis

The current OpenClaw `install.sh` has basic functionality but lacks:
1. whiptail-based interactive dialogs
2. Storage pool auto-detection and selection
3. Spinner animations during long operations
4. Proper Default/Advanced mode toggle
5. Rich validation patterns

### Recommended Enhancements

#### A. Add whiptail Storage Selection

```bash
select_storage() {
  local CONTENT='rootdir'
  local -a MENU
  local MSG_MAX_LENGTH=0

  while read -r line; do
    local TAG=$(echo $line | awk '{print $1}')
    local TYPE=$(echo $line | awk '{printf "%-10s", $2}')
    local FREE=$(echo $line | numfmt --field 4-6 --from-unit=K --to=iec --format %.2f | awk '{printf( "%9sB", $6)}')
    local ITEM="  Type: $TYPE Free: $FREE "
    if [[ $((${#ITEM} + 2)) -gt ${MSG_MAX_LENGTH} ]]; then
      MSG_MAX_LENGTH=$((${#ITEM} + 2))
    fi
    MENU+=("$TAG" "$ITEM" "OFF")
  done < <(pvesm status -content $CONTENT | awk 'NR>1')

  if [ $((${#MENU[@]}/3)) -eq 1 ]; then
    printf ${MENU[0]}
  else
    STORAGE=$(whiptail --backtitle "OpenClaw Installer" \
      --title "Storage Selection" \
      --radiolist "Select storage pool for container:\n" \
      16 $(($MSG_MAX_LENGTH + 23)) 6 \
      "${MENU[@]}" 3>&1 1>&2 2>&3) || exit
    printf $STORAGE
  fi
}
```

#### B. Add Default/Advanced Mode Toggle

```bash
install_script() {
  check_proxmox

  CT_ID=$(pvesh get /cluster/nextid)

  header_info
  if (whiptail --backtitle "OpenClaw Installer" \
      --title "SETTINGS" \
      --yesno "Use Default Settings?\n\nDefault: ${CT_ID}, 32GB disk, 4 cores, 8GB RAM, DHCP" \
      --yes-button "Default" --no-button "Advanced" 12 58); then
    echo -e "${BL}Using Default Settings${CL}"
    STORAGE=$(select_storage)
    TEMPLATE_STORAGE=$(select_template_storage)
    show_default_settings
  else
    echo -e "${YW}Using Advanced Settings${CL}"
    advanced_settings
  fi
}
```

#### C. Add Spinner for Long Operations

```bash
# Global spinner PID
SPINNER_PID=""

spinner() {
    local chars="/-\|"
    local spin_i=0
    printf "\e[?25l"
    while true; do
        printf "\r \e[36m%s\e[0m" "${chars:spin_i++%${#chars}:1}"
        sleep 0.1
    done
}

msg_info() {
  local msg="$1"
  echo -ne " ${HOLD} ${YW}${msg}...   "
  spinner &
  SPINNER_PID=$!
}

msg_ok() {
  if [ -n "$SPINNER_PID" ] && ps -p $SPINNER_PID > /dev/null; then
    kill $SPINNER_PID > /dev/null
  fi
  printf "\e[?25h"
  echo -e "\r ${CM} ${GN}$1${CL}"
}
```

#### D. Enhanced Network Configuration

```bash
configure_network() {
  # IP Address
  while true; do
    NET=$(whiptail --backtitle "OpenClaw Installer" \
        --inputbox "Static IP (CIDR format) or 'dhcp'" 8 58 dhcp \
        --title "NETWORK" 3>&1 1>&2 2>&3) || exit_script

    if [ "$NET" = "dhcp" ]; then
      break
    elif [[ "$NET" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/([0-9]|[1-2][0-9]|3[0-2])$ ]]; then
      # Get gateway if static IP
      GATE=$(whiptail --inputbox "Gateway IP Address" 8 58 "" \
          --title "GATEWAY" 3>&1 1>&2 2>&3) || exit_script

      if [[ ! "$GATE" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        whiptail --msgbox "Invalid gateway IP format" 8 58
        continue
      fi
      break
    else
      whiptail --msgbox "Invalid format. Use CIDR (e.g., 10.0.10.50/24) or 'dhcp'" 8 58
    fi
  done
}
```

#### E. Bridge Selection

```bash
select_bridge() {
  local -a BRIDGES
  while read -r bridge; do
    BRIDGES+=("$bridge" "" "OFF")
  done < <(ip -o link show type bridge | awk -F': ' '{print $2}')

  if [ ${#BRIDGES[@]} -eq 0 ]; then
    echo "vmbr0"
    return
  fi

  if [ $((${#BRIDGES[@]}/3)) -eq 1 ]; then
    echo "${BRIDGES[0]}"
  else
    BRIDGE=$(whiptail --backtitle "OpenClaw Installer" \
        --title "Network Bridge" \
        --radiolist "Select network bridge:" 12 40 4 \
        "${BRIDGES[@]}" 3>&1 1>&2 2>&3) || exit
    echo "$BRIDGE"
  fi
}
```

---

## 10. Complete Improved Script Structure

```bash
#!/usr/bin/env bash
# OpenClaw LXC Installer for Proxmox VE
# Inspired by tteck Proxmox Helper Scripts patterns

set -Eeuo pipefail

# =============================================================================
# Configuration
# =============================================================================

SCRIPT_VERSION="2.0.0"
APP="OpenClaw"
NSAPP="openclaw"
SPINNER_PID=""

# Defaults
var_disk="32"
var_cpu="4"
var_ram="8192"
var_os="debian"
var_version="12"

# =============================================================================
# Colors and Display
# =============================================================================

color() {
  YW=$(echo "\033[33m")
  BL=$(echo "\033[36m")
  RD=$(echo "\033[01;31m")
  BGN=$(echo "\033[4;92m")
  GN=$(echo "\033[1;92m")
  DGN=$(echo "\033[32m")
  CL=$(echo "\033[m")
  CM="${GN}\xE2\x9C\x93${CL}"
  CROSS="${RD}\xE2\x9C\x97${CL}"
  HOLD=" "
}

header_info() {
  clear
  cat <<"EOF"
   ___  ____  _____ _   _  ____ _        ___        __
  / _ \|  _ \| ____| \ | |/ ___| |      / \ \      / /
 | | | | |_) |  _| |  \| | |   | |     / _ \ \ /\ / /
 | |_| |  __/| |___| |\  | |___| |___ / ___ \ V  V /
  \___/|_|   |_____|_| \_|\____|_____/_/   \_\_/\_/

EOF
  echo -e "${BL}LXC Installer v${SCRIPT_VERSION}${CL}\n"
}

spinner() { ... }    # From tteck pattern
msg_info() { ... }   # From tteck pattern
msg_ok() { ... }     # From tteck pattern
msg_error() { ... }  # From tteck pattern

# =============================================================================
# Checks
# =============================================================================

catch_errors() { ... }
error_handler() { ... }
root_check() { ... }
pve_check() { ... }
arch_check() { ... }

# =============================================================================
# Storage & Template Selection
# =============================================================================

select_storage() { ... }
select_template_storage() { ... }
ensure_template() { ... }

# =============================================================================
# Settings Configuration
# =============================================================================

default_settings() {
  CT_TYPE="1"
  CT_ID=$(pvesh get /cluster/nextid)
  HN="$NSAPP"
  DISK_SIZE="$var_disk"
  CORE_COUNT="$var_cpu"
  RAM_SIZE="$var_ram"
  BRG="vmbr0"
  NET="dhcp"
  GATE=""
  SSH="no"

  echo_default
}

advanced_settings() {
  # Container ID
  CT_ID=$(whiptail --inputbox "Container ID" 8 58 "$(pvesh get /cluster/nextid)" \
      --title "CONTAINER ID" 3>&1 1>&2 2>&3) || exit_script

  # Hostname
  HN=$(whiptail --inputbox "Hostname" 8 58 "$NSAPP" \
      --title "HOSTNAME" 3>&1 1>&2 2>&3) || exit_script
  HN=$(echo ${HN,,} | tr -d ' ')

  # Disk, CPU, RAM
  # ... (pattern from tteck)

  # Network
  configure_network

  # SSH
  if (whiptail --defaultno --title "SSH ACCESS" \
      --yesno "Enable Root SSH Access?" 10 58); then
    SSH="yes"
  fi
}

# =============================================================================
# Container Operations
# =============================================================================

build_container() { ... }
setup_container() { ... }
description() { ... }

# =============================================================================
# Main
# =============================================================================

main() {
  color
  catch_errors

  header_info

  root_check
  pve_check
  arch_check

  STORAGE=$(select_storage)
  TEMPLATE_STORAGE=$(select_template_storage)
  ensure_template

  if (whiptail --title "SETTINGS" \
      --yesno "Use Default Settings?" \
      --yes-button Default --no-button Advanced 10 58); then
    default_settings
  else
    advanced_settings
  fi

  if (whiptail --title "CREATE ${APP} LXC" \
      --yesno "Create container with these settings?" 10 58); then
    build_container
    setup_container
    description
    show_completion
  else
    exit_script
  fi
}

main "$@"
```

---

## References

- tteck Proxmox Repository: https://github.com/tteck/Proxmox (archived Nov 2024)
- Key files analyzed:
  - `misc/build.func` - Core 652-line function library
  - `ct/create_lxc.sh` - Container creation logic
  - `ct/homeassistant.sh` - Example app script structure
- OpenClaw current scripts:
  - `/mnt/projects/openclaw/scripts/install.sh`
  - `/mnt/projects/openclaw/scripts/provision-lxc.sh`
