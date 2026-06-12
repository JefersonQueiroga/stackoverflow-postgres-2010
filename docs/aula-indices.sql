-- ============================================================
-- AULA PRÁTICA: A importância dos índices
-- Banco: stackoverflow (Stack Overflow 2010, PostgreSQL 15)
--
-- A tabela votes tem 9,4 MILHÕES de linhas e nenhum índice
-- além da chave primária — cenário perfeito para a demonstração.
--
-- Papéis:
--   * Alunos (usuário aluno): rodam os SELECTs e EXPLAIN ANALYZE
--   * Professor (usuário postgres): cria e remove os índices
-- ============================================================

-- ------------------------------------------------------------
-- PARTE 1: Conhecendo os índices existentes
-- ------------------------------------------------------------
SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;

-- Pergunta para a turma: a tabela votes (a maior do banco)
-- tem índice em postid? E a posts em creationdate?

-- ------------------------------------------------------------
-- PARTE 2: Consulta SEM índice (todos rodam)
-- ------------------------------------------------------------
-- Quantas linhas tem a tabela votes?
SELECT count(*) FROM votes;          -- ~9.463.843

-- Buscar os votos de um post específico:
EXPLAIN ANALYZE
SELECT * FROM votes WHERE postid = 116712;

-- O que observar no plano:
--   * "Parallel Seq Scan on votes"  -> leu a tabela INTEIRA
--   * "Rows Removed by Filter: ~3.1 milhões (x3 workers)"
--   * Execution Time: ~400-500 ms para devolver 2 linhas!
--
-- Analogia: procurar um nome numa lista telefônica SEM ordem
-- alfabética — só lendo página por página.

-- ------------------------------------------------------------
-- PARTE 3: Criando o índice (SÓ O PROFESSOR — usuário postgres)
-- ------------------------------------------------------------
-- Os alunos não têm permissão de escrita; o professor roda ao vivo
-- e a turma cronometra (~15-30 s para indexar 9,4M de linhas):
CREATE INDEX votes_postid ON votes (postid);

-- Mostrar o tamanho do índice recém-criado:
SELECT pg_size_pretty(pg_relation_size('votes_postid')) AS tamanho_indice,
       pg_size_pretty(pg_relation_size('votes'))        AS tamanho_tabela;

-- ------------------------------------------------------------
-- PARTE 4: A mesma consulta COM índice (todos rodam de novo)
-- ------------------------------------------------------------
EXPLAIN ANALYZE
SELECT * FROM votes WHERE postid = 116712;

-- O que observar agora:
--   * "Index Scan using votes_postid"
--   * Execution Time: < 1 ms  (500x ou mais de melhoria!)
--
-- Analogia: agora a lista telefônica tem índice remissivo.

-- ------------------------------------------------------------
-- PARTE 5: O índice não é bala de prata
-- ------------------------------------------------------------
-- 5a. Baixa seletividade: filtrar por votetypeid = 2 (upvote,
--     ~80% da tabela). O planner IGNORA o índice de propósito:
CREATE INDEX votes_votetypeid ON votes (votetypeid);   -- professor

EXPLAIN ANALYZE
SELECT count(*) FROM votes WHERE votetypeid = 2;
-- Continua Seq Scan! Índice só vale a pena quando filtra POUCAS linhas.

-- 5b. Função sobre a coluna invalida o índice:
EXPLAIN ANALYZE
SELECT * FROM users WHERE lower(displayname) = 'jon skeet';
-- Seq Scan, apesar do índice users_displayname existir.
-- Solução: índice de expressão (mostrar como professor):
--   CREATE INDEX users_displayname_lower ON users (lower(displayname));

-- 5c. Custo de escrita: todo INSERT/UPDATE agora atualiza
--     a tabela E os índices. Índice demais = escrita lenta.

-- ------------------------------------------------------------
-- PARTE 6: Limpeza (professor) — deixa pronto para a próxima turma
-- ------------------------------------------------------------
DROP INDEX IF EXISTS votes_postid;
DROP INDEX IF EXISTS votes_votetypeid;
DROP INDEX IF EXISTS users_displayname_lower;

-- ------------------------------------------------------------
-- EXTRAS para exercícios
-- ------------------------------------------------------------
-- 1. posts.creationdate não tem índice: medir busca por período,
--    criar o índice, medir de novo.
-- 2. badges.name não tem índice: quantos usuários têm a badge 'Epic'?
-- 3. Self-join: perguntas com mais respostas (r.parentid = p.id usa
--    o índice posts_parentid — mostrar no EXPLAIN).
-- 4. Comparar EXPLAIN (estimativa) vs EXPLAIN ANALYZE (execução real).
