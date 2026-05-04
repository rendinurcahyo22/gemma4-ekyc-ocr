# Feasibility Analysis: Gemma 4 eKYC — RTX PRO 6000 (G4) vs L4 (G2)

## 📋 Requirement Recap

| Parameter | Value |
|:---|:---|
| **Use Case** | OCR + Klasifikasi Dokumen eKYC Onboarding |
| **Volume** | 5,000 dokumen/hari |
| **SLA Latency** | ≤ 5 detik per dokumen |
| **Available GPU** | ✅ G4 VM — RTX PRO 6000 Blackwell (sudah ada slot) |
| **Comparison** | G2 VM — NVIDIA L4 |

---

## 🔥 Klarifikasi: G2 vs G4 VM

> [!IMPORTANT]
> Bro, yang lo punya itu bukan G2 — **G2 VM pakai NVIDIA L4 (24GB)**. Yang pakai **RTX PRO 6000 Blackwell** itu **G4 VM**. Pastiin yang lo punya itu memang **G4**, bukan G2. Tapi gw analisis keduanya biar lo bisa compare.

| VM Series | GPU | Arch | VRAM | Status Lo |
|:---|:---|:---|:---|:---|
| **G2** | NVIDIA L4 | Ada Lovelace | 24 GB GDDR6 | ❓ Mungkin ini yang lo punya? |
| **G4** | RTX PRO 6000 Blackwell SE | Blackwell | 96 GB GDDR7 | ✅ Kalau ini, jackpot |

---

## 🖥️ Hardware Head-to-Head

### GPU Specifications

| Spec | RTX PRO 6000 Blackwell (G4) | NVIDIA L4 (G2) | Winner |
|:---|:---|:---|:---|
| **Architecture** | Blackwell (2025) | Ada Lovelace (2023) | 🏆 RTX PRO 6000 |
| **VRAM** | 96 GB GDDR7 + ECC | 24 GB GDDR6 | 🏆 RTX PRO 6000 (4x) |
| **Memory Bandwidth** | 1,792 GB/s | 300 GB/s | 🏆 RTX PRO 6000 (6x) |
| **Tensor Cores** | 5th Gen (FP4 native) | 4th Gen (FP8 native) | 🏆 RTX PRO 6000 |
| **Interface** | PCIe Gen 5 | PCIe Gen 4 | 🏆 RTX PRO 6000 |
| **TDP** | ~300-400W | 72W | 🏆 L4 (efficiency) |
| **MIG Support** | ✅ Yes | ❌ No | 🏆 RTX PRO 6000 |
| **Price Tier** | $$$ Premium | $ Budget | 🏆 L4 (cost) |

### Machine Type Options

| Config | G4 (RTX PRO 6000) | G2 (L4) |
|:---|:---|:---|
| **Smallest (1 GPU)** | `g4-standard-48` (48 vCPU) | `g2-standard-4` (4 vCPU) |
| **Medium** | `g4-standard-96` (2 GPU) | `g2-standard-8` (8 vCPU) |
| **Network** | Up to 400 Gbps | Up to 100 Gbps |

---

## 🧠 Gemma 4 Model Fit per GPU

### Apa yang bisa jalan di masing-masing GPU?

| Model | Precision | VRAM Needed | L4 (24GB) | RTX PRO 6000 (96GB) |
|:---|:---|:---|:---|:---|
| **E4B (8B)** | FP16 | ~16 GB | ✅ Fit | ✅ Fit (overkill) |
| **E4B (8B)** | INT4 | ~6 GB | ✅ Easy | ✅ Way overkill |
| **26B MoE** | FP16 | ~50 GB | ❌ Gak muat | ✅ **Fit perfect** |
| **26B MoE** | INT8 | ~28 GB | ❌ Gak muat | ✅ Fit |
| **26B MoE** | INT4 | ~14-18 GB | ✅ Fit (tight) | ✅ Fit (room to spare) |
| **26B MoE** | FP4 (native) | ~14 GB | ⚠️ Tight | ✅ **Native support** |
| **31B Dense** | FP16 | ~62 GB | ❌ Gak muat | ✅ Fit |
| **31B Dense** | INT4 | ~18-22 GB | ⚠️ Very tight | ✅ Fit |

