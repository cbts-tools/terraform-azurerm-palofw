variable "pfw_rg_name" {
  description = "Name of the resource group the firewall resources will be created in."
  type = string
}

variable "stor_rg_name" {
  description = "Name of the resource group for the bootstrap files storage account."
  type = string
}

variable "network_rg_name" {
  description = "Name of the resource group for network connectivity resources."
  type = string
}

variable "use_panorama" {
  description = "Bool to use or not Panorama for management"
  type = bool
  default = false
}

variable "numfws" {
  description = "Number of FWs to create"
  type = number
  default = 1
}

variable "gwlb_priv_ip" {
  description = "Private IP to use for the Gateway Load Balancer Frontend."
}

variable "pfw_mgmt_subnet" {
  description = "Name of the management subnet for the firewall."
  type = string
}

variable "pfw_priv_subnet" {
  description = "Name of the data subnet for the firewall and gwlb."
  type = string
}

variable "pfw_vnet_name" {
  description = "Name of the vnet for firewall and gwlb subnets."
  type = string
}

variable "tags" {
  description = "Map of tags needed for the resouces"
  type = map
  default     = null
}