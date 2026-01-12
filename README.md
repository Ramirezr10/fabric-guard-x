Fabric Guard X 

Fabric Guard X is a high-fidelity simulation of a DGX SuperPOD cluster environment. It implements a multi-node Kubernetes architecture with a dedicated secondary High-Speed Fabric (simulating InfiniBand) to detect and visualize "Silent Drops" and network degradation using a custom-built observability stack.

🏗️ Architecture Overview

The project is structured into five distinct layers, moving from physical hardware simulation to high-level SRE visualization.

 Phase 1: The "Hardware" Layer

Objective: Create a multi-node simulation of a DGX cluster with two distinct networks: Management (Standard K8s) and High-Speed Fabric (Data Plane).

    Implementation:

        Used KinD (Kubernetes in Docker) to provision a 3-node cluster on macOS.

        Created a custom Docker bridge network (fabric-net) to act as the high-speed backend switch.

        "Hot-plugged" virtual cables by connecting the Docker network directly to the running Kind containers.

    Hurdles & Solutions:

        The Mac Sandbox: Docker on Mac doesn't expose bridge networks to the host. Verified connectivity by entering container namespaces directly.

        Minimalist OS: Kind nodes lacked networking tools. Manually injected iputils-ping via apt-get to verify the "cables" were active.

 Phase 2: The "Plumbing" Layer

Objective: Bridge the gap between the Linux host interfaces (eth1) and the Kubernetes Pods.

    Implementation:

        Deployed Multus CNI, a "meta-plugin" allowing Pods to have multiple network interfaces.

        Configured a NetworkAttachmentDefinition (NAD) to map the host's eth1 to a Pod's net1 using the macvlan driver.

    Hurdles & Solutions:

        The Missing Binary: Multus was active, but the macvlan executable was missing from /opt/cni/bin.

        Injection Scripting: Fixed "Standard Input (stdin) stealing" in bash loops by creating a targeted injection script to distribute CNI binaries to all worker nodes.

        Success Metric: Launched dgx-sim-pod showing two IP ranges: 10.244.x.x (Management) and 192.168.50.100 (Fabric).

 Phase 3: The "Sentinel" (Observability) Layer

Objective: Develop a custom monitoring agent to detect "Silent Drops" on the high-speed fabric and export them as Prometheus metrics.

    Implementation:

        Wrote a Python Sentinel Agent using prometheus_client to scrape kernel-level statistics from /proc/net/dev.

        Containerized the agent and deployed it as a Pod (fabricguard-sentinel) with a secondary interface on the fabric network.

        Exposed a Prometheus metrics endpoint on port 8000.

    Hurdles & Solutions:

        The "Slim Image" Curse: Evolved the Dockerfile to "Super Sentinel" (v4) to include iproute2 and iputils-ping for diagnostics.

        Ghost Images: Implemented Version Pinning and a marker file (/etc/is_v4_sentinel) to prevent KinD from using cached, outdated images.

        Port Collision: Used dynamic port forwarding (8080:8000) to bypass local macOS port conflicts.

 Phase 4: The "Chaos" (Failure Injection) Layer

Objective: Prove the monitoring pipeline works by manually degrading the fabric and verifying Sentinel detection.

    Implementation:

        Used Traffic Control (tc) with the Network Emulator (netem) module to simulate a 25% packet loss on the net1 interface.

        Performed Synthetic Load Generation using flood pings with maximum MTU payloads (-s 65000) to stress the simulated fabric.

    Hurdles & Solutions:

        Access Denied: Granted CAP_NET_ADMIN in the Pod's securityContext to allow kernel-level network manipulation.

        The "noqueue" Bypass: Virtual interfaces ignore drop limits by default. Swapped queuing discipline to pfifo to force the kernel to respect simulated hardware limits.

        Kernel Reporting Lag: Utilized tc -s qdisc to confirm egress layer drops, closing the detection loop.

 Phase 5: The "Command Center" (Visualization) Layer

Objective: Transform raw kernel telemetry into a professional, real-time SRE dashboard for a DGX SuperPOD.

    Implementation:

        Deployed a full stack of Prometheus (TSDB) and Grafana (Visualization).

        Configured a Scrape Job to target the Sentinel Agent every 5 seconds for high-resolution detection.

        Built a "Fabric Health" Dashboard with threshold-based color logic (Green = Healthy, Red = Alert).

    Hurdles & Solutions:

        The Bind Address Trap: Re-engineered the agent (v5) to listen on 0.0.0.0 instead of 127.0.0.1 to allow cluster-wide scraping.

        The Service Discovery Gap: Aligned Kubernetes Label Selectors (app: sentinel) to ensure the Prometheus Service could resolve the Sentinel endpoints.

        Sampling Aliasing: Implemented Synthetic Injection (v6) to validate that the entire pipeline triggers a critical "Red Alert" during failure states.

Quick Start

Prerequisites

    Docker Desktop (macOS/Linux)

    KinD (Kubernetes in Docker)

    kubectl

Deploy the Fabric


# Example command to inject the CNI binaries
docker exec -i kind-worker /bin/bash -c "cat > /opt/cni/bin/macvlan" < ./bin/macvlan
chmod +x /opt/cni/bin/macvlan

Accessing the Dashboard

    Port-forward the Grafana service:
   

    kubectl port-forward svc/grafana 3000:3000

    Open localhost:3000 in your browser.

    Observe the "Fabric Health" panel.

🛠️ Tech Stack

    Orchestration: Kubernetes (KinD)

    Networking: Multus CNI, Macvlan, Linux Traffic Control (tc)

    Monitoring: Prometheus, Grafana

    Language: Python 3.9 (Sentinel Agent)

    Diagnostics: iproute2, iputils-ping, procfs