> [!TIP]
> **RTX PRO 6000 advantage**: Lo bisa jalanin **Gemma 4 26B MoE di FP16 tanpa quantization** — ini artinya **zero accuracy loss** dari kompresi model. Di L4, lo harus quantize ke INT4 yang bisa menurunkan akurasi OCR sedikit.

---

## ⚡ Performance Projection

### Scenario: Gemma 4 26B MoE — OCR + Classification

| Metric | RTX PRO 6000 (FP16) | RTX PRO 6000 (FP4) | L4 (INT4/AWQ) |
|:---|:---|:---|:---|
| **Decode speed** | ~80-120 tok/s | ~150-200 tok/s | ~30-40 tok/s |
| **Prefill (img+prompt)** | ~0.2-0.5s | ~0.1-0.3s | ~0.5-1.5s |
| **Decode (~200 tok output)** | ~1.5-2.5s | ~1.0-1.5s | ~2.0-3.5s |
| **Total per document** | **~2-3 detik** ⚡ | **~1.5-2 detik** ⚡⚡ | **~3-5 detik** ✅ |
| **Throughput (seq.)** | ~20-30 docs/min | ~30-40 docs/min | ~12-20 docs/min |
| **Throughput (batch=8)** | ~80-120 docs/min | ~120-160 docs/min | ~30-50 docs/min |
| **Daily capacity (seq.)** | ~29K-43K docs/day | ~43K-58K docs/day | ~17K-29K docs/day |
| **Daily capacity (batched)** | ~115K-173K docs/day | ~173K-230K docs/day | ~43K-72K docs/day |

### Kenapa RTX PRO 6000 jauh lebih cepat?

```
Memory Bandwidth Comparison:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

RTX PRO 6000:  ████████████████████████████████████  1,792 GB/s
L4:            ██████                                  300 GB/s
                                                       
                        6x faster ↑
                        
LLM decoding is MEMORY BANDWIDTH BOUND
→ 6x bandwidth ≈ ~3-4x faster inference (with overhead)
```

---

## 💰 Cost Comparison

### Estimated Monthly Cost

| Scenario | RTX PRO 6000 (G4) | L4 (G2) |
|:---|:---|:---|
| **Hourly On-Demand** | ~$2.50-3.50/hr (est.) | ~$0.70-0.90/hr |
| **Monthly 24/7 On-Demand** | ~$1,800-2,500 | ~$500-650 |
| **Monthly Spot** | ~$600-900 | ~$160-200 |
| **Monthly 12hr/day** | ~$900-1,260 | ~$250-325 |
| **CUD 1-year** | ~$1,200-1,750 | ~$350-450 |

### Cost per Document

| Metric | RTX PRO 6000 | L4 |
|:---|:---|:---|
| **Cost per doc (on-demand 24/7)** | ~$0.012-0.017 | ~$0.003-0.004 |
| **Cost per doc (spot)** | ~$0.004-0.006 | ~$0.001-0.001 |

> [!NOTE]
> RTX PRO 6000 sekitar **3-4x lebih mahal** dari L4 per bulan, tapi juga **3-4x lebih cepat**. Cost per document roughly similar, tapi RTX PRO 6000 memberikan **headroom yang jauh lebih besar** dan **latency lebih rendah**.

---

## 🎯 Scenario Analysis: 5,000 Docs/Day @ 5s SLA

### ✅ RTX PRO 6000 (G4) — VERDICT: OVERKILL tapi EXCELLENT

