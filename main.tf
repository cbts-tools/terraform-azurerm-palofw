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

# Read subnet data to get subnet id
data "azurerm_subnet" "mgmt" {
  name                 = var.pfw_mgmt_subnet
  virtual_network_name = var.pfw_vnet_name
  resource_group_name  = var.network_rg_name
}

# Read subnet data to get subnet id
data "azurerm_subnet" "priv" {
  name                 = var.pfw_priv_subnet
  virtual_network_name = var.pfw_vnet_name
  resource_group_name  = var.network_rg_name
}

# Random string to ensure storage account has unique name
resource "random_string" "unique_id" {
  length  = 4
  special = false
  upper   = false
}

# This module uploads the bootstrap files that are called by the VMs
module "pfw_bootstrap" {
  source  = "PaloAltoNetworks/vmseries-modules/azurerm//modules/bootstrap"
  version = "0.5.0"

  create_storage_account = true
  storage_account_name   = "stpfw${random_string.unique_id.result}"
  storage_share_name     = "fwbootstrap"
  resource_group_name    = data.azurerm_resource_group.pfwrg.name
  location               = data.azurerm_resource_group.pfwrg.location
  tags                   = var.tags
  files                  = var.files
}

# Global Load Balance resource with private IP frontend
resource "azurerm_lb" "gwlb" {
  name                = "lbg-pfw"
  resource_group_name = data.azurerm_resource_group.pfwrg.name
  location            = data.azurerm_resource_group.pfwrg.location
  sku                 = "Gateway"
  tags                = var.tags

  frontend_ip_configuration {
    name               = "FEIpconfig1"
    subnet_id          = data.azurerm_subnet.priv.id
    private_ip_address = var.gwlb_priv_ip
  }
}

# Load balancer backend ool to add FW VMs to
resource "azurerm_lb_backend_address_pool" "pfw_pool" {
  loadbalancer_id = azurerm_lb.gwlb.id
  name            = "BackEndAddressPool"

# These are require for chaning to the firewalls
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

# Default health probe
resource "azurerm_lb_probe" "pfw_health" {
  loadbalancer_id = azurerm_lb.gwlb.id
  name            = "sec_http_health_probe"
  port            = 80
}

# Open rule for the chained firewall traffic to pass
resource "azurerm_lb_rule" "pfw_all" {
  name                           = "LBRule1"
  loadbalancer_id                = azurerm_lb.gwlb.id
  frontend_ip_configuration_name = "FEIpconfig1"
  protocol                       = "All"
  frontend_port                  = 0
  backend_port                   = 0
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.pfw_pool.id, ]
  probe_id                       = azurerm_lb_probe.pfw_health.id
}

# This will create public IPs for the firewalls if local Panorama is not used
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

# This deploys the FW VM(s), connects them to the GWLB and bootstraps them
module "pfw_vm" {
  source              = "PaloAltoNetworks/vmseries-modules/azurerm//modules/vmseries"
  version             = "0.5.0"
  count               = var.numfws
  resource_group_name = data.azurerm_resource_group.pfwrg.name
  location            = data.azurerm_resource_group.pfwrg.location
  name                = "vm-pfw-${format("%02d", count.index + 1)}"
  username            = "panadmin"
  password            = random_password.adminpass.result
  avzone              = count.index + 1
  img_sku             = var.os_sku
  img_version         = var.os_version
  tags                = var.tags

  interfaces = [{
    name                 = "nic-pfw-${format("%02d", count.index + 1)}-mgmt"
    subnet_id            = data.azurerm_subnet.mgmt.id
    public_ip_address_id = var.use_panorama ? null : azurerm_public_ip.pipfw[count.index].id
    },
    {
      name                 = "nic-pfw-${format("%02d", count.index + 1)}-data"
      subnet_id            = data.azurerm_subnet.priv.id
      enable_ip_forwarding = true
      enable_backend_pool  = true
      lb_backend_pool_id   = azurerm_lb_backend_address_pool.pfw_pool.id
  }]

  bootstrap_options = "storage-account=${module.pfw_bootstrap.storage_account.name};access-key=${module.pfw_bootstrap.storage_account.primary_access_key};file-share=${module.pfw_bootstrap.storage_share.name};share-directory=None"
}