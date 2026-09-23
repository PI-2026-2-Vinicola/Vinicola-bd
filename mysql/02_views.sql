-- =============================================================================
-- OSAIS · Visões analíticas (MySQL / MariaDB)
-- Horário local da propriedade: UTC-3 (America/Recife, sem horário de verão)
-- =============================================================================

CREATE OR REPLACE VIEW v_readings AS
SELECT r.id, r.code, r.sensor_id, s.name AS sensor_name, s.block, s.location,
       r.variety_id, v.name AS variety_name, v.type AS variety_type,
       r.captured_at,
       CONVERT_TZ(r.captured_at, '+00:00', '-03:00')       AS captured_local,
       DATE(CONVERT_TZ(r.captured_at, '+00:00', '-03:00')) AS local_day,
       r.quality, r.confidence, r.maturation, r.visual_condition, r.classification, r.observations,
       r.clusters_detected, r.model_version, r.processing_ms
  FROM readings r
  JOIN sensors   s ON s.id = r.sensor_id
  JOIN varieties v ON v.id = r.variety_id;

CREATE OR REPLACE VIEW v_quality_by_day AS
SELECT local_day, variety_id,
       COUNT(*)                   AS total,
       SUM(quality = 'boa')       AS boa,
       SUM(quality = 'atencao')   AS atencao,
       SUM(quality = 'critica')   AS critica,
       ROUND(AVG(confidence), 4)  AS avg_confidence
  FROM v_readings
 GROUP BY local_day, variety_id;

CREATE OR REPLACE VIEW v_quality_by_variety AS
SELECT v.id AS variety_id, v.name AS variety_name,
       COUNT(r.id)                                           AS total,
       COALESCE(SUM(r.quality = 'boa'), 0)                   AS boa,
       COALESCE(SUM(r.quality = 'atencao'), 0)               AS atencao,
       COALESCE(SUM(r.quality = 'critica'), 0)               AS critica,
       ROUND(AVG(r.confidence), 4)                           AS avg_confidence,
       ROUND(SUM(r.quality = 'boa') / NULLIF(COUNT(r.id), 0), 4) AS pct_boa
  FROM varieties v
  LEFT JOIN readings r ON r.variety_id = v.id
 GROUP BY v.id, v.name;

CREATE OR REPLACE VIEW v_sensor_activity AS
SELECT s.id AS sensor_id, s.name, s.block, s.location, s.status, s.battery, s.signal_dbm, s.last_communication,
       COUNT(r.id)                                                        AS readings_total,
       COALESCE(SUM(r.captured_at >= UTC_TIMESTAMP() - INTERVAL 7 DAY), 0) AS readings_7d,
       MAX(r.captured_at)                                                 AS last_reading_at,
       ROUND(SUM(r.quality = 'boa') / NULLIF(COUNT(r.id), 0), 4)          AS pct_boa
  FROM sensors s
  LEFT JOIN readings r ON r.sensor_id = s.id
 GROUP BY s.id, s.name, s.block, s.location, s.status, s.battery, s.signal_dbm, s.last_communication;

CREATE OR REPLACE VIEW v_alerts AS
SELECT code, captured_at, captured_local, sensor_id, block, variety_name, quality, classification, visual_condition, confidence, observations
  FROM v_readings
 WHERE quality <> 'boa';

CREATE OR REPLACE VIEW v_dashboard_7d AS
SELECT (SELECT COUNT(*) FROM sensors WHERE status <> 'offline') AS sensors_active,
       (SELECT COUNT(*) FROM sensors)                           AS sensors_total,
       COUNT(*)                                                 AS readings,
       COALESCE(SUM(clusters_detected), 0)                      AS clusters,
       COALESCE(SUM(quality = 'boa'), 0)                        AS boa,
       COALESCE(SUM(quality = 'atencao'), 0)                    AS atencao,
       COALESCE(SUM(quality = 'critica'), 0)                    AS critica,
       ROUND(SUM(quality = 'boa') / NULLIF(COUNT(*), 0), 4)     AS quality_ratio,
       ROUND(AVG(confidence), 4)                                AS avg_confidence
  FROM readings
 WHERE captured_at >= UTC_TIMESTAMP() - INTERVAL 7 DAY;

CREATE OR REPLACE VIEW v_detections AS
SELECT d.id, r.code, r.sensor_id, r.variety_id, r.captured_at, d.kind, d.label, d.confidence, d.x, d.y, d.w, d.h
  FROM detections d
  JOIN readings r ON r.id = d.reading_id;
