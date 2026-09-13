# Contrato com os outros repositórios (ADR-003): mudar um parâmetro quebra quem o lê.

locals {
  parametros = {
    "network/vpc_id"              = aws_vpc.principal.id
    "network/cidr"                = aws_vpc.principal.cidr_block
    "network/subnet_ids_publicas" = join(",", [for s in aws_subnet.publicas : s.id])
    "network/subnet_ids_privadas" = join(",", [for s in aws_subnet.privadas : s.id])
    "network/sg_cliente_db_id"    = aws_security_group.cliente_db.id
    "database/secret_nome"        = aws_secretsmanager_secret.app.name
  }
}

resource "aws_ssm_parameter" "contrato" {
  for_each = local.parametros

  name        = "/tech-challenge/${each.key}"
  type        = "String"
  value       = each.value
  description = "Publicado por tech-challenge-infra-db. Nao editar manualmente."

  tags = { Contrato = "infra-db" }
}
