# === Kubernetes The Hard Way - Inventory ===
# Provider: ${provider}
# Region: ${region}
# Zone: ${zone}

PROVIDER="${provider}"
REGION="${region}"
ZONE="${zone}"

JUMPBOX_PUBLIC_IP="${jumpbox_public_ip}"
SERVER_PUBLIC_IP="${server_public_ip}"
NODE_0_PUBLIC_IP="${node_0_public_ip}"
NODE_1_PUBLIC_IP="${node_1_public_ip}"

JUMPBOX_PRIVATE_IP="${jumpbox_private_ip}"
SERVER_PRIVATE_IP="${server_private_ip}"
NODE_0_PRIVATE_IP="${node_0_private_ip}"
NODE_1_PRIVATE_IP="${node_1_private_ip}"

POD_CIDR="${pod_cidr}"
NODE_0_POD_CIDR="10.200.0.0/24"
NODE_1_POD_CIDR="10.200.1.0/24"
SERVICE_CIDR="${service_cidr}"
CLUSTER_DNS="${cluster_dns}"

KUBERNETES_VERSION="1.29.2"
ETCD_VERSION="3.5.12"
CONTAINERD_VERSION="1.7.13"
CNI_VERSION="1.4.0"
RUNC_VERSION="1.1.12"

SSH_USER="${ssh_user}"
SSH_KEY_PATH="${ssh_key_path}"
