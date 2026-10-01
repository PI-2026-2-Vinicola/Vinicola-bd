-- =============================================================================
-- OASIS · Dados iniciais obrigatórios (MySQL / MariaDB)
--
-- Somente o catálogo de variedades. O primeiro administrador é criado pela API
-- (OASIS_ADMIN_EMAIL / OASIS_ADMIN_PASSWORD ou `python -m app.cli create-user`);
-- sensores e leituras vêm do painel, dos dispositivos ou de importação.
-- =============================================================================

SET NAMES utf8mb4;

INSERT IGNORE INTO varieties (id, name, type, color, maturation_cycle, origin) VALUES
  ('cabernet-sauvignon', 'Cabernet Sauvignon', 'Tinta',  'Negro-azulada',                  'Tardia (ciclo longo)', 'Bordeaux, França'),
  ('syrah',              'Syrah',              'Tinta',  'Preto-violácea',                 'Média',                'Vale do Rhône, França'),
  ('tempranillo',        'Tempranillo',        'Tinta',  'Negro-azulada com reflexos rubi', 'Precoce',              'Rioja e Ribera del Duero, Espanha'),
  ('touriga-nacional',   'Touriga Nacional',   'Tinta',  'Azul-escura',                    'Média',                'Douro e Dão, Portugal'),
  ('chenin-blanc',       'Chenin Blanc',       'Branca', 'Verde-amarelada',                'Média a tardia',       'Vale do Loire, França'),
  ('moscato-canelli',    'Moscato Canelli',    'Branca', 'Amarelo-dourada',                'Precoce',              'Piemonte, Itália');
