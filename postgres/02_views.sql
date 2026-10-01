-- =============================================================================
-- OASIS · Visões analíticas (PostgreSQL) — apoio a relatórios e Data Science
-- Fuso da propriedade: America/Recife (UTC-3). Ajuste se OASIS_TIMEZONE for outro.
-- =============================================================================

-- Status calculado dos sensores (mesma regra da API, com SENSOR_OFFLINE_FACTOR = 3)
CREATE OR REPLACE VIEW v_sensor_status AS
SELECT s.*,
       CASE
         WHEN NOT s.active THEN 'inativo'
         WHEN s.last_communication IS NULL
              OR now() - s.last_communication > make_interval(mins => s.capture_interval_min * 3) THEN 'offline'
         WHEN s.battery < 25 OR s.signal_dbm <= -80
              OR now() - s.last_communication > make_interval(mins => (s.capture_interval_min * 1.5)::int) THEN 'atencao'
         ELSE 'online'
       END AS status
  FROM sensors s;

-- Leituras com dados do sensor e da variedade, em horário local
CREATE OR REPLACE VIEW v_readings AS
SELECT r.id,
       r.code,
       r.sensor_id,
       s.name                                              AS sensor_name,
       s.block,
       s.location,
       r.variety_id,
       v.name                                              AS variety_name,
       v.type                                              AS variety_type,
       r.captured_at,
       (r.captured_at AT TIME ZONE 'America/Recife')       AS captured_local,
       (r.captured_at AT TIME ZONE 'America/Recife')::date AS local_day,
       r.quality,
       r.confidence,
       r.maturation,
       r.visual_condition,
       r.classification,
       r.observations,
       r.clusters_detected,
       r.source,
       r.model_version,
       r.processing_ms
  FROM readings r
  JOIN sensors   s ON s.id = r.sensor_id
  JOIN varieties v ON v.id = r.variety_id;

-- Evolução diária por variedade
CREATE OR REPLACE VIEW v_quality_by_day AS
SELECT local_day,
       variety_id,
       COUNT(*)                                         AS total,
       COUNT(*) FILTER (WHERE quality = 'boa')          AS boa,
       COUNT(*) FILTER (WHERE quality = 'atencao')      AS atencao,
       COUNT(*) FILTER (WHERE quality = 'critica')      AS critica,
       ROUND(AVG(confidence)::numeric, 4)               AS avg_confidence
  FROM v_readings
 GROUP BY local_day, variety_id;

-- Histórico por variedade (total, Boa, Atenção, Necessita atenção)
CREATE OR REPLACE VIEW v_quality_by_variety AS
SELECT v.id                                                          AS variety_id,
       v.name                                                        AS variety_name,
       COUNT(r.id)                                                   AS total,
       COUNT(r.id) FILTER (WHERE r.quality = 'boa')                  AS boa,
       COUNT(r.id) FILTER (WHERE r.quality = 'atencao')              AS atencao,
       COUNT(r.id) FILTER (WHERE r.quality = 'critica')              AS critica,
       ROUND(AVG(r.confidence)::numeric, 4)                          AS avg_confidence,
       ROUND((COUNT(r.id) FILTER (WHERE r.quality = 'boa'))::numeric / NULLIF(COUNT(r.id), 0), 4) AS pct_boa
  FROM varieties v
  LEFT JOIN readings r ON r.variety_id = v.id
 GROUP BY v.id, v.name;

-- Atividade dos sensores
CREATE OR REPLACE VIEW v_sensor_activity AS
SELECT s.id                                                                AS sensor_id,
       s.name,
       s.block,
       s.location,
       s.status,
       s.battery,
       s.signal_dbm,
       s.last_communication,
       COUNT(r.id)                                                         AS readings_total,
       COUNT(r.id) FILTER (WHERE r.captured_at >= now() - interval '7 days') AS readings_7d,
       MAX(r.captured_at)                                                  AS last_reading_at,
       ROUND((COUNT(r.id) FILTER (WHERE r.quality = 'boa'))::numeric / NULLIF(COUNT(r.id), 0), 4) AS pct_boa
  FROM v_sensor_status s
  LEFT JOIN readings r ON r.sensor_id = s.id
 GROUP BY s.id, s.name, s.block, s.location, s.status, s.battery, s.signal_dbm, s.last_communication;

-- Leituras que precisam de atenção (alertas)
CREATE OR REPLACE VIEW v_alerts AS
SELECT code, captured_at, captured_local, sensor_id, block, variety_name, quality, classification, visual_condition, confidence, observations, source
  FROM v_readings
 WHERE quality <> 'boa';

-- Indicadores dos últimos 7 dias
CREATE OR REPLACE VIEW v_dashboard_7d AS
WITH r AS (SELECT * FROM readings WHERE captured_at >= now() - interval '7 days')
SELECT (SELECT COUNT(*) FROM v_sensor_status WHERE status IN ('online','atencao')) AS sensors_communicating,
       (SELECT COUNT(*) FROM sensors WHERE active)                                  AS sensors_active,
       COUNT(*)                                                                     AS readings,
       COALESCE(SUM(clusters_detected), 0)                                          AS clusters,
       COUNT(*) FILTER (WHERE quality = 'boa')                                      AS boa,
       COUNT(*) FILTER (WHERE quality = 'atencao')                                  AS atencao,
       COUNT(*) FILTER (WHERE quality = 'critica')                                  AS critica,
       ROUND((COUNT(*) FILTER (WHERE quality = 'boa'))::numeric / NULLIF(COUNT(*), 0), 4) AS quality_ratio,
       ROUND(AVG(confidence)::numeric, 4)                                           AS avg_confidence
  FROM r;

-- Médias diárias das medições ambientais
CREATE OR REPLACE VIEW v_environment_daily AS
SELECT sensor_id,
       (measured_at AT TIME ZONE 'America/Recife')::date AS local_day,
       COUNT(*)                                          AS measurements,
       ROUND(AVG(temperature_c)::numeric, 1)             AS avg_temperature_c,
       MIN(temperature_c)                                AS min_temperature_c,
       MAX(temperature_c)                                AS max_temperature_c,
       ROUND(AVG(humidity_pct)::numeric, 1)              AS avg_humidity_pct,
       ROUND(AVG(luminosity_lux)::numeric, 0)            AS avg_luminosity_lux,
       ROUND(AVG(soil_moisture_pct)::numeric, 1)         AS avg_soil_moisture_pct
  FROM environment_readings
 GROUP BY sensor_id, local_day;

-- Detecções com contexto (treino/validação de modelos, análise de anomalias)
CREATE OR REPLACE VIEW v_detections AS
SELECT d.id, r.code, r.sensor_id, r.variety_id, r.captured_at, r.source, d.kind, d.label, d.confidence, d.x, d.y, d.w, d.h
  FROM detections d
  JOIN readings r ON r.id = d.reading_id;

-- Importações com o nome de quem executou
CREATE OR REPLACE VIEW v_import_jobs AS
SELECT j.id, j.created_at, u.name AS created_by_name, j.kind, j.filename, j.status,
       j.total_rows, j.inserted, j.updated, j.duplicates, j.invalid
  FROM import_jobs j
  LEFT JOIN users u ON u.id = j.created_by;
