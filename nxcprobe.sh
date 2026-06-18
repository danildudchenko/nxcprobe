#!/bin/bash

# nxcprobe - Multi-protocol credential validation tool
# Tests credentials across 10 protocols using Netexec and Impacket
# Usage: ./nxcprobe.sh <IP> <User> <Pass|Hash> [Domain]
# Press 's' to skip current test | Ctrl+C to exit

TARGET="$1"
USER="$2"
CRED="$3"
DOMAIN="${4:-WORKGROUP}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT="${TARGET}_nxcprobe_${TIMESTAMP}.txt"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

if [ "$#" -lt 3 ]; then
    echo -e "${YELLOW}Usage: ./nxcprobe.sh <IP> <User> <Pass|Hash> [Domain]${NC}"
    echo -e "${YELLOW}       NT hash format: :aad3b435b51404eeaad3b435b51404ee${NC}"
    exit 1
fi

if [[ "$CRED" == :* ]]; then
    HASH="${CRED}"
    PASS=""
    AUTH_FLAG="-H $HASH"
    AUTH_TYPE="HASH"
else
    PASS="$CRED"
    HASH=""
    AUTH_FLAG="-p $PASS"
    AUTH_TYPE="PASSWORD"
fi

LDAP_TIMEOUT=10
PROTO_TIMEOUT=25
protocols=("smb" "ssh" "ftp" "wmi" "winrm" "rdp" "vnc" "nfs")

STTY_ORIG=$(stty -g 2>/dev/null)
BGPID=""

cleanup() {
    stty "$STTY_ORIG" 2>/dev/null
    if [[ -n "$BGPID" ]] && kill -0 "$BGPID" 2>/dev/null; then
        kill -- -$BGPID 2>/dev/null
        wait "$BGPID" 2>/dev/null
    fi
    echo -e "\n${RED}[!] Exiting${NC}"
    exit 0
}
trap cleanup INT TERM

stty -echo -icanon min 0 time 0 2>/dev/null

log() {
    echo -e "$1" | tee -a "$OUTPUT"
}

flush_input() {
    while read -r -s -n 1 -t 0.05 _ 2>/dev/null; do :; done
}

run_with_skip() {
    flush_input
    # setsid creates a new process group so kill -- -$BGPID kills nxc + tee together
    setsid bash -c "$* 2>/dev/null | tee -a '$OUTPUT'" &
    BGPID=$!

    while kill -0 $BGPID 2>/dev/null; do
        if read -r -s -n 1 -t 0.05 key 2>/dev/null; then
            if [[ "$key" == "s" || "$key" == "S" ]]; then
                kill -- -$BGPID 2>/dev/null
                wait $BGPID 2>/dev/null
                BGPID=""
                echo ""
                log "${YELLOW}[!] Skipped${NC}"
                flush_input
                return
            fi
        fi
    done
    wait $BGPID
    BGPID=""
}

log "${CYAN}=========================================================${NC}"
log "${CYAN}  nxcprobe | Target: $TARGET | User: $USER | Auth: $AUTH_TYPE${NC}"
log "${CYAN}  Domain: $DOMAIN | Output: $OUTPUT${NC}"
log "${CYAN}  Press 's' to skip test | Ctrl+C to exit${NC}"
log "${CYAN}=========================================================${NC}"

# -------------------------------------------------------
# PASS 1: DOMAIN AUTH
# -------------------------------------------------------
log ""
log "${YELLOW}[+] PASS 1 - DOMAIN AUTH (d: $DOMAIN)${NC}"

for proto in "${protocols[@]}"; do
    log ""
    log "${CYAN}[*] ${proto^^} - Domain Auth${NC}"
    run_with_skip "timeout $PROTO_TIMEOUT nxc $proto $TARGET -u $USER $AUTH_FLAG -d $DOMAIN --continue-on-success"
done

log ""
log "${CYAN}[*] LDAP - Domain Auth${NC}"
run_with_skip "timeout $LDAP_TIMEOUT nxc ldap $TARGET -u $USER $AUTH_FLAG -d $DOMAIN --continue-on-success"
log "${CYAN}[*] LDAPS (port 636) - Domain Auth${NC}"
run_with_skip "timeout $LDAP_TIMEOUT nxc ldap $TARGET -u $USER $AUTH_FLAG -d $DOMAIN --port 636 --continue-on-success"

# -------------------------------------------------------
# PASS 2: LOCAL AUTH
# -------------------------------------------------------
log ""
log "${YELLOW}[+] PASS 2 - LOCAL AUTH (no domain)${NC}"

for proto in "${protocols[@]}"; do
    log ""
    log "${CYAN}[*] ${proto^^} - Local Auth${NC}"
    run_with_skip "timeout $PROTO_TIMEOUT nxc $proto $TARGET -u $USER $AUTH_FLAG --local-auth --continue-on-success"
done

log ""
log "${CYAN}[*] LDAP - Local Auth${NC}"
run_with_skip "timeout $LDAP_TIMEOUT nxc ldap $TARGET -u $USER $AUTH_FLAG --local-auth --continue-on-success"
log "${CYAN}[*] LDAPS (port 636) - Local Auth${NC}"
run_with_skip "timeout $LDAP_TIMEOUT nxc ldap $TARGET -u $USER $AUTH_FLAG --port 636 --local-auth --continue-on-success"

# -------------------------------------------------------
# PASS 3: MSSQL
# -------------------------------------------------------
log ""
log "${YELLOW}[+] PASS 3 - MSSQL${NC}"

if [ -n "$PASS" ]; then
    log "${CYAN}[*] MSSQL - SQL Auth${NC}"
    run_with_skip "echo exit | impacket-mssqlclient ${DOMAIN}/${USER}:${PASS}@${TARGET} -db master 2>&1 | grep -iE 'Logged in|SQL Server|Error|Encryption|ACK' | sed 's/^/    /'"

    log ""
    log "${CYAN}[*] MSSQL - Windows Auth${NC}"
    run_with_skip "echo exit | impacket-mssqlclient ${DOMAIN}/${USER}:${PASS}@${TARGET} -windows-auth -db master 2>&1 | grep -iE 'Logged in|SQL Server|Error|Encryption|ACK' | sed 's/^/    /'"
else
    log "${CYAN}[*] MSSQL - Hash Auth (Windows Auth)${NC}"
    run_with_skip "echo exit | impacket-mssqlclient ${DOMAIN}/${USER}@${TARGET} -hashes ${HASH} -windows-auth -db master 2>&1 | grep -iE 'Logged in|SQL Server|Error|Encryption|ACK' | sed 's/^/    /'"
fi

stty "$STTY_ORIG" 2>/dev/null
log ""
log "${GREEN}=========================================================${NC}"
log "${GREEN}  COMPLETE | Results saved to: $OUTPUT${NC}"
log "${GREEN}=========================================================${NC}"
