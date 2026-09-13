# Um segredo só: a Lambda assina o JWT e a API o valida com a mesma SECRET_KEY.

resource "random_password" "jwt" {
  length  = 64
  special = false
}

resource "random_password" "webhook" {
  length  = 40
  special = false
}

resource "random_password" "admin" {
  length           = 24
  override_special = "!#$%&*()-_=+"
}

resource "aws_secretsmanager_secret" "app" {
  name                    = "tech-challenge/app"
  description             = "Credenciais da API e da Lambda de autenticacao"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "app" {
  secret_id = aws_secretsmanager_secret.app.id

  secret_string = jsonencode({
    DATABASE_URL = format(
      "postgresql://%s:%s@%s:%s/%s?sslmode=require",
      var.usuario_master,
      urlencode(random_password.master.result),
      aws_db_instance.principal.address,
      aws_db_instance.principal.port,
      var.nome_banco,
    )
    DB_HOST        = aws_db_instance.principal.address
    DB_PORT        = tostring(aws_db_instance.principal.port)
    DB_NAME        = var.nome_banco
    DB_USER        = var.usuario_master
    DB_PASSWORD    = random_password.master.result
    SECRET_KEY     = random_password.jwt.result
    WEBHOOK_SECRET = random_password.webhook.result
    ADMIN_PASSWORD = random_password.admin.result
  })
}
