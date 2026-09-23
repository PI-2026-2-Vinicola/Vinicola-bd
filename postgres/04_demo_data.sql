-- =============================================================================
-- OSAIS · Gerador de histórico de demonstração (PostgreSQL)
--
-- Cria leituras sintéticas para os sensores cadastrados (06h–18h, horário local),
-- com qualidade, confiança, maturação e caixas de detecção coerentes.
-- Útil para exercícios de Data Science sem sensores físicos.
--
--   SELECT osais_generate_demo(30);   -- 30 dias de histórico
--
-- Observação: a API (SEED_DEMO=true) já popula um banco vazio com a mesma lógica.
-- =============================================================================

CREATE OR REPLACE FUNCTION osais_generate_demo(p_days INTEGER DEFAULT 30)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    s            RECORD;
    d            INTEGER;
    minute_of_day INTEGER;
    at           TIMESTAMPTZ;
    q            TEXT;
    conf         DOUBLE PRECISION;
    mat          TEXT;
    stage_value  DOUBLE PRECISION;
    anomaly      TEXT;
    condition    TEXT;
    obs          TEXT;
    new_id       INTEGER;
    cx           DOUBLE PRECISION;
    cy           DOUBLE PRECISION;
    cw           DOUBLE PRECISION;
    ch           DOUBLE PRECISION;
    created      INTEGER := 0;
    mild   TEXT[] := ARRAY['maturacao_desigual','baga_irregular','mancha_leve'];
    severe TEXT[] := ARRAY['podridao','baga_murcha','lesao'];
    stages TEXT[] := ARRAY['desenvolvimento','pintor','maturacao','adequada','sobrematuracao'];
BEGIN
    FOR s IN SELECT * FROM sensors LOOP
        FOR d IN REVERSE (p_days - 1)..0 LOOP
            minute_of_day := 6 * 60 + floor(random() * 25)::int;
            WHILE minute_of_day <= 18 * 60 LOOP
                at := ((current_date - d)::timestamp + make_interval(mins => minute_of_day)) AT TIME ZONE 'America/Recife';
                minute_of_day := minute_of_day + s.capture_interval_min;
                CONTINUE WHEN at > now();
                CONTINUE WHEN s.last_communication IS NOT NULL AND at > s.last_communication;

                q := CASE WHEN random() < 0.72 THEN 'boa' WHEN random() < 0.65 THEN 'atencao' ELSE 'critica' END;
                conf := CASE q WHEN 'boa' THEN 0.87 + random() * 0.115 WHEN 'atencao' THEN 0.79 + random() * 0.16 ELSE 0.71 + random() * 0.21 END;
                stage_value := 1.25 + ((p_days - 1 - d)::double precision / p_days) * 2.25 + (random() - 0.5) * 0.7;
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
                                      observations, clusters_detected, image_seed, model_version, processing_ms, stage)
                VALUES (s.id, at, s.variety_id, q, round(conf::numeric, 3), mat, condition,
                        CASE q WHEN 'boa' THEN 'APROVADA' WHEN 'atencao' THEN 'EM OBSERVAÇÃO' ELSE 'REVISÃO NECESSÁRIA' END,
                        obs, 1, floor(random() * 1e9)::int, 'YOLOv8n-osais v0.3', 180 + floor(random() * 460)::int, 'concluida')
                RETURNING id INTO new_id;
                UPDATE readings SET code = 'OS-' || lpad(new_id::text, 5, '0') WHERE id = new_id;

                cw := 0.34 + random() * 0.06;  ch := 0.60 + random() * 0.08;
                cx := 0.29 + random() * 0.07;  cy := 0.13 + random() * 0.06;
                INSERT INTO detections (reading_id, kind, label, confidence, x, y, w, h)
                VALUES (new_id, 'cacho', replace(s.variety_id, '-', '_'), round(conf::numeric, 3), cx, cy, cw, ch);
                IF anomaly IS NOT NULL THEN
                    INSERT INTO detections (reading_id, kind, label, confidence, x, y, w, h)
                    VALUES (new_id, 'anomalia', anomaly, round((0.58 + random() * 0.32)::numeric, 3),
                            cx + cw * (0.25 + random() * 0.35), cy + ch * (0.2 + random() * 0.4), 0.08, 0.11);
                END IF;
                created := created + 1;
            END LOOP;
        END LOOP;
    END LOOP;
    RETURN created;
END;
$$;
