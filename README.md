# Stack Overflow 2010 — Banco PostgreSQL para aulas

Disponibiliza o dump do Stack Overflow 2010 (PostgreSQL 15, ~1,5 GB) em uma
VPS com Docker, para alunos conectarem com DBeaver/pgAdmin em modo
somente-leitura.

Dump original: [smartpostgres.com](https://smartpostgres.com/how-to-use-query-smartpostgres-com/),
importado do [Stack Exchange Data Dump](https://archive.org/details/stackexchange)
(licença [CC BY-SA 4.0](http://creativecommons.org/licenses/by-sa/4.0/)).

## Setup na VPS

```bash
# 1. Clonar o projeto
sudo mkdir -p /opt/stackoverflow-db && sudo chown $USER /opt/stackoverflow-db
git clone https://github.com/JefersonQueiroga/stackoverflow-postgres-2010.git /opt/stackoverflow-db
cd /opt/stackoverflow-db

# 2. Configurar senhas
cp .env.example .env
nano .env   # trocar POSTGRES_PASSWORD e ALUNO_PASSWORD

# 3. Baixar o dump (fica em ./dump/, fora do git)
mkdir -p dump
wget -O dump/dump-stackoverflow2010-202408101013.sql \
  "URL-DO-DUMP"

# 4. Subir o PostgreSQL
docker compose up -d

# 5. Restaurar o dump e criar o usuário dos alunos
chmod +x scripts/*.sh
./scripts/setup.sh
```

## Acesso dos alunos

| Campo | Valor |
|---|---|
| Host | IP da VPS |
| Porta | 5432 |
| Banco | `stackoverflow` |
| Usuário | `aluno` |
| Senha | a definida em `ALUNO_PASSWORD` |

Proteções da role `aluno`: somente leitura (via role `readaccess`),
`statement_timeout = 60s`, limite de 30 conexões.

## Reset para nova turma

```bash
cd /opt/stackoverflow-db && ./scripts/reset.sh
```

Apaga o banco e restaura do dump guardado em `./dump/`.

## Validação

1. Conectar de fora como `aluno` e rodar `SELECT count(*) FROM posts;`
2. Confirmar que `INSERT`/`UPDATE`/`DELETE` retornam *permission denied*
3. `docker compose ps` mostra o container com restart `unless-stopped`

## Segurança

- Firewall liberando apenas 22 (SSH) e 5432 (PostgreSQL)
- Autenticação `scram-sha-256` (padrão do PostgreSQL 15)
- Senha do superusuário `postgres` não é distribuída aos alunos
