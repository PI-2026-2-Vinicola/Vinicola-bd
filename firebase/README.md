# OASIS no Firebase (Firestore + Storage) — estrutura alternativa

> **Situação:** proposta de modelagem NoSQL equivalente ao banco relacional. A API atual
> (Vinicola-back) usa SQLite, PostgreSQL ou MySQL e **não** grava no Firebase. Esta pasta
> documenta como os mesmos dados seriam organizados caso a equipe migre para o Firebase.

## Coleções

```
varieties/{varietyId}                      # catálogo de variedades
sensors/{sensorId}                         # dispositivos ESP32 + câmera (status calculado no backend)
  ├── telemetry/{autoId}                   # bateria, sinal, firmware
  └── environment/{autoId}                 # temperatura, umidade, luminosidade, solo
readings/{code}                            # leituras (OA-00001) com as detecções embutidas
imports/{autoId}                           # registro de importações de arquivos
users/{uid}                                # perfil de acesso (o uid vem do Firebase Auth)
```

Imagens no **Cloud Storage**: `images/{AAAA}/{MM}/{DD}/{arquivo}.jpg` (+ `_thumb.jpg`), com os caminhos gravados em `readings/{code}.imagePath` e `thumbPath`.

### Mapeamento relacional → Firestore

| SQL | Firestore | Observação |
| --- | --- | --- |
| `readings` + `detections` | `readings/{code}` com o array `detections` | As detecções são sempre lidas junto com a leitura |
| `readings.sensor_id` | `sensorId` + `block` + `location` | Desnormalizado para listar sem *join* |
| `readings.captured_at` | `capturedAt` (Timestamp) | UTC |
| `readings.source` | `source` | `sensor`, `upload`, `importacao` ou `demonstracao` |
| `sensors.latitude/longitude` | `geo` (GeoPoint, opcional) | |
| `sensor_telemetry` | `sensors/{id}/telemetry` | Subcoleção |
| `environment_readings` | `sensors/{id}/environment` | Subcoleção |
| `import_jobs` | `imports/{autoId}` | |
| `audit_log` | Cloud Logging | Logs estruturados do backend |
| `users.role` | `users/{uid}.role` + *custom claim* `role` | A *claim* é usada nas regras |

Veja o formato de cada documento em [`sample-documents.json`](sample-documents.json) (valores ilustrativos).

## Segurança

- [`firestore.rules`](firestore.rules): leitura apenas para usuários autenticados e ativos; leituras, sensores e importações são gravados **somente pelo backend** (Admin SDK). Administradores gerenciam usuários.
- [`storage.rules`](storage.rules): imagens legíveis por usuários autenticados; upload apenas pelo backend.
- [`firestore.indexes.json`](firestore.indexes.json): índices compostos para os filtros do histórico (sensor, variedade, qualidade e origem, sempre ordenados por data).

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage
```