```
Required:  5,000 docs/day @ 5s SLA
Capacity:  29,000-43,000 docs/day (sequential, FP16)
           up to 230,000 docs/day (batched, FP4)
Latency:   ~1.5-3 detik per doc ← jauh di bawah SLA
Headroom:  6-46x capacity vs requirement
VRAM:      96GB → bisa jalanin FP16 tanpa quantization
```

**Keuntungan utama:**
1. ⚡ **Latency 1.5-3s** — well under 5s SLA, bisa handle burst traffic
2. 🎯 **FP16 / no quantization** — maximum OCR accuracy, zero compression loss
3. 📈 **Massive headroom** — kalau volume naik 10x jadi 50K docs/day, masih aman
4. 🔀 **MIG support** — bisa partition GPU jadi multiple isolated instances
5. 🧠 **Bisa jalanin Gemma 4 31B Dense** — kalau butuh accuracy tertinggi

**Concern:**
- 💰 Overpaying untuk workload 5K docs/day saja
- ⚡ GPU utilization rendah (~5-15% untuk workload ini)

---

### ✅ L4 (G2) — VERDICT: SWEET SPOT untuk 5K docs/day

```
Required:  5,000 docs/day @ 5s SLA
Capacity:  17,000-29,000 docs/day (sequential, INT4)
           up to 72,000 docs/day (batched)
Latency:   ~3-5 detik per doc ← just within SLA
Headroom:  3-14x capacity vs requirement
VRAM:      24GB → perlu INT4 quantization
```

**Keuntungan utama:**
1. 💰 **3-4x lebih murah** — ~$500-650/bulan vs ~$1,800-2,500
2. ✅ **Masih sufficient** — 3-14x headroom
3. 🌱 **Efficient** — GPU utilization ~20-30%, more reasonable

**Concern:**
- ⚠️ Latency ~3-5s — cutting it close to 5s SLA
- ⚠️ INT4 quantization — slight accuracy loss (~1-3%)
- ⚠️ Limited headroom untuk growth

---

## 🏆 Decision Matrix

| Criteria | Weight | RTX PRO 6000 (G4) | L4 (G2) |
|:---|:---|:---|:---|
| **Latency** | 25% | ⭐⭐⭐⭐⭐ (1.5-3s) | ⭐⭐⭐ (3-5s) |
| **OCR Accuracy** | 25% | ⭐⭐⭐⭐⭐ (FP16, no quant) | ⭐⭐⭐⭐ (INT4, slight loss) |
| **Cost Efficiency** | 20% | ⭐⭐ ($1.8-2.5K/mo) | ⭐⭐⭐⭐⭐ ($500-650/mo) |
| **Growth Headroom** | 15% | ⭐⭐⭐⭐⭐ (46x capacity) | ⭐⭐⭐ (14x capacity) |
| **GPU Utilization** | 10% | ⭐⭐ (5-15% waste) | ⭐⭐⭐⭐ (20-30%) |
| **eKYC Compliance** | 5% | ⭐⭐⭐⭐⭐ (max accuracy) | ⭐⭐⭐⭐ (good enough) |
| **TOTAL** | 100% | **⭐⭐⭐⭐ (4.0)** | **⭐⭐⭐⭐ (3.9)** |

---

## 🧩 Advanced: MIG pada RTX PRO 6000

Kalau lo udah punya slot G4, lo bisa **maximize utilization** dengan **Multi-Instance GPU (MIG)**:

```
┌─────────────────────────────────────────────────────┐
│              RTX PRO 6000 (96GB GDDR7)              │
│                                                      │
│  ┌──────────────────┐  ┌──────────────────────────┐ │
│  │   MIG Partition 1 │  │   MIG Partition 2        │ │
│  │   ~48 GB          │  │   ~48 GB                 │ │
│  │                    │  │                          │ │
│  │   Gemma 4 26B MoE │  │   Other workload:        │ │
│  │   (FP16)          │  │   - Face matching        │ │
│  │   eKYC OCR        │  │   - Liveness detection   │ │
│  │                    │  │   - Another Gemma model  │ │
│  └──────────────────┘  └──────────────────────────┘ │
└─────────────────────────────────────────────────────┘
```

