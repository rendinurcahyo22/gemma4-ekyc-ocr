# 🚀 GKE GPU Provisioning Guide — Gemma 4 eKYC

Step-by-step guide untuk provisioning GKE cluster dengan GPU node pool untuk menjalankan Gemma 4 eKYC OCR pipeline.

---

## Phase 0: Prerequisites & Environment Setup

### Step 0.1 — Set variabel environment

Ganti value sesuai project lo:

```bash
# ⚠️ GANTI SESUAI PROJECT LO
export PROJECT_ID="YOUR_PROJECT_ID"           # <-- ganti ini
export REGION="asia-southeast2"           # Jakarta
export ZONE="asia-southeast2-a"           # atau -b, -c
export CLUSTER_NAME="ekyc-gemma4-cluster"
export GPU_NODEPOOL="gpu-pool-gemma4"
```

### Step 0.2 — Login & set project

```bash
# Login ke GCP (skip kalau udah login)
gcloud auth login

# Set project aktif
gcloud config set project $PROJECT_ID

# Confirm project
gcloud config get-value project
```

### Step 0.3 — Enable required APIs

```bash
gcloud services enable \
    container.googleapis.com \
    compute.googleapis.com \
    artifactregistry.googleapis.com \
    --project=$PROJECT_ID
```

---

## Phase 1: Cek GPU Availability di Jakarta

> [!IMPORTANT]
> Jalanin ini dulu sebelum provisioning! Kita perlu tau GPU apa aja yang available di region Jakarta.

### Step 1.1 — List semua GPU types yang available

```bash
# Cek semua accelerator types di Jakarta region
gcloud compute accelerator-types list \
    --filter="zone:asia-southeast2" \
    --format="table(name, zone, description)"
```

**Expected output** — cari salah satu dari ini:
| Yang dicari | Machine Series | Artinya |
|:---|:---|:---|
| `nvidia-l4` | G2 VM | NVIDIA L4 (24GB) |
| `nvidia-rtx-pro-6000` atau `nvidia-rtx-pro-6000-blackwell` | G4 VM | RTX PRO 6000 (96GB) |
| `nvidia-tesla-t4` | N1 VM | NVIDIA T4 (16GB) |

### Step 1.2 — Cek per zone

```bash
# Zone A
gcloud compute accelerator-types list \
    --filter="zone:asia-southeast2-a" \
    --format="table(name, zone, description)"

# Zone B
gcloud compute accelerator-types list \
    --filter="zone:asia-southeast2-b" \
    --format="table(name, zone, description)"

# Zone C
gcloud compute accelerator-types list \
    --filter="zone:asia-southeast2-c" \
    --format="table(name, zone, description)"
```

> [!NOTE]
> **Copy-paste output dari step ini** biar gw bisa bantu lo pilih GPU + machine type yang tepat.

### Step 1.3 — Cek GPU quota

```bash
# Cek current GPU quota di project
gcloud compute regions describe $REGION \
    --format="table(quotas.metric,quotas.limit,quotas.usage)" \
    --project=$PROJECT_ID | grep -i gpu
```

Kalau quota-nya 0, lo perlu request quota increase di Console:  
→ **IAM & Admin → Quotas → search "GPU" → Edit Quotas**

---

## Phase 2: Create GKE Cluster (CPU-only, tanpa GPU dulu)

> [!TIP]
> Best practice: buat cluster dulu tanpa GPU, lalu add GPU node pool terpisah. Ini lebih flexible dan cost-efficient karena system workloads (kube-system, etc.) jalan di CPU nodes.

### Step 2.1 — Create cluster

```bash
gcloud container clusters create $CLUSTER_NAME \
    --project=$PROJECT_ID \
    --region=$REGION \
    --release-channel=regular \
    --num-nodes=1 \
    --machine-type=e2-standard-4 \
    --disk-size=50 \
    --enable-ip-alias \
    --workload-pool="${PROJECT_ID}.svc.id.goog" \
    --logging=SYSTEM,WORKLOAD \
    --monitoring=SYSTEM
```

> Ini akan buat cluster dengan **1 CPU node per zone** (3 nodes total karena regional). Kalau mau hemat, bisa pakai `--zone=$ZONE` instead of `--region` untuk zonal cluster (1 zone only).

