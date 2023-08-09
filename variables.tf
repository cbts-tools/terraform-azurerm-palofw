variable "pfw_rg_name" {
  description = "Name of the resource group the firewall resources will be created in."
  type        = string
}

variable "network_rg_name" {
  description = "Name of the resource group for network connectivity resources."
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones for the region of the resource group of the firewalls."
  type        = list(string)
  default     = ["1", "2", "3"]
}

variable "files" {
  description = <<-EOF
  Map of all files to copy to bucket. The keys are local paths, the values are remote paths.
  Always use slash `/` as directory separator (unix-like), not the backslash `\`.
  Example: 
  ```
  files = {
    "dir/my.txt" = "config/init-cfg.txt"
  }
  ```
  EOF
  type        = map(string)
}

variable "os_sku" {
  description = <<-EOF
  This is the billing option:
  byol = Bring Your Own License. Use a license acquired separately.
  bundle1 = Pay As You Go. Inlcudes Threat Prevention and Premium Support.
  bundle2 = Pay As You Go. Includes URL Filtering, WildFire, GlobalProtect, DNS Security, and Premium Support.
  EOF
  type        = string
  default     = "byol"
}

variable "os_version" {
  description = "This is the PAN OS version that should be deployed. Must ensure this is an available version to Azure Marketplace."
  type        = string
  default     = "10.1.4"
}

variable "use_panorama" {
  description = "Bool to use or not Panorama for management"
  type        = bool
  default     = false
}

variable "numfws" {
  description = "Number of FWs to create"
  type        = number
  default     = 1
}

variable "gwlb_priv_ip" {
  description = "Private IP to use for the Gateway Load Balancer Frontend."
}

variable "pfw_mgmt_subnet" {
  description = "Name of the management subnet for the firewall."
  type        = string
}

variable "pfw_priv_subnet" {
  description = "Name of the data subnet for the firewall and gwlb."
  type        = string
}

variable "pfw_vnet_name" {
  description = "Name of the vnet for firewall and gwlb subnets."
  type        = string
}

variable "tags" {
  description = "Map of tags needed for the resouces"
  type        = map(any)
  default     = null
}