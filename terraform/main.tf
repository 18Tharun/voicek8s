terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

# Create a new SSH key for secure access
resource "digitalocean_ssh_key" "voice_ai_key" {
  name       = "voice-ai-key"
  public_key = file(var.ssh_public_key_path)
}

# Create a new DigitalOcean droplet
resource "digitalocean_droplet" "voice_ai_server" {
  image              = "ubuntu-20-04-x64"
  name               = "voice-ai-${var.environment}"
  region             = var.region
  size               = var.droplet_size
  private_networking = true
  ssh_keys           = [digitalocean_ssh_key.voice_ai_key.fingerprint]
  
  # Simple cloud-init script to prepare the system
  user_data = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y apt-transport-https ca-certificates curl software-properties-common
    mkdir -p /opt/voice-ai
  EOF
  
  # Wait for cloud-init to complete
  provisioner "remote-exec" {
    inline = ["echo 'Droplet is ready'"]
    
    connection {
      type        = "ssh"
      user        = "root"
      private_key = file(var.ssh_private_key_path)
      host        = self.ipv4_address
    }
  }
}

# Reserve an IP address
resource "digitalocean_reserved_ip" "voice_ai_ip" {
  droplet_id = digitalocean_droplet.voice_ai_server.id
  region     = var.region
}

# Setup DNS if domain is provided
resource "digitalocean_domain" "voice_ai_domain" {
  count      = var.domain_name != "" ? 1 : 0
  name       = var.domain_name
}

# Create an A record pointing to the droplet
resource "digitalocean_record" "voice_ai_a_record" {
  count      = var.domain_name != "" ? 1 : 0
  domain     = digitalocean_domain.voice_ai_domain[0].id
  type       = "A"
  name       = "@"
  value      = digitalocean_reserved_ip.voice_ai_ip.ip_address
  ttl        = 300
}

# Create a CNAME record for www if domain is provided
resource "digitalocean_record" "voice_ai_cname_record" {
  count      = var.domain_name != "" ? 1 : 0
  domain     = digitalocean_domain.voice_ai_domain[0].id
  type       = "CNAME"
  name       = "www"
  value      = "@"
  ttl        = 300
}

resource "digitalocean_kubernetes_cluster" "voice_ai_cluster" {
  name    = var.cluster_name
  region  = var.region
  version = var.kubernetes_version
  auto_upgrade = true
  surge_upgrade = true
  
  node_pool {
    name       = "worker-pool"
    size       = var.node_size
    node_count = var.node_count
    auto_scale = true
    min_nodes  = 2
    max_nodes  = 4
    tags       = ["voice-ai"]
  }
}

# Set up Container Registry
resource "digitalocean_container_registry" "voice_ai_registry" {
  name                   = var.registry_name
  subscription_tier_slug = "basic"
}

# Configure Kubernetes provider
provider "kubernetes" {
  host                   = digitalocean_kubernetes_cluster.voice_ai_cluster.endpoint
  token                  = digitalocean_kubernetes_cluster.voice_ai_cluster.kube_config[0].token
  cluster_ca_certificate = base64decode(digitalocean_kubernetes_cluster.voice_ai_cluster.kube_config[0].cluster_ca_certificate)
}

# Upload Kubernetes config files
resource "null_resource" "upload_kubernetes_files" {
  depends_on = [digitalocean_droplet.voice_ai_server]
  
  # Copy Kubernetes configuration files
  provisioner "file" {
    source      = "${path.module}/../kubernetes"
    destination = "/opt/voice-ai"
    
    connection {
      type        = "ssh"
      user        = "root"
      private_key = file(var.ssh_private_key_path)
      host        = digitalocean_reserved_ip.voice_ai_ip.ip_address
    }
  }
  
  # Copy installation scripts
  provisioner "file" {
    source      = "${path.module}/../install-k3s.sh"
    destination = "/opt/voice-ai/install-k3s.sh"
    
    connection {
      type        = "ssh"
      user        = "root"
      private_key = file(var.ssh_private_key_path)
      host        = digitalocean_reserved_ip.voice_ai_ip.ip_address
    }
  }
  
  # Copy deployment scripts
  provisioner "file" {
    source      = "${path.module}/../k8s-deploy.sh"
    destination = "/opt/voice-ai/k8s-deploy.sh"
    
    connection {
      type        = "ssh"
      user        = "root"
      private_key = file(var.ssh_private_key_path)
      host        = digitalocean_reserved_ip.voice_ai_ip.ip_address
    }
  }
}

# Install Kubernetes (k3s) on the droplet
resource "null_resource" "install_kubernetes" {
  depends_on = [null_resource.upload_kubernetes_files]
  
  provisioner "remote-exec" {
    inline = [
      "chmod +x /opt/voice-ai/install-k3s.sh",
      "cd /opt/voice-ai && ./install-k3s.sh ${digitalocean_reserved_ip.voice_ai_ip.ip_address} ${var.domain_name}"
    ]
    
    connection {
      type        = "ssh"
      user        = "root"
      private_key = file(var.ssh_private_key_path)
      host        = digitalocean_reserved_ip.voice_ai_ip.ip_address
    }
  }
}

# Deploy the application
resource "null_resource" "deploy_application" {
  depends_on = [null_resource.install_kubernetes]
  
  provisioner "remote-exec" {
    inline = [
      "chmod +x /opt/voice-ai/k8s-deploy.sh",
      "cd /opt/voice-ai && ./k8s-deploy.sh"
    ]
    
    connection {
      type        = "ssh"
      user        = "root"
      private_key = file(var.ssh_private_key_path)
      host        = digitalocean_reserved_ip.voice_ai_ip.ip_address
    }
  }
}
