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
  source = "PaloAltoNetworks/vmseries-modules/azurerm//modules/bootstrap"

  create_storage_account = true
  name                   = "stpfw${random_string.unique_id.result}"
  storage_share_name     = "fwbootstrap"
  resource_group_name    = data.azurerm_resource_group.pfwrg.name
  location               = var.pfw_location
  tags                   = var.tags
  files                  = var.files
  storage_acl            = false
}

# Gateway Load Balancers
module "gwlb" {
  source   = "PaloAltoNetworks/vmseries-modules/azurerm//modules/gwlb"

  name                = "lbg-pfw"
  resource_group_name = data.azurerm_resource_group.pfwrg.name
  location            = var.pfw_location

  health_probe = {
    port = 80
  }

  frontend_ip_config = {
    name                          = "FEIpconfig1"
    private_ip_address            = var.gwlb_priv_ip
    subnet_id                     = data.azurerm_subnet.priv.id
  }

  tags = var.tags
}

# Generate random password
resource "random_password" "adminpass" {
  length           = 16
  special          = true
  override_special = "_%@"
}

# This deploys the FW VM(s), connects them to the GWLB and bootstraps them
module "pfw_vm" {
  source = "PaloAltoNetworks/vmseries-modules/azurerm//modules/vmseries"

  count               = var.numfws
  resource_group_name = data.azurerm_resource_group.pfwrg.name
  location            = var.pfw_location
  name                = "vm-pfw-${format("%02d", count.index + 1)}"
  username            = "panadmin"
  password            = random_password.adminpass.result
  enable_zones        = var.availability_zones == [""] ? false : true
  avzone              = var.availability_zones == [""] ? null : element(var.availability_zones, (count.index))
  vm_size             = var.custom_vm_size
  img_sku             = var.os_sku
  img_version         = var.os_version
  tags                = var.tags

  interfaces = [{
    name             = "nic-pfw-${format("%02d", count.index + 1)}-mgmt"
    subnet_id        = data.azurerm_subnet.mgmt.id
    create_public_ip = true
    public_ip_name   = var.use_panorama ? null : azurerm_public_ip.pipfw[count.index].name
    },
    {
      name                 = "nic-pfw-${format("%02d", count.index + 1)}-data"
      subnet_id            = data.azurerm_subnet.priv.id
      enable_ip_forwarding = true
      enable_backend_pool  = true
      lb_backend_pool_id   = module.gwlb.backend_pool_ids["ext-int"]
  }]

  bootstrap_options = "storage-account=${module.pfw_bootstrap.storage_account.name};access-key=${module.pfw_bootstrap.storage_account.primary_access_key};file-share=${module.pfw_bootstrap.storage_share.name};share-directory=None"
}