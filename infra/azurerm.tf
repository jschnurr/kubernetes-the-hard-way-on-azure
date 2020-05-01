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
variable "prefix" {
  default = "kthw"
}
variable "master_vm_size" {
  default = "Standard_B1ms"
}
variable "master_vm_count" {
  type    = number
  default = 1

  # validation {
  #   condition = var.master_vm_count > 0 && var.master_vm_count < 6
  #   error_message = "The master vm count must be in the range - 1 to 5."
  # }
}
variable "worker_vm_size" {
  default = "Standard_B1ms"
}
variable "worker_vm_count" {
  type    = number
  default = 1

  # validation {
  #   condition = var.worker_vm_count > 0 && var.worker_vm_count < 10
  #   error_message = "The worker vm count must be in the range - 1 to 9."
  # }
}
variable "enable_health_probe" {
  type    = bool
  default = false
}
variable "enable_master_setup" {
  type    = bool
  default = false
}
variable "master_disk_size" {
  type    = number
  default = 32
}
variable "worker_disk_size" {
  type    = number
  default = 32
}


# initialise azure resource manager provider
provider "azurerm" {
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  version         = "=2.6.0"
  features {}
}

# single resource group
resource "azurerm_resource_group" "rg01" {
  name     = "${var.prefix}-${var.environment}-rg01"
  location = var.location

  tags = {
    managedby = "terraform"
  }
}

# single virtual network
resource "azurerm_virtual_network" "vnet01" {
  name                = "${var.prefix}-${var.environment}-vnet01"
  resource_group_name = azurerm_resource_group.rg01.name
  location            = azurerm_resource_group.rg01.location
  address_space       = ["10.240.0.0/24"]

  tags = {
    managedby = "terraform"
  }
}

# single subnet
resource "azurerm_subnet" "subnet01" {
  name                 = "${var.prefix}-${var.environment}-subnet01"
  resource_group_name  = azurerm_resource_group.rg01.name
  virtual_network_name = azurerm_virtual_network.vnet01.name
  address_prefix       = "10.240.0.0/24"
}

# network route table for free communication of pods b/w nodes
resource "azurerm_route_table" "rt01" {
  name                          = "${var.prefix}-${var.environment}-rt01"
  resource_group_name           = azurerm_resource_group.rg01.name
  location                      = azurerm_resource_group.rg01.location
  disable_bgp_route_propagation = false

  route {
    name                   = "workervm01"
    address_prefix         = "10.200.1.0/24"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = "10.240.0.21"
  }
  route {
    name                   = "workervm02"
    address_prefix         = "10.200.2.0/24"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = "10.240.0.22"
  }
  route {
    name                   = "workervm03"
    address_prefix         = "10.200.3.0/24"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = "10.240.0.23"
  }
  route {
    name                   = "workervm04"
    address_prefix         = "10.200.4.0/24"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = "10.240.0.24"
  }
  route {
    name                   = "workervm05"
    address_prefix         = "10.200.5.0/24"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = "10.240.0.25"
  }
  route {
    name                   = "workervm06"
    address_prefix         = "10.200.6.0/24"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = "10.240.0.26"
  }
  route {
    name                   = "workervm07"
    address_prefix         = "10.200.7.0/24"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = "10.240.0.27"
  }
  route {
    name                   = "workervm08"
    address_prefix         = "10.200.8.0/24"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = "10.240.0.28"
  }
  route {
    name                   = "workervm09"
    address_prefix         = "10.200.9.0/24"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = "10.240.0.29"
  }
}

# associate network route table to the subnet
resource "azurerm_subnet_route_table_association" "subnet01-rt01" {
  subnet_id      = azurerm_subnet.subnet01.id
  route_table_id = azurerm_route_table.rt01.id
}

# network security group (nsg) to act as firewall
resource "azurerm_network_security_group" "nsg01" {
  name                = "${var.prefix}-${var.environment}-nsg01"
  resource_group_name = azurerm_resource_group.rg01.name
  location            = azurerm_resource_group.rg01.location

  # ssh
  security_rule {
    name                       = "ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = "*"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "22"
  }

  # kube api server
  security_rule {
    name                       = "kubeapiserver"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = "*"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "6443"
  }

  security_rule {
    name                       = "icmp"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Icmp"
    source_address_prefix      = "*"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "*"
  }

  # web port
  security_rule {
    name                       = "web"
    priority                   = 400
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = "*"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "80"
  }

  # ssl web port
  security_rule {
    name                       = "ssl"
    priority                   = 500
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = "*"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "443"
  }

  # service of type NodePort
  security_rule {
    name                       = "nodeports"
    priority                   = 600
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = "*"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "30000-32767"
  }

  tags = {
    managedby = "terraform"
  }
}

