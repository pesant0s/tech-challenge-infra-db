resource "aws_db_subnet_group" "principal" {
  name        = "${var.prefixo}-db-subnets"
  description = "Subnets privadas do PostgreSQL"
  subnet_ids  = [for s in aws_subnet.privadas : s.id]

  tags = { Name = "${var.prefixo}-db-subnets" }
}

resource "aws_db_parameter_group" "principal" {
  name        = "${var.prefixo}-pg${var.versao_postgres}"
  family      = "postgres${var.versao_postgres}"
  description = "Parametros do PostgreSQL da oficina"

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "pending-reboot"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "random_password" "master" {
  length           = 32
  override_special = "!#$%&*()-_=+[]{}<>:?" # o RDS recusa / @ " e espaço
}

resource "aws_db_instance" "principal" {
  identifier     = "${var.prefixo}-postgres"
  engine         = "postgres"
  engine_version = var.versao_postgres
  instance_class = var.classe_instancia_db

  db_name  = var.nome_banco
  username = var.usuario_master
  password = random_password.master.result
  port     = 5432

  allocated_storage     = var.armazenamento_gb
  max_allocated_storage = var.armazenamento_maximo_gb
  storage_type          = "gp3"
  storage_encrypted     = true

  db_subnet_group_name   = aws_db_subnet_group.principal.name
  vpc_security_group_ids = [aws_security_group.banco.id]
  parameter_group_name   = aws_db_parameter_group.principal.name
  publicly_accessible    = false
  multi_az               = false

  backup_retention_period         = var.retencao_backup_dias
  backup_window                   = "06:00-07:00"
  maintenance_window              = "Mon:07:30-Mon:08:30"
  auto_minor_version_upgrade      = true
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  deletion_protection       = var.protecao_delecao
  skip_final_snapshot       = var.pular_snapshot_final
  final_snapshot_identifier = var.pular_snapshot_final ? null : "${var.prefixo}-final-${formatdate("YYYYMMDD-hhmmss", timestamp())}"

  lifecycle {
    ignore_changes = [final_snapshot_identifier]
  }

  tags = { Name = "${var.prefixo}-postgres" }
}
