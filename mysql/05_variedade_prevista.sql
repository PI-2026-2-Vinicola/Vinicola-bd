-- Migração para bancos criados antes da previsão de variedade (a API também faz isso sozinha ao iniciar).
-- O MySQL não aceita IF NOT EXISTS em ADD COLUMN; a verificação no information_schema deixa o script
-- idempotente (também roda sem erro num banco novo, como no docker-entrypoint-initdb.d do compose).
SET @falta = (SELECT COUNT(*) = 0 FROM information_schema.columns
              WHERE table_schema = DATABASE() AND table_name = 'readings' AND column_name = 'predicted_variety');
SET @sql = IF(@falta, 'ALTER TABLE readings ADD COLUMN predicted_variety VARCHAR(40) NULL, ADD COLUMN variety_confidence DOUBLE NULL', 'DO 0');
PREPARE st FROM @sql; EXECUTE st; DEALLOCATE PREPARE st;
