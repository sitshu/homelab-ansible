# homelab-ansible

Ansible automation for a single-host homelab on Windows 11 + WSL2 + Docker Desktop.

## What's deployed
- Arr stack: Prowlarr, Sonarr, Radarr, Bazarr
- Downloads: qBittorrent behind Gluetun (Mullvad WireGuard)
- Media: Plex (Plex Pass + Intel iGPU HW transcode)
- Photos: Immich
- Files: Nextcloud (+ Postgres + Redis)
- Remote access: Cloudflare Tunnel (public) + Tailscale (private)
- Backups: restic to E:\ drive, nightly

## Layout
```
homelab-ansible/
├── ansible.cfg
├── requirements.yml
├── .gitignore
├── .ansible-lint
├── inventory/hosts.yml
├── group_vars/all/main.yml        # non-secret config
├── group_vars/all/vault.yml       # ENCRYPTED secrets (ansible-vault)
├── playbooks/
│   ├── site.yml                   # everything
│   ├── arr.yml                    # arr stack only
│   ├── media.yml                  # plex + immich
│   ├── files.yml                  # nextcloud
│   ├── remote.yml                 # cloudflared
│   └── backup.yml                 # restic
└── roles/
    ├── common/                    # dirs, docker network
    ├── gluetun/ qbittorrent/
    ├── prowlarr/ sonarr/ radarr/ bazarr/
    ├── plex/
    ├── immich/
    ├── nextcloud/
    ├── cloudflared/
    └── backup/
```

## Storage
- C:\immich-library → Immich photos (NVMe)
- C:\docker-data → configs/DBs (NVMe)
- D:\data\media → movies/tv/music/marathi/audiobooks/study/photos
- D:\data\downloads → qBittorrent
- E:\backups → restic repo

WSL paths: /mnt/c, /mnt/d, /mnt/e

## First-time setup
```bash
cd ~/homelab-ansible
ansible-galaxy collection install -r requirements.yml
echo "YOUR_VAULT_PASSWORD" > ~/.vault_pass && chmod 600 ~/.vault_pass
ansible-vault edit group_vars/all/vault.yml  # fill in secrets
vim group_vars/all/main.yml                   # set domain, paths
ansible-playbook playbooks/site.yml --check   # dry run
ansible-playbook playbooks/site.yml           # deploy
```
