# This block specifies the required providers and the required versions
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.36.0"
    }
  }
}

# Read resource group data for location
data "azurerm_resource_group" "pfwrg" {
  name = var.pfw_rg_name
}

data "azurerm_resource_group" "storrg" {
  name = var.stor_rg_name
}

data "azurerm_subnet" "mgmt" {
  name  = var.pfw_mgmt_subnet
  virtual_network_name = var.pfw_vnet_name
  resource_group_name  = var.network_rg_name
}

data "azurerm_subnet" "priv" {
  name  = var.pfw_priv_subnet
  virtual_network_name = var.pfw_vnet_name
  resource_group_name  = var.network_rg_name
}

resource "random_string" "unique_id" {
  length = 4
  special = false
  upper = false
}

module "pfw_bootstrap" {
  source  = "PaloAltoNetworks/vmseries-modules/azurerm//modules/bootstrap"
  version = "0.5.0"

  create_storage_account = true
  storage_account_name = "stpfw${random_string.unique_id.result}"
  storage_share_name   = "fwbootstrap"
  resource_group_name  = data.azurerm_resource_group.storrg.name
  location             = data.azurerm_resource_group.storrg.location

  files = {
    "files/init-cfg.txt"  = "config/init-cfg.txt"
    "files/bootstrap.xml" = "config/bootstrap.xml"
  }
}

resource "azurerm_lb" "gwlb" {
  name                = "lbg-pfw"
  resource_group_name = data.azurerm_resource_group.pfwrg.name
  location            = data.azurerm_resource_group.pfwrg.location
  sku                 = "Gateway"

  frontend_ip_configuration {
    name               = "FEIpconfig1"
    subnet_id          = data.azurerm_subnet.priv.id
    private_ip_address = var.gwlb_priv_ip
  }
}

resource "azurerm_lb_backend_address_pool" "pfw_pool" {
  loadbalancer_id = azurerm_lb.gwlb.id
  name            = "BackEndAddressPool"

  tunnel_interface {
    identifier = 800
    type       = "Internal"
    protocol   = "VXLAN"
    port       = 2000
  }

  tunnel_interface {
    identifier = 801
    type       = "External"
    protocol   = "VXLAN"
    port       = 2001
  }
}

resource "azurerm_lb_probe" "pfw_health" {
  loadbalancer_id = azurerm_lb.gwlb.id
  name            = "sec_http_health_probe"
  port            = 80
}

resource "azurerm_lb_rule" "pfw_all" {
  name                           = "LBRule1"
  loadbalancer_id                = azurerm_lb.gwlb.id
  frontend_ip_configuration_name = "FEIpconfig1"
  protocol                       = "All"
  frontend_port                  = 0
  backend_port                   = 0
  backend_address_pool_ids       = azurerm_lb_backend_address_pool.pfw_pool.id
}

resource "azurerm_public_ip" "pipfw" {
  count               = var.use_panorama ? 0 : var.numfws
  name                = "pip-vm-pfw-${format("%02d", count.index + 1)}"
  resource_group_name = data.azurerm_resource_group.pfwrg.name
  location            = data.azurerm_resource_group.pfwrg.location
  sku                 = "Standard"
  allocation_method   = "Static"
  tags                = var.tags
}

# Generate random password
resource "random_password" "adminpass" {
  length           = 16
  special          = true
  override_special = "_%@"
}

module "pfw_vm" {
  source              = "PaloAltoNetworks/vmseries-modules/azurerm//modules/vmseries"
  version             = "0.5.0"
  count               = var.numfws
  resource_group_name = data.azurerm_resource_group.pfwrg.name
  location            = data.azurerm_resource_group.pfwrg.location
  name                = "vm-pfw-${format("%02d", count.index + 1)}"
  username            = "panadmin"
  password            = random_password.adminpass.result
  avzone              = "${count.index + 1}"
  img_version         = "10.1.4"
  tags                = var.tags

  interfaces  = [{
      name = "fw-mgmt"
      subnet_id = data.azurerm_subnet.mgmt.id
      public_ip_address_id = var.use_panorama ? null : azurerm_public_ip.pipfw[count.index].id
    },
    {
      name = "fw-data"
      subnet_id = data.azurerm_subnet.priv.id
      enable_ip_forwarding = true
      enable_backend_pool = true
      lb_backend_pool_id = azurerm_lb_backend_address_pool.pfw_pool.id
    }]
}