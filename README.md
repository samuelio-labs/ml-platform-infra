# ML Platform — Production-Grade Reference Implementation

A production-quality ML Platform Engineering project built to demonstrate deep infrastructure and platform skills. The ML model is intentionally simple (tabular classification); the platform built around it is the focus.

---

## Architecture Overview

```
External Zone
├── Developer
├── GitHub: ml-platform-infra   ← Terraform + ArgoCD manifests (GitOps source of truth)
├── GitHub: ml-platform-models  ← Model code + DVC + Kubeflow pipeline definitions
├── GitHub Actions              ← CI/CD engine
└── Inference Client            ← REST / gRPC consumer

Kubernetes Cluster (k3d local ↔ EKS production)
├── ns: argocd              GitOps operator, App-of-Apps pattern
├── ns: platform-storage    MinIO (object store) + PostgreSQL (metadata + pgvector)
├── ns: mlplatform          MLflow Tracking Server + Model Registry
├── ns: kubeflow            Kubeflow Pipelines — DAG orchestrator
├── ns: ray-system          Ray Head + auto-scaled Worker pods
├── ns: kserve              KServe + Istio — model serving, canary, HPA
├── ns: llm-serving         vLLM (OpenAI-compat) + NGINX ingress (rate limit + auth)    ← Phase 2.5
├── ns: rag-platform        Embedding Service + RAG Ingestion + RAG Query Service        ← Phase 2.5
└── ns: monitoring          Prometheus + Grafana + OTel + Alertmanager + Tempo + Loki
```

Architecture diagram: [`ml-platform-architecture.drawio`](./ml-platform-architecture.drawio)

---

## Repository Structure

### `ml-platform-infra` — Config repo (GitOps source of truth)

```
ml-platform-infra/
├── terraform/
│   ├── modules/
│   │   ├── k3d-cluster/         # cluster bootstrap
│   │   ├── argocd/              # ArgoCD install + App-of-Apps root app
│   │   ├── minio/               # MinIO StatefulSet + PVCs + buckets
│   │   ├── postgres/            # PostgreSQL StatefulSet + PVCs
│   │   ├── mlflow/              # MLflow Deployment + Service + Ingress
│   │   ├── ray/                 # RayCluster CRD + RBAC
│   │   ├── kubeflow/            # KFP install
│   │   ├── kserve/              # KServe + Istio install
│   │   ├── monitoring/          # kube-prometheus-stack + OTel Collector
│   │   ├── vllm/                # vLLM Helm chart + namespace + RBAC         ← Phase 2.5
│   │   ├── pgvector/            # pgvector DB init + rag_store schema         ← Phase 2.5
│   │   └── loki/                # Loki + Promtail DaemonSet                   ← Phase 2.5
│   ├── environments/
│   │   ├── local/               # k3d-specific vars (reduced resources)
│   │   └── prod/                # EKS-specific vars
│   └── main.tf
├── argocd/
│   ├── app-of-apps.yaml         # root Application that manages all others
│   └── apps/
│       ├── platform-storage.yaml
│       ├── mlplatform.yaml
│       ├── kubeflow.yaml
│       ├── ray.yaml
│       ├── kserve.yaml
│       ├── monitoring.yaml
│       ├── llm-serving.yaml         ← Phase 2.5
│       └── rag-platform.yaml        ← Phase 2.5
└── manifests/                   # raw K8s manifests synced by ArgoCD
    ├── platform-storage/
    ├── mlplatform/
    ├── kserve/
    │   └── inference-service.yaml   ← image tag updated by CI/CD
    ├── monitoring/
    │   ├── grafana-dashboard-vllm.yaml     ← Phase 2.5
    │   ├── grafana-dashboard-rag.yaml      ← Phase 2.5
    │   ├── prometheus-rules-llm.yaml       ← Phase 2.5
    │   └── loki-promtail-config.yaml       ← Phase 2.5
    ├── llm-serving/                 ← Phase 2.5
    │   ├── Chart.yaml               # Helm chart for vLLM
    │   ├── values.yaml              # CPU defaults (local dev)
    │   ├── values-local.yaml        # TinyLlama, no GPU
    │   ├── values-prod.yaml         # Mistral-7B, GPU node pool
    │   └── templates/
    │       ├── deployment.yaml
    │       ├── service.yaml
    │       ├── hpa.yaml
    │       ├── ingress.yaml         # NGINX rate limit + API key auth
    │       ├── configmap.yaml
    │       └── servicemonitor.yaml
    └── rag-platform/                ← Phase 2.5
        ├── namespace.yaml
        ├── pgvector.yaml            # StatefulSet + init job (pgvector ext)
        ├── embedding-service.yaml
        ├── ingestion-service.yaml
        ├── query-service.yaml
        └── ingress.yaml
```

