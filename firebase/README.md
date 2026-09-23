# OSAIS no Firebase (Firestore + Storage)

Alternativa NoSQL ao banco relacional, com o mesmo modelo de dados. Útil quando a equipe prefere hospedar tudo no Firebase (autenticação, banco e armazenamento de imagens).

## Coleções

```
varieties/{varietyId}                      # biblioteca de variedades
sensors/{sensorId}                         # dispositivos ESP32 + câmera
  └── telemetry/{autoId}                   # bateria, sinal, firmware (subcoleção)
readings/{code}                            # leituras (OS-00001) com as detecções embutidas
users/{uid}                                # perfil de acesso (o uid vem do Firebase Auth)
```

Imagens no **Cloud Storage**: `images/{AAAA}/{MM}/{DD}/{code}.jpg`, com o caminho gravado em `readings/{code}.imagePath`.

### Mapeamento relacional → Firestore

| SQL | Firestore | Observação |
| --- | --- | --- |
| `readings` + `detections` | `readings/{code}` com o array `detections` | As detecções são sempre lidas junto com a leitura, por isso ficam embutidas |
| `readings.sensor_id` | `sensorId` + `block` + `location` | Desnormalizado para listar sem *join* |
| `readings.captured_at` | `capturedAt` (Timestamp) | UTC |
| `sensors.latitude/longitude` | `geo` (GeoPoint) | |
| `sensor_telemetry` | `sensors/{id}/telemetry` | Subcoleção |
| `users.role` | `users/{uid}.role` + *custom claim* `role` | A *claim* é usada nas regras |

Veja um documento de cada coleção em [`sample-documents.json`](sample-documents.json).

## Segurança

- [`firestore.rules`](firestore.rules): leitura apenas para usuários autenticados. A escrita de leituras e sensores é feita **somente pelo backend** (Admin SDK), que executa o YOLO. Administradores gerenciam usuários.
- [`storage.rules`](storage.rules): imagens legíveis por usuários autenticados; upload apenas pelo backend.
- [`firestore.indexes.json`](firestore.indexes.json): índices compostos para os filtros do histórico (sensor, variedade e qualidade, sempre ordenados por data).

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage
```
