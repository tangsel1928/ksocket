# KSocket

Encrypted reverse shell with auto-persistence. Single file deploy, secret-key based connection

## Features

- Single file deploy
- Secret key connection (no IP/port needed)
- End-to-end encrypted (SRP-AES-256-CBC-SHA)
- Auto-persistence (systemd, crontab, bashrc, profile, bash_profile, zshrc)
- Process disguise
- Auto-reconnect
- Full interactive PTY
- Root & non-root support
- Zero dependency
- Lightweight (~1-2MB RAM, ~0% CPU)

## Quick Start

### Deploy

```bash
./deploy
```

### Connect

```bash
ks -s "SECRET" -i
```

### Uninstall

```bash
./deploy uninstall
```
