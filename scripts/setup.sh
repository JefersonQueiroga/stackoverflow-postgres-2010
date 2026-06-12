#!/usr/bin/env bash
# Prepara roles, restaura o dump e cria o usuário dos alunos.
# Uso: ./scripts/setup.sh [nome-do-arquivo-de-dump]
# Pré-requisitos: container rodando (docker compose up -d) e dump em ./dump/
set -euo pipefail
cd "$(dirname "$0")/.."

source .env
DUMP_FILE="${1:-dump-stackoverflow2010-202408101013.sql}"

if [ ! -f "dump/${DUMP_FILE}" ]; then
  echo "ERRO: dump/${DUMP_FILE} não encontrado. Baixe o dump para ./dump/ primeiro." >&2
  exit 1
fi

echo "==> Aguardando PostgreSQL aceitar conexões..."
until docker compose exec -T postgres pg_isready -U postgres -q; do sleep 2; done

echo "==> Criando roles esse e readaccess (se não existirem)..."
docker compose exec -T postgres psql -U postgres -v ON_ERROR_STOP=1 <<'SQL'
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'esse') THEN
    CREATE ROLE esse NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'readaccess') THEN
    CREATE ROLE readaccess NOLOGIN;
  END IF;
END
$$;
SQL

echo "==> Criando banco stackoverflow (se não existir)..."
docker compose exec -T postgres psql -U postgres -tAc \
  "SELECT 1 FROM pg_database WHERE datname = 'stackoverflow'" | grep -q 1 || {
  docker compose exec -T postgres createdb -U postgres -O esse stackoverflow
  # O dump traz seu próprio CREATE SCHEMA public; remover o default evita
  # "schema public already exists" com --exit-on-error
  docker compose exec -T postgres psql -U postgres -d stackoverflow \
    -v ON_ERROR_STOP=1 -c "DROP SCHEMA IF EXISTS public CASCADE"
}

echo "==> Restaurando o dump (pode levar vários minutos)..."
docker compose exec -T postgres pg_restore -U postgres -d stackoverflow \
  --no-password --exit-on-error "/dump/${DUMP_FILE}"

echo "==> Criando usuário aluno (somente leitura, com proteções)..."
docker compose exec -T postgres psql -U postgres -v ON_ERROR_STOP=1 <<'SQL'
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'aluno') THEN
    CREATE ROLE aluno LOGIN;
  END IF;
END
$$;
SQL
# A senha e as proteções são (re)aplicadas sempre, para o script ser idempotente:
docker compose exec -T postgres psql -U postgres -v ON_ERROR_STOP=1 \
  -c "ALTER ROLE aluno PASSWORD '${ALUNO_PASSWORD}'" \
  -c "GRANT readaccess TO aluno" \
  -c "ALTER ROLE aluno SET statement_timeout = '60s'" \
  -c "ALTER ROLE aluno CONNECTION LIMIT 30"

echo "==> Pronto! Validação rápida:"
docker compose exec -T postgres psql -U postgres -d stackoverflow -c \
  "SELECT relname AS tabela, n_live_tup AS linhas FROM pg_stat_user_tables ORDER BY n_live_tup DESC"
