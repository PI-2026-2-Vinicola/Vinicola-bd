-- Migração para bancos que receberam o cadastro de clientes internacionais (já removido do projeto).
-- Usuários do perfil "cliente" viram operadores desativados (nenhum acesso novo é concedido; o administrador
-- decide se reativa), e a tabela international_clients e a coluna users.client_id são apagadas.
-- Idempotente: cada alteração só roda se ainda for necessária. MySQL 8.0.19+ (DROP CHECK).
SET NAMES utf8mb4;

-- Restrição de perfis sem o "cliente" (os usuários dele viram operadores desativados antes)
SET @falta = (SELECT COUNT(*) > 0 FROM information_schema.check_constraints
              WHERE constraint_schema = DATABASE() AND constraint_name = 'ck_users_role' AND check_clause LIKE '%cliente%');
SET @sql = IF(@falta, 'UPDATE users SET role = ''operador'', is_active = FALSE WHERE role = ''cliente''', 'DO 0');
PREPARE st FROM @sql; EXECUTE st; DEALLOCATE PREPARE st;
SET @sql = IF(@falta, 'ALTER TABLE users DROP CHECK ck_users_role', 'DO 0');
PREPARE st FROM @sql; EXECUTE st; DEALLOCATE PREPARE st;
SET @sql = IF(@falta, 'ALTER TABLE users ADD CONSTRAINT ck_users_role CHECK (role IN (''admin'',''gestor'',''operador''))', 'DO 0');
PREPARE st FROM @sql; EXECUTE st; DEALLOCATE PREPARE st;

-- Chave estrangeira e coluna users.client_id
SET @falta = (SELECT COUNT(*) > 0 FROM information_schema.table_constraints
              WHERE constraint_schema = DATABASE() AND table_name = 'users' AND constraint_name = 'fk_users_client');
SET @sql = IF(@falta, 'ALTER TABLE users DROP FOREIGN KEY fk_users_client', 'DO 0');
PREPARE st FROM @sql; EXECUTE st; DEALLOCATE PREPARE st;
SET @falta = (SELECT COUNT(*) > 0 FROM information_schema.columns
              WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'client_id');
SET @sql = IF(@falta, 'ALTER TABLE users DROP COLUMN client_id', 'DO 0');
PREPARE st FROM @sql; EXECUTE st; DEALLOCATE PREPARE st;

DROP TABLE IF EXISTS international_clients;