**Versi hemat (zonal cluster — 1 zone saja):**

```bash
gcloud container clusters create $CLUSTER_NAME \
    --project=$PROJECT_ID \
    --zone=$ZONE \
    --release-channel=regular \
    --num-nodes=1 \
    --machine-type=e2-standard-4 \
    --disk-size=50 \
    --enable-ip-alias \
    --workload-pool="${PROJECT_ID}.svc.id.goog" \
    --logging=SYSTEM,WORKLOAD \
    --monitoring=SYSTEM
```

⏱️ *Ini bisa makan waktu 5-10 menit.*

### Step 2.2 — Get credentials

```bash
# Untuk regional cluster:
gcloud container clusters get-credentials $CLUSTER_NAME \
    --region=$REGION \
    --project=$PROJECT_ID

# ATAU untuk zonal cluster:
gcloud container clusters get-credentials $CLUSTER_NAME \
    --zone=$ZONE \
    --project=$PROJECT_ID
```

### Step 2.3 — Verify cluster

```bash
kubectl get nodes
kubectl cluster-info
```

---

## Phase 3: Add GPU Node Pool

> [!IMPORTANT]
> Pilih **SATU** dari opsi di bawah berdasarkan GPU yang available di Phase 1.

---

### Option A: NVIDIA L4 (G2 VM) — Recommended for cost efficiency

```bash
gcloud container node-pools create $GPU_NODEPOOL \
    --cluster=$CLUSTER_NAME \
    --zone=$ZONE \
    --machine-type=g2-standard-8 \
    --accelerator=type=nvidia-l4,count=1 \
    --num-nodes=1 \
    --min-nodes=0 \
    --max-nodes=2 \
    --enable-autoscaling \
    --disk-size=100 \
    --disk-type=pd-ssd \
    --spot
```

**Specs per node:**
- 1x NVIDIA L4 (24GB VRAM)
- 8 vCPU, 32GB RAM
- 100GB SSD
- Spot VM (cheaper, bisa interrupted)

> Hapus `--spot` kalau mau On-Demand (lebih stable, lebih mahal).

---

### Option B: RTX PRO 6000 Blackwell (G4 VM) — Max performance

```bash
gcloud container node-pools create $GPU_NODEPOOL \
    --cluster=$CLUSTER_NAME \
    --zone=$ZONE \
    --machine-type=g4-standard-48 \
    --accelerator=type=nvidia-rtx-pro-6000,count=1 \
    --num-nodes=1 \
    --min-nodes=0 \
    --max-nodes=1 \
    --enable-autoscaling \
    --disk-size=200 \
    --disk-type=pd-ssd
```

**Specs per node:**
- 1x RTX PRO 6000 Blackwell (96GB VRAM)
- 48 vCPU, 192GB RAM
- 200GB SSD

> [!WARNING]
> Accelerator type name mungkin beda — sesuaikan `type=nvidia-rtx-pro-6000` dengan **exact name** dari output Phase 1 Step 1.1. Bisa jadi `nvidia-rtx-pro-6000-blackwell` atau nama lain.

---

### Option C: NVIDIA T4 (N1 VM) — Budget option

```bash
gcloud container node-pools create $GPU_NODEPOOL \
    --cluster=$CLUSTER_NAME \
    --zone=$ZONE \
    --machine-type=n1-standard-8 \
    --accelerator=type=nvidia-tesla-t4,count=1 \
    --num-nodes=1 \
    --min-nodes=0 \
    --max-nodes=2 \
    --enable-autoscaling \
    --disk-size=100 \
    --disk-type=pd-ssd \
    --spot
```

---

### Step 3.1 — Verify GPU node pool

```bash
# Cek node pool
gcloud container node-pools list \
    --cluster=$CLUSTER_NAME \
    --zone=$ZONE

# Cek nodes
kubectl get nodes -o wide

# Cek GPU resource di nodes
kubectl describe nodes | grep -A 5 "nvidia.com/gpu"
```

---

## Phase 4: Install NVIDIA GPU Drivers

> [!IMPORTANT]
> GPU node butuh NVIDIA driver. GKE menyediakan DaemonSet untuk auto-install.

### Step 4.1 — Install NVIDIA GPU device plugin

