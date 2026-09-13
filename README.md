## Prerequisites

- Docker
- minikube
- kubectl
- Terraform
- Helm

## How to run it? 

```bash
git clone <this-repo>
cd taran_devops
./pipeline/deploy.sh
```
This pipeline script:

1. Starts minikube and enables the `ingress` addon.
2. Builds the Docker image from `app/` and loads it directly into minikube's node.
3. Runs `terraform init && terraform apply` in `terraform/`, which:
   - creates a Kubernetes `Secret` holding `BASIC_AUTH_PASSWORD`, and
   - installs the Helm chart, wiring the Deployment to that secret by name.
4. Waits for the rollout to become healthy.
5. Hits `GET /healthz` and `POST /decision` through the Ingress.

## How to verify it? 

After running `deploy.sh`, run `minikube tunnel` in a separate terminal first.

###1. Health check
- Linux/macOS:
```bash
curl --resolve score-api.local:80:127.0.0.1 http://score-api.local/healthz
```
- Windows PowerShell:
```bash
Invoke-WebRequest -Uri "http://127.0.0.1/healthz" -Headers @{ Host = "score-api.local" }
```

###2. Decision API test
- Linux/macOS:
```bash
# Decision API with correct password
curl --resolve score-api.local:80:127.0.0.1 \
  -u score:<the password you used> \
  -H "Content-Type: application/json" \
  -d '{"client_id": "CL-0001", "amount": 1500}' \
  http://score-api.local/decision
```
```bash
# Decision API with wrong password (expect 401)
curl --resolve score-api.local:80:127.0.0.1 \
  -u score:wrong-password \
  -H "Content-Type: application/json" \
  -d '{"client_id": "CL-0001"}' \
  http://score-api.local/decision
```
- Windows PowerShell:
```bash
# Decision API with correct password
$pair   = "score:devsecret"
$bytes  = [System.Text.Encoding]::ASCII.GetBytes($pair)
$base64 = [Convert]::ToBase64String($bytes)

Invoke-WebRequest -Uri "http://127.0.0.1/decision" `
  -Headers @{ 
      Host = "score-api.local"; 
      "Content-Type" = "application/json"; 
      Authorization = "Basic $base64" } `
  -Method Post `
  -Body '{"client_id": "CL-0001", "amount": 1500}'
```
```bash
# Decision API with wrong password (expect 401)
$pair   = "score:wrong-password"
$bytes  = [System.Text.Encoding]::ASCII.GetBytes($pair)
$base64 = [Convert]::ToBase64String($bytes)

Invoke-WebRequest -Uri "http://127.0.0.1/decision" `
  -Headers @{ 
      Host = "score-api.local"; 
      "Content-Type" = "application/json"; 
      Authorization = "Basic $base64" } `
  -Method Post `
  -Body '{"client_id": "CL-0001", "amount": 1500}'
```

###3. Inspect the workload directly
```bash
# Pods status
kubectl get pods -n score-api

# Application logs
kubectl logs -n score-api deploy/score-api

# Ingress details
kubectl describe ingress -n score-api score-api
```

When you're done evaluating, removes everything:
```bash
cd terraform
terraform destroy -var="basic_auth_password=x"
minikube stop
```
