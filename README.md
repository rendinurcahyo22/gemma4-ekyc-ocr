# Gemma 4 eKYC OCR & Classification

Repository ini berisi panduan dan analisis untuk deploy **Gemma 4 26B MoE** untuk use case OCR dan Klasifikasi Dokumen eKYC Onboarding di Google Cloud (GKE).

## 📂 Konten
- [Analisis Kelayakan (Feasibility)](gemma4_ekyc_feasibility.md): Perbandingan GPU (L4 vs RTX PRO 6000), estimasi cost, dan performance benchmark.
- [Panduan GKE Provisioning](gke_gpu_provisioning_guide.md): Step-by-step setup cluster GKE dengan GPU node pool, driver installation, dan deployment vLLM.

## 🚀 Quick Start
Untuk menjalankan vLLM dengan Gemma 4:
1. Setup GKE cluster dengan GPU L4 atau G4.
2. Install NVIDIA Driver.
3. Deploy vLLM menggunakan manifest yang tersedia di panduan.

---
Created by Antigravity Assistant.
