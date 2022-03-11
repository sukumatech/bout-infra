provider "google" {
    project = var.project_id_a
    region = var.subnet_region_a
}


data "google_client_config" "default" {}

provider "kubernetes" {
    host                   = "https://${module.gke.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(module.gke.ca_certificate)
    //config_path    = "~/.kube/config"
}