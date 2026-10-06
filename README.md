# DevOps Heros — Homework Submission

**Student:** Poorav Kumar Gupta  **Enrollment No:** 24bcs10080

Solutions for the DevOps Heros course homework (`DevOps Homework.md`), Sessions 01–20.
Every session folder has its own `README.md` with the tasks, commands, explanations and screenshots
(`screenshots/`). Everything was run on my machine: Docker Desktop, a local minikube cluster, GitHub Actions
workflows run locally with `act`, and Terraform against AWS (us-east-1).

| Session | Topic | Folder |
|---|---|---|
| 01 & 02 | Linux fundamentals — links, adduser vs useradd, journalctl, cheat sheet | [session01-02-linux](session01-02-linux/) |
| 03 | Shell scripting — system information script | [session03-shell-scripting](session03-shell-scripting/) |
| 04 | Networking fundamentals | [session04-networking](session04-networking/) |
| 05 | Git/GitHub — `commit -a -m` vs `commit -m`, cherry-pick | [session05-git-github](session05-git-github/) |
| 06 | Docker fundamentals — 6 Hello World apps | [session06-docker-fundamentals](session06-docker-fundamentals/) |
| 07 | Dockerfiles & multi-stage builds | [session07-dockerfiles-multistage](session07-dockerfiles-multistage/) |
| 08 | Docker networking & volumes | [session08-docker-networking-volume](session08-docker-networking-volume/) |
| 09 | Kubernetes fundamentals (minikube, architecture, basics tutorial) | [session09-k8s-fundamentals](session09-k8s-fundamentals/) |
| 10 | Deployment strategies & pod lifecycle | [session10-pods-replicasets-deployments](session10-pods-replicasets-deployments/) |
| 11 | Services, object comparisons, FQDN, CoreDNS | [session11-kubernetes-services](session11-kubernetes-services/) |
| 12 | Ingress, ConfigMaps, Secrets, troubleshooting | [session12-ingress-configmaps-secrets](session12-ingress-configmaps-secrets/) |
| 13 | Storage, HPA, probes, mini project | [session13-storage-hpa-probes](session13-storage-hpa-probes/) |
| 14 | Kubernetes troubleshooting, mini project | [session14-kubernetes-troubleshooting](session14-kubernetes-troubleshooting/) |
| 15 | Helm — commands, rollback workflow, mini project | [session15-helm](session15-helm/) |
| 16 | CI/CD with GitHub Actions | [session16-github-actions-cicd](session16-github-actions-cicd/) |
| 17 | Complete CI/CD + DevSecOps pipeline | [session17-devsecops](session17-devsecops/) |
| 18 | Terraform S3 demo + AWS services research | [session18-terraform-iac](session18-terraform-iac/) |
| 19 | Cloud infrastructure with Terraform (VPC, subnet, SG, EC2, S3) | [session19-cloud-terraform](session19-cloud-terraform/) |
| 20 | Monitoring (Prometheus/Grafana), observability, GitOps (Argo CD) | [session20-monitoring-observability-gitops](session20-monitoring-observability-gitops/) |

## Notes on the environment
- Platform: macOS on Apple Silicon (arm64), Docker Desktop, minikube (docker driver) with the ingress and metrics-server addons.
- Pipelines (Sessions 16 & 17) were executed locally with [`act`](https://github.com/nektos/act); the workflow files are standard GitHub Actions and run unchanged on GitHub.
- Session 18: S3 bucket applied for real on AWS; the bucket deletion needed elevated permissions and was removed manually afterwards.
  Session 19: the AWS stack was validated and planned against real AWS (13 resources); see that README for details.
- Deviations from the course material (arm64 images, port changes, etc.) are documented in each session README.
