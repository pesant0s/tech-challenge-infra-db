SHELL := /bin/bash
.DEFAULT_GOAL := help
.PHONY: help conta bootstrap bootstrap-destroy init fmt validate plan apply destroy output segredo custo

AWS_REGION ?= us-east-1
export AWS_REGION

CONTA  = $(shell aws sts get-caller-identity --query Account --output text)
BUCKET = tech-challenge-tfstate-$(CONTA)

help: ## Lista os alvos
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

conta: ## Mostra em qual conta AWS os comandos vão atuar
	@test -n "$$AWS_PROFILE$$AWS_ACCESS_KEY_ID" || { echo "Defina AWS_PROFILE com a conta que vai receber a rede e o banco."; exit 1; }
	@echo "Conta AWS: $(CONTA) · perfil: $${AWS_PROFILE:-credenciais do ambiente} · região: $(AWS_REGION)"

bootstrap: conta ## Passo zero: cria o bucket do estado remoto
	@./scripts/bootstrap.sh criar "$(BUCKET)" "$(AWS_REGION)"

bootstrap-destroy: conta ## Último passo: apaga o bucket do estado; recusa se houver recurso vivo
	@./scripts/bootstrap.sh destruir "$(BUCKET)" "$(AWS_REGION)"

init: conta ## Inicializa o Terraform com o estado desta conta
	terraform init -backend-config="bucket=$(BUCKET)" -backend-config="region=$(AWS_REGION)"

fmt: ## Formata os arquivos .tf
	terraform fmt -recursive

validate: ## Valida a configuração, sem AWS
	terraform init -backend=false -input=false >/dev/null
	terraform validate

plan: conta ## Mostra o que será alterado
	@test -f .terraform/terraform.tfstate || $(MAKE) --no-print-directory init
	terraform plan

apply: conta ## Provisiona rede, banco e segredos (~10 min)
	@aws s3api head-bucket --bucket $(BUCKET) 2>/dev/null || { echo "Bucket do estado inexistente: rode 'make bootstrap'."; exit 1; }
	@test -f .terraform/terraform.tfstate || $(MAKE) --no-print-directory init
	terraform apply

destroy: conta ## Destrói rede e banco; exige Lambda e cluster já destruídos
	@! aws ssm get-parameter --name /tech-challenge/cluster/nome >/dev/null 2>&1 || { echo "O cluster ainda existe: rode 'make down' no tech-challenge-infra-k8s."; exit 1; }
	@! aws lambda get-function --function-name tech-challenge-auth >/dev/null 2>&1 || { echo "A Lambda ainda existe: rode 'make destroy' no tech-challenge-auth-lambda."; exit 1; }
	@read -r -p "Isto apaga o banco da oficina. Digite 'destruir': " r && [ "$$r" = "destruir" ]
	@test -f .terraform/terraform.tfstate || $(MAKE) --no-print-directory init
	@terraform destroy || { echo "Se falhou em subnet ou security group logo após remover a Lambda, aguarde alguns minutos e repita."; exit 1; }

output: ## Exibe os outputs
	terraform output

segredo: conta ## Mostra as credenciais geradas, incluindo a senha do admin da API
	@aws secretsmanager get-secret-value --secret-id tech-challenge/app --query SecretString --output text | python3 -m json.tool

custo: ## Estimativa do que este repositório mantém de pé
	@echo "RDS db.t4g.micro   ~US\$$ 0,016/h (~US\$$ 12/mês se 24/7)"
	@echo "Armazenamento 20GB ~US\$$ 2,30/mês"
	@echo "Secrets Manager    ~US\$$ 0,40/mês"
	@echo "VPC, subnets, IGW  gratuitos (sem NAT Gateway)"
