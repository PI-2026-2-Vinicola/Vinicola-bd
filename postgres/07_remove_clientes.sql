-- Migração para bancos que receberam o cadastro de clientes internacionais (já removido do projeto).
-- Usuários do perfil "cliente" viram operadores desativados (nenhum acesso novo é concedido; o administrador
-- decide se reativa), e a tabela international_clients e a coluna users.client_id são apagadas.
-- Idempotente: num banco novo, ou já ajustado, não altera nada.
BEGIN;

UPDATE users SET role = 'operador', is_active = FALSE WHERE role = 'cliente';
ALTER TABLE users DROP CONSTRAINT IF EXISTS ck_users_role;
ALTER TABLE users ADD  CONSTRAINT ck_users_role CHECK (role IN ('admin','gestor','operador'));

ALTER TABLE users DROP COLUMN IF EXISTS client_id;
DROP TABLE IF EXISTS international_clients;

COMMIT;
