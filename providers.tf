provider "aws" {
  region  = var.regiao
  profile = var.perfil_aws

  default_tags {
    tags = {
      Project     = "tech-challenge"
      Fase        = "03"
      Repositorio = "tech-challenge-infra-db"
      ManagedBy   = "terraform"
    }
  }
}