# associate network security group (nsg) to the subnet
resource "azurerm_subnet_network_security_group_association" "subnet01-nsg01" {
  subnet_id                 = azurerm_subnet.subnet01.id
  network_security_group_id = azurerm_network_security_group.nsg01.id
}

# master nodes availability set
resource "azurerm_availability_set" "masteras01" {
  name                         = "${var.prefix}-${var.environment}-masteras01"
  resource_group_name          = azurerm_resource_group.rg01.name
  location                     = azurerm_resource_group.rg01.location
  platform_fault_domain_count  = 2
  platform_update_domain_count = 3

  tags = {
    managedby = "terraform"
  }
}

# master node - public ip address
resource "azurerm_public_ip" "masterpip" {
  name                = "${var.prefix}-${var.environment}-masterpip0${count.index + 1}"
  resource_group_name = azurerm_resource_group.rg01.name
  location            = azurerm_resource_group.rg01.location
  sku                 = "Basic"
  allocation_method   = "Static"
  domain_name_label   = "${var.prefix}-${var.environment}-mastervm0${count.index + 1}"

  count = var.master_vm_count

  tags = {
    managedby = "terraform"
  }
}

# master node - network interface card (nic)
resource "azurerm_network_interface" "masternic" {
  name                 = "${var.prefix}-${var.environment}-masternic0${count.index + 1}"
  resource_group_name  = azurerm_resource_group.rg01.name
  location             = azurerm_resource_group.rg01.location
  enable_ip_forwarding = true
  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.subnet01.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.240.0.1${count.index + 1}"
    public_ip_address_id          = azurerm_public_ip.masterpip[count.index].id
  }

  count = var.master_vm_count

  tags = {
    managedby = "terraform"
  }
}

# master node - virtual machine (vm)
resource "azurerm_linux_virtual_machine" "mastervm" {
  name                  = "${var.prefix}-${var.environment}-mastervm0${count.index + 1}"
  resource_group_name   = azurerm_resource_group.rg01.name
  location              = azurerm_resource_group.rg01.location
  size                  = var.master_vm_size
  availability_set_id   = azurerm_availability_set.masteras01.id
  admin_username        = "usr1"
  network_interface_ids = [azurerm_network_interface.masternic[count.index].id]

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  os_disk {
    name                 = "${var.prefix}-${var.environment}-masterdisk0${count.index + 1}"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = var.master_disk_size
  }

  admin_ssh_key {
    username   = "usr1"
    public_key = file(var.ssh_key_file)
  }

  count = var.master_vm_count

  tags = {
    managedby = "terraform"
  }
}


# worker node - public ip address
resource "azurerm_public_ip" "workerpip" {
  name                = "${var.prefix}-${var.environment}-workerpip0${count.index + 1}"
  resource_group_name = azurerm_resource_group.rg01.name
  location            = azurerm_resource_group.rg01.location
  sku                 = "Basic"
  allocation_method   = "Static"
  domain_name_label   = "${var.prefix}-${var.environment}-workervm0${count.index + 1}"

  count = var.worker_vm_count

  tags = {
    managedby = "terraform"
  }
}

# worker node - network interface card (nic)
resource "azurerm_network_interface" "workernic" {
  name                 = "${var.prefix}-${var.environment}-workernic0${count.index + 1}"
  resource_group_name  = azurerm_resource_group.rg01.name
  location             = azurerm_resource_group.rg01.location
  enable_ip_forwarding = true
  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.subnet01.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.240.0.2${count.index + 1}"
    public_ip_address_id          = azurerm_public_ip.workerpip[count.index].id
  }

  count = var.worker_vm_count

  tags = {
    managedby = "terraform"
  }
}

