variable "subscription_id" {
  default = ""
}
variable "tenant_id" {
  default = ""
}
variable "client_id" {
  default = ""
}
variable "client_secret" {
  default = ""
}
variable "environment" {
  default = ""
}
variable "location" {
  default = ""
}
variable "ssh_key_file" {
  default = ""
}

# initialise azure resource manager provider
provider "azurerm" {
  subscription_id = var.subscription_id
  tenant_id = var.tenant_id
  client_id = var.client_id
  client_secret = var.client_secret
  features {}
}

# single resource group
resource "azurerm_resource_group" "rg01" {
  name = "kthw-${var.environment}-rg01"
  location = var.location

  tags = {
    managedby = "terraform"
  }
}

# single virtual network
resource "azurerm_virtual_network" "vnet01" {
  name = "kthw-${var.environment}-vnet01"
  resource_group_name = azurerm_resource_group.rg01.name
  location = azurerm_resource_group.rg01.location
  address_space = ["10.240.0.0/24"]

  tags = {
    managedby = "terraform"
  }
}

# single subnet
resource "azurerm_subnet" "subnet01" {
  name = "kthw-${var.environment}-subnet01"
  resource_group_name = azurerm_resource_group.rg01.name
  virtual_network_name = azurerm_virtual_network.vnet01.name
  address_prefix = "10.240.0.0/24"
}

# network route table for free communication of pods b/w nodes
resource "azurerm_route_table" "rt01" {
  name = "poc-kube-rt01"
  resource_group_name = azurerm_resource_group.rg01.name
  location = azurerm_resource_group.rg01.location
  disable_bgp_route_propagation = false

  route {
    name           = "workervm01"
    address_prefix = "10.200.1.0/24"
    next_hop_type  = "VirtualAppliance"
    next_hop_in_ip_address = "10.240.0.20"
  }

  route {
    name           = "workervm02"
    address_prefix = "10.200.2.0/24"
    next_hop_type  = "VirtualAppliance"
    next_hop_in_ip_address = "10.240.0.21"
  }

  route {
    name           = "workervm03"
    address_prefix = "10.200.3.0/24"
    next_hop_type  = "VirtualAppliance"
    next_hop_in_ip_address = "10.240.0.22"
  }
}

# associate network route table to the subnet
resource "azurerm_subnet_route_table_association" "subnet01-rt01" {
  subnet_id = azurerm_subnet.subnet01.id
  route_table_id = azurerm_route_table.rt01.id
}

# network security group (nsg) to act as firewall
resource "azurerm_network_security_group" "nsg01" {
  name = "kthw-${var.environment}-nsg01"
  resource_group_name = azurerm_resource_group.rg01.name
  location = azurerm_resource_group.rg01.location

  # ssh
  security_rule {
    name = "ssh"
    priority = 100
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_address_prefix = "*"
    source_port_range = "*"
    destination_address_prefix = "*"
    destination_port_range = "22"
  }

  # kube api server
  security_rule {
    name = "kubeapiserver"
    priority = 200
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_address_prefix = "*"
    source_port_range = "*"
    destination_address_prefix = "*"
    destination_port_range = "6443"
  }

  security_rule {
    name = "icmp"
    priority = 300
    direction = "Inbound"
    access = "Allow"
    protocol = "Icmp"
    source_address_prefix = "*"
    source_port_range = "*"
    destination_address_prefix = "*"
    destination_port_range = "*"
  }

  # web port
  security_rule {
    name = "web"
    priority = 400
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_address_prefix = "*"
    source_port_range = "*"
    destination_address_prefix = "*"
    destination_port_range = "80"
  }

  # service of type NodePort
  security_rule {
    name = "nodeports"
    priority = 500
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_address_prefix = "*"
    source_port_range = "*"
    destination_address_prefix = "*"
    destination_port_range = "30000-32767"
  }

  tags = {
    managedby = "terraform"
  }
}

# associate network security group (nsg) to the subnet
resource "azurerm_subnet_network_security_group_association" "subnet01-nsg01" {
  subnet_id = azurerm_subnet.subnet01.id
  network_security_group_id = azurerm_network_security_group.nsg01.id
}

# master nodes availability set
resource "azurerm_availability_set" "masteras01" {
  name = "kthw-${var.environment}-masteras01"
  resource_group_name = azurerm_resource_group.rg01.name
  location = azurerm_resource_group.rg01.location
  platform_fault_domain_count = 2
  platform_update_domain_count = 3

  tags = {
    managedby = "terraform"
  }
}

# master node - public ip address
resource "azurerm_public_ip" "masterpip" {
  name = "kthw-${var.environment}-masterpip0${count.index + 1}"
  resource_group_name = azurerm_resource_group.rg01.name
  location = azurerm_resource_group.rg01.location
  sku = "Basic"
  allocation_method = "Static"
  domain_name_label = "kthw-${var.environment}-mastervm0${count.index + 1}"

  count = 2

  tags = {
    managedby = "terraform"
  }
}

# master node - network interface card (nic)
resource "azurerm_network_interface" "masternic" {
  name = "kthw-${var.environment}-masternic0${count.index + 1}"
  resource_group_name = azurerm_resource_group.rg01.name
  location = azurerm_resource_group.rg01.location
  enable_ip_forwarding = true
  ip_configuration {
    name = "primary"
    subnet_id = azurerm_subnet.subnet01.id
    private_ip_address_allocation = "Static"
    private_ip_address = "10.240.0.1${count.index + 1}"
    public_ip_address_id = azurerm_public_ip.masterpip[count.index].id
  }

  count = 2

  tags = {
    managedby = "terraform"
  }
}

