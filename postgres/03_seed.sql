-- =============================================================================
-- OASIS · Dados iniciais obrigatórios (PostgreSQL)
--
-- Somente o catálogo de variedades. Usuários, sensores e leituras NÃO são criados aqui:
--   · o primeiro administrador é criado pela API na primeira inicialização
--     (OASIS_ADMIN_EMAIL / OASIS_ADMIN_PASSWORD) ou com `python -m app.cli create-user`;
--   · sensores são cadastrados no painel (Sensores → Novo sensor) ou por importação;
--   · leituras chegam dos dispositivos, de envios manuais ou de importação de arquivos.
-- =============================================================================

BEGIN;

INSERT INTO varieties (id, name, type, color, maturation_cycle, origin) VALUES
  ('cabernet-sauvignon', 'Cabernet Sauvignon', 'Tinta',  'Negro-azulada',                  'Tardia (ciclo longo)', 'Bordeaux, França'),
  ('syrah',              'Syrah',              'Tinta',  'Preto-violácea',                 'Média',                'Vale do Rhône, França'),
  ('tempranillo',        'Tempranillo',        'Tinta',  'Negro-azulada com reflexos rubi', 'Precoce',              'Rioja e Ribera del Duero, Espanha'),
  ('touriga-nacional',   'Touriga Nacional',   'Tinta',  'Azul-escura',                    'Média',                'Douro e Dão, Portugal'),
  ('chenin-blanc',       'Chenin Blanc',       'Branca', 'Verde-amarelada',                'Média a tardia',       'Vale do Loire, França'),
  ('moscato-canelli',    'Moscato Canelli',    'Branca', 'Amarelo-dourada',                'Precoce',              'Piemonte, Itália')
ON CONFLICT (id) DO NOTHING;

COMMIT;
