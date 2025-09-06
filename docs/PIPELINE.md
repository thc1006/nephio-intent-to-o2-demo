# Intent to KRM Pipeline Documentation

This document provides step-by-step instructions for executing the 3GPP TS 28.312 Expectation to KRM conversion pipeline using the kpt function.

## Overview

The `expectation-to-krm` kpt function converts 3GPP TS 28.312 Intent/Expectation JSON into Kubernetes Resource Model (KRM) resources for O-RAN deployments.

### Supported Conversions

- **Edge scenarios**: O-RAN-DU with latency/availability expectations → Deployment + PVC + ServiceMonitor
- **Central scenarios**: O-RAN-CU-CP with throughput/latency expectations → Deployment + PVC + ServiceMonitor + HPA

## Prerequisites

- Go 1.22 or later
- `kpt` CLI installed
- `kubeconform` for YAML validation (optional)

## Building the Function

```bash
cd kpt-functions/expectation-to-krm
go build -o expectation-to-krm .
```

## Usage Examples

### Direct Function Execution

#### Edge Scenario - O-RAN DU

```bash
cat <<EOF | ./expectation-to-krm
apiVersion: v1
kind: ConfigMap
metadata:
  name: expectation-input
  namespace: default
  annotations:
    expectation.28312.3gpp.org/input: "true"
data:
  expectation.json: |
    {
      "expectationId": "edge-latency-expectation-001",
      "expectationObject": {
        "objectType": "O-RAN-DU",
        "objectInstance": "edge-du-cluster-01",
        "objectParameters": {
          "deployment": "edge",
          "location": "cell-site-tower-001",
          "resources": {
            "cpu": "4",
            "memory": "8Gi",
            "storage": "100Gi"
          }
        }
      },
      "expectationTarget": [
        {
          "targetName": "user-plane-latency",
          "targetCondition": "LessThanOrEqual",
          "targetValue": 1,
          "targetContexts": [
            {
              "contextAttribute": "measurement-unit",
              "contextCondition": "Equal",
              "contextValueType": "string",
              "contextValue": "milliseconds"
            },
            {
              "contextAttribute": "percentile",
              "contextCondition": "Equal",
              "contextValueType": "number",
              "contextValue": 95
            }
          ]
        }
      ],
      "expectationContext": {
        "timeWindow": "1hour",
        "monitoringInterval": "30seconds",
        "o2imsProvider": "edge-o2ims-001",
        "deployment-mode": "edge"
      }
    }
EOF
```

#### Central Scenario - O-RAN CU-CP

```bash
cat <<EOF | ./expectation-to-krm
apiVersion: v1
kind: ConfigMap
metadata:
  name: expectation-input
  namespace: default
  annotations:
    expectation.28312.3gpp.org/input: "true"
data:
  expectation.json: |
    {
      "expectationId": "central-throughput-expectation-002",
      "expectationObject": {
        "objectType": "O-RAN-CU-CP",
        "objectInstance": "central-cu-cp-cluster-02",
        "objectParameters": {
          "deployment": "central",
          "location": "datacenter-region-west",
          "resources": {
            "cpu": "16",
            "memory": "64Gi",
            "storage": "1Ti"
          },
          "scaling": {
            "minReplicas": 3,
            "maxReplicas": 10,
            "targetCPUUtilization": 70
          }
        }
      },
      "expectationTarget": [
        {
          "targetName": "uplink-throughput",
          "targetCondition": "GreaterThanOrEqual",
          "targetValue": 1000,
          "targetContexts": [
            {
              "contextAttribute": "measurement-unit",
              "contextCondition": "Equal",
              "contextValueType": "string",
              "contextValue": "Mbps"
            }
          ]
        }
      ],
      "expectationContext": {
        "timeWindow": "24hours",
        "monitoringInterval": "5minutes",
        "o2imsProvider": "central-o2ims-002",
        "deployment-mode": "central"
      }
    }
EOF
```

### Using with kpt Packages

#### Step 1: Create Package Structure

```bash
mkdir -p packages/intent-to-krm
cd packages/intent-to-krm

# Create Kptfile
cat > Kptfile <<EOF
apiVersion: kpt.dev/v1
kind: Kptfile
metadata:
  name: intent-to-krm
pipeline:
  mutators:
  - image: expectation-to-krm:latest
    configPath: expectation-config.yaml
EOF
```

#### Step 2: Add Expectation ConfigMap

