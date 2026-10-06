# Session 17: Complete CI/CD & DevSecOps

**Student:** Poorav Kumar Gupta | **Enrollment No:** 24bcs10080

A complete CI/CD + DevSecOps pipeline for a Flask app (the "DevSecOps Hub" dashboard from the course demo). Security checks are built into every stage, and a **security gate** decides whether an image is allowed to be pushed and deployed.

```
Code → Build → Unit Test → SAST → SCA → Secret Scan → Docker Build → Container Image Scan
     → Security Gate → Push Image → Deploy to Kubernetes
```

## How it was run (local, as allowed by the homework)
The pipeline was executed **two ways**, and both produced the same results:

1. **GitHub Actions workflow** [`.github/workflows/devsecops.yml`](.github/workflows/devsecops.yml), run locally with [`act`](https://github.com/nektos/act). `ubuntu-latest` jobs ran in the `catthehacker/ubuntu:act-latest` container. The `deploy` job uses `runs-on: self-hosted` and ran directly on my machine, which has access to the minikube cluster.
2. **[`scripts/run-pipeline.sh`](scripts/run-pipeline.sh)**, a stage-by-stage local equivalent with the same tools, configs and order. It writes a log per stage to `reports/` for easy screenshots.

- **Container registry:** local `registry:2` container (`s17-registry`, `localhost:18420`) standing in for GHCR/Docker Hub. On GitHub you would set the `REGISTRY` variable and the `REGISTRY_USERNAME`/`REGISTRY_PASSWORD` secrets.
- **Kubernetes:** minikube, namespace `s17-devsecops`. Since minikube can't pull from the host's `localhost` registry, the deploy step runs `minikube image load` for the pushed image. With a real registry, the kubelet would simply pull it.

## Project structure
```
session17-devsecops/
├── app/                         # Flask app (app.py, templates/, static/)
├── tests/test_app.py            # 8 unit tests
├── requirements.txt             # runtime deps (Flask, gunicorn)
├── requirements-dev.txt         # + pytest, pytest-cov
├── Dockerfile                   # hardened multi-stage image
├── .github/workflows/devsecops.yml
├── security/
│   ├── bandit.yaml              # SAST config (Python)
│   ├── semgrep.yml              # SAST custom rules (+ community ruleset p/python)
│   ├── gitleaks.toml            # secret scanning config (default rules + allowlist)
│   ├── trivy.yaml               # SCA + image scan config (HIGH/CRITICAL, fixable only)
│   ├── .trivyignore             # documented risk acceptances (empty)
│   ├── gate-policy.json         # security gate thresholds
│   ├── security_gate.py         # the gate: evaluates all reports, exit 1 on violation
│   └── requirements-tools.txt   # bandit, pip-audit (isolated from app deps)
├── k8s/
│   ├── namespace.yaml           # Pod Security Admission: restricted
│   ├── deployment.yaml          # non-root, read-only rootfs, drop ALL caps, probes, limits
│   └── service.yaml
├── scripts/run-pipeline.sh      # local pipeline runner
├── demo/make-vulnerable.sh      # generates an insecure change to prove the gate works
├── logs/                        # full logs + JSON reports of every run shown below
└── screenshots/
```

## Tools per stage

| Stage | Tool(s) | What it catches | Config |
|---|---|---|---|
| Build | pip, compileall | broken dependencies, syntax/import errors | `requirements.txt` |
| Unit Test | pytest + pytest-cov | functional regressions | `pytest.ini` |
| **SAST** | **bandit**, **semgrep** (`p/python` + custom rules), hadolint (Dockerfile, informational) | insecure code: shell injection, eval, weak hashes, Flask debug, binding 0.0.0.0, … | `security/bandit.yaml`, `security/semgrep.yml` |
| **SCA** | **pip-audit** (PyPI/OSV advisories, resolves transitive deps), **trivy fs** | known CVEs in third-party packages | `security/trivy.yaml` |
| **Secret Scan** | **gitleaks** (working tree; `gitleaks git` scans history on GitHub) | hard-coded API keys, tokens, passwords | `security/gitleaks.toml` |
| Docker Build | docker | builds `s17-devsecops:<sha>` | `Dockerfile` |
| **Image Scan** | **trivy image** | CVEs in OS packages and Python packages *inside the image* | `security/trivy.yaml` |
| **Security Gate** | `security/security_gate.py` | fails the pipeline if any category exceeds `gate-policy.json` | `security/gate-policy.json` |
| Push | docker push | only runs if the gate passed | `REGISTRY` var/secrets |
| Deploy | kubectl | only runs if push succeeded and it's `main` | `k8s/` |

**Design choice:** scanners never fail on their own. Each one writes a JSON report and exits 0, and the **gate** evaluates all reports together. This way a single run shows *every* problem, not just the first, and the policy lives in one versioned file (`gate-policy.json`, currently 0 allowed findings for bandit HIGH, semgrep ERROR, any SCA vuln, any secret, and image HIGH/CRITICAL). Image scans use `ignore-unfixed`, so the gate only blocks on issues that can actually be fixed.

---

## Run 0: the gate caught a *real* problem in my first Dockerfile
My first Dockerfile was a single `python:3.12-slim` stage. Every stage passed **except the image scan**: trivy found 4 HIGH CVEs in packages that ship *inside pip itself* (vendored `msgpack`, `urllib3`, `setuptools`). They are not my app's dependencies, so pip-audit/SCA could never see them. Only the image scan did.

![baseline real cves](screenshots/00-baseline-gate-caught-real-image-cves.png)

**Fix:** a multi-stage Dockerfile. The builder installs the deps, and the runtime stage deletes `pip`/`ensurepip` (not needed at runtime) and applies OS updates. The image then had 0 HIGH/CRITICAL findings, and it is also smaller and gives an attacker fewer tools.

---

## Pipeline overview: pass vs. fail
![overview](screenshots/01-pipeline-overview.png)

### A) GitHub Actions workflow (act)

The 10 jobs and their order (each job `needs:` the previous one; the gate needs all four scan jobs):
![jobs](screenshots/40-act-workflow-jobs.png)

**Clean commit: all 10 jobs succeed.** Each scan job uploads its report as an artifact. The gate job downloads them all (`pattern: reports-*`, `merge-multiple`), and only then are push and deploy allowed.
![act pass](screenshots/41-act-pass-summary.png)
![act gate pass](screenshots/42-act-pass-gate.png)
![act push deploy](screenshots/43-act-pass-push-deploy.png)

**Insecure commit (see "The vulnerable change" below): blocked at the Security Gate.** Push Image and Deploy never run.
![act fail](screenshots/44-act-fail-summary.png)
![act fail sast](screenshots/45-act-fail-sast.png)
![act fail secrets](screenshots/46-act-fail-secrets.png)
![act fail gate](screenshots/47-act-fail-gate.png)

### B) Every stage in detail: passing run (`scripts/run-pipeline.sh`)

| # | Stage | Screenshot |
|---|---|---|
| 1 | Build | ![](screenshots/10-pass-01-build.png) |
| 2 | Unit Test: 8 passed | ![](screenshots/11-pass-02-unit-test.png) |
| 3 | SAST: bandit only LOW B311 (`random` used for greetings, not crypto → accepted), semgrep 0, hadolint clean | ![](screenshots/12-pass-03-sast.png) |
| 4 | SCA: pip-audit "No known vulnerabilities", trivy fs 0 | ![](screenshots/13-pass-04-sca.png) |
| 5 | Secret Scan: gitleaks 0 | ![](screenshots/14-pass-05-secret-scan.png) |
| 6 | Docker Build | ![](screenshots/15-pass-06-docker-build.png) |
| 7 | Container Image Scan: debian 13.7 and all Python packages at 0 | ![](screenshots/16-pass-07-container-image-scan.png) |
| 8 | **Security Gate: PASSED** | ![](screenshots/17-pass-08-security-gate.png) |
| 9 | Push Image to registry | ![](screenshots/18-pass-09-push-image.png) |
| 10 | Deploy to Kubernetes + smoke test | ![](screenshots/19-pass-10-deploy-to-kubernetes.png) |

**Deployed application** (browser via `kubectl port-forward`):
![app](screenshots/20-deployed-app-browser.png)

**Hardening verified in the cluster:** the namespace enforces Pod Security `restricted`, the container runs as uid 10001, the root filesystem is read-only, and there is no `pip` in the image.
![verify](screenshots/21-verify-k8s-security.png)

### C) The vulnerable change: failing run

[`demo/make-vulnerable.sh`](demo/make-vulnerable.sh) makes a copy of the project with a typical "quick fix" commit:
- `app/insecure_utils.py`: `subprocess(..., shell=True)` with user input, `eval()`, MD5 password hashing, `app.run(host="0.0.0.0", debug=True)`, plus a hard-coded AWS access key, AWS secret key and GitHub token. The fake credentials are **generated randomly at runtime**, so no secret-like string is committed to this repo.
- `requirements.txt`: adds `requests==2.19.1` (pulls in `urllib3 1.23`, `idna 2.7`).

| Stage | Result on the insecure change |
|---|---|
| SAST | bandit **HIGH** B602 (shell=True), B324 (MD5); semgrep **4 ERROR** (shell injection, eval, Flask debug) |
| SCA | pip-audit **19 vulnerabilities** in requests/urllib3/idna; trivy fs CVE-2018-18074 HIGH |
| Secret Scan | gitleaks **3 leaks**: aws-access-token, generic-api-key, github-pat (values redacted) |
| Image Scan | trivy image **7 HIGH** (the vulnerable libraries are now inside the image) |
| **Security Gate** | **FAILED (6 checks over threshold)**. Pipeline stops, nothing is pushed or deployed |

![fail sast](screenshots/30-fail-03-sast.png)
![fail sca](screenshots/31-fail-04-sca.png)
![fail secrets](screenshots/32-fail-05-secret-scan.png)
![fail image](screenshots/33-fail-07-container-image-scan.png)
![fail gate](screenshots/34-fail-08-security-gate.png)

Note that unit tests still **passed** on the insecure change. Functional tests alone would have shipped it. The gate is what stopped it.

---

## Security hardening summary
- **Code:** no debug mode in production (env-controlled, local-only default `127.0.0.1`), gunicorn instead of the Flask dev server.
- **Image:** multi-stage build, no pip/ensurepip at runtime, OS packages patched, non-root `USER 10001`, `HEALTHCHECK`, `.dockerignore` keeps tests/security/scripts out of the image.
- **Kubernetes:** PSA `restricted` namespace, `runAsNonRoot`, `readOnlyRootFilesystem` (+ `emptyDir` for `/tmp`), `allowPrivilegeEscalation: false`, `capabilities: drop [ALL]`, `seccompProfile: RuntimeDefault`, `automountServiceAccountToken: false`, resource requests/limits, readiness/liveness probes.
- **Pipeline:** `permissions: contents: read`, scanners pinned to versions, security tools in an isolated environment, secret values redacted in logs (bandit B105 messages pass through `sed`, gitleaks runs with `--redact`), push only after the gate, deploy only from `main`.

## Running it
```bash
docker run -d --name s17-registry -p 18420:5000 registry:2   # local registry
scripts/run-pipeline.sh                                      # clean code -> deploys
demo/make-vulnerable.sh /tmp/vuln && scripts/run-pipeline.sh /tmp/vuln   # blocked at gate

# GitHub Actions workflow locally (needs a git repo):
act push -P ubuntu-latest=catthehacker/ubuntu:act-latest -P self-hosted=-self-hosted \
    --var REGISTRY=localhost:18420 --artifact-server-path /tmp/artifacts
```

## Lessons learned
- Shift-left works best with **layers**. Each tool caught something the others couldn't: SAST found code flaws, SCA found vulnerable dependencies, gitleaks found credentials, and only the image scan found the CVEs vendored inside pip.
- Collect first, decide once. A single gate with a versioned policy is clearer than many jobs failing at random points.
- Scanner output can leak secrets too. My first SAST log printed the fake keys through bandit's code context, so I switched to a one-line format with redaction.
- Tests passing ≠ safe to ship.
