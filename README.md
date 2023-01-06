# Introduction 
Palo Alto FW w/ Azure Gateway Load Balancer module creates all required and associted resources other than the vnets, subnets, NSGs, etc.

# Usage
You must have executed one of these, depending on your choice, in advance:
```
az vm image terms accept --publisher paloaltonetworks --offer vmseries-flex --plan byol --subscription <MySubscription>
az vm image terms accept --publisher paloaltonetworks --offer vmseries-flex --plan bundle1 --subscription <MySubscription>
az vm image terms accept --publisher paloaltonetworks --offer vmseries-flex --plan bundle2 --subscription <MySubscription>
```
You will also need to copy the 'files' folder from this repo to your root module and pass the files variable.

# Required providers
```
provider "azurerm" {
  features {}
  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id
}
```

# Variables
## Required Variables
- files
- gwlb_priv_ip
- network_rg_name
- pfw_mgmt_subnet
- pfw_priv_subnet
- pfw_rg_name
- pfw_vnet_name

## Optional Variables
- numfws
- os_sku
- os_version
- tags
- use_panorama

# Sample module code:
```
module "pfw" {
  source = "github.com/cbts-tools/terraform-palofw-azurerm?ref=v1.0.0"

  pfw_rg_name     = "rg-panfw-sec"
  network_rg_name = "rg-panfw-sec"
  files           = local.files
  numfws          = 2
  gwlb_priv_ip    = "10.0.0.4"
  pfw_mgmt_subnet = "Subnet-mgmt"
  pfw_priv_subnet = "Subnet-data"
  pfw_vnet_name   = "secVnet"
  os_sku          = "bundle2"
  tags            = local.tags
}
```

# Sample local variable with a hub and spoke vnets and multiple snets each.
```
locals {
  tags = {
    environment    = "dev"
  }

  files = {
    "files/init-cfg.txt"  = "config/init-cfg.txt"
    "files/bootstrap.xml" = "config/bootstrap.xml"
  }
}
```