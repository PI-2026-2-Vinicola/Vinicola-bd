-- Migração para bancos criados antes da previsão de variedade (a API também faz isso sozinha ao iniciar).
-- MySQL 8.0.29+ / MariaDB 10.0+ aceitam IF NOT EXISTS em ADD COLUMN.
ALTER TABLE readings ADD COLUMN IF NOT EXISTS predicted_variety  VARCHAR(40);
ALTER TABLE readings ADD COLUMN IF NOT EXISTS variety_confidence DOUBLE;
