#!/usr/bin/env bash
set -euo pipefail

mkdir -p evidence/onprem

echo "Collecte d'état Vagrant..."
vagrant status > evidence/onprem/vagrant-status.txt

for host in jumpbox controller-0 controller-1 controller-2 worker-0 worker-1; do
  echo "Collecte ${host}"
  vagrant ssh "${host}" -c 'hostnamectl; ip -brief addr; ip route; free -h; nproc' > "evidence/onprem/${host}-baseline.txt"
done

echo "Preuves collectées dans evidence/onprem/"