```bash
# Untuk driver default (recommended)
kubectl apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/container-engine-accelerators/master/nvidia-driver-installer/cos/daemonset-preloaded-latest.yaml
```

### Step 4.2 — Verify driver installation

```bash
# Tunggu ~2-3 menit, lalu cek
kubectl get pods -n kube-system | grep nvidia

# Cek GPU terdeteksi
kubectl describe nodes | grep -A 10 "Capacity" | grep nvidia
```

**Expected output:**
```
nvidia.com/gpu:     1
```

### Step 4.3 — Quick GPU test

```bash
# Run nvidia-smi di dalam pod
kubectl run gpu-test \
    --rm -it \
    --restart=Never \
    --image=nvidia/cuda:12.6.0-base-ubuntu22.04 \
    --limits="nvidia.com/gpu=1" \
    -- nvidia-smi
```

**Expected output:** Lo harus liat info GPU (nama, VRAM, driver version, CUDA version).

---

## Phase 5: Deploy vLLM + Gemma 4

### Step 5.1 — Create namespace

```bash
kubectl create namespace ekyc
```

### Step 5.2 — Create Kubernetes Deployment

Simpan file ini sebagai `vllm-gemma4-deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vllm-gemma4
  namespace: ekyc
  labels:
    app: vllm-gemma4
spec:
  replicas: 1
  selector:
    matchLabels:
      app: vllm-gemma4
  template:
    metadata:
      labels:
        app: vllm-gemma4
    spec:
      nodeSelector:
        cloud.google.com/gke-accelerator: "nvidia-l4"   # <-- sesuaikan dgn GPU lo
      containers:
      - name: vllm
        image: vllm/vllm-openai:latest
        ports:
        - containerPort: 8000
          name: http
        env:
        - name: HF_TOKEN
          valueFrom:
            secretKeyRef:
              name: hf-secret
              key: token
        args:
        # === OPTION A: L4 (INT4 quantized) ===
        - "--model"
        - "google/gemma-4-26b-a4b-it-awq"
        - "--quantization"
        - "awq"
        - "--max-model-len"
        - "4096"
        - "--max-num-seqs"
        - "8"
        - "--gpu-memory-utilization"
        - "0.90"
        - "--dtype"
        - "float16"
        - "--host"
        - "0.0.0.0"
        - "--port"
        - "8000"
        
        # === OPTION B: RTX PRO 6000 (FP16 full precision) ===
        # Uncomment below, comment Option A above
        # - "--model"
        # - "google/gemma-4-26b-a4b-it"
        # - "--max-model-len"
        # - "8192"
        # - "--max-num-seqs"
        # - "16"
        # - "--gpu-memory-utilization"
        # - "0.85"
        # - "--dtype"
        # - "float16"
        # - "--host"
        # - "0.0.0.0"
        # - "--port"
        # - "8000"

        resources:
          limits:
            nvidia.com/gpu: "1"
          requests:
            cpu: "4"
            memory: "16Gi"
            nvidia.com/gpu: "1"
        readinessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 120    # Model loading takes time
          periodSeconds: 10
          failureThreshold: 30
        livenessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 180
          periodSeconds: 30
          failureThreshold: 5
        volumeMounts:
        - name: model-cache
          mountPath: /root/.cache/huggingface
        - name: shm
          mountPath: /dev/shm
      volumes:
      - name: model-cache
        emptyDir:
          sizeLimit: 80Gi
      - name: shm
        emptyDir:
          medium: Memory
          sizeLimit: 8Gi
      tolerations:
      - key: "nvidia.com/gpu"
        operator: "Exists"
        effect: "NoSchedule"
---
apiVersion: v1
kind: Service
metadata:
  name: vllm-gemma4-svc
  namespace: ekyc
spec:
  type: ClusterIP
  selector:
    app: vllm-gemma4
  ports:
  - port: 8000
    targetPort: 8000
    protocol: TCP
    name: http
```

### Step 5.3 — Create HuggingFace token secret

> [!IMPORTANT]
> Gemma 4 butuh HuggingFace token untuk download model (gated model). Daftar dulu di https://huggingface.co/google/gemma-4-26b-a4b-it dan accept license.

```bash
kubectl create secret generic hf-secret \
    --from-literal=token="hf_YOUR_HUGGINGFACE_TOKEN_HERE" \
    --namespace=ekyc
```