```bash
cat > expectation-config.yaml <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: expectation-input
  namespace: default
  annotations:
    expectation.28312.3gpp.org/input: "true"
data:
  expectation.json: |
    {
      "expectationId": "demo-expectation-001",
      "expectationObject": {
        "objectType": "O-RAN-DU",
        "objectInstance": "demo-du-01",
        "objectParameters": {
          "deployment": "edge",
          "location": "demo-site",
          "resources": {
            "cpu": "2",
            "memory": "4Gi",
            "storage": "50Gi"
          }
        }
      },
      "expectationTarget": [
        {
          "targetName": "latency",
          "targetCondition": "LessThanOrEqual",
          "targetValue": 5,
          "targetContexts": [
            {
              "contextAttribute": "measurement-unit",
              "contextCondition": "Equal",
              "contextValueType": "string",
              "contextValue": "milliseconds"
            }
          ]
        }
      ],
      "expectationContext": {
        "timeWindow": "1hour",
        "monitoringInterval": "30seconds",
        "o2imsProvider": "demo-o2ims",
        "deployment-mode": "edge"
      }
    }
EOF
```

#### Step 3: Execute kpt Function Pipeline

```bash
# Run the function (using local binary for development)
kpt fn render packages/intent-to-krm --exec ./expectation-to-krm

# Or using container image (in production)
# kpt fn render packages/intent-to-krm
```

### Validation Steps

#### 1. YAML Validation with kubeconform

```bash
# Install kubeconform (if not already installed)
go install github.com/yannh/kubeconform/cmd/kubeconform@latest

# Validate generated KRM resources
kpt fn render packages/intent-to-krm --exec ./expectation-to-krm | kubeconform -strict -verbose
```

#### 2. Resource Structure Validation

Generated resources should include:

**For Edge scenarios:**
- Deployment (namespace: `o-ran-edge`)
- PersistentVolumeClaim (storageClass: `fast-ssd`)
- ServiceMonitor (interval: 30s)

**For Central scenarios:**
- Deployment (namespace: `o-ran-central`) 
- PersistentVolumeClaim (storageClass: `high-performance`)
- ServiceMonitor (interval: 5m)
- HorizontalPodAutoscaler (if scaling parameters present)

#### 3. Annotation Verification

All generated resources should contain:
- `expectation.28312.3gpp.org/id`: Original expectation ID
- `expectation.28312.3gpp.org/object-type`: Object type from expectation
- `expectation.28312.3gpp.org/deployment-mode`: edge/central
- `o2ims.o-ran.org/provider`: O2 IMS provider ID

ServiceMonitor resources additionally contain target-specific annotations:
- `expectation.28312.3gpp.org/target-{name}`: Target conditions and values
- `expectation.28312.3gpp.org/time-window`: Monitoring time window
- `expectation.28312.3gpp.org/monitoring-interval`: Monitoring frequency

## Error Handling

### Common Issues

1. **Missing expectation ConfigMap**
   ```
   Error: no expectation ConfigMap found with annotation expectation.28312.3gpp.org/input=true
   ```
   Solution: Ensure your ConfigMap has the required annotation

2. **Invalid JSON format**
   ```
   Error: failed to parse expectation JSON
   ```
   Solution: Validate JSON structure matches 3GPP TS 28.312 schema

3. **Missing required fields**
   ```
   Error: failed to generate KRM resources
   ```
   Solution: Ensure all required fields (expectationId, expectationObject, etc.) are present

### Debugging

Enable debug mode by adding debug output to the function:

```bash
# Build debug version
go build -tags debug -o expectation-to-krm .

# Run with verbose output
./expectation-to-krm < input.yaml 2>&1 | tee debug.log
```

## Integration with Nephio

The generated KRM resources are compatible with Nephio R5 and can be used in GitOps workflows:

```bash
# Apply to Nephio workspace
kpt fn render packages/intent-to-krm --exec ./expectation-to-krm | kubectl apply -f -

# Or commit to Git for GitOps
kpt fn render packages/intent-to-krm --exec ./expectation-to-krm > rendered-resources.yaml
git add rendered-resources.yaml
git commit -m "Add O-RAN resources from expectation"
```

## Testing

Run the test suite to verify function correctness:

```bash
cd kpt-functions/expectation-to-krm
go test -v
```

The test suite includes:
- Edge scenario validation (O-RAN-DU)
- Central scenario validation (O-RAN-CU-CP)
- kpt function interface compliance
- Golden file comparison for deterministic output

## Performance Considerations

- Function processes expectations in <100ms typically
- Memory usage scales with number of expectation targets
- Output size depends on complexity of generated resources
- No external dependencies for core processing

## Security Notes

- Function validates input JSON schema
- No network access required
- Runs in isolated container environment
- Generated resources follow principle of least privilege
- All generated images use explicit tags (no `latest`)