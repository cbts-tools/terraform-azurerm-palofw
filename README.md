# Introduction 
Palo Alto FW w/ Azure Gateway Load Balancer module creates all required and associted resources.

# Usage
Three azurerum providers will need to be called in the template, one with an alias of hub.

Must have executed this in advance:
```
az vm image terms accept --publisher paloaltonetworks --offer vmseries-flex --plan bundle2 --subscription MySubscription
```

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
- resource_group_name
- network_info

## Optional Variables
- hubvnet_name
- hubvnet_id
- tags

# Sample hub/spoke module code:
```
module "hub-vnet" {
  source              = "github.com/cbts-tools/terraform-network-azurerm?ref=1.1.0"
  network_info        = local.network_info.hub_vnets
  resource_group_name = azurerm_resource_group.network.name
  tags                = local.tags
  providers = {
    azurerm = azurerm
  }

  depends_on = [
    azurerm_resource_group.network
  ]
}

# Creating a spoke vnet also creates the two-way vnet peering with the hub vnet
module "spoke-vnets" {
  source              = "github.com/cbts-tools/terraform-network-azurerm?ref=1.1.0"
  for_each            = local.network_info.spoke_vnets
  network_info        = each.value
  hubvnet_name        = module.hub-vnet.vnet_name
  hubvnet_id          = module.hub-vnet.vnet_id
  resource_group_name = azurerm_resource_group.network.name
  tags                = local.tags

  providers = {
    azurerm = azurerm
  }

  depends_on = [
    module.hub-vnet
  ]
}
```

# Sample local variable with a hub and spoke vnets and multiple snets each.
```
locals {
  network_info = {
    hub_vnets = {
      hub1 = {
        name          = "vnet-hub"
        address_space = ["10.0.0.0/17"]
        dns_servers   = []
        subnets = {
          gateway = {
            name               = "GatewaySubnet"
            address_prefixes   = ["10.0.0.0/27"]
            service_endpoints  = []
            set_nsg            = false
            # These must remain empty for AzureBastionSubnet, FirewallSubnet, and GatewaySubnet
            nsg_inbound_rules  = []
            # These must remain empty for AzureBastionSubnet, FirewallSubnet, and GatewaySubnet
            nsg_outbound_rules = []
            service            = ""
          }
          bastion = {
            name               = "AzureBastionSubnet"
            address_prefixes   = ["10.0.0.64/26"]
            service_endpoints  = []
            set_nsg            = false
            # These must remain empty for AzureBastionSubnet, FirewallSubnet, and GatewaySubnet
            nsg_inbound_rules  = []
            # These must remain empty for AzureBastionSubnet, FirewallSubnet, and GatewaySubnet
            nsg_outbound_rules = []
            service            = ""
          }
          public = {
            name               = "snet-hub1-pub"
            address_prefixes   = ["10.0.1.0/24"]
            service_endpoints  = []
            set_nsg            = true
            # [name, priority, direction, access, protocol, destination_port_range, source_address_prefix, destination_address_prefix]
            # To use defaults, use "" without adding any values.
            nsg_inbound_rules  = []
            # [name, priority, direction, access, protocol, destination_port_range, source_address_prefix, destination_address_prefix]
            # To use defaults, use "" without adding any values.
            nsg_outbound_rules = []
            service            = ""
          }
          private = {
            name               = "snet-hub1-priv"
            address_prefixes   = ["10.0.2.0/24"]
            service_endpoints  = []
            set_nsg            = true
            # [name, priority, direction, access, protocol, destination_port_range, source_address_prefix, destination_address_prefix]
            # To use defaults, use "" without adding any values.
            nsg_inbound_rules  = []
            # [name, priority, direction, access, protocol, destination_port_range, source_address_prefix, destination_address_prefix]
            # To use defaults, use "" without adding any values.
            nsg_outbound_rules = []
            service            = ""
          }
        }
      }
    }
    spoke_vnets = {
      spoke1 = {
        name          = "vnet-spoke1"
        address_space = ["10.1.0.0/24"]
        dns_servers   = []
        subnets = {
          palo-pan-mgt = {
            name               = "snet-spoke1-subnet"
            address_prefixes   = ["10.1.0.0/24"]
            service_endpoints  = []
            set_nsg            = true
            # [name, priority, direction, access, protocol, destination_port_range, source_address_prefix, destination_address_prefix]
            # To use defaults, use "" without adding any values.
            nsg_inbound_rules  = []
            # [name, priority, direction, access, protocol, destination_port_range, source_address_prefix, destination_address_prefix]
            # To use defaults, use "" without adding any values.
            nsg_outbound_rules = []
            service            = ""
          }
        }
      }
  }
}
```