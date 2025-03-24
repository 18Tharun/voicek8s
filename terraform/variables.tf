variable "do_token" {
  description = "DigitalOcean API token"
  sensitive   = true
}

variable "environment" {
  description = "Environment name (e.g., prod, dev, staging)"
  default     = "prod"
}

variable "ssh_public_key_path" {
  description = "Path to your SSH public key file"
  default     = "~/.ssh/id_rsa.pub"
}

variable "ssh_private_key_path" {
  description = "Path to your SSH private key file"
  default     = "~/.ssh/id_rsa"
  sensitive   = true
}

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  default     = "voice-ai-cluster"
}

variable "region" {
  description = "DigitalOcean region"
  default     = "nyc1"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  default     = "1.27.4-do.0" # Updated to latest stable version
}

variable "node_size" {
  description = "Size of the worker nodes"
  default     = "s-2vcpu-4gb" # Optimized based on stress test results
}

variable "node_count" {
  description = "Number of worker nodes"
  default     = 2 # Two nodes for redundancy and load handling
}

variable "droplet_size" {
  description = "Size of the DigitalOcean droplet"
  default     = "s-2vcpu-4gb" # Based on stress test results
}

variable "domain_name" {
  description = "Domain name for the application (leave empty if not using a domain)"
  default     = ""
}

variable "registry_name" {
  description = "Name for the container registry"
  default     = "voice-ai-registry"
}
