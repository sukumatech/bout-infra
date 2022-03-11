# ---------------------------------------------------------------------------------------------------------------------
# networking
# ---------------------------------------------------------------------------------------------------------------------

//-------------- project A create Network ------------
module "vpc-a" {
    source  = "terraform-google-modules/network/google"
    version = "~> 4.0"

    project_id   = var.project_id_a
    network_name = var.vpc_name_a
    routing_mode = "GLOBAL"

    subnets = [
        {
            subnet_name           = var.subnet_name_a
            subnet_ip             = "10.1.0.0/16"
            subnet_region         = var.subnet_region_a
        },
    ]

    secondary_ranges = {
    (var.subnet_name_a) = [
      {
        range_name    = "${var.subnet_name_a}-pods"
        ip_cidr_range = "192.168.1.0/24"
      },
      {
        range_name    = "${var.subnet_name_a}-services"
        ip_cidr_range = "192.168.2.0/24"
      },
    ]
    }
}

/*-----------------second project network and subnets-----------------------*/

module "vpc-b" {
    source  = "terraform-google-modules/network/google"
    version = "~> 4.0"

    project_id   = var.project_id_b
    network_name = var.vpc_name_b
    routing_mode = "GLOBAL"

    subnets = [
        {
            subnet_name           = var.subnet_name_b
            subnet_ip             = "10.2.0.0/16"
            subnet_region         = var.subnet_region_b
        },
    ]
}


# ---------------------------------------------------------------------------------------------------------------------
# firewall rules
# ---------------------------------------------------------------------------------------------------------------------

module "firewall_rules-a" {
  source       = "terraform-google-modules/network/google//modules/firewall-rules"
  project_id   = var.project_id_a
  network_name = module.vpc-a.network_name

  rules = [{
    name                    = "allow-projectb-ingress"
    description             = null
    direction               = "INGRESS"
    priority                = null
    ranges                  = ["0.0.0.0/0"]
    source_tags             = null
    source_service_accounts = null
    target_tags             = null
    target_service_accounts = null
    allow = [{
      protocol = "tcp"
      ports    = ["22"]
    }]
    deny = []
    log_config = {
      metadata = "INCLUDE_ALL_METADATA"
    }
  }]
}

module "firewall_rules-b" {
  source       = "terraform-google-modules/network/google//modules/firewall-rules"
  project_id   = var.project_id_b
  network_name = module.vpc-b.network_name

  rules = [{
    name                    = "allow-projecta-ingress"
    description             = null
    direction               = "INGRESS"
    priority                = null
    ranges                  = ["0.0.0.0/0"]
    source_tags             = null
    source_service_accounts = null
    target_tags             = null
    target_service_accounts = null
    allow = [{
      protocol = "tcp"
      ports    = ["22"]
    }]
    deny = []
    log_config = {
      metadata = "INCLUDE_ALL_METADATA"
    }
  }]
}

# ---------------------------------------------------------------------------------------------------------------------
# vpn
# ---------------------------------------------------------------------------------------------------------------------


module "vpn_ha-1" {
  source  = "terraform-google-modules/vpn/google//modules/vpn_ha"
  version = "~> 1.3.0"
  project_id  = var.project_id_b
  region  = var.subnet_region_b
  network         = module.vpc-b.network_name
  name            = "netb-to-neta"
  peer_gcp_gateway = module.vpn_ha-2.self_link
  router_asn = 64514
  tunnels = {
    remote-0 = {
      bgp_peer = {
        address = "169.254.1.1"
        asn     = 64513
      }
      bgp_peer_options  = null
      bgp_session_range = "169.254.1.2/30"
      ike_version       = 2
      vpn_gateway_interface = 0
      peer_external_gateway_interface = null
      shared_secret     = ""
    }
    remote-1 = {
      bgp_peer = {
        address = "169.254.2.1"
        asn     = 64513
      }
      bgp_peer_options  = null
      bgp_session_range = "169.254.2.2/30"
      ike_version       = 2
      vpn_gateway_interface = 1
      peer_external_gateway_interface = null
      shared_secret     = ""
    }
  }
}

module "vpn_ha-2" {
  source  = "terraform-google-modules/vpn/google//modules/vpn_ha"
  version = "~> 1.3.0"
  project_id  = var.project_id_a
  region  = var.subnet_region_a
  network         = module.vpc-a.network_name
  name            = "neta-to-netb"
  router_asn = 64513
  peer_gcp_gateway = module.vpn_ha-1.self_link
  tunnels = {
    remote-0 = {
      bgp_peer = {
        address = "169.254.1.2"
        asn     = 64514
      }
      bgp_peer_options  = null
      bgp_session_range = "169.254.1.1/30"
      ike_version       = 2
      vpn_gateway_interface = 0
      peer_external_gateway_interface = null
      shared_secret     = module.vpn_ha-1.random_secret
    }
    remote-1 = {
      bgp_peer = {
        address = "169.254.2.2"
        asn     = 64514
      }
      bgp_peer_options  = null
      bgp_session_range = "169.254.2.1/30"
      ike_version       = 2
      vpn_gateway_interface = 1
      peer_external_gateway_interface = null
      shared_secret     = module.vpn_ha-1.random_secret
    }
  }
}


# ---------------------------------------------------------------------------------------------------------------------
# cluster
# ---------------------------------------------------------------------------------------------------------------------
module "gke" {
  source                    = "terraform-google-modules/kubernetes-engine/google//modules/private-cluster"
  project_id                = var.project_id_a
  name                      = "${var.cluster_name}-cluster"
  regional                  = true
  region                    = var.subnet_region_a
  network                   = module.vpc-a.network_name
  subnetwork                = var.subnet_name_a
  ip_range_pods             = "${var.subnet_name_a}-pods"
  ip_range_services         = "${var.subnet_name_a}-services"
  create_service_account    = true
  service_account           = "create"
  enable_private_endpoint   = false
  enable_private_nodes      = true
  master_ipv4_cidr_block    = "172.16.0.0/28"
  default_max_pods_per_node = 20
  remove_default_node_pool  = true

  node_pools = [
    {
      name              = "bout-01"
      min_count         = 1
      max_count         = 15
      auto_repair       = true
      auto_upgrade      = true
      preemptible       = true
    },
  ]

  master_authorized_networks = [
    {
      cidr_block   = "0.0.0.0/0"
      display_name = "VPC"
    },

  ]

  cluster_autoscaling = {
  "enabled": true,
  "gpu_resources": [],
  "max_cpu_cores": 16,
  "max_memory_gb": 32,
  "min_cpu_cores": 2,
  "min_memory_gb": 4
}
}




# ---------------------------------------------------------------------------------------------------------------------
# workload identity
# ---------------------------------------------------------------------------------------------------------------------
/*
module "my-app-workload-identity" {
  source     = "terraform-google-modules/kubernetes-engine/google//modules/workload-identity"
  name       = "iden-${module.gke.name}"
  //namespace  = "dev"
  project_id = var.project_id_a
  roles      = ["roles/storage.admin", "roles/compute.admin"]
  use_existing_k8s_sa = false
}

resource "kubernetes_namespace" "dev" {
  metadata {
    annotations = {
      name = "dev"
    }
    name = "dev"
  }
}
*/