### `ml-platform-models` — App repo (model code + pipelines)

```
ml-platform-models/
├── model/
│   ├── train.py                 # Ray Train job entry point
│   ├── evaluate.py
│   ├── preprocess.py
│   └── requirements.txt
├── pipelines/
│   └── training_pipeline.py     # Kubeflow Pipeline SDK v2 definition
├── serving/
│   └── transformer.py           # KServe Transformer custom logic
├── data/
│   └── dataset.dvc              # DVC pointer file (not the data itself)
├── dvc.yaml                     # DVC pipeline stages
├── .dvc/config                  # remote = MinIO endpoint
├── rag/                         ← Phase 2.5
│   ├── embedding/
│   │   ├── main.py              # FastAPI embedding service (all-MiniLM-L6-v2)
│   │   ├── config.py
│   │   ├── Dockerfile
│   │   └── requirements.txt
│   ├── ingestion/
│   │   ├── main.py              # FastAPI ingestion API
│   │   ├── pipeline.py          # LangChain: load → chunk → embed → upsert
│   │   ├── config.py
│   │   ├── Dockerfile
│   │   └── requirements.txt
│   ├── query/
│   │   ├── main.py              # FastAPI query API
│   │   ├── retriever.py         # pgvector semantic search
│   │   ├── llm_client.py        # OpenAI-compat client → vLLM
│   │   ├── config.py
│   │   ├── Dockerfile
│   │   └── requirements.txt
│   ├── evaluation/
│   │   ├── ragas_eval.py        # Ragas: faithfulness, answer_relevance, context_precision
│   │   └── requirements.txt
│   └── docs/
│       └── corpus.dvc           # DVC pointer to document corpus in MinIO
└── .github/workflows/
    ├── ci.yaml                  # lint + test + build Docker image
    ├── train-and-promote.yaml   # trigger KFP → promote model → update infra repo
    ├── llm-ci.yaml              # lint + test + smoke test vLLM + build RAG images  ← Phase 2.5
    └── rag-update.yaml          # dvc pull → ingest → Ragas eval → fail on regression ← Phase 2.5
```

**Why two repos?** Separating infra config from application code is a core GitOps principle:
- ArgoCD watches one stable config repo for drift reconciliation
- Model engineers cannot accidentally mutate infrastructure
- Independent audit trails and approval gates per repo
- Infra repo changes can require a separate PR approval from a platform engineer

---

## Stack

