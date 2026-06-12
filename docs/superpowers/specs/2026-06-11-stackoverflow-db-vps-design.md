# Design: Banco Stack Overflow 2010 em VPS (Docker)

Data: 2026-06-11
Status: aprovado pelo usuário

## Objetivo

Disponibilizar o dump do Stack Overflow 2010 (PostgreSQL, formato custom do
`pg_dump`, ~1,5 GB, gerado no PostgreSQL 15.5) em uma VPS Linux, para que
alunos conectem com clientes SQL (DBeaver, pgAdmin etc.) e estudem o banco
em modo somente-leitura.

## Contexto

- Arquivo local: `dump-stackoverflow2010-202408101013.sql` (formato PGDMP/custom)
- O dump cria o banco `stackoverflow`, referencia o owner `esse` e a role
  `readaccess` (com `GRANT SELECT` em todas as tabelas)
- Acesso à VPS: SSH via Termius (usuário guiado por comandos, um a um)
- Execução: o usuário cola os comandos no Termius e reporta os resultados

## Decisões

| Decisão | Escolha |
|---|---|
| Instalação do PostgreSQL | Docker, imagem `postgres:15` |
| Acesso dos alunos | Cliente SQL direto na porta 5432 |
| Credenciais dos alunos | Login único `aluno` (somente leitura) |
| Execução | Guiada no Termius (comandos passados um a um) |

## Arquitetura

- VPS Linux com Docker + plugin compose
- Container `postgres:15`:
  - Volume nomeado para `/var/lib/postgresql/data`
  - Porta `5432:5432` publicada
  - Senha forte do superusuário `postgres` (uso exclusivo do professor)
- `docker-compose.yml` em `/opt/stackoverflow-db/` na VPS
- Dump guardado na VPS para permitir reset do banco em turmas futuras

## Carga dos dados

1. Transferir o dump para a VPS — preferência: `wget` direto do site da
   smartpostgres na própria VPS; fallback: SFTP via Termius ou `scp` do
   PowerShell do Windows
2. Criar roles `esse` (nologin) e `readaccess` (nologin) e o banco
   `stackoverflow` antes do restore
3. Restaurar com `pg_restore -d stackoverflow` dentro do container

## Acesso dos alunos

- Role `aluno` com `LOGIN`, senha, membro de `readaccess`
- Proteções na role:
  - `ALTER ROLE aluno SET statement_timeout = '60s'`
  - `ALTER ROLE aluno CONNECTION LIMIT 30`
- Dados de conexão distribuídos à turma: IP da VPS, porta 5432, banco
  `stackoverflow`, usuário `aluno` + senha

## Segurança

- Firewall da VPS liberando apenas SSH (22) e PostgreSQL (5432)
- Autenticação por senha `scram-sha-256`
- Superusuário `postgres` com senha forte, não distribuído aos alunos

## Validação (critérios de sucesso)

1. Conexão externa (do Windows do professor) como `aluno` funciona
2. `SELECT count(*) FROM posts` retorna dados
3. `INSERT`/`UPDATE`/`DELETE` como `aluno` são negados (permission denied)
4. Container reinicia automaticamente com a VPS (`restart: unless-stopped`)

## Manutenção

- Reset para nova turma: `DROP DATABASE` + recriar + `pg_restore` do dump
  guardado na VPS
