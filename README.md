🛡️ FabricGuard X: AI Infrastructure Sentinel

FabricGuard X is a specialized observability solution designed to detect "Silent Packet Loss" in high-speed AI training fabrics (simulating NVIDIA DGX SuperPOD environments). It utilizes a custom Python agent, Multus CNI, and a Prometheus/Grafana stack to monitor kernel-level telemetry that standard observability tools often miss.
🏗️ Phase 1: The "Hardware" Layer

Objective: Create a multi-node simulation of a DGX cluster with two distinct networks: Management (Standard K8s) and High-Speed Fabric (Data Plane).
> What we did:

    Provisioned a 3-node KinD (Kubernetes in Docker) cluster on macOS.

    Created a custom Docker bridge network (fabric-net) to act as the high-speed switch.

    "Hot-plugged" virtual cables by connecting the Docker network to the running Kind containers.

> Hurdles & Solutions:

    The Mac Sandbox: Docker on Mac doesn't expose bridge networks to the host. We bypassed this by verifying connectivity directly inside the containers.

    Minimalist OS: Kind nodes lacked basic networking tools. We manually installed iputils-ping to verify "physical" link integrity.

Bash

# Create the Kubernetes cluster
'kind create cluster --config k8s/fabricguard-config.yaml --name fabricguard-cluster'

# Create and connect the Fabric network
docker network create fabric-net --subnet=192.168.50.0/24
docker network connect fabric-net fabricguard-cluster-control-plane
docker network connect fabric-net fabricguard-cluster-worker
docker network connect fabric-net fabricguard-cluster-worker2

🛠️ Phase 2: The "Plumbing" Layer

Objective: Bridge the gap between Linux host interfaces (eth1) and Kubernetes Pods.
> What we did:

    Deployed Multus CNI, a "meta-plugin" that allows Pods to have multiple network interfaces.

    Configured a NetworkAttachmentDefinition (NAD) to map the host's eth1 to a Pod's net1 using the macvlan driver.

> Hurdles & Solutions:

    The Missing Binary: Multus was ready, but the macvlan execution file was missing from /opt/cni/bin.

    Injection Scripting: Overcame "Standard Input stealing" by providing a targeted injection script to copy CNI binaries to all workers.

Bash

# Inject missing CNI binaries to all nodes
for node in $(kind get nodes --name fabricguard-cluster); do
    docker cp ./binaries/macvlan $node:/opt/cni/bin/
done

# Apply Network Config and Deploy Simulation
kubectl apply -f k8s/fabric-network.yaml
kubectl apply -f k8s/dgx-sim-pod.yaml

📡 Phase 3: The "Sentinel" Layer

Objective: Develop a custom monitoring agent to detect "Silent Drops" on the fabric.
> What we did:

    Wrote a Python Sentinel Agent using prometheus_client to scrape statistics from /proc/net/dev.

    Containerized the agent using a python:3.9-slim base and deployed it with a secondary interface on the fabric.

> Hurdles & Solutions:

    The "Slim Image" Curse: Initial images lacked ip and ping. Evolved to a "Super Sentinel" (v6) containing iproute2 for diagnostics.

    Port Collision: Local macOS processes occupied port 8000; pivoted to Dynamic Port Forwarding to access metrics.

Bash

# Build and Load the Sentinel
docker build --platform linux/amd64 -t fabricguard-sentinel:v6 ./sentinel
kind load docker-image fabricguard-sentinel:v6 --name fabricguard-cluster

# Deploy Sentinel
kubectl apply -f k8s/sentinel-pod.yaml

🌪️ Phase 4: The "Chaos" Layer

Objective: Prove the monitoring works by manually degrading the fabric and verifying detection.
> What we did:

    Used Traffic Control (tc) with netem to simulate 25% packet loss on the net1 interface.

    Performed Synthetic Load Generation using flood pings (-f) with maximum MTU payloads.

> Hurdles & Solutions:

    Access Denied: Containers couldn't modify the network; solved by adding CAP_NET_ADMIN to the securityContext.

    The "noqueue" Bypass: Swapped the queuing discipline to pfifo to force the kernel to respect simulated hardware limits.

Bash

# Inject 25% packet loss
kubectl exec -it fabricguard-sentinel -- tc qdisc add dev net1 root netem drop 25%

# Generate flood traffic
kubectl exec -it fabricguard-sentinel -- ping -f -w 30 192.168.50.1

📊 Phase 5: The "Command Center" Layer

Objective: Transform raw telemetry into professional, real-time SRE insights.
> What we did:

    Deployed a complete Prometheus and Grafana stack within the cluster.

    Built a "Fabric Health" Dashboard in Grafana using threshold-based color logic (Green/Red).

> Hurdles & Solutions:

    The Bind Address Trap: Re-engineered the agent (v5) to bind to 0.0.0.0 to allow cluster-wide scraping.

    The Sampling Aliasing: Implemented Synthetic Injection (v6) to force a constant failure state (125.0) to validate alerting logic.

Bash

# Access UI
kubectl port-forward pod/prometheus 9090:9090 &
kubectl port-forward pod/grafana 3000:3000 &

💡 SRE Takeaways & Methodologies
Concept	Implementation in FabricGuard X
SLI (Indicator)	Network Packet Drop Rate on the net1 fabric interface.
SLO (Objective)	< 0.01% packet loss over a 5-minute rolling window.
MTTD (Detection)	Reduced to < 5 seconds via high-frequency Prometheus scraping.
Chaos Engineering	Used tc netem to verify monitoring catches real-world degradation.
Observability	Correlated kernel /proc/net/dev stats with Grafana visual thresholds.
🏁 How to Run

    Ensure kind, docker, and kubectl are installed.

    Ensure the macvlan Linux binary is in ./binaries/.

    Run the automated bootstrap: bash bootstrap.sh