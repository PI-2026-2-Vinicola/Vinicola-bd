-- Migração para bancos criados antes da segurança por organização (a API também faz isso sozinha ao iniciar).
-- Cria as organizações, liga usuários, sensores e importações a uma organização e coloca os dados
-- existentes numa organização padrão. Idempotente.
BEGIN;

CREATE TABLE IF NOT EXISTS organizations (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(120) NOT NULL,
    city        VARCHAR(80),
    active      BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS ix_organizations_name ON organizations (name);

ALTER TABLE users       ADD COLUMN IF NOT EXISTS organization_id INTEGER REFERENCES organizations (id);
ALTER TABLE sensors     ADD COLUMN IF NOT EXISTS organization_id INTEGER REFERENCES organizations (id);
ALTER TABLE import_jobs ADD COLUMN IF NOT EXISTS organization_id INTEGER REFERENCES organizations (id);
CREATE INDEX IF NOT EXISTS ix_users_organization_id   ON users (organization_id);
CREATE INDEX IF NOT EXISTS ix_sensors_organization_id ON sensors (organization_id);

-- Dados existentes passam para a organização mais antiga (ou para uma "Organização padrão" nova).
-- Num banco vazio nada é criado: a API cria a organização padrão com o nome de OASIS_FARM_NAME.
INSERT INTO organizations (name) SELECT 'Organização padrão'
 WHERE NOT EXISTS (SELECT 1 FROM organizations)
   AND (EXISTS (SELECT 1 FROM sensors WHERE organization_id IS NULL)
          OR EXISTS (SELECT 1 FROM import_jobs WHERE organization_id IS NULL)
          OR EXISTS (SELECT 1 FROM users WHERE organization_id IS NULL AND role <> 'admin'));
UPDATE sensors     SET organization_id = (SELECT min(id) FROM organizations) WHERE organization_id IS NULL;
UPDATE import_jobs SET organization_id = (SELECT min(id) FROM organizations) WHERE organization_id IS NULL;
UPDATE users       SET organization_id = (SELECT min(id) FROM organizations) WHERE organization_id IS NULL AND role <> 'admin';

COMMIT;
