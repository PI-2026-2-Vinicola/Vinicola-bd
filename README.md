# OSAIS — Banco de dados

**Observação Agroambiental Sensorizada, Inteligente e Sustentável**

Modelo de dados da OSAIS, a camada de **aquisição e geração de dados de origem** do Projeto Integrador **“Inteligência de Dados no Vale do São Francisco”**. Guarda sensores, imagens analisadas, detecções do modelo YOLO e indicadores para o dashboard e para Data Science.

| Opção | Pasta | Validação |
| --- | --- | --- |
| **PostgreSQL** (recomendado) | [`postgres/`](postgres) | PostgreSQL 16 + API OSAIS |
| **MySQL / MariaDB** | [`mysql/`](mysql) | MariaDB 10.11 + API OSAIS (MySQL 8.0.16 ou mais recente) |
| **Firebase** (Firestore + Storage) | [`firebase/`](firebase) | Estrutura, regras e índices |

O esquema espelha exatamente os modelos da API ([`Vinicola-back/app/models.py`](https://github.com/PI-2026-2-Vinicola/Vinicola-back)), então a API pode usar um banco criado por estes scripts.

## Conteúdo

```
postgres/
├── 01_schema.sql      # tabelas, restrições e índices
├── 02_views.sql       # visões analíticas (dashboard, histórico, alertas)
├── 03_seed.sql opcional: 30 dias de histórico# variedades, usuários e sensores de demonstração
└── 04_demo_data.sql   # função osais_generate_demo(dias): histórico sintético
mysql/ opcional: 30 dias de histórico         # equivalentes para MySQL/MariaDB (01–03)
firebase/ opcional: 30 dias de histórico      # coleções, regras, índices e documentos de exemplo
consultas/ opcional: 30 dias de histórico     # consultas que respondem às perguntas-chave da plataforma
docs/modelo-de-dados.md  # diagrama ER, dicionário de dados, visões e índices
```

## Subindo com Docker

```bash
docker compose up -d postgres adminer     # Postgres :5432 · Adminer :8080
docker compose exec postgres psql -U osais -c "SELECT osais_generate_demo(30);"
```

Ou, com MySQL: `docker compose up -d mysql`.

## Manualmente

```bash
createdb osais
for f in postgres/0*.sql; do psql -d osais -f "$f"; done
psql -d osais -c "SELECT osais_generate_demo(30);"   # opcional: 30 dias de histórico
psql -d osais -f consultas/postgres.sql
```

## Conectando a API

```bash
# Vinicola-back/.env
DATABASE_URL=postgresql+psycopg://osais:osais@localhost:5432/osais
# ou
DATABASE_URL=mysql+pymysql://osais:osais@localhost:3306/osais
```

> Com `SEED_DEMO=true`, a API cria o esquema e popula um banco **vazio** sozinha. Se os sensores já foram cadastrados pelo `03_seed.sql`, gere o histórico com `osais_generate_demo()` (PostgreSQL) ou envie imagens pelo endpoint `/api/v1/ingest`.

## Credenciais de demonstração

| Tipo | Valor |
| --- | --- |
| Usuários | `admin@osais.agr.br`, `gestor@osais.agr.br`, `operador@osais.agr.br` (senha `osais2026`) |
| Tokens dos dispositivos | `osais-dev-s-001` … `osais-dev-s-006` |

Os dois valores são armazenados apenas como hash PBKDF2. **Troque todos antes de qualquer uso real.**

## Perguntas que os dados respondem

| Pergunta | Visão |
| --- | --- |
| Onde estão os sensores? | `v_sensor_activity` |
| Quantas análises foram feitas? | `v_readings`, `v_dashboard_7d` |
| Quais uvas foram identificadas? | `v_quality_by_variety` |
| Como está a qualidade das uvas? | `v_dashboard_7d`, `v_quality_by_variety` |
| Quais análises precisam de atenção? | `v_alerts` |
| Como os resultados estão evoluindo? | `v_quality_by_day` |

Detalhes em [`docs/modelo-de-dados.md`](docs/modelo-de-dados.md).
