-- =============================================================================
-- OASIS — Observação Agroambiental Sensorizada, Inteligente e Sustentável
-- Esquema relacional · PostgreSQL 14+
--
-- Espelha os modelos SQLAlchemy da API (Vinicola-back/app/models.py).
-- Datas/horas em UTC (TIMESTAMPTZ); conversão para o fuso da propriedade nas visões.
-- =============================================================================

BEGIN;

-- Organizações (exportadoras): cada uma só acessa os próprios sensores, leituras, importações e clientes
CREATE TABLE IF NOT EXISTS organizations (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(120) NOT NULL,
    city        VARCHAR(80),
    active      BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS ix_organizations_name ON organizations (name);
COMMENT ON TABLE organizations IS 'Exportadoras (multi-organização): base do isolamento de dados entre empresas';

-- Clientes internacionais (importadores). Os campos *_enc guardam só o valor cifrado pela API
-- (AES-256-GCM, formato enc:v1:<id da chave>:<nonce>:<cifra+tag>); a chave nunca fica no banco.
CREATE TABLE IF NOT EXISTS international_clients (
    id                    SERIAL PRIMARY KEY,
    organization_id       INTEGER      NOT NULL REFERENCES organizations (id),
    company_name          VARCHAR(120) NOT NULL,
    country               VARCHAR(60)  NOT NULL,
    contact_name_enc      TEXT,                           -- dado pessoal (cifrado)
    email_enc             TEXT,                           -- dado pessoal (cifrado)
    phone_enc             TEXT,                           -- dado pessoal (cifrado)
    tax_id_enc            TEXT,                           -- identificação fiscal (cifrado)
    commercial_terms_enc  TEXT,                           -- segredo comercial: volume, preço, Incoterm (cifrado)
    active                BOOLEAN      NOT NULL DEFAULT TRUE,
    created_by            INTEGER,
    created_at            TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at            TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT uq_clients_org_company UNIQUE (organization_id, company_name)
);
CREATE INDEX IF NOT EXISTS ix_international_clients_organization_id ON international_clients (organization_id);
COMMENT ON TABLE international_clients IS 'Clientes internacionais; dados pessoais e comerciais cifrados pela aplicação';

-- Usuários da plataforma e perfis de acesso
CREATE TABLE IF NOT EXISTS users (
    id              SERIAL PRIMARY KEY,
    name            VARCHAR(120) NOT NULL,
    email           VARCHAR(160) NOT NULL,
    password_hash   VARCHAR(255) NOT NULL,              -- PBKDF2-SHA256 (nunca a senha em texto)
    role            VARCHAR(20)  NOT NULL,
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE, -- desativado = sem acesso, histórico preservado
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    last_login_at   TIMESTAMPTZ,
    organization_id INTEGER      REFERENCES organizations (id),          -- vazio só para o administrador
    client_id       INTEGER      REFERENCES international_clients (id) ON DELETE SET NULL,  -- perfil cliente
    CONSTRAINT ck_users_role CHECK (role IN ('admin','gestor','operador','cliente'))
);
CREATE UNIQUE INDEX IF NOT EXISTS ix_users_email ON users (email);
CREATE INDEX IF NOT EXISTS ix_users_organization_id ON users (organization_id);
COMMENT ON TABLE  users      IS 'Usuários da plataforma OASIS';
COMMENT ON COLUMN users.role IS 'admin = todas as organizações · gestor = exportadora (sensores, clientes, importação) · operador = campo e logística (fotos e medições) · cliente = cliente internacional (só leitura)';

-- Variedades de uva (catálogo de referência)
CREATE TABLE IF NOT EXISTS varieties (
    id                VARCHAR(40)  PRIMARY KEY,           -- ex.: cabernet-sauvignon
    name              VARCHAR(80)  NOT NULL,
    type              VARCHAR(10)  NOT NULL,
    color             VARCHAR(80)  NOT NULL,
    maturation_cycle  VARCHAR(60)  NOT NULL,
    origin            VARCHAR(120) NOT NULL,
    CONSTRAINT ck_varieties_type CHECK (type IN ('Tinta','Branca'))
);
COMMENT ON TABLE varieties IS 'Variedades monitoradas; o id corresponde à classe do modelo YOLO (com _ no lugar de -)';

-- Sensores IoT (ESP32 + câmera) instalados nos talhões.
-- O status (online/atenção/offline/inativo) não é gravado: é calculado a partir da
-- última comunicação, do intervalo de captura, da bateria e do sinal (visão v_sensor_status).
CREATE TABLE IF NOT EXISTS sensors (
    id                    VARCHAR(20)  PRIMARY KEY,       -- ex.: S-001
    name                  VARCHAR(80)  NOT NULL,
    block                 VARCHAR(40)  NOT NULL,          -- talhão / bloco
    location              VARCHAR(120) NOT NULL,
    latitude              DOUBLE PRECISION,               -- opcional: sem coordenadas o sensor não aparece no mapa
    longitude             DOUBLE PRECISION,
    variety_id            VARCHAR(40)  NOT NULL REFERENCES varieties (id),
    device                VARCHAR(60),
    firmware              VARCHAR(20),
    battery               INTEGER,                        -- último valor informado pelo dispositivo
    signal_dbm            INTEGER,
    capture_interval_min  INTEGER      NOT NULL DEFAULT 90,
    active                BOOLEAN      NOT NULL DEFAULT TRUE,
    installed_at          DATE,
    last_communication    TIMESTAMPTZ,
    device_token_hash     VARCHAR(255),                   -- hash do token individual do dispositivo
    organization_id       INTEGER      REFERENCES organizations (id),
    created_at            TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT ck_sensors_battery  CHECK (battery IS NULL OR battery BETWEEN 0 AND 100),
    CONSTRAINT ck_sensors_lat      CHECK (latitude  IS NULL OR latitude  BETWEEN -90  AND 90),
    CONSTRAINT ck_sensors_lng      CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180),
    CONSTRAINT ck_sensors_coords   CHECK ((latitude IS NULL) = (longitude IS NULL)),
    CONSTRAINT ck_sensors_interval CHECK (capture_interval_min BETWEEN 5 AND 1440)
);
CREATE INDEX IF NOT EXISTS ix_sensors_organization_id ON sensors (organization_id);
COMMENT ON TABLE sensors IS 'Dispositivos da camada Device (ESP32 + câmera)';

