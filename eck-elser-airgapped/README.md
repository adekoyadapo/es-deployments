# ECK ELSER Air-Gapped Lab

This repo is a focused Elasticsearch/Kibana lab for three air-gapped inference setups on ECK:

| Mode | What it deploys | Primary use case |
| --- | --- | --- |
| `file` | Elasticsearch ML reads ELSER from local files mounted into the pod | Elastic ELSER with file-based model access |
| `http` | Elasticsearch ML reads ELSER from a passwordless in-cluster HTTP server | Elastic ELSER with HTTP model access |
| `jina` | Elasticsearch points to an external amd64 Jina Docker service through `sslip.io` | External embedding service for the same validation flow |

The Elastic modes use the cross-platform ELSER v2 artifacts. The Jina mode is a separate dense embedding path based on the `jina-ai/jina-airgap` example.

## Key Documentation

These are the docs this repo follows:

- [ELSER model artifacts, file-based access, and HTTP server setup](https://www.elastic.co/docs/explore-analyze/machine-learning/nlp/ml-nlp-elser#elser-model-artifacts)
- [Install ECK using the YAML manifests](https://www.elastic.co/docs/deploy-manage/deploy/cloud-on-k8s/install-using-yaml-manifest-quickstart)
- [Deploy an Elastic Cloud on Kubernetes orchestrator](https://www.elastic.co/docs/deploy-manage/deploy/cloud-on-k8s/deploy-an-orchestrator)
- [Manage your license in ECK](https://www.elastic.co/docs/deploy-manage/license/manage-your-license-in-eck)
- [Jina air-gap reference example](https://github.com/jina-ai/jina-airgap/blob/main/k8s/jina-airgap.yaml)

## Versions

Defaults in the Makefile:

- Elasticsearch and Kibana: `9.4.2`
- ECK: `3.4.0`
- ELSER model: `.elser_model_2`
- ELSER artifact variant: cross-platform
- Jina runtime: external Docker, `linux/amd64`

Override them as needed:

```sh
make up MODE=file ES_VERSION=9.4.2 ECK_VERSION=3.4.0
```

## Kubernetes Requirements

You need:

- A Kubernetes cluster with `kubectl`
- Docker for the local `k3d` cluster and the external Jina container
- The ECK operator installed from the YAML manifests
- Either an ECK trial secret or an orchestration license secret
- Enough node memory for Elasticsearch plus ML allocation

The local setup uses `k3d` and keeps all application workloads in the `elser-lab` namespace while the ECK operator runs in `elastic-system`.

## ECK Bootstrap

This repo vendors the ECK `3.4.0` YAML manifests under `manifests/elastic/` so the cluster can be bootstrapped without pulling them at deploy time.

Official install flow:

```sh
kubectl create -f https://download.elastic.co/downloads/eck/3.4.0/crds.yaml
kubectl apply -f https://download.elastic.co/downloads/eck/3.4.0/operator.yaml
```

Local equivalent used by this repo:

```sh
kubectl apply -f manifests/elastic/eck-crds.yaml
kubectl apply -f manifests/elastic/eck-operator.yaml
```

For licenses, ECK expects one of these secret shapes in `elastic-system`:

Trial:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: eck-trial-license
  namespace: elastic-system
  labels:
    license.k8s.elastic.co/type: enterprise_trial
  annotations:
    elastic.co/eula: accepted
```

Or orchestration license:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: eck-license
  namespace: elastic-system
  labels:
    license.k8s.elastic.co/scope: operator
type: Opaque
```

Docs:

- [Install ECK using the YAML manifests](https://www.elastic.co/docs/deploy-manage/deploy/cloud-on-k8s/install-using-yaml-manifest-quickstart)
- [Manage your license in ECK](https://www.elastic.co/docs/deploy-manage/license/manage-your-license-in-eck)

## ELSER Artifacts

For `MODE=file` and `MODE=http`, download the cross-platform ELSER v2 artifacts into `artifacts/elser`:

```text
artifacts/elser/elser_model_2.metadata.json
artifacts/elser/elser_model_2.pt
artifacts/elser/elser_model_2.vocab.json
```

Source URLs:

```text
https://ml-models.elastic.co/elser_model_2.metadata.json
https://ml-models.elastic.co/elser_model_2.pt
https://ml-models.elastic.co/elser_model_2.vocab.json
```

Validate the files before deployment:

```sh
make artifacts-check
```

## Mode Configuration

### `file`

This is the direct file-based ELSER path described in the Elastic docs.

Important YAML settings:

```yaml
spec:
  version: 9.4.2
  nodeSets:
    - name: default
      config:
        node.roles: ["master", "data_hot", "data_content", "ingest", "ml", "remote_cluster_client"]
        xpack.ml.model_repository: "file://${path.home}/config/models/"
        xpack.ml.use_auto_machine_memory_percent: true
      podTemplate:
        spec:
          volumes:
            - name: elser-models
              hostPath:
                path: /mnt/elser-models
          containers:
            - name: elasticsearch
              volumeMounts:
                - name: elser-models
                  mountPath: /usr/share/elasticsearch/config/models
                  readOnly: true
```

What matters:

- `xpack.ml.model_repository` must point at the local `config/models` directory
- The model artifacts must exist on every master-eligible node
- The mounted path in this repo is `/mnt/elser-models`

Relevant doc section:

- [Using file-based access](https://www.elastic.co/docs/explore-analyze/machine-learning/nlp/ml-nlp-elser#elser-model-artifacts)

### `http`

This follows Elastic's passwordless HTTP model repository pattern.

Important YAML settings:

```yaml
spec:
  version: 9.4.2
  nodeSets:
    - name: default
      config:
        node.roles: ["master", "data_hot", "data_content", "ingest", "ml", "remote_cluster_client"]
        xpack.ml.model_repository: "http://elser-model-repository.elser-lab.svc.cluster.local"
        xpack.ml.use_auto_machine_memory_percent: true
```

The model repository service is a small Nginx deployment:

```yaml
kind: Deployment
metadata:
  name: elser-model-repository
spec:
  template:
    spec:
      containers:
        - name: nginx
          image: nginx:1.27-alpine
          volumeMounts:
            - name: elser-models
              mountPath: /usr/share/nginx/html
              readOnly: true
```

What matters:

- The model repository must be reachable from Elasticsearch
- The server must be passwordless
- The URL must include `http://`

Relevant doc section:

- [Using an HTTP server](https://www.elastic.co/docs/explore-analyze/machine-learning/nlp/ml-nlp-elser#elser-model-artifacts)

### `jina`

This mode uses a real external amd64 Jina container instead of in-cluster Jina.

Key behavior:

- Docker starts `ghcr.io/jina-ai/jina-airgap/jina-embeddings-v5-text-small:cpu`
- The container runs with `--platform linux/amd64`
- The endpoint is published as `http://<host-ip-with-dashes>.sslip.io:18080`
- Elasticsearch registers a custom inference endpoint that points to `/v1/embeddings`

Relevant commands and settings:

```sh
docker run -d \
  --platform linux/amd64 \
  --name eck-elser-jina \
  -p 18080:8080 \
  -e HF_HUB_OFFLINE=1 \
  -e TRANSFORMERS_OFFLINE=1 \
  ghcr.io/jina-ai/jina-airgap/jina-embeddings-v5-text-small:cpu
```

```yaml
service: custom
service_settings:
  url: "http://<host>.sslip.io:18080/v1/embeddings"
  headers:
    Content-Type: application/json
  request: "{\"input\": ${input}, \"model\": \"jina-embeddings-v5-text-small\"}"
```

What matters:

- Docker must be able to run amd64 images
- The host IP must resolve through `sslip.io`
- Elasticsearch must be able to reach the Jina service URL

## License

ELSER requires a subscription level that permits semantic search, or an active trial.

For ECK, this repo supports both options:

- A trial secret in `elastic-system`
- An orchestration license secret named `eck-license`

Create a trial with:

```sh
make license
```

Or provide a license file:

```sh
make license LICENSE_FILE=/path/to/license.json
```

Docs:

- [Manage your license in ECK](https://www.elastic.co/docs/deploy-manage/license/manage-your-license-in-eck)

## Deploy

File-based ELSER:

```sh
make up MODE=file
make test MODE=file
```

HTTP repository ELSER:

```sh
make up MODE=http
make test MODE=http
```

Jina airgap embedding service:

```sh
make up MODE=jina
make test MODE=jina
```

## Validation

`make test` validates both model inference and document retrieval.

For `file` and `http`:

1. Call the ELSER sparse embedding inference endpoint.
2. Create a small index with a `sparse_vector` field.
3. Create an ingest pipeline that uses `.elser_model_2`.
4. Ingest one relevant document and one unrelated document.
5. Search with sparse vectors and assert the relevant document ranks first.

For `jina`:

1. Check the Jina `/health` endpoint.
2. Call Jina `/v1/embeddings` through the `sslip.io` URL.
3. Call the Elasticsearch inference endpoint that targets the external Jina service.
4. Index sample documents with embeddings produced through Elasticsearch inference.
5. Run dense-vector search and assert the expected document ranks first.

## Access

Print port-forward commands:

```sh
make port-forward MODE=file
```

Elasticsearch:

```sh
kubectl -n elser-lab port-forward svc/elasticsearch-es-http 9200:9200
```

Kibana:

```sh
kubectl -n elser-lab port-forward svc/kibana-kb-http 5601:5601
```

Get the `elastic` password:

```sh
kubectl -n elser-lab get secret elasticsearch-es-elastic-user -o jsonpath='{.data.elastic}' | base64 -d; echo
```

## Make Targets

- `make up MODE=file|http|jina`: create the k3d cluster, install ECK, deploy the selected mode, apply license, and configure inference
- `make test MODE=file|http|jina`: run inference and document retrieval validation for the selected mode
- `make artifacts-check`: verify the three ELSER cross-platform files exist
- `make license LICENSE_FILE=...`: apply a license JSON or start a trial if `LICENSE_FILE` is unset
- `make status`: show Kubernetes and ECK status
- `make logs`: show recent operator, Elasticsearch, Kibana, and Jina logs
- `make down`: delete the local k3d cluster
- `make clean-generated`: remove downloaded ECK operator and CRD manifests

## Troubleshooting

If `make artifacts-check` fails, download the three cross-platform files into `artifacts/elser`.

If ELSER allocation times out, check memory and CPU availability:

```sh
kubectl -n elser-lab describe pod -l elasticsearch.k8s.elastic.co/cluster-name=elasticsearch
kubectl -n elser-lab logs -l elasticsearch.k8s.elastic.co/cluster-name=elasticsearch
```

If the HTTP mode fails, verify that the model repository service is reachable:

```sh
kubectl -n elser-lab run repo-check --restart=Never --rm --attach --image=curlimages/curl:8.7.1 -- \
  curl -fsS http://elser-model-repository/elser_model_2.metadata.json
```

If Jina mode fails, check that Docker can run the amd64 image and that the `sslip.io` URL resolves to the host IP.
