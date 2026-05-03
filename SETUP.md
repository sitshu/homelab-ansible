# Setup guide — external prerequisites

Before running `ansible-playbook`, set up these accounts and fill in `vault.yml`.

## 1. Remote access: Tailscale + native apps (already covered)

The default deploy uses Tailscale for private service access and the services'
own native apps/relays for family/friends. **No domain purchase, no tunnel
setup, no port forwarding required.**

- **Plex** — Plex's built-in relay handles remote access. Share libraries at
  https://app.plex.tv/desktop/#!/settings/sharing. Friends use the Plex app,
  no Tailscale needed for them.
- **Immich** — install the Immich app on your phone, connect to
  `http://100.74.221.111:2283` (your Tailscale IP). Family members install
  Tailscale + Immich and use the same URL.
- **Nextcloud** — same pattern: Nextcloud iOS/Android/desktop app pointed at
  the Tailscale URL.
- **Arr stack, qBittorrent, Open WebUI** — browser over Tailscale.

## (Optional) Public sharing via Cloudflare Tunnel

Only needed if you want public URLs for people who don't use Tailscale — e.g.
sharing a Nextcloud file link with a random colleague, or a public Immich
album. Not part of the default `site.yml`. To enable:

1. Buy a domain at https://dash.cloudflare.com → Registrar (~$10/yr for .com)
2. Cloudflare dashboard → Zero Trust → Networks → Tunnels → Create tunnel,
   name it `homelab`, copy the tunnel token
3. Save the token to `vault.yml` as `vault_cloudflare_tunnel_token`
4. In the tunnel's Public Hostname tab, add routes:
   - `cloud.YOURDOMAIN.com`  → HTTP → `localhost:8443` (Nextcloud)
   - `photos.YOURDOMAIN.com` → HTTP → `localhost:2283` (Immich)
5. Set the domain in `group_vars/all/main.yml` as `domain:`
6. Deploy cloudflared: `ansible-playbook playbooks/remote.yml`

Cloudflare issues TLS certs automatically. No port forwarding on your router.

## 3. ProtonVPN Plus (with dynamic port forwarding)

1. Sign up at https://protonvpn.com/pricing — **VPN Plus**. Monthly billing
   works for a trial; 24-month plan is best long-term.

2. Go to https://account.protonvpn.com/downloads → **WireGuard configuration**

3. Create a new config:
   - Platform: any (WireGuard is WireGuard)
   - **Enable "NAT-PMP (Port Forwarding)"** ← critical; without this Proton
     won't forward a port regardless of Gluetun settings
   - **Enable "VPN Accelerator"** and **"Moderate NAT"**
   - Server: pick a country marked with the P2P icon (Netherlands,
     Switzerland, Romania, Iceland are solid). Download the `.conf` file.

4. Open the `.conf` file. Copy these two values into `vault.yml`:
   ```
   [Interface]
   PrivateKey = xxxxxxxxxxxx    → vault_wireguard_private_key
   Address    = 10.2.0.2/32     → vault_wireguard_addresses
   ```

5. In `group_vars/all/main.yml` set `vpn.server_countries` to a comma-separated
   list matching your chosen countries (e.g. `"Netherlands,Switzerland"`).

6. **Generate a Gluetun API key.** Gluetun 3.40+ requires auth on its control
   server — the sync-port mod uses this key to fetch the forwarded port:
   ```bash
   docker run --rm qmcgaw/gluetun genkey
   ```
   Copy the output into `vault.yml` as `vault_gluetun_api_key`.

7. **After first Ansible deploy**, open qBittorrent WebUI at `http://HOST:8080`:
   - Get the temp password: `docker logs qbittorrent 2>&1 | grep -i password`
   - Log in with user `admin` + that password
   - **Settings → Web UI → enable "Bypass authentication for clients on
     localhost"** (this is what the mod expects; simpler than managing creds)
   - Optional: change the admin password while you're there

### How the dynamic port works (verified against upstream docs)
- Proton rotates the forwarded port on each reconnect (typically once/day)
- Gluetun requests a port via NAT-PMP and exposes it at its control server
  endpoint `GET /v1/portforward` (auth via `X-API-Key` header)
- The qBittorrent container runs `gsp-qbittorent-gluetun-sync-port-mod` as a
  DOCKER_MODS sidecar — every 120s it fetches Gluetun's current port and,
  if it differs from qBit's listening port, updates qBit via its WebAPI
- Since qBit shares Gluetun's network namespace (`network_mode:
  container:gluetun`), both services talk to each other over `localhost`

### Why P2P/PORT_FORWARD_ONLY matters
Not all Proton servers forward ports. Without `PORT_FORWARD_ONLY=on`,
Gluetun can land on a non-PF server and `/v1/portforward` returns port `0`
forever. The scaffold has this set.

### Kill switch — what stops qBit when the VPN drops
The setup is already leak-proof by design, but verify it works before
trusting it. Three layers of protection:

1. **`network_mode: container:gluetun`** means qBit and Prowlarr literally
   have no network interface of their own. They share Gluetun's. If Gluetun
   stops, they have zero network access. This is the airtight kill switch.
2. **Gluetun's built-in firewall** (default) denies all non-VPN traffic.
   Even if the WireGuard tunnel drops but Gluetun itself stays up, no packets
   escape outside the tunnel.
3. **Proton's WireGuard client logic** reconnects automatically. Brief
   tunnel flaps drop traffic (peer connections fail) but nothing leaks.

**What's NOT on the VPN:** Sonarr, Radarr, Bazarr talk to TheMovieDB/TVDB/
Trakt/OpenSubtitles on the clear net. These are low-risk — metadata APIs,
not torrent peers.

### Verify the kill switch yourself

After first deploy, run these inside WSL:

```bash
# Confirm qBit's public IP matches your VPN (not your real IP)
docker exec qbittorrent curl -s https://ifconfig.me

# Confirm it differs from your real IP
curl -s https://ifconfig.me

# Test the kill switch — stop Gluetun and verify qBit loses network
docker stop gluetun
docker exec qbittorrent curl -m 5 https://ifconfig.me    # should hang/fail
docker start gluetun
# Wait 30s then re-test; should show VPN IP again.
```

If `docker exec qbittorrent curl ifconfig.me` ever returns your real home
IP, the kill switch is broken — stop and debug before downloading anything.

## 4. Plex Claim Token

Only needed on first Plex deploy. Valid for 4 minutes so fetch right before `ansible-playbook`:
- https://www.plex.tv/claim
- Copy `claim-XXXXXXXX`
- Paste into `vault.yml` as `vault_plex_claim`
- Deploy within 4 minutes

## 5. Restic backup password

Generate a strong passphrase (32+ chars). You will need this to restore backups:
```bash
openssl rand -base64 32
```
Save to `vault.yml` as `vault_restic_password`.

**WRITE IT DOWN somewhere safe outside this computer** — losing it means losing backups.

## 6. Tailscale (already installed, skipped)

Already running. The arr stack + open-webui stay on Tailscale-only access
(never exposed via Cloudflare) because they're attractive to scanners.

---

After all of the above:
```bash
ansible-playbook playbooks/site.yml --check   # dry run
ansible-playbook playbooks/site.yml           # actually deploy
```