Ini bikin investasi G4 lebih worth it — lo bisa jalanin **multiple eKYC workloads** di 1 GPU:
1. **Partition 1**: Gemma 4 26B MoE (OCR + Classification)
2. **Partition 2**: Face matching model / liveness detection / fraud detection

---

## 📌 Final Recommendation

### Kalau lo udah punya slot G4 (RTX PRO 6000):

> [!TIP]
> **PAKAI AJA.** RTX PRO 6000 overkill untuk 5K docs/day, tapi advantage-nya significant:
> - **FP16 tanpa quantization** = max accuracy untuk eKYC compliance
> - **Latency ~1.5-3s** = well under 5s SLA, smooth UX
> - **MIG** = bisa share GPU untuk workload lain (face matching, liveness, dll)
> - **Future-proof** = kalau volume naik 10x, masih aman

### Kalau belum punya dan mau cost-optimize:

> **PAKAI L4 (G2).** Sufficient untuk 5K docs/day, 3-4x lebih murah, dan latency masih within SLA.

---

## 🏗️ Recommended Setup (RTX PRO 6000)

```
┌──────────────────────────────────────────────────────────────┐
│                    eKYC Pipeline — G4 VM                     │
│                                                              │
│  VM:    g4-standard-48 (1x RTX PRO 6000, 48 vCPU)          │
│  Model: Gemma 4 26B A4B MoE (FP16 — no quantization!)      │
│  Engine: vLLM / TensorRT-LLM                                │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                  vLLM Server                         │    │
│  │                                                      │    │
│  │  Config:                                             │    │
│  │    model: google/gemma-4-26b-a4b-it                  │    │
│  │    dtype: float16  (no quantization needed!)         │    │
│  │    max_model_len: 8192                               │    │
│  │    max_num_seqs: 16                                  │    │
│  │    gpu_memory_utilization: 0.85                      │    │
│  │    performance_mode: throughput                      │    │
│  │                                                      │    │
│  │  Endpoints:                                          │    │
│  │    POST /v1/ocr          → Extract text fields       │    │
│  │    POST /v1/classify     → Classify document type    │    │
│  │    POST /v1/ocr-classify → Combined pipeline         │    │
│  └─────────────────────────────────────────────────────┘    │
│                           │                                  │
│                           ▼                                  │
│              ┌──────────────────────┐                        │
│              │  Results → Cloud SQL │                        │
│              │  Images → GCS Bucket │                        │
│              └──────────────────────┘                        │
└──────────────────────────────────────────────────────────────┘
```

### vLLM Launch Command (RTX PRO 6000)
```bash
# FP16 — full precision, maximum OCR accuracy
python -m vllm.entrypoints.openai.api_server \
    --model google/gemma-4-26b-a4b-it \
    --dtype float16 \
    --max-model-len 8192 \
    --max-num-seqs 16 \
    --gpu-memory-utilization 0.85 \
    --host 0.0.0.0 \
    --port 8000

# FP4 — native Blackwell support, maximum speed
python -m vllm.entrypoints.openai.api_server \
    --model google/gemma-4-26b-a4b-it \
    --quantization fp4 \
    --max-model-len 8192 \
    --max-num-seqs 32 \
    --gpu-memory-utilization 0.90 \
    --host 0.0.0.0 \
    --port 8000
```

### vLLM Launch Command (L4 — kalau mau compare)
```bash
# INT4/AWQ — quantized to fit 24GB
python -m vllm.entrypoints.openai.api_server \
    --model google/gemma-4-26b-a4b-it-awq \
    --quantization awq \
    --max-model-len 4096 \
    --max-num-seqs 8 \
    --gpu-memory-utilization 0.90 \
    --host 0.0.0.0 \
    --port 8000
```