# worker node - virtual machine (vm)
resource "azurerm_linux_virtual_machine" "workervm" {
  name                  = "${var.prefix}-${var.environment}-workervm0${count.index + 1}"
  resource_group_name   = azurerm_resource_group.rg01.name
  location              = azurerm_resource_group.rg01.location
  size                  = var.worker_vm_size
  admin_username        = "usr1"
  network_interface_ids = [azurerm_network_interface.workernic[count.index].id]

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  os_disk {
    name                 = "${var.prefix}-${var.environment}-workerdisk0${count.index + 1}"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = var.worker_disk_size
  }

  admin_ssh_key {
    username   = "usr1"
    public_key = file(var.ssh_key_file)
  }

  count = var.worker_vm_count

  tags = {
    managedby = "terraform"
  }
}


# network load balancer - public ip address
resource "azurerm_public_ip" "lbpip01" {
  name                = "${var.prefix}-${var.environment}-lbpip01"
  resource_group_name = azurerm_resource_group.rg01.name
  location            = azurerm_resource_group.rg01.location
  sku                 = "Basic"
  allocation_method   = "Static"
  domain_name_label   = "${var.prefix}-${var.environment}-apiserver"

  tags = {
    managedby = "terraform"
  }
}

# network load balancer
resource "azurerm_lb" "lb01" {
  name                = "${var.prefix}-${var.environment}-lb01"
  resource_group_name = azurerm_resource_group.rg01.name
  location            = azurerm_resource_group.rg01.location
  sku                 = "Basic"

  frontend_ip_configuration {
    name                 = "${var.prefix}-${var.environment}-apiserver"
    public_ip_address_id = azurerm_public_ip.lbpip01.id
  }

  tags = {
    managedby = "terraform"
  }
}

# network load balancer - backend address pool
resource "azurerm_lb_backend_address_pool" "bap01" {
  name                = "${var.prefix}-${var.environment}-bap01"
  resource_group_name = azurerm_resource_group.rg01.name
  loadbalancer_id     = azurerm_lb.lb01.id
}

# network load balancer - associate network interface card of master nodes to backend address pool
resource "azurerm_network_interface_backend_address_pool_association" "bapa" {
  network_interface_id    = azurerm_network_interface.masternic[count.index].id
  ip_configuration_name   = "primary"
  backend_address_pool_id = azurerm_lb_backend_address_pool.bap01.id

  count = var.master_vm_count
}

# network load balancer - health probe
resource "azurerm_lb_probe" "lbp01" {
  name                = "${var.prefix}-${var.environment}-lbp01"
  resource_group_name = azurerm_resource_group.rg01.name
  loadbalancer_id     = azurerm_lb.lb01.id
  protocol            = "Http"
  request_path        = "/healthz"
  port                = 80
  interval_in_seconds = 10
}

# network load balancer - load balancing rule with health probe
resource "azurerm_lb_rule" "lbr01" {
  name                           = "${var.prefix}-${var.environment}-lbr01"
  resource_group_name            = azurerm_resource_group.rg01.name
  loadbalancer_id                = azurerm_lb.lb01.id
  frontend_ip_configuration_name = "${var.prefix}-${var.environment}-apiserver"
  protocol                       = "Tcp"
  frontend_port                  = "6443"
  backend_port                   = "6443"
  backend_address_pool_id        = azurerm_lb_backend_address_pool.bap01.id

  # attach health probe
  probe_id = azurerm_lb_probe.lbp01.id

  count      = var.enable_health_probe ? 1 : 0
  depends_on = [azurerm_lb_rule.lbr01noprobe]
}

# network load balancer - load balancing rule without health probe
resource "azurerm_lb_rule" "lbr01noprobe" {
  name                           = "${var.prefix}-${var.environment}-lbr01"
  resource_group_name            = azurerm_resource_group.rg01.name
  loadbalancer_id                = azurerm_lb.lb01.id
  frontend_ip_configuration_name = "${var.prefix}-${var.environment}-apiserver"
  protocol                       = "Tcp"
  frontend_port                  = "6443"
  backend_port                   = "6443"
  backend_address_pool_id        = azurerm_lb_backend_address_pool.bap01.id

  # un-attach health probe
  count = var.enable_health_probe ? 0 : 1
}

resource "null_resource" "setupmasternodes" {
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = "../scripts/setup-master-nodes.sh ${var.master_vm_count}"
  }

  count      = var.enable_master_setup ? 1 : 0
  depends_on = [azurerm_linux_virtual_machine.mastervm]
}
