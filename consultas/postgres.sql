-- =============================================================================
-- OSAIS · Consultas de referência (PostgreSQL)
-- Respondem às perguntas-chave da plataforma.
-- =============================================================================

-- Onde estão os sensores? (status e última leitura)
SELECT sensor_id, name, location, status, last_communication, last_reading_at, readings_7d
  FROM v_sensor_activity ORDER BY sensor_id;

-- Quantas análises foram feitas? (hoje, 7 e 30 dias)
SELECT COUNT(*) FILTER (WHERE local_day = (now() AT TIME ZONE 'America/Recife')::date) AS hoje,
       COUNT(*) FILTER (WHERE captured_at >= now() - interval '7 days')               AS ultimos_7_dias,
       COUNT(*) FILTER (WHERE captured_at >= now() - interval '30 days')              AS ultimos_30_dias
  FROM v_readings;

-- Quais uvas foram identificadas e como está a qualidade?
SELECT variety_name, total, boa, atencao, critica, pct_boa, avg_confidence
  FROM v_quality_by_variety ORDER BY total DESC;

-- Quais análises precisam de atenção? (últimas 20)
SELECT code, captured_local, sensor_id, variety_name, classification, visual_condition, confidence
  FROM v_alerts ORDER BY captured_at DESC LIMIT 20;

-- Como os resultados estão evoluindo? (% Boa por dia, últimos 14 dias)
SELECT local_day,
       SUM(total)                                          AS total,
       ROUND(SUM(boa)::numeric / NULLIF(SUM(total), 0), 3) AS pct_boa
  FROM v_quality_by_day
 WHERE local_day >= (now() AT TIME ZONE 'America/Recife')::date - 13
 GROUP BY local_day ORDER BY local_day;

-- Histórico individual do sensor S-001 (ex.: "10/09 — 10:30 — Cabernet Sauvignon — Boa")
SELECT to_char(captured_local, 'DD/MM — HH24:MI') AS quando, variety_name,
       CASE quality WHEN 'boa' THEN 'Boa' WHEN 'atencao' THEN 'Atenção' ELSE 'Necessita atenção' END AS qualidade
  FROM v_readings WHERE sensor_id = 'S-001' ORDER BY captured_at DESC LIMIT 20;

-- Anomalias mais frequentes por variedade (apoio ao manejo)
SELECT r.variety_id, d.label, COUNT(*) AS ocorrencias, ROUND(AVG(d.confidence)::numeric, 3) AS confianca_media
  FROM detections d JOIN readings r ON r.id = d.reading_id
 WHERE d.kind = 'anomalia'
 GROUP BY r.variety_id, d.label ORDER BY ocorrencias DESC;

-- Exportação para Data Science (CSV) — execute no psql:
-- \copy (SELECT * FROM v_readings ORDER BY captured_at) TO 'osais_readings.csv' WITH CSV HEADER
