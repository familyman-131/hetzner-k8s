variable "hcloud_token" {
  description = "Hetzner Cloud API token (Read & Write). Лучше передавать через TF_VAR_hcloud_token."
  type        = string
  sensitive   = true
}

variable "cluster_name" {
  description = "Префикс для имён ресурсов."
  type        = string
  default     = "k8s-lab"
}

variable "location" {
  description = "Локация Hetzner. CX23/CX33 (Cost-Optimized) доступны в EU-локациях: fsn1, nbg1, hel1."
  type        = string
  default     = "fsn1"
}

variable "network_zone" {
  description = "Network zone для подсети; должна совпадать с регионом location (fsn1/nbg1/hel1 -> eu-central)."
  type        = string
  default     = "eu-central"
}

variable "image" {
  description = "Ubuntu LTS образ."
  type        = string
  default     = "ubuntu-24.04"
}

variable "control_plane_type" {
  type    = string
  default = "cx23" # 2 vCPU / 4 GB — минимум kubeadm: 2 CPU, 2 GB RAM
}

variable "worker_type" {
  type    = string
  default = "cx33" # 4 vCPU / 8 GB
}

variable "worker_count" {
  type    = number
  default = 2
}

variable "kubernetes_minor" {
  description = <<-EOT
    Минорная версия Kubernetes для репозитория pkgs.k8s.io (формат vX.Y).
    На ноябрь 2026 поддерживаются 1.35/1.36/1.37. Берём 1.36, чтобы потом
    потренировать `kubeadm upgrade` до 1.37.
  EOT
  type    = string
  default = "v1.36"
}

variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/id_ed25519.pub"
}

variable "admin_cidrs" {
  description = "Откуда разрешены SSH (22) и Kubernetes API (6443). Укажи свой IP/32, а не 0.0.0.0/0."
  type        = list(string)
}

variable "expose_nodeports" {
  description = "Открыть NodePort-диапазон 30000-32767 на воркерах для admin_cidrs (удобно для тестов без LoadBalancer)."
  type        = bool
  default     = true
}

# --- Адресный план. Важно, чтобы три диапазона НЕ пересекались. ---
variable "network_cidr" {
  description = "Вся приватная сеть Hetzner."
  type        = string
  default     = "10.0.0.0/16"
}

variable "nodes_subnet_cidr" {
  description = "Подсеть для нод внутри network_cidr."
  type        = string
  default     = "10.0.1.0/24"
}

variable "pod_cidr" {
  description = "Диапазон для подов (передаётся в kubeadm init --pod-network-cidr и в CNI)."
  type        = string
  default     = "10.244.0.0/16"
}

variable "service_cidr" {
  description = "Диапазон ClusterIP-сервисов (дефолт kubeadm)."
  type        = string
  default     = "10.96.0.0/12"
}
