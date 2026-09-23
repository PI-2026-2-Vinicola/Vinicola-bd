-- =============================================================================
-- OSAIS — Observação Agroambiental Sensorizada, Inteligente e Sustentável
-- Esquema relacional · PostgreSQL 14+
--
-- Espelha exatamente os modelos SQLAlchemy da API (Vinicola-back/app/models.py).
-- Datas/horas em UTC (TIMESTAMPTZ); conversão para America/Recife nas visões.
-- =============================================================================

BEGIN;

-- Usuários da plataforma e perfis de acesso
CREATE TABLE IF NOT EXISTS users (
    id              SERIAL PRIMARY KEY,
    name            VARCHAR(120) NOT NULL,
    email           VARCHAR(160) NOT NULL,
    password_hash   VARCHAR(255) NOT NULL,              -- PBKDF2-SHA256 (nunca a senha em texto)
    role            VARCHAR(20)  NOT NULL,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT ck_users_role CHECK (role IN ('admin','gestor','operador'))
);
CREATE UNIQUE INDEX IF NOT EXISTS ix_users_email ON users (email);
COMMENT ON TABLE  users      IS 'Usuários da plataforma OSAIS';
COMMENT ON COLUMN users.role IS 'admin = acesso total · gestor = dashboard, sensores, análises e histórico · operador = leituras, imagens e resultados';

-- Variedades de uva cultivadas (biblioteca educacional)
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

-- Sensores IoT (ESP32 + câmera) instalados nos talhões
CREATE TABLE IF NOT EXISTS sensors (
    id                    VARCHAR(10)  PRIMARY KEY,       -- ex.: S-001
    name                  VARCHAR(80)  NOT NULL,
    block                 VARCHAR(40)  NOT NULL,          -- talhão
    location              VARCHAR(120) NOT NULL,
    latitude              DOUBLE PRECISION NOT NULL,
    longitude             DOUBLE PRECISION NOT NULL,
    variety_id            VARCHAR(40)  NOT NULL REFERENCES varieties (id),
    device                VARCHAR(60)  NOT NULL,
    firmware              VARCHAR(20)  NOT NULL,
    battery               INTEGER      NOT NULL DEFAULT 100,
    signal_dbm            INTEGER      NOT NULL DEFAULT -60,
    capture_interval_min  INTEGER      NOT NULL DEFAULT 90,
    status                VARCHAR(10)  NOT NULL DEFAULT 'online',
    installed_at          DATE         NOT NULL,
    last_communication    TIMESTAMPTZ,
    device_token_hash     VARCHAR(255),                   -- hash do token individual do dispositivo
    CONSTRAINT ck_sensors_status  CHECK (status IN ('online','atencao','offline')),
    CONSTRAINT ck_sensors_battery CHECK (battery BETWEEN 0 AND 100),
    CONSTRAINT ck_sensors_lat     CHECK (latitude  BETWEEN -90  AND 90),
    CONSTRAINT ck_sensors_lng     CHECK (longitude BETWEEN -180 AND 180)
);
COMMENT ON TABLE sensors IS 'Dispositivos da camada Device (ESP32 + câmera)';

-- Leituras: cada imagem capturada e o resultado da análise pela IA
CREATE TABLE IF NOT EXISTS readings (
    id                 SERIAL PRIMARY KEY,
    code               VARCHAR(16) UNIQUE,                -- identificador público: OS-00001
    sensor_id          VARCHAR(10) NOT NULL REFERENCES sensors (id),
    captured_at        TIMESTAMPTZ NOT NULL,
    variety_id         VARCHAR(40) NOT NULL REFERENCES varieties (id),
    quality            VARCHAR(10) NOT NULL,              -- boa · atencao · critica
    confidence         DOUBLE PRECISION NOT NULL,         -- confiança do modelo (0–1)
    maturation         VARCHAR(20) NOT NULL,
    visual_condition   VARCHAR(60) NOT NULL,
    classification     VARCHAR(30) NOT NULL,              -- APROVADA · EM OBSERVAÇÃO · REVISÃO NECESSÁRIA
    observations       TEXT        NOT NULL,
    clusters_detected  INTEGER     NOT NULL DEFAULT 1,
    image_path         VARCHAR(255),                      -- caminho no armazenamento de imagens
    image_seed         INTEGER     NOT NULL DEFAULT 0,    -- usado pela ilustração do modo demonstração
    model_version      VARCHAR(60) NOT NULL,
    processing_ms      INTEGER     NOT NULL DEFAULT 0,
    stage              VARCHAR(12) NOT NULL DEFAULT 'concluida',
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_readings_quality    CHECK (quality IN ('boa','atencao','critica')),
    CONSTRAINT ck_readings_stage      CHECK (stage IN ('recebida','processando','analisando','concluida')),
    CONSTRAINT ck_readings_maturation CHECK (maturation IN ('desenvolvimento','pintor','maturacao','adequada','sobrematuracao')),
    CONSTRAINT ck_readings_confidence CHECK (confidence BETWEEN 0 AND 1)
);
CREATE INDEX IF NOT EXISTS ix_readings_captured_at  ON readings (captured_at);
CREATE INDEX IF NOT EXISTS ix_readings_sensor_time  ON readings (sensor_id, captured_at);
CREATE INDEX IF NOT EXISTS ix_readings_variety_time ON readings (variety_id, captured_at);
CREATE INDEX IF NOT EXISTS ix_readings_alerts       ON readings (captured_at) WHERE quality <> 'boa';
COMMENT ON TABLE readings IS 'Resultado de cada imagem processada: Sensor → Imagem → YOLO → Classificação';

-- Caixas detectadas pelo YOLO (coordenadas normalizadas 0–1)
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
    sensor_id    VARCHAR(10) NOT NULL REFERENCES sensors (id),
    received_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    battery      INTEGER,
    signal_dbm   INTEGER,
    firmware     VARCHAR(20)
);
CREATE INDEX IF NOT EXISTS ix_sensor_telemetry_sensor_id ON sensor_telemetry (sensor_id);

COMMIT;
