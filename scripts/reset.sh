#!/usr/bin/env bash
# Reseta o banco para uma nova turma: derruba conexões, apaga e restaura do dump.
# Uso: ./scripts/reset.sh [nome-do-arquivo-de-dump]
set -euo pipefail
cd "$(dirname "$0")/.."

DUMP_FILE="${1:-dump-stackoverflow2010-202408101013.sql}"

echo "ATENÇÃO: isso vai APAGAR o banco stackoverflow e restaurar do zero."
read -r -p "Continuar? (digite sim) " resp
[ "$resp" = "sim" ] || { echo "Cancelado."; exit 1; }

echo "==> Derrubando conexões e apagando o banco..."
docker compose exec -T postgres psql -U postgres -v ON_ERROR_STOP=1 \
  -c "DROP DATABASE IF EXISTS stackoverflow WITH (FORCE)"

echo "==> Recriando e restaurando..."
exec ./scripts/setup.sh "${DUMP_FILE}"
