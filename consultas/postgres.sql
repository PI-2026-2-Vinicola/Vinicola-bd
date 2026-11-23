-- =============================================================================
-- OASIS · Consultas de referência (PostgreSQL)
-- Respondem às perguntas-chave da plataforma.
-- =============================================================================

-- Onde estão os sensores? (status calculado e última leitura)
SELECT sensor_id, name, location, status, last_communication, last_reading_at, readings_7d
  FROM v_sensor_activity ORDER BY sensor_id;

-- Sensores sem coordenadas (não aparecem no mapa)
SELECT id, name, block FROM sensors WHERE latitude IS NULL ORDER BY id;

-- Quantas análises foram feitas? (hoje, 7 e 30 dias, sem dados de demonstração)
SELECT COUNT(*) FILTER (WHERE local_day = (now() AT TIME ZONE 'America/Recife')::date) AS hoje,
       COUNT(*) FILTER (WHERE captured_at >= now() - interval '7 days')               AS ultimos_7_dias,
       COUNT(*) FILTER (WHERE captured_at >= now() - interval '30 days')              AS ultimos_30_dias
  FROM v_readings
 WHERE source <> 'demonstracao';

-- De onde vieram os dados? (sensor, envio manual, importação, demonstração)
SELECT source, COUNT(*) AS leituras, MIN(captured_at) AS primeira, MAX(captured_at) AS ultima
  FROM readings GROUP BY source ORDER BY leituras DESC;

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

-- Histórico individual de um sensor (ex.: "10/09 — 10:30 — Syrah — Boa")
SELECT to_char(captured_local, 'DD/MM — HH24:MI') AS quando, variety_name,
       CASE quality WHEN 'boa' THEN 'Boa' WHEN 'atencao' THEN 'Atenção' ELSE 'Necessita atenção' END AS qualidade
  FROM v_readings WHERE sensor_id = 'S-001' ORDER BY captured_at DESC LIMIT 20;

-- Clima do talhão nos últimos 14 dias
SELECT sensor_id, local_day, avg_temperature_c, max_temperature_c, avg_humidity_pct
  FROM v_environment_daily
 WHERE local_day >= (now() AT TIME ZONE 'America/Recife')::date - 13
 ORDER BY sensor_id, local_day;

-- Anomalias mais frequentes por variedade (apoio ao manejo)
SELECT r.variety_id, d.label, COUNT(*) AS ocorrencias, ROUND(AVG(d.confidence)::numeric, 3) AS confianca_media
  FROM detections d JOIN readings r ON r.id = d.reading_id
 WHERE d.kind = 'anomalia'
 GROUP BY r.variety_id, d.label ORDER BY ocorrencias DESC;

-- Importações recentes
SELECT id, created_at, created_by_name, kind, filename, status, inserted, updated, duplicates, invalid
  FROM v_import_jobs ORDER BY created_at DESC LIMIT 10;

-- Exportação para Data Science (CSV) — execute no psql:
-- \copy (SELECT * FROM v_readings WHERE source <> 'demonstracao' ORDER BY captured_at) TO 'oasis_readings.csv' WITH CSV HEADER

-- ---------------------------------------------------------------- segurança da informação
-- Senhas: só o hash PBKDF2 (formato pbkdf2_sha256$iterações$sal$hash), nunca o texto
SELECT email, role, organization_id, password_hash FROM users ORDER BY id;

-- Dados sensíveis dos clientes internacionais: só o valor cifrado (enc:v1:...)
SELECT id, organization_id, company_name, country, email_enc, tax_id_enc FROM international_clients ORDER BY id;

-- Acessos negados (perfil sem permissão ou registro de outra organização)
SELECT created_at, actor, target, details, ip FROM audit_log WHERE action = 'acesso_negado' ORDER BY created_at DESC LIMIT 20;

-- Quem consultou os dados decifrados de clientes
SELECT created_at, actor, target, ip FROM audit_log WHERE action = 'dados_sensiveis_consultados' ORDER BY created_at DESC LIMIT 20;

-- Usuários e sensores por exportadora
SELECT o.name AS exportadora,
       (SELECT COUNT(*) FROM users u WHERE u.organization_id = o.id) AS usuarios,
       (SELECT COUNT(*) FROM sensors s WHERE s.organization_id = o.id) AS sensores,
       (SELECT COUNT(*) FROM international_clients c WHERE c.organization_id = o.id) AS clientes
  FROM organizations o ORDER BY o.name;
