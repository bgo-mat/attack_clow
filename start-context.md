# Spectre — Attack Claw System Context

You are managing a Spectre pentest agent deployment. Here is the full system context.

## Architecture

```
[Browser] --HTTPS--> [Caddy :443] --reverse proxy--> [OpenClaw Gateway :18790] --API--> [Ollama :11434]
                                                           |
                                                    [Spectre Agent]
                                                           |
                                                    [Tor/Proxychains] --> [Target]
```

## Services

| Service | Port | Status command |
|---------|------|----------------|
| Ollama | 11434 | `systemctl status ollama` or `curl http://127.0.0.1:11434/api/tags` |
| OpenClaw Gateway | 18790 | `systemctl --user status openclaw-gateway` |
| Caddy HTTPS | 443 | `systemctl status caddy` |
| Tor SOCKS | 9050-9053 | `systemctl status tor@default` |
| Tor Control | 9054 | via tor-rotate.sh |

## Key Files

| File | Purpose |
|------|---------|
| `/root/.openclaw/openclaw.json` | OpenClaw main config (model, auth, gateway) |
| `/root/.openclaw/workspace/SOUL.md` | Agent personality and OPSEC rules |
| `/root/.openclaw/workspace/AGENTS.md` | Operational rules |
| `/root/.openclaw/workspace/TOOLS.md` | Arsenal documentation |
| `/root/.openclaw/exec-approvals.json` | Allowed binaries for agent |
| `/etc/tor/torrc` | Tor config (4 SOCKS ports, 30s rotation) |
| `/etc/proxychains4.conf` | Proxychains config (dynamic chain, Tor) |
| `/etc/caddy/Caddyfile` | HTTPS reverse proxy config |
| `/etc/caddy/certs/` | Self-signed TLS cert |

## OPSEC Scripts

| Script | Usage |
|--------|-------|
| `/root/.openclaw/workspace/scripts/opsec-check.sh` | Pre-flight anonymity check |
| `/root/.openclaw/workspace/scripts/tor-rotate.sh` | Force new Tor circuit. `--check` = show IP, `--loop 30` = rotate every 30s |
| `/root/.openclaw/workspace/scripts/stealth-wrapper.sh` | Wrap command through proxychains + random delay |

## Server Info

- IP: __VPS_IP__
- Dashboard: https://__VPS_IP__/
- Model: spectre (huihui_ai/qwen3-abliterated:32b uncensored, via Ollama)

## Common Operations

```bash
# Restart everything
systemctl restart ollama && systemctl --user restart openclaw-gateway && systemctl restart caddy

# Check all services
systemctl status ollama; systemctl --user status openclaw-gateway; systemctl status caddy; systemctl status tor@default

# Verify OPSEC
/root/.openclaw/workspace/scripts/opsec-check.sh

# Check Tor exit IP
curl --socks5-hostname 127.0.0.1:9050 -s https://check.torproject.org/api/ip

# View gateway logs
journalctl --user -u openclaw-gateway --no-pager -n 50

# Approve new device for dashboard
openclaw devices list
openclaw devices approve <device-id>

# Change dashboard password
# Edit /root/.openclaw/openclaw.json → gateway.auth.password
# Edit /etc/caddy/Caddyfile → X-Gateway-Token (must match token without special chars)
# Then: systemctl --user restart openclaw-gateway && systemctl restart caddy
```

## What you can help with

- Troubleshoot services (Ollama, OpenClaw, Caddy, Tor)
- Modify agent personality (SOUL.md, AGENTS.md)
- Add/remove tools
- Update OPSEC configuration
- Approve dashboard devices
- Change passwords/tokens
- Monitor and manage engagements
