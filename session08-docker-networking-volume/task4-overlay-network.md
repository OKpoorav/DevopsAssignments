# Task 4 – Docker Overlay Networks (research)

## What is an overlay network?

A **bridge** network only exists on one Docker host. An **overlay** network is a virtual layer-2 network that **spans multiple Docker hosts**. Containers on different machines attached to the same overlay get IPs from one subnet and can talk to each other directly by name, as if they were plugged into the same switch.

Overlay networks are built into Docker **Swarm mode**. Creating one needs a swarm (`docker swarm init`), and the network has `SCOPE = swarm` instead of `local`.

## How it works across hosts

```
   Host A (192.168.1.10)                         Host B (192.168.1.11)
 ┌─────────────────────────┐                  ┌─────────────────────────┐
 │ container web.1         │                  │ container web.2         │
 │ 10.0.1.3                │                  │ 10.0.1.4                │
 │     │  (overlay ns, br0)│                  │ (overlay ns, br0) │     │
 │   vxlan0 ── VTEP        │  UDP 4789 VXLAN  │        VTEP ── vxlan0   │
 │     eth0 ===============╪══════════════════╪=============== eth0     │
 └─────────────────────────┘ underlay network └─────────────────────────┘
```

1. **VXLAN encapsulation.** When `web.1` sends a frame to `10.0.1.4`, Docker's overlay driver wraps the Ethernet frame in a UDP packet (VXLAN, **UDP 4789**) addressed to Host B's real IP. Host B removes the wrapper and delivers the original frame to `web.2`. Each overlay has its own **VXLAN ID (VNI)**; the demo network got `4097`.
2. **Control plane.** Swarm managers keep the network state in the Raft store. Nodes share which container IP/MAC lives on which host through a **gossip protocol** (TCP/UDP **7946**). This replaces the external key-value store (Consul/etcd) that older Docker versions needed.
3. **Cluster management** traffic uses TCP **2377**. Ports 2377/tcp, 7946/tcp+udp and 4789/udp must be open between hosts.
4. **Service discovery and load balancing.** Docker's embedded DNS (127.0.0.11) resolves a **service name** to a virtual IP (VIP), and IPVS spreads connections across the tasks. `tasks.<service>` returns each task's IP.
5. **Encryption (optional).** `docker network create -d overlay --opt encrypted` adds IPsec (AES-GCM) between nodes.
6. **Ingress network.** Swarm creates an `ingress` overlay automatically. It powers the **routing mesh**: a published service port answers on *every* node and forwards to a healthy task.

## Use cases

- Microservices spread over several hosts in a **Docker Swarm** cluster (frontend on node 1, API on node 2, DB on node 3) using plain service names.
- **High availability**: replicas on different machines behind one service name / VIP.
- **Isolation per application**: one overlay per stack, so stacks cannot see each other.
- `--attachable` overlays let standalone containers (`docker run`) join a swarm network for debugging or one-off jobs.
- **Secure east-west traffic** between data centres or cloud VMs with `--opt encrypted`.

(In Kubernetes the same job is done by CNI plugins such as Flannel (VXLAN), Calico or Cilium; Docker overlay is the Swarm equivalent.)

## Bridge vs Host vs Overlay

| | bridge | host | overlay |
|---|---|---|---|
| Scope | single host | single host | multi-host (swarm) |
| Isolation | own network namespace, NAT | none – shares host stack | own namespace, VXLAN |
| Port publishing | `-p` needed | not needed / ignored | routing mesh / `-p` on service |
| DNS by name | user-defined bridges only | n/a | yes (services + containers) |
| Typical use | single-host apps, dev | max performance, network tools | Swarm services across nodes |

## Hands-on (single node)

I only have one Docker host (Docker Desktop), so the demo runs a one-node swarm. The commands are the same on a real multi-node cluster; you only add `docker swarm join --token ...` on the other machines.

```bash
docker swarm init --advertise-addr 127.0.0.1
docker network create -d overlay --attachable s08-overlay-net
docker network inspect s08-overlay-net        # driver=overlay scope=swarm vxlan-id=4097
docker service create --name s08-web --replicas 2 --network s08-overlay-net nginx:alpine
docker run --rm --network s08-overlay-net alpine sh -c 'nslookup s08-web; nslookup tasks.s08-web; wget -qO- http://s08-web'
# cleanup
docker service rm s08-web && docker network rm s08-overlay-net && docker swarm leave --force
```

![overlay demo](screenshots/12-overlay-demo.png)

Observations:
- `s08-web` resolves to one **VIP** (`10.0.1.2`), and `tasks.s08-web` returns the two task IPs (`10.0.1.3`, `10.0.1.4`). This shows the built-in service discovery and load balancing.
- A standalone container reached the service over the overlay because the network was created with `--attachable`.
- Swarm also created the `ingress` overlay automatically.
