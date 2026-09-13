output "vpc_id" {
  value = aws_vpc.principal.id
}

output "subnet_ids_publicas" {
  value = [for s in aws_subnet.publicas : s.id]
}

output "subnet_ids_privadas" {
  value = [for s in aws_subnet.privadas : s.id]
}

output "sg_cliente_db_id" {
  description = "Anexe a quem precisa acessar o banco"
  value       = aws_security_group.cliente_db.id
}

output "endereco_banco" {
  description = "Endpoint do PostgreSQL, alcançável só de dentro da VPC"
  value       = aws_db_instance.principal.address
}
