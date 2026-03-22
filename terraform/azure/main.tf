# ==============================================================================
# Kubernetes The Hard Way - Multi-Cloud
# Provider: Microsoft Azure
# Fichier: main.tf
# Auteur: Zidane Djamal
# ==============================================================================

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "k8s_rg" {
  name     = var.resource_group_name
  location = var.location
}

# ------------------------------------------------------------------------------
# 1. Réseau (VNet, Subnet, Route Table)
# ------------------------------------------------------------------------------
resource "azurerm_virtual_network" "k8s_vnet" {
  name                = "k8s-thw-vnet"
  address_space       = ["10.240.0.0/24"]
  location            = azurerm_resource_group.k8s_rg.location
  resource_group_name = azurerm_resource_group.k8s_rg.name
}

resource "azurerm_subnet" "k8s_subnet" {
  name                 = "k8s-thw-subnet"
  resource_group_name  = azurerm_resource_group.k8s_rg.name
  virtual_network_name = azurerm_virtual_network.k8s_vnet.name
  address_prefixes     = ["10.240.0.0/24"]
}

resource "azurerm_route_table" "k8s_rt" {
  name                = "k8s-thw-rt"
  location            = azurerm_resource_group.k8s_rg.location
  resource_group_name = azurerm_resource_group.k8s_rg.name

  route {
    name                   = "route-node-0"
    address_prefix         = "10.200.0.0/24"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = "10.240.0.20"
  }

  route {
    name                   = "route-node-1"
    address_prefix         = "10.200.1.0/24"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = "10.240.0.21"
  }
}

resource "azurerm_subnet_route_table_association" "k8s_rta" {
  subnet_id      = azurerm_subnet.k8s_subnet.id
  route_table_id = azurerm_route_table.k8s_rt.id
}

# ------------------------------------------------------------------------------
# 2. Network Security Group (NSG)
# ------------------------------------------------------------------------------
resource "azurerm_network_security_group" "k8s_nsg" {
  name                = "k8s-thw-nsg"
  location            = azurerm_resource_group.k8s_rg.location
  resource_group_name = azurerm_resource_group.k8s_rg.name

  security_rule {
    name                       = "Allow-SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-KubeAPI"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-Internal"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefixes    = ["10.240.0.0/24", "10.200.0.0/16"]
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "k8s_nsg_assoc" {
  subnet_id                 = azurerm_subnet.k8s_subnet.id
  network_security_group_id = azurerm_network_security_group.k8s_nsg.id
}

# ------------------------------------------------------------------------------
# 3. Public IPs
# ------------------------------------------------------------------------------
resource "azurerm_public_ip" "jumpbox_pip" {
  name                = "jumpbox-pip"
  location            = azurerm_resource_group.k8s_rg.location
  resource_group_name = azurerm_resource_group.k8s_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_public_ip" "server_pip" {
  name                = "server-pip"
  location            = azurerm_resource_group.k8s_rg.location
  resource_group_name = azurerm_resource_group.k8s_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_public_ip" "node_0_pip" {
  name                = "node-0-pip"
  location            = azurerm_resource_group.k8s_rg.location
  resource_group_name = azurerm_resource_group.k8s_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_public_ip" "node_1_pip" {
  name                = "node-1-pip"
  location            = azurerm_resource_group.k8s_rg.location
  resource_group_name = azurerm_resource_group.k8s_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# ------------------------------------------------------------------------------
# 4. Network Interfaces (NICs)
# ------------------------------------------------------------------------------
# Note : enable_ip_forwarding = true est requis pour le routage des pods sur les workers

resource "azurerm_network_interface" "jumpbox_nic" {
  name                = "jumpbox-nic"
  location            = azurerm_resource_group.k8s_rg.location
  resource_group_name = azurerm_resource_group.k8s_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.k8s_subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.240.0.10"
    public_ip_address_id          = azurerm_public_ip.jumpbox_pip.id
  }
}

resource "azurerm_network_interface" "server_nic" {
  name                = "server-nic"
  location            = azurerm_resource_group.k8s_rg.location
  resource_group_name = azurerm_resource_group.k8s_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.k8s_subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.240.0.11"
    public_ip_address_id          = azurerm_public_ip.server_pip.id
  }
}

resource "azurerm_network_interface" "node_0_nic" {
  name                 = "node-0-nic"
  location             = azurerm_resource_group.k8s_rg.location
  resource_group_name  = azurerm_resource_group.k8s_rg.name
  enable_ip_forwarding = true

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.k8s_subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.240.0.20"
    public_ip_address_id          = azurerm_public_ip.node_0_pip.id
  }
}

