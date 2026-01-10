#!/bin/bash

# --- Configuration ---
CLUSTER_NAME="fabricguard-cluster"
NETWORK_NAME="fabric-net"
SENTINEL_IMAGE="fabricguard-sentinel:v6"
KIND_CONFIG="k8s/fabricguard-config.yaml"

echo " Starting FabricGuard X Bootstrap..."

# 1. Pre-flight Checks
if [ ! -f "$KIND_CONFIG" ]; then
    echo "Error: $KIND_CONFIG not found!"
    exit 1
fi

if [ ! -f "binaries/macvlan" ]; then
    echo "Error: binaries/macvlan not found! Multus will fail."
    exit 1
fi

# 2. Infrastructure Layer
echo "Creating KinD Cluster..."
kind create cluster --config "$KIND_CONFIG" --name "$CLUSTER_NAME"

echo "Setting up Docker Fabric Network..."
docker network create "$NETWORK_NAME" --subnet=192.168.50.0/24

echo "Connecting nodes to the fabric..."
for node in $(kind get nodes --name "$CLUSTER_NAME"); do
    docker network connect "$NETWORK_NAME" "$node"
    echo "Connected $node to $NETWORK_NAME"
done

# 3. Plumbing Layer (Multus & Macvlan)
echo "Installing Multus CNI..."
kubectl apply -f https://raw.githubusercontent.com/k8snetworkplumbingwg/multus-cni/master/deployments/multus-daemonset.yml

echo " Injecting CNI binaries..."
sleep 2
for node in $(kind get nodes --name "$CLUSTER_NAME"); do
    docker cp binaries/macvlan "$node":/opt/cni/bin/
done

echo "Applying Network Attachment Definitions..."
kubectl apply -f k8s/fabric-network.yaml

# 4. Application & Observability Layer
echo "Loading Sentinel v6 Image into KinD..."
kind load docker-image "$SENTINEL_IMAGE" --name "$CLUSTER_NAME"

echo "Deploying Monitoring Stack & Sentinel..."
# We apply individual files to avoid issues with the Cluster config in the same dir
kubectl apply -f k8s/monitoring.yaml
kubectl apply -f k8s/sentinel-pod.yaml

echo "Waiting for pods to stabilize (this may take 30s)..."
kubectl wait --for=condition=Ready pod --all --timeout=90s

echo "✅ BOOTSTRAP COMPLETE!"
echo "--------------------------------------------------"
echo "Prometheus: http://localhost:9090"
echo "Grafana:    http://localhost:3000 (User: admin / Pass: admin)"
echo "--------------------------------------------------"
echo "Run these in a new terminal to access the UI:"
echo "kubectl port-forward pod/prometheus 9090:9090 &"
echo "kubectl port-forward pod/grafana 3000:3000 &"