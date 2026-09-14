# RFC-002 · Escolha do banco de dados

| | |
|---|---|
| **Status** | Aceita |
| **Data** | 2026-09-07 |
| **Decisões derivadas** | ADR-001 (VPC no repositório do banco), ADR-004 (grupo `cliente-db`) |
| **Modelo de dados** | `tech-challenge-app` · `docs/modelo-de-dados.md` |

## Contexto

A oficina registra clientes, veículos, catálogo de serviços, estoque de peças e ordens de
serviço com itens e histórico de status. Desde a Fase 01 os dados vivem em PostgreSQL, rodando
em container. A Fase 03 pede um banco gerenciado na nuvem e a justificativa formal da escolha.

## O que o domínio exige

- **Transação entre tabelas.** Quando a OS entra em execução, a baixa das peças e a mudança de
  status acontecem juntas ou não acontecem. Faltando estoque de uma peça, a transição inteira
  volta atrás.
- **Bloqueio de linha.** Duas OS simultâneas não podem consumir a mesma peça: a aplicação usa
  `SELECT ... FOR UPDATE` na OS e na peça.
- **Integridade referencial.** Item sem OS, OS sem cliente e veículo sem dono não podem existir.
- **Unicidade garantida pelo banco.** CPF/CNPJ, placa, nome de serviço e nome de peça.
- **Consultas relacionais.** Fila por prioridade, tempo médio por status e ordens de um cliente
  cruzam tabelas e agregam.
- **Migrações seguras.** O schema evolui por Alembic, e dois pods subindo juntos podem rodar a
  mesma migração ao mesmo tempo.

## Opções

| Critério | RDS PostgreSQL | RDS MySQL | Aurora PostgreSQL | DynamoDB | DocumentDB |
|---|---|---|---|---|---|
| Transação entre tabelas ou documentos | sim | sim | sim | limitada a 100 itens por transação | sim, com limites |
| `SELECT ... FOR UPDATE` | sim | sim | sim | não | não |
| Chave estrangeira | sim | sim | sim | não | não |
| DDL dentro de transação | sim | não: cada DDL confirma a transação | sim | não se aplica | não se aplica |
| Tipos usados pela aplicação: UUID, ENUM, NUMERIC, `timestamptz` | todos nativos | sem UUID e sem fuso no timestamp | todos nativos | não | parcial |
| Mudança no código atual | nenhuma | driver e migrations | nenhuma | reescrita da persistência | reescrita da persistência |
| Custo nesta carga | menor instância gerenciada | equivalente ao PostgreSQL | maior: a menor instância é bem acima da do RDS | baixo, após remodelagem | maior |

## Proposta

**Amazon RDS for PostgreSQL 16**, instância `db.t4g.micro`, em subnet privada, com TLS
obrigatório (`rds.force_ssl`), armazenamento criptografado e backup de 7 dias.

É a única opção que atende a todos os requisitos sem mudança de código. Entre os relacionais, o
DDL transacional decide a favor do PostgreSQL: uma migração que falha no meio volta inteira.
Antes do primeiro deploy, duas migrações simultâneas contra um banco vazio terminaram sem erro
no PostgreSQL 16. O Aurora teria a mesma compatibilidade, com alta disponibilidade e réplicas
que este volume não usa, a um custo mínimo maior.

## Consequências

- **Uma zona de disponibilidade.** `multi_az = false`, por custo. Uma falha na zona derruba o
  banco até a recuperação; em produção, Multi-AZ.
- **Limite de conexões.** No RDS, o máximo de conexões é proporcional à memória, algo da ordem
  de uma centena em 1 GiB. A API limita o pool a 5 conexões por processo: no teto do HPA (6 pods
  com 2 workers cada) são 60, com folga para a Lambda e para as migrações. Crescer além disso
  pede RDS Proxy.
- **Escala vertical.** Crescer é trocar a classe da instância, com uma janela curta de
  indisponibilidade.
- **Credenciais no Secrets Manager.** A senha é gerada pelo Terraform e ninguém a digita.
- **Snapshot final a cada destroy**, para que nenhum dado se perca por engano.