-- Leituras: cada imagem analisada (ou registro importado) e seu resultado
CREATE TABLE IF NOT EXISTS readings (
    id                 SERIAL PRIMARY KEY,
    code               VARCHAR(16) UNIQUE,                -- identificador público: OA-00001
    sensor_id          VARCHAR(20) NOT NULL REFERENCES sensors (id),
    captured_at        TIMESTAMPTZ NOT NULL,
    variety_id         VARCHAR(40) NOT NULL REFERENCES varieties (id),
    quality            VARCHAR(10) NOT NULL,              -- boa · atencao · critica
    confidence         DOUBLE PRECISION NOT NULL,         -- confiança da detecção (0–1)
    maturation         VARCHAR(20) NOT NULL,
    visual_condition   VARCHAR(60) NOT NULL,
    classification     VARCHAR(30) NOT NULL,              -- APROVADA · EM OBSERVAÇÃO · REVISÃO NECESSÁRIA
    observations       TEXT        NOT NULL,
    clusters_detected  INTEGER     NOT NULL DEFAULT 1,
    image_path         VARCHAR(255),                      -- imagem processada (sem EXIF)
    thumb_path         VARCHAR(255),                      -- miniatura para listagens
    source             VARCHAR(20) NOT NULL DEFAULT 'sensor',
    model_version      VARCHAR(80) NOT NULL,
    predicted_variety  VARCHAR(40),                         -- variedade prevista pela foto (classificador YOLO de variedades)
    variety_confidence DOUBLE PRECISION,                         -- probabilidade da previsão (0–1)
    processing_ms      INTEGER     NOT NULL DEFAULT 0,
    stage              VARCHAR(12) NOT NULL DEFAULT 'concluida',
    created_by         INTEGER     REFERENCES users (id) ON DELETE SET NULL,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_readings_sensor_time UNIQUE (sensor_id, captured_at),
    CONSTRAINT ck_readings_quality    CHECK (quality IN ('boa','atencao','critica')),
    CONSTRAINT ck_readings_stage      CHECK (stage IN ('recebida','processando','analisando','concluida')),
    CONSTRAINT ck_readings_maturation CHECK (maturation IN ('desenvolvimento','pintor','maturacao','adequada','sobrematuracao','nao_informada')),
    CONSTRAINT ck_readings_confidence CHECK (confidence BETWEEN 0 AND 1),
    CONSTRAINT ck_readings_source     CHECK (source IN ('sensor','upload','importacao','demonstracao'))
);
CREATE INDEX IF NOT EXISTS ix_readings_captured_at  ON readings (captured_at);
CREATE INDEX IF NOT EXISTS ix_readings_variety_time ON readings (variety_id, captured_at);
CREATE INDEX IF NOT EXISTS ix_readings_quality_time ON readings (quality, captured_at);
CREATE INDEX IF NOT EXISTS ix_readings_alerts       ON readings (captured_at) WHERE quality <> 'boa';
COMMENT ON TABLE  readings        IS 'Resultado de cada imagem processada: Sensor → Imagem → Análise → Classificação';
COMMENT ON COLUMN readings.source IS 'sensor = dispositivo · upload = envio manual no painel · importacao = arquivo CSV/Excel/JSON · demonstracao = dados sintéticos';

