#!/usr/bin/env bash
# Bucket do estado remoto: criado antes de tudo, apagado depois de tudo.
set -euo pipefail

acao=${1:?uso: bootstrap.sh criar|destruir <bucket> <regiao>}
bucket=${2:?informe o bucket}
regiao=${3:?informe a região}

case "$acao" in
  criar)
    if aws s3api head-bucket --bucket "$bucket" 2>/dev/null; then
      echo "✓ bucket $bucket já existe"
      exit 0
    fi
    if [[ "$regiao" == "us-east-1" ]]; then
      aws s3api create-bucket --bucket "$bucket" --region "$regiao" >/dev/null
    else
      aws s3api create-bucket --bucket "$bucket" --region "$regiao" \
        --create-bucket-configuration "LocationConstraint=$regiao" >/dev/null
    fi
    aws s3api put-bucket-versioning --bucket "$bucket" --versioning-configuration Status=Enabled
    aws s3api put-bucket-encryption --bucket "$bucket" --server-side-encryption-configuration \
      '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
    aws s3api put-public-access-block --bucket "$bucket" --public-access-block-configuration \
      "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
    echo "✓ bucket $bucket criado"
    ;;

  destruir)
    if ! aws s3api head-bucket --bucket "$bucket" 2>/dev/null; then
      echo "✓ bucket $bucket não existe"
      exit 0
    fi

    # Recursos ainda no estado ficariam órfãos e cobrando.
    vivos=0
    # shellcheck disable=SC2016
    for chave in $(aws s3api list-objects-v2 --bucket "$bucket" \
                     --query 'Contents[?ends_with(Key, `.tfstate`)].Key' --output text); do
      [[ "$chave" == "None" ]] && continue
      n=$(aws s3 cp "s3://$bucket/$chave" - | python3 -c \
        'import json, sys; print(sum(r.get("mode") == "managed" for r in json.load(sys.stdin).get("resources", [])))')
      (( n > 0 )) && echo "  $chave ainda gerencia $n recurso(s)"
      vivos=$(( vivos + n ))
    done
    if (( vivos > 0 )); then
      echo "Recusado: destrua antes auth-lambda, infra-k8s e infra-db." >&2
      exit 1
    fi

    read -r -p "Apagar $bucket e todo o histórico de estado? Digite 'apagar': " resposta
    [[ "$resposta" == "apagar" ]] || { echo "Cancelado."; exit 1; }

    # Bucket versionado: cada versão e marcador precisa ser removido.
    python3 - "$bucket" <<'PY'
import json, subprocess, sys

bucket = sys.argv[1]
while True:
    saida = subprocess.run(["aws", "s3api", "list-object-versions", "--bucket", bucket,
                            "--max-items", "1000", "--output", "json"],
                           check=True, capture_output=True, text=True).stdout
    pagina = json.loads(saida or "{}")
    objetos = [{"Key": o["Key"], "VersionId": o["VersionId"]}
               for grupo in ("Versions", "DeleteMarkers") for o in pagina.get(grupo) or []]
    if not objetos:
        break
    subprocess.run(["aws", "s3api", "delete-objects", "--bucket", bucket,
                    "--delete", json.dumps({"Objects": objetos, "Quiet": True})],
                   check=True, capture_output=True)
PY
    aws s3api delete-bucket --bucket "$bucket" --region "$regiao"
    echo "✓ bucket $bucket apagado"

    snapshots=$(aws rds describe-db-snapshots --snapshot-type manual --region "$regiao" --output text \
      --query "DBSnapshots[?starts_with(DBSnapshotIdentifier, 'tech-challenge-final')].DBSnapshotIdentifier")
    [[ -z "$snapshots" || "$snapshots" == "None" ]] || echo "⚠ Snapshots finais do banco seguem cobrando: $snapshots"
    ;;

  *)
    echo "ação desconhecida: $acao (use criar ou destruir)" >&2
    exit 2
    ;;
esac