# master node - virtual machine (vm)
resource "azurerm_linux_virtual_machine" "mastervm" {
  name = "kthw-${var.environment}-mastervm0${count.index + 1}"
  resource_group_name = azurerm_resource_group.rg01.name
  location = azurerm_resource_group.rg01.location
  size = "Standard_B1ms"
  availability_set_id = azurerm_availability_set.masteras01.id
  admin_username ="ankur"
  network_interface_ids = [azurerm_network_interface.masternic[count.index].id]

  source_image_reference {
    publisher = "Canonical"
    offer = "UbuntuServer"
    sku = "18.04-LTS"
    version = "latest"
  }

  os_disk {
    name = "kthw-${var.environment}-masterdisk0${count.index + 1}"
    caching = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb = "32"
  }

  admin_ssh_key {
    username = "ankur"
    public_key = file(var.ssh_key_file)
  }

  count = 2

  tags = {
    managedby = "terraform"
  }
}


# worker vm - public ip address
resource "azurerm_public_ip" "workerpip" {
  name = "kthw-${var.environment}-workerpip0${count.index + 1}"
  resource_group_name = azurerm_resource_group.rg01.name
  location = azurerm_resource_group.rg01.location
  sku = "Basic"
  allocation_method = "Static"
  domain_name_label = "kthw-${var.environment}-workervm0${count.index + 1}"

  count = 2

  tags = {
    managedby = "terraform"
  }
}

# worker vm - network interface card (nic)
resource "azurerm_network_interface" "workernic" {
  name = "kthw-${var.environment}-workernic0${count.index + 1}"
  resource_group_name = azurerm_resource_group.rg01.name
  location = azurerm_resource_group.rg01.location
  enable_ip_forwarding = true
  ip_configuration {
    name = "primary"
    subnet_id = azurerm_subnet.subnet01.id
    private_ip_address_allocation = "Static"
    private_ip_address = "10.240.0.2${count.index + 1}"
    public_ip_address_id = azurerm_public_ip.workerpip[count.index].id
  }

  count = 2

  tags = {
    managedby = "terraform"
  }
}

# worker vm - virtual machine (vm)
resource "azurerm_linux_virtual_machine" "workervm" {
  name = "kthw-${var.environment}-workervm0${count.index + 1}"
  resource_group_name = azurerm_resource_group.rg01.name
  location = azurerm_resource_group.rg01.location
  size = "Standard_B1s"
  admin_username ="ankur"
  network_interface_ids = [azurerm_network_interface.workernic[count.index].id]

  source_image_reference {
    publisher = "Canonical"
    offer = "UbuntuServer"
    sku = "18.04-LTS"
    version = "latest"
  }

  os_disk {
    name = "kthw-${var.environment}-workerdisk0${count.index + 1}"
    caching = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb = "32"
  }

  admin_ssh_key {
    username = "ankur"
    public_key = file(var.ssh_key_file)
  }

  count = 2

  tags = {
    managedby = "terraform"
  }
}


# network load balancer - public ip address
resource "azurerm_public_ip" "lbpip01" {
  name = "kthw-${var.environment}-lbpip01"
  resource_group_name = azurerm_resource_group.rg01.name
  location = azurerm_resource_group.rg01.location
  sku = "Basic"
  allocation_method = "Static"
  domain_name_label = "kthw-${var.environment}-apiserver"

  tags = {
    managedby = "terraform"
  }
}

# network load balancer
resource "azurerm_lb" "lb01" {
  name = "kthw-${var.environment}-lb01"
  resource_group_name = azurerm_resource_group.rg01.name
  location = azurerm_resource_group.rg01.location
  sku = "Basic"

  frontend_ip_configuration {
    name = "kthw-${var.environment}-apiserver"
    public_ip_address_id = azurerm_public_ip.lbpip01.id
  }

  tags = {
    managedby = "terraform"
  }
}

# network load balancer - backend address pool
resource "azurerm_lb_backend_address_pool" "bap01" {
  name = "kthw-${var.environment}-bap01"
  resource_group_name = azurerm_resource_group.rg01.name
  loadbalancer_id = azurerm_lb.lb01.id
}

# network load balancer - associate network interface card of master node 01 to backend address pool
resource "azurerm_network_interface_backend_address_pool_association" "bapa01" {
  network_interface_id = azurerm_network_interface.masternic[0].id
  ip_configuration_name = "primary"
  backend_address_pool_id = azurerm_lb_backend_address_pool.bap01.id
}

# network load balancer - associate network interface card of master node 02 to backend address pool
resource "azurerm_network_interface_backend_address_pool_association" "bapa02" {
  network_interface_id = azurerm_network_interface.masternic[1].id
  ip_configuration_name = "primary"
  backend_address_pool_id = azurerm_lb_backend_address_pool.bap01.id
}

# network load balancer - health probe
resource "azurerm_lb_probe" "lbp01" {
  name = "kthw-${var.environment}-lbp01"
  resource_group_name = azurerm_resource_group.rg01.name
  loadbalancer_id = azurerm_lb.lb01.id
  protocol = "Http"
  request_path = "/healthz"
  port = 80
  interval_in_seconds = 10
}

# network load balancer - load balancing rule
resource "azurerm_lb_rule" "lbr01" {
  name = "kthw-${var.environment}-lbr01"
  resource_group_name = azurerm_resource_group.rg01.name
  loadbalancer_id = azurerm_lb.lb01.id
  frontend_ip_configuration_name = "kthw-${var.environment}-apiserver"
  protocol = "Tcp"
  frontend_port = "6443"
  backend_port = "6443"
  backend_address_pool_id = azurerm_lb_backend_address_pool.bap01.id
  probe_id = azurerm_lb_probe.lbp01.id
}