#!/bin/bash

# ==============================================================================
# GKE GPU PROVISIONING SCRIPT — Gemma 4 eKYC
# ==============================================================================

# ⚠️ GANTI SESUAI PROJECT LO
export PROJECT_ID="YOUR_PROJECT_ID"
export REGION="asia-southeast2"
export ZONE="asia-southeast2-a"
export CLUSTER_NAME="ekyc-gemma4-cluster"
export GPU_NODEPOOL="gpu-pool-gemma4"

echo "🚀 Starting GKE Provisioning for project: $PROJECT_ID"

# 1. Enable APIs
echo "📡 Enabling APIs..."
gcloud services enable \
    container.googleapis.com \
    compute.googleapis.com \
    artifactregistry.googleapis.com \
    --project=$PROJECT_ID

# 2. Create Cluster (CPU-only base)
echo "🏗️ Creating GKE Cluster (Zonal)..."
gcloud container clusters create $CLUSTER_NAME \
    --project=$PROJECT_ID \
    --zone=$ZONE \
    --release-channel=regular \
    --num-nodes=1 \
    --machine-type=e2-standard-4 \
    --disk-size=50 \
    --enable-ip-alias \
    --workload-pool="${PROJECT_ID}.svc.id.goog"

# 3. Add GPU Node Pool (RTX PRO 6000 - G4 series)
echo "🏎️ Adding GPU Node Pool (RTX PRO 6000)..."
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

# 4. Get Credentials
echo "🔑 Getting cluster credentials..."
gcloud container clusters get-credentials $CLUSTER_NAME --zone=$ZONE --project=$PROJECT_ID

# 5. Install GPU Driver
echo "🔧 Installing NVIDIA GPU Drivers..."
kubectl apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/container-engine-accelerators/master/nvidia-driver-installer/cos/daemonset-preloaded-latest.yaml

echo "✅ Provisioning Complete! Wait 2-3 mins for GPU driver to be ready."
echo "Check progress with: kubectl get pods -n kube-system | grep nvidia"
