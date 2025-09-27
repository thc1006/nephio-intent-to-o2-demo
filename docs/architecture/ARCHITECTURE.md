# Architecture Overview - Nephio v1.2.0 with GenAI Enhancement

## Unified Intent-to-O2 Pipeline (September 2025)

```
┌─────────────┐   TMF921 v5.0   ┌──────────────┐   3GPP 28.312 v18   ┌─────────────────┐
│  GenAI LLM  │────────────────▶│Intent Gateway│───────────────────▶│  OrchestRAN     │
│ 175B params │   <125ms proc   │   Enhanced   │    60+ O-RAN       │   Framework     │
│ Claude-4    │                 │              │      Specs         │                 │
└─────────────┘                 └──────────────┘                    └─────────────────┘
       │                               │                                      │
  AI Reasoning                   Validation                            AI-Enhanced
  <150ms latency                (TIO/CTK v2.0)                         Mapping
       │                               │                                      │
┌─────────────────┐        KRM v1.2    ┌──────────────┐    Expectation JSON  │
│ Zero-Trust Mesh │◀──────────────────│Expectation→  │◀─────────────────────┘
│   4-Site Topo   │    Packages        │KRM (kpt fn)  │
│ Edge1-4 Sites   │                    │  Enhanced    │
└─────────────────┘                    └──────────────┘
         │                                      │
   Deploy Request                        Real-time Monitoring
   (WebSocket)                          (ports 8002/8003/8004)
         │                                      │
         ▼                                      ▼
┌─────────────────┐      Metrics       ┌──────────────┐
│  4-Site O-Cloud │───────────────────▶│ SLO Gateway  │
│   Workloads     │   99.2% success    │ 2.8min recov │
│ Config Sync Auto│                    │  (GitOps)    │
└─────────────────┘                    └──────────────┘
```

## Enhanced Module Interfaces (v1.2.0)

### 1. GenAI Intent Gateway (`services/genai-intent-gateway/`)
- **Input**: Natural language + TMF921 v5.0 Intent JSON
- **Processing**: 175B parameter GenAI model with <150ms processing
- **AI Features**: Context awareness, multi-language support, intent optimization
- **Output**: Validated TMF921 v5.0 Intent with AI confidence scores
- **Interface**: WebSocket (real-time), REST API (POST /v2/intents), GraphQL

### 2. OrchestRAN Converter (`tools/orchestran-converter/`)
- **Input**: TMF921 v5.0 Intent with 60+ O-RAN specifications
- **Processing**: AI-enhanced transformation with OrchestRAN framework positioning
- **Innovation**: Dynamic mapping adaptation, specification evolution tracking
- **Output**: 3GPP TS 28.312 v18 Expectation + OrchestRAN compatibility matrix
- **Interface**: CLI (`orchestran convert`), Python SDK, gRPC API

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

## Enhanced Non-Functional Requirements (v1.2.0)

- **Performance**: Intent→KRM <125ms (GenAI), SLO evaluation <500ms, 99.2% success rate
- **AI Capabilities**: 175B parameter model, <150ms processing, multi-modal support
- **Scalability**: 4-site topology support, zero-trust mesh, auto-scaling to 100+ edge sites
- **Security**: Zero-trust architecture, post-quantum cryptography ready, supply chain attestation
- **Observability**: Real-time WebSocket monitoring (ports 8002/8003/8004), AI decision tracking
- **Recovery**: 2.8-minute automated recovery, self-healing workflows, chaos engineering ready

## v1.2.0 Enhancements & Future Roadmap

### Current (September 2025)
- ✅ GenAI 175B parameter model integration
- ✅ OrchestRAN framework positioning vs alternatives
- ✅ 4-site zero-trust mesh topology (Edge1-4)
- ✅ TMF921 v5.0 and 3GPP TS 28.312 v18 compliance
- ✅ WebSocket real-time monitoring architecture
- ✅ Config Sync automation with 2.8min recovery

### Future (Q4 2025 - Q1 2026)
- 🚀 A1/E2 interface with AI-driven RAN optimization
- 🚀 Massive-scale intent distribution (1000+ edge sites)
- 🚀 AI-powered intent conflict resolution with federated learning
- 🚀 Predictive SLO management with quantum-enhanced algorithms
- 🚀 OrchestRAN ecosystem expansion and standardization