-- Caixas detectadas (coordenadas normalizadas 0–1, padrão YOLO)
CREATE TABLE IF NOT EXISTS detections (
    id          SERIAL PRIMARY KEY,
    reading_id  INTEGER NOT NULL REFERENCES readings (id) ON DELETE CASCADE,
    kind        VARCHAR(10) NOT NULL,                     -- cacho · anomalia
    label       VARCHAR(40) NOT NULL,                     -- classe do modelo
    confidence  DOUBLE PRECISION NOT NULL,
    x           DOUBLE PRECISION NOT NULL,                -- canto superior esquerdo
    y           DOUBLE PRECISION NOT NULL,
    w           DOUBLE PRECISION NOT NULL,
    h           DOUBLE PRECISION NOT NULL,
    CONSTRAINT ck_detections_kind CHECK (kind IN ('cacho','anomalia')),
    CONSTRAINT ck_detections_box  CHECK (x >= 0 AND y >= 0 AND w > 0 AND h > 0 AND x + w <= 1.0001 AND y + h <= 1.0001)
);
CREATE INDEX IF NOT EXISTS ix_detections_reading_id ON detections (reading_id);

-- Telemetria dos dispositivos (bateria, sinal Wi-Fi, firmware)
CREATE TABLE IF NOT EXISTS sensor_telemetry (
    id           SERIAL PRIMARY KEY,
    sensor_id    VARCHAR(20) NOT NULL REFERENCES sensors (id) ON DELETE CASCADE,
    received_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    battery      INTEGER,
    signal_dbm   INTEGER,
    firmware     VARCHAR(20)
);
CREATE INDEX IF NOT EXISTS ix_sensor_telemetry_sensor_time ON sensor_telemetry (sensor_id, received_at);

-- Medições ambientais do talhão (DHT22, luxímetro, umidade do solo ou importação)
CREATE TABLE IF NOT EXISTS environment_readings (
    id                 SERIAL PRIMARY KEY,
    sensor_id          VARCHAR(20) NOT NULL REFERENCES sensors (id) ON DELETE CASCADE,
    measured_at        TIMESTAMPTZ NOT NULL,
    temperature_c      DOUBLE PRECISION,
    humidity_pct       DOUBLE PRECISION,
    luminosity_lux     DOUBLE PRECISION,
    soil_moisture_pct  DOUBLE PRECISION,
    source             VARCHAR(20) NOT NULL DEFAULT 'sensor',
    CONSTRAINT uq_environment_sensor_time UNIQUE (sensor_id, measured_at),
    CONSTRAINT ck_environment_temperature CHECK (temperature_c IS NULL OR temperature_c BETWEEN -20 AND 60),
    CONSTRAINT ck_environment_humidity    CHECK (humidity_pct IS NULL OR humidity_pct BETWEEN 0 AND 100),
    CONSTRAINT ck_environment_luminosity  CHECK (luminosity_lux IS NULL OR luminosity_lux BETWEEN 0 AND 200000),
    CONSTRAINT ck_environment_soil        CHECK (soil_moisture_pct IS NULL OR soil_moisture_pct BETWEEN 0 AND 100),
    CONSTRAINT ck_environment_source      CHECK (source IN ('sensor','manual','importacao','demonstracao'))
);
CREATE INDEX IF NOT EXISTS ix_environment_sensor_time ON environment_readings (sensor_id, measured_at);

-- Registro de cada importação de arquivo (resumo e erros por linha)
CREATE TABLE IF NOT EXISTS import_jobs (
    id           SERIAL PRIMARY KEY,
    kind         VARCHAR(20)  NOT NULL,                   -- readings · sensors · environment
    filename     VARCHAR(255) NOT NULL,
    status       VARCHAR(20)  NOT NULL,                   -- concluida · parcial · sem_alteracoes · falhou
    total_rows   INTEGER      NOT NULL DEFAULT 0,
    inserted     INTEGER      NOT NULL DEFAULT 0,
    updated      INTEGER      NOT NULL DEFAULT 0,
    duplicates   INTEGER      NOT NULL DEFAULT 0,
    invalid      INTEGER      NOT NULL DEFAULT 0,
    errors_json  TEXT         NOT NULL DEFAULT '[]',      -- [{row, field, message}]
    created_by   INTEGER      REFERENCES users (id) ON DELETE SET NULL,
    organization_id INTEGER   REFERENCES organizations (id),
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT ck_import_kind   CHECK (kind IN ('readings','sensors','environment')),
    CONSTRAINT ck_import_status CHECK (status IN ('concluida','parcial','sem_alteracoes','falhou'))
);

-- Trilha de auditoria (logins, acessos negados, consultas a dados sensíveis, usuários, sensores, importações, exclusões)
CREATE TABLE IF NOT EXISTS audit_log (
    id          SERIAL PRIMARY KEY,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    actor       VARCHAR(160),
    action      VARCHAR(60)  NOT NULL,
    target      VARCHAR(160),
    details     TEXT,                                     -- JSON com os detalhes da ação
    ip          VARCHAR(64)
);
CREATE INDEX IF NOT EXISTS ix_audit_created_at ON audit_log (created_at);

COMMIT;
