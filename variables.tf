variable "regiao" {
  description = "Região AWS"
  type        = string
  default     = "us-east-1"
}

variable "perfil_aws" {
  description = "Perfil local do AWS CLI; vazio no CI, que usa OIDC"
  type        = string
  default     = null
}

variable "prefixo" {
  description = "Prefixo dos nomes de recurso"
  type        = string
  default     = "tech-challenge"
}

variable "cidr_vpc" {
  description = "CIDR da VPC; /16 porque o VPC CNI atribui um IP a cada pod"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.cidr_vpc, 0))
    error_message = "cidr_vpc precisa ser um bloco CIDR válido."
  }
}

variable "zonas_disponibilidade" {
  description = "AZs usadas; EKS e DB subnet group exigem ao menos duas"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]

  validation {
    condition     = length(var.zonas_disponibilidade) >= 2
    error_message = "São necessárias ao menos duas zonas de disponibilidade."
  }
}

variable "classe_instancia_db" {
  description = "Classe da instância RDS"
  type        = string
  default     = "db.t4g.micro"
}

variable "versao_postgres" {
  description = "Versão maior do PostgreSQL"
  type        = string
  default     = "16"
}

variable "armazenamento_gb" {
  description = "Armazenamento inicial em GB"
  type        = number
  default     = 20
}

variable "armazenamento_maximo_gb" {
  description = "Teto do autoscaling de armazenamento"
  type        = number
  default     = 50
}

variable "nome_banco" {
  description = "Nome do banco"
  type        = string
  default     = "oficina"
}

variable "usuario_master" {
  description = "Usuário administrador do banco"
  type        = string
  default     = "oficina_admin"
}

variable "retencao_backup_dias" {
  description = "Dias de retenção dos backups automáticos"
  type        = number
  default     = 7
}

variable "protecao_delecao" {
  description = "Protege o banco contra destroy; desligado porque o ambiente é efêmero"
  type        = bool
  default     = false
}

variable "pular_snapshot_final" {
  description = "Se true, o destroy não gera snapshot final"
  type        = bool
  default     = false
}
