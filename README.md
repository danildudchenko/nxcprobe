# nxcprobe

Multi-protocol credential validation tool for penetration testing engagements.
Tests a given username/password or NT hash across 10 protocols automatically.

## Protocols Tested
SMB, SSH, FTP, WMI, WinRM, RDP, VNC, NFS, LDAP/LDAPS, MSSQL

## Features
- Supports both password and NT hash authentication
- Domain auth and local auth tested separately
- Press `s` to skip current test and move to next
- Ctrl+C to exit cleanly
- Auto-saves results to timestamped output file
- LDAP/LDAPS timeout to prevent hanging

## Dependencies
- [Netexec](https://github.com/Pennyw0rth/NetExec)
- [Impacket](https://github.com/fortra/impacket)

## Usage
```bash
# Password authentication
./nxcprobe.sh <IP> <User> <Password> [Domain]

# NT hash authentication
./nxcprobe.sh <IP> <User> :NTHash [Domain]

Examples

./nxcprobe.sh 192.168.1.10 administrator Password123 corp.local
./nxcprobe.sh 192.168.1.10 administrator :aad3b435b51404eeaad3b435b51404ee corp.local
```

Disclaimer

This tool is intended for authorized penetration testing only.
