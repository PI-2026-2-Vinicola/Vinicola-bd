# OASIS — Banco de dados

**Observação Agroambiental Sensorizada, Inteligente e Sustentável**

Modelo de dados da OASIS, a camada de **aquisição e geração de dados de origem** do Projeto Integrador **“Inteligência de Dados no Vale do São Francisco”**. Guarda sensores, imagens analisadas, detecções, medições ambientais, importações e auditoria.

| Opção | Pasta | Validação |
| --- | --- | --- |
| **PostgreSQL** (recomendado) | [`postgres/`](postgres) | PostgreSQL 16 — scripts aplicados e suíte de testes da API executada sobre o banco criado |
| **MySQL / MariaDB** | [`mysql/`](mysql) | MariaDB 10.11 — idem (MySQL 8.0.16 ou mais recente) |
| **Firebase** (Firestore + Storage) | [`firebase/`](firebase) | Apenas proposta de estrutura; a API atual não usa Firebase |

O esquema espelha os modelos da API ([`Vinicola-back/app/models.py`](https://github.com/PI-2026-2-Vinicola/Vinicola-back)): a API funciona tanto com um banco criado por estes scripts quanto criando as tabelas sozinha.

## Conteúdo

```
postgres/
├── 01_schema.sql      # tabelas, restrições e índices
├── 02_views.sql       # visões analíticas (status dos sensores, histórico, alertas, ambiente)
├── 03_seed.sql        # catálogo de variedades (único dado inicial)
└── 04_demo_data.sql   # funções OPCIONAIS oasis_generate_demo() / oasis_clear_demo()
mysql/                 # equivalentes para MySQL/MariaDB (01–03)
firebase/              # proposta de coleções, regras e índices
consultas/             # consultas que respondem às perguntas-chave da plataforma
docs/modelo-de-dados.md  # diagrama ER, dicionário de dados, visões e índices
```

Nenhum usuário, sensor ou leitura é criado pelos scripts. O primeiro administrador é criado pela API na primeira inicialização (`OASIS_ADMIN_EMAIL` / `OASIS_ADMIN_PASSWORD`); sensores são cadastrados no painel ou importados; leituras vêm dos dispositivos, de envios manuais ou de importação de arquivos.

## Subindo com Docker

```bash
cp .env.example .env                      # defina POSTGRES_PASSWORD (e as do MySQL, se usar)
docker compose up -d postgres adminer     # Postgres 127.0.0.1:5432 · Adminer 127.0.0.1:8080
```

Ou, com MySQL: `docker compose up -d mysql`.

## Manualmente

```bash
createdb oasis
for f in postgres/0*.sql; do psql -d oasis -f "$f"; done
psql -d oasis -f consultas/postgres.sql
```

## Conectando a API

```bash
# Vinicola-back/.env
DATABASE_URL=postgresql+psycopg://oasis:SENHA@localhost:5432/oasis
# ou
DATABASE_URL=mysql+pymysql://oasis:SENHA@localhost:3306/oasis
```

## Dados de demonstração (opcional)

Para apresentar o painel sem hardware, existem funções que geram dados **sintéticos e identificados**: sensores `DEMO-01..03` sem coordenadas e leituras com `source = 'demonstracao'`, que o painel marca com um selo e a página pública ignora.

```sql
SELECT oasis_generate_demo(30);   -- PostgreSQL
SELECT oasis_clear_demo();        -- remove tudo
```

Na API, o equivalente é `python -m app.cli seed-demo` / `clear-demo` (funciona com qualquer banco).

## Perguntas que os dados respondem

| Pergunta | Visão |
| --- | --- |
| Onde estão os sensores e como estão? | `v_sensor_status`, `v_sensor_activity` |
| Quantas análises foram feitas e de onde vieram? | `v_readings`, `v_dashboard_7d` |
| Quais uvas foram identificadas? | `v_quality_by_variety` |
| Como está a qualidade das uvas? | `v_dashboard_7d`, `v_quality_by_variety` |
| Quais análises precisam de atenção? | `v_alerts` |
| Como os resultados estão evoluindo? | `v_quality_by_day` |
| Como está o clima do talhão? | `v_environment_daily` |
| O que foi importado e por quem? | `v_import_jobs` |

Detalhes em [`docs/modelo-de-dados.md`](docs/modelo-de-dados.md).