### Step 5.4 — Deploy!

```bash
kubectl apply -f vllm-gemma4-deployment.yaml
```

### Step 5.5 — Monitor deployment

```bash
# Watch pod status
kubectl get pods -n ekyc -w

# Cek logs (model downloading & loading)
kubectl logs -f deployment/vllm-gemma4 -n ekyc

# Cek events kalau ada error
kubectl describe pod -l app=vllm-gemma4 -n ekyc
```

⏱️ *Model download + loading bisa makan waktu 10-20 menit pertama kali (tergantung model size dan network speed).*

---

## Phase 6: Test Endpoint

### Step 6.1 — Port forward ke local

```bash
kubectl port-forward svc/vllm-gemma4-svc 8000:8000 -n ekyc
```

### Step 6.2 — Test health

```bash
curl http://localhost:8000/health
```

### Step 6.3 — Test OCR dengan gambar

```bash
# Test dengan gambar KTP (ganti URL dengan gambar asli)
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "google/gemma-4-26b-a4b-it-awq",
    "messages": [
      {
        "role": "user",
        "content": [
          {
            "type": "text",
            "text": "Extract all fields from this Indonesian ID card (KTP). Return as JSON with fields: nik, nama, tempat_lahir, tanggal_lahir, jenis_kelamin, alamat, rt_rw, kel_desa, kecamatan, agama, status_perkawinan, pekerjaan, kewarganegaraan, berlaku_hingga"
          },
          {
            "type": "image_url",
            "image_url": {
              "url": "data:image/jpeg;base64,YOUR_BASE64_IMAGE_HERE"
            }
          }
        ]
      }
    ],
    "max_tokens": 500,
    "temperature": 0.1
  }'
```

### Step 6.4 — Test document classification

```bash
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "google/gemma-4-26b-a4b-it-awq",
    "messages": [
      {
        "role": "user",
        "content": [
          {
            "type": "text",
            "text": "Classify this document into one of: KTP, SIM, PASSPORT, NPWP, KK, SERTIFIKAT, OTHER. Return only the classification label."
          },
          {
            "type": "image_url",
            "image_url": {
              "url": "data:image/jpeg;base64,YOUR_BASE64_IMAGE_HERE"
            }
          }
        ]
      }
    ],
    "max_tokens": 10,
    "temperature": 0.0
  }'
```

---

## Phase 7: Expose via Internal Load Balancer (Optional)

Kalau mau expose ke internal network (bukan public internet):

```yaml
# internal-lb.yaml
apiVersion: v1
kind: Service
metadata:
  name: vllm-gemma4-ilb
  namespace: ekyc
  annotations:
    networking.gke.io/load-balancer-type: "Internal"
spec:
  type: LoadBalancer
  selector:
    app: vllm-gemma4
  ports:
  - port: 80
    targetPort: 8000
    protocol: TCP
```

```bash
kubectl apply -f internal-lb.yaml

# Get internal IP
kubectl get svc vllm-gemma4-ilb -n ekyc
```

---

## 🧹 Cleanup (Kalau Mau Hapus)

```bash
# Hapus deployment
kubectl delete -f vllm-gemma4-deployment.yaml

# Hapus GPU node pool (stop GPU billing)
gcloud container node-pools delete $GPU_NODEPOOL \
    --cluster=$CLUSTER_NAME \
    --zone=$ZONE \
    --quiet

# Hapus entire cluster
gcloud container clusters delete $CLUSTER_NAME \
    --zone=$ZONE \
    --quiet
```

---

## 📋 Troubleshooting Checklist

| Issue | Solution |
|:---|:---|
| `Insufficient nvidia.com/gpu` | GPU driver belum terinstall → jalanin Phase 4 |
| `Unschedulable` | Quota GPU habis → request quota increase di Console |
| Pod `Pending` lama | Node pool belum scale up → cek autoscaler events |
| `CUDA out of memory` | Model terlalu besar → turunkan `max-model-len` atau pakai quantized model |
| Model download lambat | Network bandwidth → pakai disk SSD lebih besar atau pre-pull image |
| `403 Forbidden` dari HuggingFace | HF token salah/expired, atau belum accept Gemma license |
| `nvidia-smi` not found | GPU driver belum ready → tunggu DaemonSet selesai |
