# Architecture Overview

## Pipeline Diagram

```
┌─────────┐    TMF921     ┌──────────────┐    3GPP 28.312    ┌─────────────────┐
│   LLM   │──────────────▶│Intent Gateway│─────────────────▶│TMF921→28.312    │
└─────────┘   Intent JSON  └──────────────┘   Expectation    └─────────────────┘
                                  │                                    │
                           Validation                           Conversion
                           (TIO/CTK)                             Mapping
                                                                      │
┌─────────────────┐         KRM          ┌──────────────┐   Expectation JSON
│  O2 IMS Client  │◀─────────────────────│Expectation→  │◀──────────────────┘
│(Provisioning Req)│     Packages        │KRM (kpt fn)  │
└─────────────────┘                      └──────────────┘
         │                                                  
   Deploy Request                            
         │                                    
         ▼                                    
┌─────────────────┐      Metrics      ┌──────────────┐
│  O-Cloud/K8s    │───────────────────▶│ SLO Gateway  │
│   Workloads     │                    │  (GitOps)    │
└─────────────────┘                    └──────────────┘
```

## Module Interfaces

### 1. Intent Gateway (`tools/intent-gateway/`)
- **Input**: TMF921 Intent JSON from LLM/UI
- **Processing**: Schema validation (TIO/CTK compliant)
- **Output**: Validated TMF921 Intent
- **Interface**: REST API (POST /validate), CLI (`intent-gateway validate`)

### 2. TMF921 to 28.312 Converter (`tools/tmf921-to-28312/`)
- **Input**: Validated TMF921 Intent
- **Processing**: Model transformation using explicit mapping tables
- **Output**: 3GPP TS 28.312 Expectation/Intent JSON + Delta Report
- **Interface**: CLI (`tmf921-to-28312 convert`), Python library

### 3. Expectation to KRM Function (`kpt-functions/expectation-to-krm/`)
- **Input**: 3GPP TS 28.312 Expectation JSON
- **Processing**: Generate Kubernetes Resource Model packages
- **Output**: kpt-compatible KRM YAML
- **Interface**: kpt function SDK (Go), `kpt fn render`

### 4. O2 IMS SDK (`o2ims-sdk/`)
- **Input**: KRM packages
- **Processing**: Create ProvisioningRequest for O-RAN O2 IMS
- **Output**: Deployment status, resource handles
- **Interface**: Go SDK, CLI (`o2imsctl pr create`)

### 5. SLO-Gated GitOps (`slo-gated-gitops/`)
- **Components**:
  - Job Query Adapter: Fetch metrics from O2 IMS Measurement API
  - Gate: Evaluate SLO conditions against metrics
- **Interface**: CLI (`gate --slo`), Webhook for GitOps integration

## Data Flow & Boundaries

### Security Boundaries
```
External │ Validation │ Processing │ Deployment │ Runtime
─────────┼────────────┼────────────┼────────────┼─────────
  LLM    │  Schemas   │ Transforms │  Sigstore  │ Kyverno
  Input  │  (JSON)    │  (Pure Fn) │  Signing   │ Policies
         │            │            │            │
         └──cert-manager managed TLS throughout──┘
```

### Key Integration Points
1. **LLM → Intent Gateway**: Rate-limited, schema-validated
2. **Gateway → Converter**: Type-safe Python interfaces
3. **Converter → kpt Function**: JSON → YAML transformation
4. **kpt → O2 IMS**: Authenticated REST API calls
5. **O2 IMS → SLO Gate**: Measurement Job Query API

## Deployment Architecture

```
┌─────────────────────────────────────────┐
│         Control Plane (Nephio R5)        │
│  ┌─────────────┐  ┌──────────────────┐  │
│  │   Porch     │  │  Config Sync     │  │
│  └─────────────┘  └──────────────────┘  │
└─────────────────────────────────────────┘
                    │
┌─────────────────────────────────────────┐
│         Workload Clusters (O-Cloud)      │
│  ┌─────────────┐  ┌──────────────────┐  │
│  │ O-RAN DU/CU │  │  5G Core NFs     │  │
│  └─────────────┘  └──────────────────┘  │
└─────────────────────────────────────────┘
```

## Non-Functional Requirements

- **Performance**: Intent processing < 5s, SLO evaluation < 1s
- **Scalability**: Horizontal scaling for gateway and converter
- **Security**: Default-deny, signed images, encrypted transit
- **Observability**: JSON structured logging, OpenTelemetry traces

## Future Extensions

- A1/E2 interface integration for RAN intelligence
- Multi-cluster intent distribution
- Intent conflict resolution engine
- ML-based SLO prediction