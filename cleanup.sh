#!/bin/bash

# --- Configuration ---
CLUSTER_NAME="fabricguard-cluster"
NETWORK_NAME="fabric-net"

echo "Starting FabricGuard X Cleanup..."

# 1. Kill any active Port-Forwards
echo "Stopping Port-Forwards..."
# This finds the PIDs for kubectl port-forward and kills them
pkill -f "kubectl port-forward"

# 2. Delete the KinD Cluster
echo " Deleting KinD Cluster: $CLUSTER_NAME..."
kind delete cluster --name $CLUSTER_NAME

# 3. Delete the Docker Fabric Network
echo "Removing Docker Network: $NETWORK_NAME..."
docker network rm $NETWORK_NAME

echo "Environment is clean!"