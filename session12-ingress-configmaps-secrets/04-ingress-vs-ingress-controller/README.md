# Ingress vs Ingress Controller

## What is Ingress?
An **Ingress** is a Kubernetes API object (`networking.k8s.io/v1`) that declares **HTTP/HTTPS routing rules** from outside the cluster to Services inside it:
- **Host-based routing** – `shop.example.com` → `shop-svc`, `admin.example.com` → `admin-svc`
- **Path-based routing** – `/api` → `backend-svc`, `/` → `frontend-svc`
- **TLS termination** – reference a `kubernetes.io/tls` Secret for HTTPS
- **Default backend** – where unmatched requests go

An Ingress on its own is **just data stored in etcd**. Nothing happens until something reads it.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: yatri-ingress
spec:
  ingressClassName: nginx          # which controller should implement this
  rules:
    - host: yatri.local
      http:
        paths:
          - path: /api
            pathType: Prefix
            backend: {service: {name: backend-svc, port: {number: 80}}}
```

## What is an Ingress Controller?
An **Ingress Controller** is a **running application (Pods + a Service)** that:
1. Watches the Kubernetes API for Ingress (and Service/EndpointSlice/Secret) objects.
2. Translates the rules into the configuration of a real reverse proxy / load balancer (e.g. generates `nginx.conf`).
3. Receives the actual traffic (usually exposed via a `LoadBalancer` or `NodePort` Service) and proxies it straight to Pod IPs.

In this homework the controller is **ingress-nginx**, installed with `minikube addons enable ingress`:
```
$ kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller
NAME                                       READY   STATUS    RESTARTS   AGE
ingress-nginx-controller-d7cd8c989-tctv5   1/1     Running   0          ...
$ kubectl get ingressclass
NAME    CONTROLLER             PARAMETERS   AGE
nginx   k8s.io/ingress-nginx   <none>       ...
```

## Difference

| | Ingress | Ingress Controller |
|---|---|---|
| What it is | API object (YAML, configuration) | Software (Deployment/DaemonSet of proxy pods) |
| Role | *Declares* routing rules | *Implements* routing rules, carries traffic |
| Installed by default? | API type is built into Kubernetes | **No** – must be installed separately |
| Count | Many per cluster (one per app/team) | Usually 1–2 per cluster (selected via `IngressClass`) |
| Analogy | The *routing table / rule book* | The *traffic police / router* that enforces it |
| Failure symptom | Wrong rules → 404 / wrong backend | Missing controller → Ingress has no ADDRESS, nothing listens |

## Why both are required
- Without a **controller**, an Ingress object is ignored — no proxy is configured, `kubectl get ingress` shows no address and requests never reach the app.
- Without **Ingress objects**, the controller runs but has no rules → every request gets the default backend (404).
- The split keeps routing **declarative and portable**: the same Ingress YAML works with NGINX, Traefik, HAProxy, AWS ALB, GKE, etc. by changing `ingressClassName`.

## Request flow (as demonstrated in this session)
```
curl -H "Host: yatri.local" localhost:18300/api
   │  (kubectl port-forward to ingress-nginx-controller Service :80)
   ▼
ingress-nginx controller pod  ── reads Ingress "yatri-ingress" rules
   │  host=yatri.local, path=/api → backend-svc:80
   ▼
backend-svc EndpointSlice → Pod IP 10.244.0.x:5678
   ▼
backend pod responds {"service":"backend-api","status":"ok"}
```

## Examples of Ingress Controllers
| Controller | Notes |
|---|---|
| **ingress-nginx** (Kubernetes community) | Most common; used in this demo (`minikube addons enable ingress`) |
| NGINX Inc. / F5 NGINX Ingress | Commercial NGINX Plus features |
| **Traefik** | Default in k3s; auto Let's Encrypt |
| HAProxy Ingress | High performance |
| **AWS Load Balancer Controller** | Creates AWS ALBs from Ingress objects (EKS) |
| GKE Ingress | Creates Google Cloud HTTP(S) LB |
| Azure Application Gateway Ingress Controller (AGIC) | Azure App Gateway |
| Istio / Contour / Kong / Emissary | Envoy-based, often with API gateway / service-mesh features |

> Note: The newer **Gateway API** (`Gateway`, `HTTPRoute`) is the successor model with the same idea: a *GatewayClass/controller* implements *route objects*.