| Layer | Tool | Why |
|---|---|---|
| Local Kubernetes | k3d | Lightweight, mirrors EKS API surface, fast iteration |
| Cloud Kubernetes | EKS | Production target |
| Infrastructure-as-Code | Terraform | Reproducible, `plan` before apply, module reuse |
| GitOps | ArgoCD | Self-managing, drift detection, rollback built-in |
| Object Storage | MinIO | S3-compatible — identical code works against real S3 in prod |
| Metadata Store | PostgreSQL | MLflow officially supports it; transactional, production-grade |
| Experiment Tracking | MLflow | De-facto standard; integrates with Ray, sklearn, PyTorch |
| Model Registry | MLflow | Stage lifecycle (Staging → Production), alias-based promotion |
| Data Versioning | DVC | Git-native dataset versioning; MinIO as remote |
| Pipeline Orchestration | Kubeflow Pipelines | Kubernetes-native DAGs; SDK v2 type-annotated components |
| Distributed Training | Ray (KubeRay) | Scales to multi-node; workers auto-scale to zero between jobs |
| Model Serving | KServe | Standard gRPC v2 inference protocol; canary splits; HPA |
| Service Mesh | Istio | mTLS, traffic management, canary routing for KServe |
| Metrics | Prometheus | Pull-based scraping; PrometheusRules for SLO alerting |
| Dashboards | Grafana | Platform Health, Ray Utilization, Inference SLOs, Model Drift |
| Telemetry Pipeline | OpenTelemetry Collector | Decouples instrumentation from backend |
| Distributed Tracing | Grafana Tempo | Trace pipeline steps and inference requests |
| Log Aggregation | Loki + Promtail | Structured JSON logs for RAG/LLM requests; Grafana Explore |
| Alerting | Alertmanager | Routes to Slack/PagerDuty; per-team routing trees |
| CI/CD | GitHub Actions | Orchestrates the full train→register→deploy loop |
| **LLM Serving** | **vLLM** | **PagedAttention, continuous batching, OpenAI-compat API** |
| **Vector DB** | **pgvector** | **Reuses existing PostgreSQL; ACID, SQL filtering, ivfflat index** |
| **Embedding** | **sentence-transformers** | **all-MiniLM-L6-v2; CPU-native, 384-dim, 80MB** |
| **RAG Framework** | **LangChain** | **Document loaders, text splitters, retriever abstraction** |
| **LLM Eval** | **Ragas** | **Reference-free RAG metrics; faithfulness, answer_relevance** |
| **Ingress (LLM)** | **NGINX** | **Rate limiting, API key auth, routes to vLLM / RAG services** |

---

## Phased Implementation Plan

### Phase 1 — Foundation

**Goal:** Running k3d cluster with ArgoCD managing MinIO, PostgreSQL, and MLflow.

**Deliverables:**
- k3d cluster provisioned by Terraform
- ArgoCD installed and bootstrapped with App-of-Apps
- MinIO running as a StatefulSet with three buckets: `mlflow-artifacts`, `dvc-store`, `pipeline-cache`
- PostgreSQL running as a StatefulSet, `mlflow` database created
- MLflow Tracking Server deployed, backed by MinIO (artifacts) and PostgreSQL (metadata)
- All components reachable via local Ingress, all declared as ArgoCD Applications

**Key design decisions:**
- MinIO uses the S3 API — `MLFLOW_S3_ENDPOINT_URL` is the only difference between local and AWS S3 in production
- ArgoCD App-of-Apps: one root `Application` manages all child `Application` CRDs. Adding a new platform component is a single YAML file with no Terraform changes
- Namespace isolation from day one: each layer gets its own namespace with independent RBAC and resource quotas

---

### Phase 2 — Training Platform

**Goal:** End-to-end Kubeflow pipeline: DVC data fetch → feature engineering → Ray distributed training → MLflow experiment logging → model registration.

**Deliverables:**
- RayCluster deployed via KubeRay operator (head + auto-scaling workers)
- Kubeflow Pipelines installed with PostgreSQL backend
- DVC configured against MinIO `dvc-store` bucket
- KFP pipeline with typed components: `data_prep → feature_eng → train → evaluate → register`
- Simple sklearn RandomForestClassifier on tabular data (e.g., UCI Adult Income dataset)
- MLflow autologging capturing params, metrics, and model artifact
- Model registered in MLflow Registry with `Staging` tag on successful pipeline run

**Key design decisions:**
- Ray for distributed training even on a simple model: demonstrates the platform can scale without changing training code
- KFP SDK v2 components are type-annotated Python functions compiled to container steps — reusable, testable, and versioned independently
- Threshold gate in the `evaluate` step: pipeline fails (and does not register) if accuracy < baseline, preventing model regression

---

### Phase 2.5 — GenAI & LLMOps Platform

**Goal:** LLM serving and RAG infrastructure running on the same cluster, reusing all Phase 1/2 shared infrastructure — same ArgoCD, same MinIO, same PostgreSQL, same Prometheus/Grafana.

**Deliverables:**

**LLM Serving:**
- vLLM deployed as a Helm chart via ArgoCD, in `ns: llm-serving`
- NGINX Ingress with rate limiting (10 req/s per IP) and API key auth middleware
- CPU mode for local dev (TinyLlama-1.1B); GPU mode for prod via `values-prod.yaml` override
- Model weights stored in MinIO `llm-models/` bucket — version-pinned, not baked into image
- HPA on `vllm_request_queue_depth` custom metric; ServiceMonitor for Prometheus scrape

