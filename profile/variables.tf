variable "cluster_name" {
    type = string
    description = "name of the cluster being created"
}

variable "cluster_location" {
    type = string
    description = "location of the cluster being created"
}

/*--------------------------------------------------variables project A--------------------------*/

variable "project_id_a" {
    type = string
    description = "project holding the network"
}

variable "vpc_name_a" {
    type = string
    description = "Name of the network this set of firewall rules applies to."
}

variable "subnet_region_a" {
    type = string
    description = "Name of the region where the cluster is implemented."
}

variable "subnet_name_a" {
    type = string
    description = "Name of the subnet where the cluster is implemented."
}

variable "repo_name" {
    type = string
    description = "App repo name"
    default = "bitbucket_cornel_stefan_pet-project"
}

variable "repo_url" {
    type = string
    description = "App repo name"
    default = "https://source.developers.google.com/p/$PROJECT_ID/r/bitbucket_cornel_stefan_pet-project"
}


variable "services" {
  type    = list
  default = [
    "sourcerepo.googleapis.com",
    "container.googleapis.com",
    "cloudbuild.googleapis.com",
    "clouddeploy.googleapis.com",
    "dns.googleapis.com",
    "iam.googleapis.com"
 ]
}

/*-------------------------------------------------variables for project b for vpn connections------------------------------*/
variable "project_id_b" {
    type = string
    description = "project holding the network"
}

variable "vpc_name_b" {
    type = string
    description = "Name of the network this set of firewall rules applies to."
}

variable "subnet_region_b" {
    type = string
    description = "Name of the region where the cluster is implemented."
}

variable "subnet_name_b" {
    type = string
    description = "Name of the subnet where the cluster is implemented."
}
/*---------------------------------------------------------------------------------------------------------------------------*/

variable "rules" {
  description = "List of custom rule definitions (refer to module variables file for syntax)."
  default     = []
  type = list(object({
    name                    = string
    description             = string
    direction               = string
    priority                = number
    ranges                  = list(string)
    source_tags             = list(string)
    source_service_accounts = list(string)
    target_tags             = list(string)
    target_service_accounts = list(string)
    allow = list(object({
      protocol = string
      ports    = list(string)
    }))
    deny = list(object({
      protocol = string
      ports    = list(string)
    }))
    log_config = object({
      metadata = string
    })
  }))
}
