#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="${ROOT_DIR}/app"
TF_DIR="${ROOT_DIR}/terraform"

IMAGE_NAME="score-api"
IMAGE_TAG="local"
NAMESPACE="score-api"
INGRESS_HOST="score-api.local"
AUTH_USER="score"
BASIC_AUTH_PASSWORD="${BASIC_AUTH_PASSWORD:-$(openssl rand -hex 16)}"

log()  { echo -e "\033[1;34m[deploy]\033[0m $*"; }
fail() { echo -e "\033[1;31m[deploy][FAIL]\033[0m $*" >&2; exit 1; }

log "Checking minikube status..."
if ! minikube status >/dev/null 2>&1; then
  minikube start --driver=docker
fi
minikube addons enable ingress >/dev/null

log "Building and loading image..."
docker build -t "${IMAGE_NAME}:${IMAGE_TAG}" "${APP_DIR}"
minikube image load "${IMAGE_NAME}:${IMAGE_TAG}"

log "Running terraform apply..."
pushd "${TF_DIR}" >/dev/null
terraform init -input=false
terraform apply -auto-approve -input=false \
  -var="image_repository=${IMAGE_NAME}" \
  -var="image_tag=${IMAGE_TAG}" \
  -var="namespace=${NAMESPACE}" \
  -var="ingress_host=${INGRESS_HOST}" \
  -var="basic_auth_password=${BASIC_AUTH_PASSWORD}"
popd >/dev/null

log "Waiting for rollout..."
kubectl rollout status deployment/score-api -n "${NAMESPACE}" --timeout=120s \
  || fail "Deployment did not become ready in time."

MINIKUBE_IP="$(minikube ip)"
TUNNEL_PID=""
cleanup() { [[ -n "${TUNNEL_PID}" ]] && kill "${TUNNEL_PID}" 2>/dev/null || true; }
trap cleanup EXIT

curl_healthz() {
  curl -sf -o /dev/null -w "%{http_code}" \
    --resolve "${INGRESS_HOST}:80:${1}" \
    "http://${INGRESS_HOST}/healthz" 2>/dev/null || echo "000"
}

TARGET_IP="${MINIKUBE_IP}"
if [[ "$(curl_healthz "${MINIKUBE_IP}")" != "200" ]]; then
  log "Direct IP not reachable, starting minikube tunnel..."
  minikube tunnel >/tmp/minikube-tunnel.log 2>&1 &
  TUNNEL_PID=$!
  sleep 5
  TARGET_IP="127.0.0.1"
fi

log "Checking GET /healthz..."
for i in {1..10}; do
  CODE="$(curl_healthz "${TARGET_IP}")"
  [[ "${CODE}" == "200" ]] && break
  sleep 3
done
[[ "${CODE}" == "200" ]] || fail "GET /healthz did not return 200 (last code: ${CODE})"
log "GET /healthz -> 200 OK"

log "Checking POST /decision with basic auth..."
DECISION_RESPONSE="$(curl -sf \
  --resolve "${INGRESS_HOST}:80:${TARGET_IP}" \
  -u "${AUTH_USER}:${BASIC_AUTH_PASSWORD}" \
  -H "Content-Type: application/json" \
  -d '{"client_id": "CL-0001", "amount": 1500}' \
  "http://${INGRESS_HOST}/decision" 2>&1)" \
  || fail "POST /decision failed: ${DECISION_RESPONSE}"
echo "${DECISION_RESPONSE}" | grep -q '"state":"FINISHED"' \
  || fail "Unexpected response: ${DECISION_RESPONSE}"
log "POST /decision -> ${DECISION_RESPONSE}"

log "Checking bad credentials are rejected..."
BAD_CODE="$(curl -s -o /dev/null -w "%{http_code}" \
  --resolve "${INGRESS_HOST}:80:${TARGET_IP}" \
  -u "${AUTH_USER}:wrong-password" \
  -d '{"client_id": "CL-0001"}' \
  "http://${INGRESS_HOST}/decision")"
[[ "${BAD_CODE}" == "401" ]] || fail "expected 401, got ${BAD_CODE}"

log "All checks passed."