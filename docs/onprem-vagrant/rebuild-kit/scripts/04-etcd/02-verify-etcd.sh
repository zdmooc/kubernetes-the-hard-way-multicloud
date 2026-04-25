#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../env.sh"

ssh_vm controller-0 "
etcdctl --endpoints=https://192.168.56.11:2379,https://192.168.56.12:2379,https://192.168.56.13:2379 \
  --cacert=/var/lib/etcd/ca.pem --cert=/var/lib/etcd/etcd.pem --key=/var/lib/etcd/etcd-key.pem endpoint status --write-out=table
etcdctl --endpoints=https://192.168.56.11:2379,https://192.168.56.12:2379,https://192.168.56.13:2379 \
  --cacert=/var/lib/etcd/ca.pem --cert=/var/lib/etcd/etcd.pem --key=/var/lib/etcd/etcd-key.pem endpoint health
"
