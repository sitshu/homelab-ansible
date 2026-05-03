#!/bin/bash
# One-time setup for a fresh WSL2 Ubuntu. Run with: bash bootstrap.sh
set -euo pipefail

echo "==> Installing prerequisites..."
sudo apt update
sudo apt install -y ansible git python3-pip python3-venv curl vim restic

echo "==> Installing Ansible collections..."
ansible-galaxy collection install -r requirements.yml

echo "==> Setting up vault password file..."
if [ ! -f ~/.vault_pass ]; then
  read -rsp "Enter a vault password (you'll need this to unlock secrets): " pw
  echo
  echo "$pw" > ~/.vault_pass
  chmod 600 ~/.vault_pass
fi

echo "==> Setting up vault.yml..."
if [ ! -f group_vars/all/vault.yml ]; then
  cp group_vars/all/vault.yml.template group_vars/all/vault.yml
  ansible-vault encrypt group_vars/all/vault.yml
  echo "Created ENCRYPTED vault.yml. Edit with:"
  echo "  ansible-vault edit group_vars/all/vault.yml"
fi

echo "==> Creating host config directories..."
sudo mkdir -p /mnt/c/docker-data /mnt/d/data/media /mnt/d/data/downloads /mnt/c/immich-library /mnt/e/backups
sudo chown -R "$(id -u):$(id -g)" /mnt/c/docker-data /mnt/c/immich-library || true

echo
echo "All set. Next steps:"
echo "  1. ansible-vault edit group_vars/all/vault.yml    # fill in secrets"
echo "  2. vim group_vars/all/main.yml                    # set domain + timezone"
echo "  3. ansible-playbook playbooks/site.yml --check    # dry run"
echo "  4. ansible-playbook playbooks/site.yml            # deploy"
