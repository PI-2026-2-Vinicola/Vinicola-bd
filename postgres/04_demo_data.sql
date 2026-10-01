-- =============================================================================
-- OASIS · Dados de DEMONSTRAÇÃO (PostgreSQL) — opcional, nunca executado sozinho
--
-- Este arquivo apenas cria as funções. Os dados só existem se alguém chamar:
--   SELECT oasis_generate_demo(30);   -- sensores DEMO-01..03 + 30 dias de leituras sintéticas
--   SELECT oasis_clear_demo();        -- remove tudo que foi gerado
--
-- As leituras ficam com source = 'demonstracao' e model_version = 'Demonstração (sintético)';
-- os sensores não têm coordenadas. O painel identifica esses registros com um selo e a
-- página pública os ignora. Equivale a `python -m app.cli seed-demo` na API.
-- =============================================================================

CREATE OR REPLACE FUNCTION oasis_generate_demo(p_days INTEGER DEFAULT 30)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    s             RECORD;
    d             INTEGER;
    minute_of_day INTEGER;
    at            TIMESTAMPTZ;
    q             TEXT;
    conf          DOUBLE PRECISION;
    mat           TEXT;
    stage_value   DOUBLE PRECISION;
    anomaly       TEXT;
    condition     TEXT;
    obs           TEXT;
    new_id        INTEGER;
    cx DOUBLE PRECISION; cy DOUBLE PRECISION; cw DOUBLE PRECISION; ch DOUBLE PRECISION;
    created       INTEGER := 0;
    mild   TEXT[] := ARRAY['maturacao_desigual','baga_irregular','mancha_leve'];
    severe TEXT[] := ARRAY['podridao','baga_murcha','lesao'];
    stages TEXT[] := ARRAY['desenvolvimento','pintor','maturacao','adequada','sobrematuracao'];