**RAG Pipeline:**
- pgvector enabled on existing PostgreSQL (`rag_store` DB, `document_chunks` table, ivfflat index)
- Dedicated Embedding Service (all-MiniLM-L6-v2) shared by ingestion and query
- RAG Ingestion Service: DVC pull docs → chunk (512 tokens, 64 overlap) → embed → pgvector upsert
- RAG Query Service: embed question → cosine search → top-k context → vLLM generate → return answer + sources
- Document corpus versioned in DVC, stored in MinIO `rag-docs/` bucket

**LLM Observability:**
- vLLM Grafana dashboard: tokens/sec, TTFT p50/p95, queue depth, GPU memory, KV cache hit rate
- RAG Quality dashboard: retrieval latency, Ragas scores (faithfulness, answer_relevance, context_precision)
- Loki + Promtail: structured JSON logs from all RAG/LLM pods; queryable in Grafana Explore
- PrometheusRules: TTFT p95 > 2s → warning; queue depth > 20 → critical; Ragas score < 0.7 → warning

**LLM CI/CD:**
- `llm-ci.yaml`: lint → unit test → build Docker images → smoke test vLLM endpoint
- `rag-update.yaml`: DVC pull new docs → trigger ingestion → run Ragas eval → fail if below threshold → push Ragas scores to Prometheus Pushgateway

**Key design decisions:**

| Decision | Rationale |
|---|---|
| vLLM over Triton | PagedAttention gives 2-4x memory efficiency; OpenAI-compat API means zero client changes; Triton requires TensorRT-LLM conversion for comparable LLM perf |
| pgvector over Chroma | Reuses existing PostgreSQL — no new DB to operate; ACID for atomic upserts; SQL metadata filtering; ivfflat scales to millions of vectors |
| Weights in MinIO, not image | Mistral-7B is ~14GB; baking into image kills CI performance and layer caching; MinIO + Helm values pin = model upgrade is a PR, not a rebuild |
| Separate Embedding Service | Shared between ingestion and query (one model load in memory); independently scalable; swap embedding models with zero pipeline code change |
| Ragas over custom eval | Reference-free metrics (faithfulness, answer_relevance) don't need ground-truth labels for every query — viable for production monitoring |
| CPU-first, GPU via Helm | vLLM supports CPU inference; local dev uses TinyLlama-1.1B on CPU; prod overrides values-prod.yaml with `nvidia.com/gpu: 1` — zero code change |

---

### Phase 3 — Model Serving

**Goal:** KServe InferenceService with Istio ingress, canary traffic splitting, and horizontal pod autoscaling.

**Deliverables:**
- KServe controller and Istio installed via ArgoCD
- `InferenceService` manifest in infra repo pointing to MLflow `Production` model
- REST endpoint: `POST /v1/models/income-classifier:predict`
- gRPC endpoint: v2 inference protocol
- Canary deployment: 90% stable / 10% canary traffic split via Istio VirtualService
- HPA: min 1 → max 10 pods, targeting 70% CPU
- KServe Transformer pod for pre/post-processing (feature encoding on raw input)

**Key design decisions:**
- KServe abstracts the serving runtime (sklearn/pytorch/onnx) behind the standard gRPC v2 inference protocol — clients never change when you swap the runtime
- Canary traffic split happens at the Istio layer, not in application code — model version rollout is a manifest change, not a code deployment
- Transformer pod decouples feature engineering from model serving, so the predictor only sees already-encoded tensors

---

### Phase 4 — Observability

**Goal:** Full telemetry stack with actionable dashboards and firing alert rules.

**Deliverables:**
- `kube-prometheus-stack` deployed (Prometheus + Grafana + node-exporter + kube-state-metrics)
- OpenTelemetry Collector scraping Ray `:8080`, KServe `:8080`, MLflow `:5000`
- Grafana Tempo for distributed tracing (pipeline steps + inference requests)
- Four Grafana dashboards:
  - **Platform Health** — cluster CPU/memory, pod restarts, PVC usage
  - **Ray Cluster Utilization** — worker count, task throughput, GPU utilization
  - **KServe Inference SLOs** — p50/p95/p99 latency, RPS, error rate
  - **Model Drift & Accuracy** — MLflow metrics over time, prediction distribution
