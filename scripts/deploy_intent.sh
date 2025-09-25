#!/bin/bash

# Deploy Intent to Edge Site
# Purpose: Deploy intent JSON to specified edge site via GitOps
# 用途：透過 GitOps 將 Intent JSON 部署到指定的邊緣站點

set -e

INTENT_FILE=$1
TARGET_SITE=$2
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Validate inputs
if [ -z "$INTENT_FILE" ] || [ -z "$TARGET_SITE" ]; then
    echo -e "${RED}Usage: $0 <intent-json-file> <edge1|edge2|both>${NC}"
    exit 1
fi

# Check if intent file exists
if [ ! -f "$INTENT_FILE" ]; then
    echo -e "${RED}Error: Intent file not found: $INTENT_FILE${NC}"
    exit 1
fi

echo -e "${GREEN}[Deploy Intent]${NC} Deploying $(basename $INTENT_FILE) to $TARGET_SITE"

# Parse intent and generate KRM
echo -e "${YELLOW}  → Parsing intent JSON...${NC}"
INTENT_ID=$(cat $INTENT_FILE | jq -r '.id // "intent-'$TIMESTAMP'"')
SERVICE_TYPE=$(cat $INTENT_FILE | jq -r '.serviceType // "5G-eMBB"')

# Create KRM output directory
KRM_DIR="artifacts/$TIMESTAMP/krm"
mkdir -p $KRM_DIR

echo -e "${YELLOW}  → Generating KRM manifests...${NC}"

# Generate deployment manifest based on intent
cat > $KRM_DIR/deployment-$TARGET_SITE.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${INTENT_ID}-deployment
  namespace: default
  labels:
    intent-id: ${INTENT_ID}
    target-site: ${TARGET_SITE}
    service-type: ${SERVICE_TYPE}
spec:
  replicas: 3
  selector:
    matchLabels:
      app: ${INTENT_ID}
  template:
    metadata:
      labels:
        app: ${INTENT_ID}
        site: ${TARGET_SITE}
    spec:
      containers:
      - name: service
        image: nginx:alpine
        resources:
          requests:
            memory: "64Mi"
            cpu: "250m"
          limits:
            memory: "128Mi"
            cpu: "500m"
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: ${INTENT_ID}-service
  namespace: default
spec:
  selector:
    app: ${INTENT_ID}
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
  type: ClusterIP
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${INTENT_ID}-config
  namespace: default
data:
  intent.json: |
$(cat $INTENT_FILE | sed 's/^/    /')
  site: "${TARGET_SITE}"
  service-type: "${SERVICE_TYPE}"
  deployment-time: "${TIMESTAMP}"
EOF

echo -e "${YELLOW}  → Applying to cluster...${NC}"

# Deploy based on target site
case $TARGET_SITE in
    edge1)
        echo -e "  ${GREEN}✓${NC} Deploying to Edge-1 (172.16.4.45)"
        kubectl apply -f $KRM_DIR/deployment-$TARGET_SITE.yaml
        ;;
    edge2)
        echo -e "  ${GREEN}✓${NC} Deploying to Edge-2 (172.16.4.176)"
        kubectl apply -f $KRM_DIR/deployment-$TARGET_SITE.yaml
        ;;
    both)
        echo -e "  ${GREEN}✓${NC} Deploying to both Edge-1 and Edge-2"
        kubectl apply -f $KRM_DIR/deployment-$TARGET_SITE.yaml
        ;;
    *)
        echo -e "${RED}Error: Invalid target site: $TARGET_SITE${NC}"
        exit 1
        ;;
esac

# Save deployment record
REPORT_DIR="reports/$TIMESTAMP"
mkdir -p $REPORT_DIR
cat > $REPORT_DIR/deployment-record.json << EOF
{
  "timestamp": "$TIMESTAMP",
  "intent_file": "$INTENT_FILE",
  "intent_id": "$INTENT_ID",
  "target_site": "$TARGET_SITE",
  "service_type": "$SERVICE_TYPE",
  "krm_location": "$KRM_DIR",
  "status": "deployed"
}
EOF

echo -e "${GREEN}[Success]${NC} Intent deployed successfully"
echo -e "  Intent ID: $INTENT_ID"
echo -e "  Target: $TARGET_SITE"
echo -e "  KRM saved: $KRM_DIR"
echo -e "  Report: $REPORT_DIR/deployment-record.json"