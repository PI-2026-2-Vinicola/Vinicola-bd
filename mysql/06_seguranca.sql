-- Migração para bancos criados antes da segurança por organização (a API também faz isso sozinha ao iniciar).
-- Idempotente: cada alteração só roda se ainda faltar (o MySQL não aceita IF NOT EXISTS em ADD COLUMN).
-- MySQL 8.0.16+.
SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS organizations (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    name        VARCHAR(120) NOT NULL,
    city        VARCHAR(80)  NULL,
    active      BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at  DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    UNIQUE KEY ix_organizations_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Exportadoras: base do isolamento de dados';

-- Executa @sql só quando @falta = 1
SET @falta = (SELECT COUNT(*) = 0 FROM information_schema.columns
              WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'organization_id');
SET @sql = IF(@falta, 'ALTER TABLE users
    ADD COLUMN organization_id INT NULL,
    ADD KEY ix_users_organization_id (organization_id),
    ADD CONSTRAINT fk_users_organization FOREIGN KEY (organization_id) REFERENCES organizations (id)', 'DO 0');
PREPARE st FROM @sql; EXECUTE st; DEALLOCATE PREPARE st;

SET @falta = (SELECT COUNT(*) = 0 FROM information_schema.columns
              WHERE table_schema = DATABASE() AND table_name = 'sensors' AND column_name = 'organization_id');
SET @sql = IF(@falta, 'ALTER TABLE sensors
    ADD COLUMN organization_id INT NULL,
    ADD KEY ix_sensors_organization_id (organization_id),
    ADD CONSTRAINT fk_sensors_organization FOREIGN KEY (organization_id) REFERENCES organizations (id)', 'DO 0');
PREPARE st FROM @sql; EXECUTE st; DEALLOCATE PREPARE st;

SET @falta = (SELECT COUNT(*) = 0 FROM information_schema.columns
              WHERE table_schema = DATABASE() AND table_name = 'import_jobs' AND column_name = 'organization_id');
SET @sql = IF(@falta, 'ALTER TABLE import_jobs
    ADD COLUMN organization_id INT NULL,
    ADD CONSTRAINT fk_import_organization FOREIGN KEY (organization_id) REFERENCES organizations (id)', 'DO 0');
PREPARE st FROM @sql; EXECUTE st; DEALLOCATE PREPARE st;

-- Dados existentes passam para a organização mais antiga (ou para uma "Organização padrão" nova).
-- Num banco vazio nada é criado: a API cria a organização padrão com o nome de OASIS_FARM_NAME.
INSERT INTO organizations (name) SELECT 'Organização padrão' FROM DUAL
 WHERE NOT EXISTS (SELECT 1 FROM organizations)
   AND (EXISTS (SELECT 1 FROM sensors WHERE organization_id IS NULL)
          OR EXISTS (SELECT 1 FROM import_jobs WHERE organization_id IS NULL)
          OR EXISTS (SELECT 1 FROM users WHERE organization_id IS NULL AND role <> 'admin'));
SET @org = (SELECT MIN(id) FROM organizations);
UPDATE sensors     SET organization_id = @org WHERE organization_id IS NULL;
UPDATE import_jobs SET organization_id = @org WHERE organization_id IS NULL;
UPDATE users       SET organization_id = @org WHERE organization_id IS NULL AND role <> 'admin';