- Alertmanager rules: inference p99 > 500ms, training job failure, MinIO disk > 85%

**Key design decisions:**
- OTel Collector as the single telemetry pipeline: decouples instrumentation from backend. Adding Datadog or a new backend requires only a Collector config change, not application changes
- PrometheusRules stored in Git and applied by ArgoCD — alert definitions are version-controlled and auditable
- Trace IDs propagated in inference response headers — correlate a slow request in Grafana directly to the pipeline step that produced the slow model

---

### Phase 5 — CI/CD Automation

**Goal:** GitHub Actions workflow closes the full loop: code change → retrain → promote → deploy.

**Deliverables:**
- `ci.yaml`: on PR — lint, unit test, build Docker image, push to registry
- `train-and-promote.yaml`: on merge to `main` —
  1. Trigger Kubeflow Pipeline run via KFP SDK
  2. Poll for pipeline completion
  3. If pipeline passes threshold gate: promote model from `Staging` → `Production` in MLflow Registry
  4. Update `inference-service.yaml` in `ml-platform-infra` repo (new model URI / image tag)
  5. ArgoCD detects the change and reconciles — new KServe predictor rolls out
- GitHub Actions OIDC → AWS IAM role (no long-lived credentials)

**Key design decisions:**
- CI never touches the cluster directly — it only writes to Git. ArgoCD handles the actual deployment. This is the "push to Git, not to Kubernetes" GitOps contract
- The threshold gate in the pipeline means bad models never reach the registry — no manual gatekeeping needed for routine retraining runs
- OIDC-based AWS credentials: no secrets stored in GitHub, short-lived tokens per workflow run

---

## Key Interview Talking Points

| Topic | Decision | Rationale |
|---|---|---|
| Two-repo GitOps | Infra config separate from model code | Independent audit, approval gates, ArgoCD stability |
| App-of-Apps | One root ArgoCD app manages all others | Self-healing, easy to add new platform components |
| MinIO over S3 | Local S3-compatible storage | Zero code change to target real S3 in production |
| Namespace isolation | One namespace per platform layer | Independent RBAC, NetworkPolicy, resource quotas |
| KubeRay autoscaling | Workers scale to zero | No idle GPU/CPU cost between training runs |
| KServe + Istio canary | Traffic split at mesh layer | Model version rollout without code changes or downtime |
| OTel Collector | Central telemetry pipeline | Backend-agnostic instrumentation, single config point |
| GitOps promotion | CI writes to Git, ArgoCD deploys | No kubectl in CI, full audit trail, easy rollback |
| vLLM PagedAttention | Non-contiguous KV cache blocks | Eliminates memory fragmentation; 2-4x more concurrent requests per GPU |
| pgvector reuse | pgvector extension on existing Postgres | One less stateful service to operate; no new backup/HA strategy needed |
| Model weights in MinIO | Version-pinned path in Helm values | Decouples model lifecycle from image lifecycle; 14GB weights not in CI |
| Ragas reference-free eval | faithfulness + answer_relevance metrics | No ground-truth labels required; can evaluate every production query sample |
| Separate embedding service | Shared by ingestion and query paths | Single model load in memory; swap embedding model without touching pipeline code |
| Loki structured logs | JSON logs with request_id, token counts | Correlate slow inference in Grafana metrics → full log entry in Loki Explore |

---

## Getting Started

> Phase 1 implementation begins here.

**Prerequisites:**
- Docker Desktop
- k3d `>= 5.6`
- Terraform `>= 1.7`
- kubectl
- helm `>= 3.14`
- ArgoCD CLI

```bash
# Clone the infra repo
git clone https://github.com/<org>/ml-platform-infra
cd ml-platform-infra

# Provision the cluster and bootstrap ArgoCD
cd terraform/environments/local
terraform init
terraform apply

# ArgoCD will reconcile all platform components automatically
argocd app list
```