resource "azurerm_network_interface" "node_1_nic" {
  name                 = "node-1-nic"
  location             = azurerm_resource_group.k8s_rg.location
  resource_group_name  = azurerm_resource_group.k8s_rg.name
  enable_ip_forwarding = true

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.k8s_subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.240.0.21"
    public_ip_address_id          = azurerm_public_ip.node_1_pip.id
  }
}

# ------------------------------------------------------------------------------
# 5. Virtual Machines
# ------------------------------------------------------------------------------
resource "azurerm_linux_virtual_machine" "jumpbox" {
  name                = "jumpbox"
  resource_group_name = azurerm_resource_group.k8s_rg.name
  location            = azurerm_resource_group.k8s_rg.location
  size                = "Standard_B1s"
  admin_username      = var.ssh_user
  network_interface_ids = [
    azurerm_network_interface.jumpbox_nic.id,
  ]

  admin_ssh_key {
    username   = var.ssh_user
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

resource "azurerm_linux_virtual_machine" "server" {
  name                = "server"
  resource_group_name = azurerm_resource_group.k8s_rg.name
  location            = azurerm_resource_group.k8s_rg.location
  size                = var.vm_size
  admin_username      = var.ssh_user
  network_interface_ids = [
    azurerm_network_interface.server_nic.id,
  ]

  admin_ssh_key {
    username   = var.ssh_user
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 50
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

resource "azurerm_linux_virtual_machine" "node_0" {
  name                = "node-0"
  resource_group_name = azurerm_resource_group.k8s_rg.name
  location            = azurerm_resource_group.k8s_rg.location
  size                = var.vm_size
  admin_username      = var.ssh_user
  network_interface_ids = [
    azurerm_network_interface.node_0_nic.id,
  ]

  admin_ssh_key {
    username   = var.ssh_user
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 50
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

resource "azurerm_linux_virtual_machine" "node_1" {
  name                = "node-1"
  resource_group_name = azurerm_resource_group.k8s_rg.name
  location            = azurerm_resource_group.k8s_rg.location
  size                = var.vm_size
  admin_username      = var.ssh_user
  network_interface_ids = [
    azurerm_network_interface.node_1_nic.id,
  ]

  admin_ssh_key {
    username   = var.ssh_user
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 50
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

# ------------------------------------------------------------------------------
# 6. Génération de l'Inventory (Contrat d'interface)
# ------------------------------------------------------------------------------
resource "local_file" "inventory" {
  content = templatefile("${path.module}/inventory.tpl", {
    provider          = "azure"
    region            = var.location
    zone              = "none"
    jumpbox_public_ip = azurerm_public_ip.jumpbox_pip.ip_address
    server_public_ip  = azurerm_public_ip.server_pip.ip_address
    node_0_public_ip  = azurerm_public_ip.node_0_pip.ip_address
    node_1_public_ip  = azurerm_public_ip.node_1_pip.ip_address
    jumpbox_private_ip = "10.240.0.10"
    server_private_ip  = "10.240.0.11"
    node_0_private_ip  = "10.240.0.20"
    node_1_private_ip  = "10.240.0.21"
    pod_cidr          = var.pod_cidr
    service_cidr      = var.service_cidr
    cluster_dns       = var.cluster_dns
    ssh_user          = var.ssh_user
    ssh_key_path      = replace(var.ssh_public_key_path, ".pub", "")
  })
  filename = "${path.module}/../../inventories/azure/inventory.env"
}