BEGIN
    IF EXISTS (SELECT 1 FROM sensors WHERE id LIKE 'DEMO-%') THEN
        RAISE EXCEPTION 'Dados de demonstração já existem. Execute SELECT oasis_clear_demo(); antes.';
    END IF;
    INSERT INTO sensors (id, name, block, location, variety_id, device, capture_interval_min, active) VALUES
      ('DEMO-01', 'Sensor de demonstração 01', 'Demonstração', 'Dados sintéticos — sem localização real', 'cabernet-sauvignon', 'Demonstração', 120, TRUE),
      ('DEMO-02', 'Sensor de demonstração 02', 'Demonstração', 'Dados sintéticos — sem localização real', 'syrah',              'Demonstração', 120, TRUE),
      ('DEMO-03', 'Sensor de demonstração 03', 'Demonstração', 'Dados sintéticos — sem localização real', 'chenin-blanc',       'Demonstração', 120, TRUE);

    FOR s IN SELECT * FROM sensors WHERE id LIKE 'DEMO-%' LOOP
        FOR d IN REVERSE (p_days - 1)..0 LOOP
            minute_of_day := 6 * 60;
            WHILE minute_of_day <= 18 * 60 LOOP
                at := date_trunc('second', ((current_date - d)::timestamp + make_interval(mins => minute_of_day + floor(random() * 10)::int - 5)) AT TIME ZONE 'America/Recife');
                minute_of_day := minute_of_day + s.capture_interval_min;
                CONTINUE WHEN at > now();

                q := CASE WHEN random() < 0.72 THEN 'boa' WHEN random() < 0.65 THEN 'atencao' ELSE 'critica' END;
                conf := CASE q WHEN 'boa' THEN 0.87 + random() * 0.115 WHEN 'atencao' THEN 0.79 + random() * 0.16 ELSE 0.71 + random() * 0.21 END;
                stage_value := 1.2 + ((p_days - 1 - d)::double precision / greatest(1, p_days - 1)) * 2.4 + (random() - 0.5) * 0.8;
                mat := stages[greatest(1, least(5, floor(stage_value)::int + 1))];

                anomaly := CASE q WHEN 'atencao' THEN mild[1 + floor(random() * 3)::int] WHEN 'critica' THEN severe[1 + floor(random() * 3)::int] END;
                condition := CASE anomaly
                    WHEN 'maturacao_desigual' THEN 'Maturação desigual'  WHEN 'baga_irregular' THEN 'Bagas irregulares'
                    WHEN 'mancha_leve'        THEN 'Manchas leves'       WHEN 'podridao'       THEN 'Sinais de podridão'
                    WHEN 'baga_murcha'        THEN 'Bagas desidratadas'  WHEN 'lesao'          THEN 'Lesões visíveis'
                    ELSE 'Boa' END;
                obs := CASE WHEN q = 'boa' THEN 'Cacho uniforme, coloração compatível com a variedade e sem sinais visuais de dano.'
                            WHEN q = 'atencao' THEN 'Características que precisam ser acompanhadas nas próximas leituras.'
                            ELSE 'Características visuais fora do padrão esperado — recomenda-se inspeção em campo.' END;

                INSERT INTO readings (sensor_id, captured_at, variety_id, quality, confidence, maturation, visual_condition, classification,
                                      observations, clusters_detected, source, model_version, processing_ms, stage)
                VALUES (s.id, at, s.variety_id, q, round(conf::numeric, 3), mat, condition,
                        CASE q WHEN 'boa' THEN 'APROVADA' WHEN 'atencao' THEN 'EM OBSERVAÇÃO' ELSE 'REVISÃO NECESSÁRIA' END,
                        obs, 1, 'demonstracao', 'Demonstração (sintético)', 0, 'concluida')
                RETURNING id INTO new_id;
                UPDATE readings SET code = 'OA-' || lpad(new_id::text, 5, '0') WHERE id = new_id;

                cw := 0.34 + random() * 0.06;  ch := 0.60 + random() * 0.08;
                cx := 0.29 + random() * 0.07;  cy := 0.13 + random() * 0.06;
                INSERT INTO detections (reading_id, kind, label, confidence, x, y, w, h)
                VALUES (new_id, 'cacho', replace(s.variety_id, '-', '_'), round(conf::numeric, 3), cx, cy, cw, ch);
                IF anomaly IS NOT NULL THEN
                    INSERT INTO detections (reading_id, kind, label, confidence, x, y, w, h)
                    VALUES (new_id, 'anomalia', anomaly, round((0.58 + random() * 0.32)::numeric, 3),
                            cx + cw * (0.25 + random() * 0.35), cy + ch * (0.2 + random() * 0.4), 0.08, 0.11);
                END IF;

                INSERT INTO environment_readings (sensor_id, measured_at, temperature_c, humidity_pct, source)
                VALUES (s.id, at, round((24 + 7 * (1 - abs(minute_of_day / 60.0 - 14) / 8) + (random() - 0.5) * 3)::numeric, 1),
                        round(least(95, greatest(25, 62 - 18 * (1 - abs(minute_of_day / 60.0 - 14) / 8) + (random() - 0.5) * 10))::numeric, 1),
                        'demonstracao')
                ON CONFLICT DO NOTHING;
                created := created + 1;
            END LOOP;
        END LOOP;
    END LOOP;
    RETURN created;
END;
$$;

CREATE OR REPLACE FUNCTION oasis_clear_demo()
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    removed INTEGER;
BEGIN
    DELETE FROM readings WHERE source = 'demonstracao';
    GET DIAGNOSTICS removed = ROW_COUNT;
    DELETE FROM environment_readings WHERE source = 'demonstracao';
    DELETE FROM sensors s
     WHERE s.id LIKE 'DEMO-%'
       AND NOT EXISTS (SELECT 1 FROM readings r WHERE r.sensor_id = s.id);
    RETURN removed;
END;
$$;
