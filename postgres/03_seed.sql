-- =============================================================================
-- OSAIS · Dados iniciais (PostgreSQL)
-- Catálogo de variedades, usuários de demonstração, sensores e leituras de exemplo.
--
-- Usuários (senha de demonstração: osais2026 — troque em produção):
--   admin@osais.agr.br · gestor@osais.agr.br · operador@osais.agr.br
-- Tokens de demonstração dos dispositivos: osais-dev-s-001 … osais-dev-s-006
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

INSERT INTO users (name, email, password_hash, role) VALUES
  ('Ana Ribeiro',    'admin@osais.agr.br',    'pbkdf2_sha256$240000$7uso8m8G29O2OSwXj1bimg==$HB5j7sjRjpAwYEDNqxVnOJvOvAgkX8uMWjWhmis1+h4=', 'admin'),
  ('Carlos Menezes', 'gestor@osais.agr.br',   'pbkdf2_sha256$240000$7uso8m8G29O2OSwXj1bimg==$HB5j7sjRjpAwYEDNqxVnOJvOvAgkX8uMWjWhmis1+h4=', 'gestor'),
  ('Júlia Santos',   'operador@osais.agr.br', 'pbkdf2_sha256$240000$7uso8m8G29O2OSwXj1bimg==$HB5j7sjRjpAwYEDNqxVnOJvOvAgkX8uMWjWhmis1+h4=', 'operador')
ON CONFLICT (email) DO NOTHING;

-- Fazenda demonstrativa em Lagoa Grande (PE), Vale do São Francisco
INSERT INTO sensors (id, name, block, location, latitude, longitude, variety_id, device, firmware, battery, signal_dbm, capture_interval_min, status, installed_at, last_communication, device_token_hash) VALUES
  ('S-001', 'OSAIS Cam 01', 'Bloco A', 'Bloco A — Fileira 12', -8.99375, -40.27552, 'cabernet-sauvignon', 'ESP32-CAM (OV2640)', 'v1.4.2', 92, -58,  90, 'online',  '2026-03-02', now() - interval '2 minutes', 'pbkdf2_sha256$240000$HloBKDHrDa6ajrVY/WBv2A==$x3JuYnCHXqK5QRlCyBMWAyemPzRJTzXBGMN3BiRrKcY='),
  ('S-002', 'OSAIS Cam 02', 'Bloco B', 'Bloco B — Fileira 07', -8.99390, -40.27158, 'syrah',              'ESP32-CAM (OV2640)', 'v1.4.2', 87, -61,  90, 'online',  '2026-03-02', now() - interval '3 minutes', 'pbkdf2_sha256$240000$16a/x/FFPIZbLSF32SZJsg==$FyBCV/5uZf0qatyN96afgGwAdMYTtXbIu9WeLbcx3G0='),
  ('S-003', 'OSAIS Cam 03', 'Bloco C', 'Bloco C — Fileira 21', -8.99360, -40.26770, 'chenin-blanc',       'ESP32-S3 + OV5640',  'v1.5.0', 78, -66,  75, 'online',  '2026-04-11', now() - interval '1 minute',  'pbkdf2_sha256$240000$NTVgwSe5qxxO/6tyEEwDcQ==$lxwwBxyDyxr4tdlag/G+qYMCv6t4soGcrSt4zJlqzXM='),
  ('S-004', 'OSAIS Cam 04', 'Bloco D', 'Bloco D — Fileira 03', -8.99690, -40.27560, 'tempranillo',        'ESP32-CAM (OV2640)', 'v1.4.2', 81, -63,  90, 'online',  '2026-04-11', now() - interval '4 minutes', 'pbkdf2_sha256$240000$BEj6ZtxwbVk3UDwjkNHdGQ==$oikpPqTr7ShuVlbpf7eiMkdICYi9hY17wEL9wXd3dsM='),
  ('S-005', 'OSAIS Cam 05', 'Bloco E', 'Bloco E — Fileira 15', -8.99705, -40.27170, 'moscato-canelli',    'ESP32-CAM (OV2640)', 'v1.3.9', 23, -79, 120, 'atencao', '2026-05-20', now() - interval '3 hours',   'pbkdf2_sha256$240000$FHpa2+5eERtnnTKCH0GYGg==$c7ZQwF7Bo6R6xy1eL3Kk4COEEC63cUPF46lmn+mS7z0='),
  ('S-006', 'OSAIS Cam 06', 'Bloco F', 'Bloco F — Fileira 09', -8.99680, -40.26780, 'touriga-nacional',   'ESP32-S3 + OV5640',  'v1.5.0',  0, -95,  90, 'offline', '2026-05-20', now() - interval '44 hours',  'pbkdf2_sha256$240000$d0khCqC/bC+blMlb1DUMPQ==$6M6VOvYQJcjIJTmAT7J+T5z3v73AScxDR4164N/nyjc=')
ON CONFLICT (id) DO NOTHING;

COMMIT;
