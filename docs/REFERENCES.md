# References & Standards

## Core Standards

### TMF921 Intent API
- **Specification**: [TMF921 Intent Management API v4.0](https://www.tmforum.org/resources/standard/tmf921-intent-api-v4-0/)
- **REST API Guide**: [TMF921 API User Guide](https://github.com/tmforum-apis/TMF921_Intent)
- **JSON Schema**: [TMF921 OpenAPI Specification](https://github.com/tmforum-apis/TMF921_Intent/blob/master/TMF921-Intent-v4.0.0.swagger.json)
- **Conformance**: TM Forum Intent Orchestration (TIO) / Catalyst Tool Kit (CTK)

### 3GPP TS 28.312
- **Specification**: [TS 28.312 Intent driven management services](https://www.3gpp.org/ftp/Specs/archive/28_series/28.312/)
- **Version**: Release 18 (latest stable)
- **Related**: 
  - TS 28.532: Management services for 5G networks
  - TS 28.541: 5G Network Resource Model (NRM)
  - TS 28.622: Generic Network Resource Model

### O-RAN O2 IMS
- **O2 Interface Specification**: [O-RAN.WG6.O2-GA&P-v03.00](https://www.o-ran.org/specifications)
- **IMS Architecture**: [O-RAN O2 IMS General Aspects and Principles](https://www.o-ran.org/blog/2023/10/26/o2-ims-performance-api)
- **Provisioning API**: O2 DMS Profile Management
- **Measurement Job Query**: [First O2 IMS Performance API Blog](https://www.o-ran.org/blog/measurement-job-query)

## Platform Documentation

### Nephio R5
- **Release Notes**: [Nephio R5 Release](https://nephio.org/releases/r5/)
- **Documentation**: [Nephio Docs](https://docs.nephio.org/)
- **API Reference**: [Nephio API](https://github.com/nephio-project/api)
- **Porch (Package Orchestration)**: [Porch Documentation](https://kpt.dev/book/08-package-orchestration/)
- **Config Sync**: [Config Sync Overview](https://cloud.google.com/anthos-config-management/docs/config-sync-overview)

### kpt Function SDK
- **Developer Guide**: [kpt Function Development](https://kpt.dev/book/05-developing-functions/)
- **Go SDK**: [kpt fn Go SDK](https://github.com/GoogleContainerTools/kpt-functions-sdk/tree/main/go)
- **Function Catalog**: [kpt Functions Catalog](https://catalog.kpt.dev/)
- **Testing Functions**: [Function Testing Guide](https://kpt.dev/book/05-developing-functions/04-testing)

## Security Frameworks

### Sigstore
- **Official Docs**: [Sigstore Documentation](https://docs.sigstore.dev/)
- **Cosign**: [Container Signing](https://docs.sigstore.dev/cosign/overview/)
- **Policy Controller**: [Kubernetes Admission Control](https://docs.sigstore.dev/policy-controller/overview/)
- **Fulcio**: [Certificate Authority](https://docs.sigstore.dev/fulcio/overview/)
- **Rekor**: [Transparency Log](https://docs.sigstore.dev/rekor/overview/)

### Kyverno
- **Documentation**: [Kyverno Docs](https://kyverno.io/docs/)
- **Policy Library**: [Kyverno Policies](https://kyverno.io/policies/)
- **Image Verification**: [verifyImages](https://kyverno.io/docs/writing-policies/verify-images/)
- **Best Practices**: [Kyverno Best Practices](https://kyverno.io/docs/writing-policies/best-practices/)

### cert-manager
- **Documentation**: [cert-manager.io](https://cert-manager.io/docs/)
- **Installation**: [Getting Started](https://cert-manager.io/docs/installation/)
- **Issuers**: [Configuring Issuers](https://cert-manager.io/docs/configuration/)
- **Troubleshooting**: [Debugging Guide](https://cert-manager.io/docs/troubleshooting/)

## Development Tools

### Testing Frameworks
- **Python**: [pytest](https://docs.pytest.org/), [pytest-asyncio](https://github.com/pytest-dev/pytest-asyncio)
- **Go**: [testing package](https://pkg.go.dev/testing), [testify](https://github.com/stretchr/testify)
- **Kubernetes**: [kubeconform](https://github.com/yannh/kubeconform), [kubeval](https://www.kubeval.com/)

### Linting & Formatting
- **Python**: [ruff](https://docs.astral.sh/ruff/), [black](https://black.readthedocs.io/)
- **Go**: [golangci-lint](https://golangci-lint.run/), [gofmt](https://pkg.go.dev/cmd/gofmt)
- **YAML**: [yamllint](https://yamllint.readthedocs.io/)

### CI/CD
- **GitHub Actions**: [Workflow Syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
- **Semantic Release**: [semantic-release](https://semantic-release.gitbook.io/)
- **Container Registry**: [GitHub Container Registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)

## Cloud Native Standards

### Kubernetes
- **API Reference**: [Kubernetes API](https://kubernetes.io/docs/reference/kubernetes-api/)
- **CRD Development**: [Extending Kubernetes](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/)
- **Operators**: [Operator Pattern](https://kubernetes.io/docs/concepts/extend-kubernetes/operator/)

### OpenTelemetry
- **Specification**: [OpenTelemetry Spec](https://opentelemetry.io/docs/reference/specification/)
- **Go SDK**: [OpenTelemetry Go](https://opentelemetry.io/docs/instrumentation/go/)
- **Python SDK**: [OpenTelemetry Python](https://opentelemetry.io/docs/instrumentation/python/)

### GitOps
- **Principles**: [OpenGitOps](https://opengitops.dev/)
- **Argo CD**: [Argo CD Docs](https://argo-cd.readthedocs.io/)
- **Flux**: [Flux Documentation](https://fluxcd.io/docs/)

## Telco-Specific Resources

### ETSI NFV
- **MANO**: [NFV Management and Orchestration](https://www.etsi.org/technologies/nfv)
- **SOL APIs**: [NFV SOL API Specifications](https://www.etsi.org/deliver/etsi_gs/NFV-SOL/)

### ONAP
- **Documentation**: [ONAP Docs](https://docs.onap.org/)
- **Intent Framework**: [ONAP Intent](https://wiki.onap.org/display/DW/Intent+Based+Networking)

## Additional Resources

### Blogs & Tutorials
- [Nephio Blog](https://nephio.org/blog/)
- [O-RAN Alliance News](https://www.o-ran.org/news)
- [CNCF Blog - Telco](https://www.cncf.io/blog/tag/telecom/)

### Community
- **Nephio Slack**: [Join Nephio Slack](https://nephio.org/community/)
- **O-RAN Working Groups**: [O-RAN Participation](https://www.o-ran.org/get-involved)
- **CNCF Telecom User Group**: [CNCF TUG](https://github.com/cncf/telecom-user-group)

### Example Implementations
- [Nephio Examples](https://github.com/nephio-project/nephio/tree/main/examples)
- [kpt Samples](https://github.com/GoogleContainerTools/kpt/tree/main/package-examples)
- [O-RAN SC (Software Community)](https://wiki.o-ran-sc.org/)

## Quick Links Cheatsheet

```bash
# Standards
TMF921 API: https://github.com/tmforum-apis/TMF921_Intent
3GPP TS 28.312: https://www.3gpp.org/ftp/Specs/archive/28_series/28.312/
O-RAN O2: https://www.o-ran.org/specifications

# Platforms
Nephio: https://docs.nephio.org/
kpt: https://kpt.dev/
Porch: https://kpt.dev/book/08-package-orchestration/

# Security
Sigstore: https://docs.sigstore.dev/
Kyverno: https://kyverno.io/docs/
cert-manager: https://cert-manager.io/docs/

# Development
pytest: https://docs.pytest.org/
golangci-lint: https://golangci-lint.run/
GitHub Actions: https://docs.github.com/en/actions
```