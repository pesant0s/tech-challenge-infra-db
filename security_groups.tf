# Quem precisa do banco anexa o grupo cliente-db; o RDS só aceita membros dele (ADR-004).

resource "aws_security_group" "cliente_db" {
  name        = "${var.prefixo}-cliente-db"
  description = "Anexe a quem precisa falar com o PostgreSQL"
  vpc_id      = aws_vpc.principal.id

  tags = { Name = "${var.prefixo}-cliente-db" }
}

resource "aws_security_group" "banco" {
  name        = "${var.prefixo}-rds"
  description = "PostgreSQL - acesso apenas pelo grupo cliente-db"
  vpc_id      = aws_vpc.principal.id

  tags = { Name = "${var.prefixo}-rds" }
}

resource "aws_vpc_security_group_ingress_rule" "postgres_de_clientes" {
  security_group_id            = aws_security_group.banco.id
  description                  = "PostgreSQL a partir do grupo cliente-db"
  referenced_security_group_id = aws_security_group.cliente_db.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "cliente_para_banco" {
  security_group_id            = aws_security_group.cliente_db.id
  description                  = "Saida para o PostgreSQL"
  referenced_security_group_id = aws_security_group.banco.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}
