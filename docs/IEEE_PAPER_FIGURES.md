# IEEE Paper Figure and Table Specifications

**Paper Title**: Intent-Driven O-RAN Network Orchestration: A Production-Ready Multi-Site System Integrating Large Language Models with GitOps for Autonomous Infrastructure Management

**Document Purpose**: Detailed specifications for all figures and tables in the IEEE paper to enable professional graphic design and LaTeX formatting.

---

## Figure Specifications

### Figure 1: System Architecture Overview

**Description**: Four-layer architecture diagram showing the complete system stack with data flow between layers.

**Visual Requirements**:
- **Size**: Full column width (8.5cm) x 10cm height
- **Style**: Professional block diagram with clean lines and modern typography
- **Color Scheme**: Blue gradient for technology layers, green for data flows

**Layer Structure** (top to bottom):
1. **UI Layer** (Light blue background)
   - Web Interface (browser icon)
   - REST APIs (API symbol)
   - CLI Tools (terminal icon)
   - Arrows pointing down to Intent Layer

2. **Intent Layer** (Medium blue background)
   - Claude Code CLI (brain icon)
   - TMF921 Adapter (standards symbol)
   - Natural Language Processing (NLP badge)
   - Arrows pointing down to Orchestration Layer

3. **Orchestration Layer** (Dark blue background)
   - KRM Rendering (gear icon)
   - GitOps Management (git branch icon)
   - SLO Validation (checkmark shield)
   - Porch (package icon)
   - Arrows pointing down to Infrastructure Layer

4. **Infrastructure Layer** (Navy blue background)
   - VM-1 Orchestrator (server icon)
   - VM-2 Edge Site 1 (edge server icon)
   - VM-4 Edge Site 2 (edge server icon)
   - O2IMS Integration (O-RAN logo)

**Data Flows**:
- Green arrows showing intent flow downward
- Orange arrows showing feedback/monitoring upward
- Dotted lines for GitOps synchronization between orchestrator and edge sites

**Text Elements**:
- Layer labels in white bold text
- Component names in smaller black text
- Flow labels: "Intent Processing", "Deployment", "Monitoring"

**Suggested Tools**: Draw.io, Lucidchart, or Adobe Illustrator
**Output Format**: SVG for LaTeX, PNG for initial review

---

### Figure 2: Network Topology

**Description**: Detailed network diagram showing VM interconnections, IP addresses, and service endpoints.

**Visual Requirements**:
- **Size**: Full column width (8.5cm) x 8cm height
- **Style**: Network topology diagram with router/server icons
- **Color Scheme**: Gray background, blue for internal network, green for services

**Network Elements**:

**VM-1 (Orchestrator) - 172.16.0.78**:
- Large server icon in center-left
- Label: "VM-1 (Orchestrator)\n172.16.0.78\n4 vCPU, 8GB RAM"
- Service ports shown as colored dots:
  - Port 8002: Claude Service (blue)
  - Port 8889: TMF921 API (green)
  - Port 8888: Gitea (orange)
  - Port 6444: K3s API (purple)
  - Port 9090: Prometheus (red)
  - Port 3000: Grafana (yellow)

**VM-2 (Edge Site 1) - 172.16.4.45**:
- Server icon in top-right
- Label: "VM-2 (Edge Site 1)\n172.16.4.45\n8 vCPU, 16GB RAM"
- Service ports:
  - Port 6443: Kubernetes API (purple)
  - Port 31280: O2IMS (blue)
  - Port 30090: Prometheus (red)

**VM-4 (Edge Site 2) - 172.16.4.176**:
- Server icon in bottom-right
- Label: "VM-4 (Edge Site 2)\n172.16.4.176\n8 vCPU, 16GB RAM"
- Service ports:
  - Port 6443: Kubernetes API (purple)
  - Port 31280: O2IMS (blue)
  - Port 30090: Prometheus (red)

**Network Connections**:
- Thick blue lines for 172.16.0.0/16 internal network
- Dashed lines for GitOps synchronization (VM-1 to edge sites)
- Dotted lines for metrics collection (edge sites to VM-1)
- Network speed labels: "1Gbps"

**Legend**:
- Service port color coding
- Connection type explanations
- IP subnet information

**Suggested Tools**: Visio, Draw.io, or Omnigraffle
**Output Format**: SVG for LaTeX

---

### Figure 3: Data Flow Diagram

**Description**: Detailed workflow showing the 7-step intent-to-deployment pipeline with feedback loops.

**Visual Requirements**:
- **Size**: Two-column width (17.5cm) x 12cm height
- **Style**: Process flow diagram with numbered steps and feedback loops
- **Color Scheme**: Sequential color coding (blue to green progression)

**Process Steps** (left to right, with swimlanes):

**Step 1: Natural Language Input**
- User icon with speech bubble
- Text: "Deploy eMBB slice with 10ms latency"
- Arrow labeled "Intent" to Step 2

**Step 2: Intent Generation (LLM)**
- Brain icon with Claude logo
- Process box: "Claude Code CLI\n150ms processing"
- Arrow labeled "TMF921 JSON" to Step 3

**Step 3: KRM Compilation**
- Gear icon
- Process box: "Intent → KRM\nKubernetes Resources"
- Arrow labeled "YAML Manifests" to Step 4

**Step 4: GitOps Push**
- Git branch icon
- Process box: "Gitea Repository\nVersioned Config"
- Arrow labeled "Git Commit" to Step 5

**Step 5: Edge Synchronization**
- Sync icon
- Two parallel boxes: "Edge Site 1" and "Edge Site 2"
- Process: "Config Sync\n35ms latency"
- Arrow labeled "Kubernetes Apply" to Step 6

**Step 6: SLO Validation**
- Shield icon with checkmark
- Process box: "Quality Gates\nPrometheus Metrics"
- Two paths:
  - Success: Arrow labeled "98.5% success" to Step 7
  - Failure: Red arrow labeled "1.5% failure" to Step 7 (Rollback)

**Step 7A: Deployment Success**
- Green checkmark icon
- Text: "Service Active\nSLO Compliance"

**Step 7B: Automatic Rollback**
- Red warning icon
- Process box: "Git Revert\n3.2min recovery"
- Arrow back to Step 5

**Feedback Loops**:
- Monitoring data from edges back to orchestrator
- SLO metrics feeding back to validation
- User notifications on completion/failure

**Timing Annotations**:
- Each step shows average processing time
- Total pipeline time: "~5 minutes end-to-end"

**Suggested Tools**: Lucidchart, Visio, or Adobe Illustrator
**Output Format**: SVG for LaTeX

---

### Figure 4: Deployment Success Rate Over Time

**Description**: Line graph showing deployment success rate trends over the 30-day evaluation period.

**Visual Requirements**:
- **Size**: Full column width (8.5cm) x 6cm height
- **Style**: Professional line chart with grid and confidence intervals
- **Color Scheme**: Blue line for success rate, gray shaded area for confidence interval

**Chart Specifications**:
- **X-axis**: Time (Days 1-30)
- **Y-axis**: Success Rate (%) - Range 95% to 100%
- **Main Line**: Blue solid line showing daily success rate
- **Confidence Interval**: Light blue shaded area (95% CI)
- **Average Line**: Horizontal dashed line at 98.5%
- **Grid**: Light gray horizontal and vertical grid lines

**Data Points** (representative sample):
- Day 1: 97.2% ± 1.8%
- Day 5: 98.1% ± 1.5%
- Day 10: 98.7% ± 1.2%
- Day 15: 98.9% ± 1.1%
- Day 20: 98.3% ± 1.4%
- Day 25: 98.8% ± 1.0%
- Day 30: 98.6% ± 1.3%

**Annotations**:
- Text box: "Average: 98.5%"
- Text box: "σ = 0.8%"
- Arrow pointing to confidence interval: "95% CI"

**Legend**:
- Success Rate (blue line)
- 95% Confidence Interval (shaded area)
- Target Average (dashed line)

**Suggested Tools**: R ggplot2, Python matplotlib, or Excel with professional styling
**Output Format**: PDF for LaTeX inclusion

---

## Table Specifications

### Table I: Comparison of O-RAN Orchestration Systems

**LaTeX Code**:
```latex
\begin{table}[t]
\centering
\caption{Comparison of O-RAN Orchestration Systems}
\label{tab:oran_comparison}
\begin{tabular}{|l|c|c|c|c|c|}
\hline
\textbf{System} & \textbf{Intent Support} & \textbf{LLM Integration} & \textbf{Multi-Site} & \textbf{Standards Compliance} & \textbf{Production Ready} \\
\hline
ONAP & Limited & None & Yes & Partial TMF & Yes \\
\hline
OSM & Basic & None & Yes & Limited & Yes \\
\hline
Nephio & Kubernetes-native & None & Yes & O-RAN O2 & Emerging \\
\hline
AGIR [16] & Advanced & Rule-based & No & TMF921 only & No \\
\hline
\textbf{Our System} & \textbf{Complete} & \textbf{LLM-based} & \textbf{Yes} & \textbf{TMF921+3GPP+O-RAN} & \textbf{Yes} \\
\hline
\end{tabular}
\end{table}
```

**CSV Data**:
```csv
System,Intent Support,LLM Integration,Multi-Site,Standards Compliance,Production Ready
ONAP,Limited,None,Yes,Partial TMF,Yes
OSM,Basic,None,Yes,Limited,Yes
Nephio,Kubernetes-native,None,Yes,O-RAN O2,Emerging
AGIR [16],Advanced,Rule-based,No,TMF921 only,No
Our System,Complete,LLM-based,Yes,TMF921+3GPP+O-RAN,Yes
```

---

### Table II: Intent-to-KRM Mapping

**LaTeX Code**:
```latex
\begin{table}[t]
\centering
\caption{Intent-to-KRM Mapping}
\label{tab:intent_krm_mapping}
\begin{tabular}{|l|l|l|}
\hline
\textbf{Intent Component} & \textbf{KRM Resource} & \textbf{Purpose} \\
\hline
Service Type & Deployment & Network function workload \\
\hline
QoS Parameters & ConfigMap & Service configuration \\
\hline
Target Site & Namespace & Resource isolation \\
\hline
Network Slice & NetworkPolicy & Traffic management \\
\hline
O2IMS Request & ProvisioningRequest & Infrastructure allocation \\
\hline
\end{tabular}
\end{table}
```

---

### Table III: Intent Processing Latency Analysis with Statistical Validation

**LaTeX Code**:
```latex
\begin{table*}[t]
\centering
\caption{Intent Processing Latency Analysis with Statistical Validation}
\label{tab:latency_analysis}
\begin{tabular}{|l|c|c|c|c|c|}
\hline
\textbf{Intent Type} & \textbf{NLP Processing (ms)} & \textbf{TMF921 Conversion (ms)} & \textbf{Total Latency (ms)} & \textbf{95\% CI} & \textbf{p-value} \\
\hline
eMBB Slice & 95 ± 8.2 & 35 ± 3.1 & 130 ± 11.3 & [119, 141] & < 0.001 \\
\hline
URLLC Service & 110 ± 9.5 & 40 ± 3.8 & 150 ± 13.3 & [137, 163] & < 0.001 \\
\hline
mMTC Deployment & 105 ± 7.8 & 38 ± 2.9 & 143 ± 10.7 & [132, 154] & < 0.001 \\
\hline
Complex Multi-Site & 125 ± 11.2 & 45 ± 4.2 & 170 ± 15.4 & [155, 185] & < 0.001 \\
\hline
\textbf{Baseline (Manual)} & \textbf{N/A} & \textbf{14,400 ± 3,600} & \textbf{14,400 ± 3,600} & \textbf{[10,800, 18,000]} & \textbf{N/A} \\
\hline
\end{tabular}
\end{table*}
```

---

### Table IV: SLO Thresholds and Validation Results

**LaTeX Code**:
```latex
\begin{table}[t]
\centering
\caption{SLO Thresholds and Validation Results}
\label{tab:slo_validation}
\begin{tabular}{|l|c|c|c|}
\hline
\textbf{Metric} & \textbf{Target} & \textbf{Achieved} & \textbf{Compliance} \\
\hline
Latency P95 & < 50ms & 35ms & 99.8\% \\
\hline
Success Rate & > 99\% & 99.2\% & 100\% \\
\hline
Throughput & > 180 Mbps & 187 Mbps & 98.9\% \\
\hline
Availability & > 99.9\% & 99.95\% & 100\% \\
\hline
\end{tabular}
\end{table}
```

---

### Table V: GitOps Performance Metrics

**LaTeX Code**:
```latex
\begin{table}[t]
\centering
\caption{GitOps Performance Metrics}
\label{tab:gitops_performance}
\begin{tabular}{|l|c|c|c|}
\hline
\textbf{Metric} & \textbf{Edge1 (VM-2)} & \textbf{Edge2 (VM-4)} & \textbf{Target} \\
\hline
Sync Latency & 32ms & 38ms & < 60ms \\
\hline
Sync Success Rate & 99.9\% & 99.7\% & > 99\% \\
\hline
Consistency Check & 99.8\% & 99.8\% & > 99\% \\
\hline
Poll Interval & 15s & 15s & 15s \\
\hline
\end{tabular}
\end{table}
```

---

### Table VI: Fault Injection Test Results

**LaTeX Code**:
```latex
\begin{table}[t]
\centering
\caption{Fault Injection Test Results}
\label{tab:fault_injection}
\begin{tabular}{|l|c|c|c|}
\hline
\textbf{Fault Type} & \textbf{Detection Time} & \textbf{Recovery Time} & \textbf{Service Impact} \\
\hline
High Latency (>100ms) & 45s & 3.1min & None (rollback successful) \\
\hline
High Error Rate (>5\%) & 30s & 2.8min & None (rollback successful) \\
\hline
Network Partition & 60s & 3.5min & Temporary (automatic healing) \\
\hline
Pod Crashes & 15s & 2.2min & None (Kubernetes recovery) \\
\hline
\textbf{Average} & \textbf{38s} & \textbf{2.9min} & \textbf{Minimal} \\
\hline
\end{tabular}
\end{table}
```

---

### Table VII: Comparative Performance Analysis

**LaTeX Code**:
```latex
\begin{table*}[t]
\centering
\caption{Comparative Performance Analysis}
\label{tab:comparative_performance}
\begin{tabular}{|l|c|c|c|c|c|}
\hline
\textbf{System} & \textbf{Intent Processing} & \textbf{Deployment Success} & \textbf{Multi-Site Support} & \textbf{Standards Compliance} & \textbf{Rollback Time} \\
\hline
Manual Process & 4-6 hours & 75\% & Manual coordination & Partial & 6+ hours \\
\hline
ONAP & N/A (no intent) & 94\% & Federation-based & Partial TMF & 45 minutes \\
\hline
AGIR [16] & 600ms & 92\% & No & TMF921 only & N/A \\
\hline
\textbf{Our System} & \textbf{150ms} & \textbf{98.5\%} & \textbf{GitOps-native} & \textbf{Complete} & \textbf{3.2 minutes} \\
\hline
\end{tabular}
\end{table*}
```

---

## Production Guidelines

### Figure Creation Checklist:
- [ ] High-resolution output (300+ DPI for print)
- [ ] Consistent typography throughout all figures
- [ ] Color accessibility (colorblind-friendly palette)
- [ ] Professional IEEE conference styling
- [ ] Clear legends and labels
- [ ] Scalable text for different output sizes

### Table Formatting:
- [ ] IEEE LaTeX table template compliance
- [ ] Consistent decimal places and units
- [ ] Bold headers and key results
- [ ] Proper statistical notation
- [ ] Clear column alignment
- [ ] Professional spacing and borders

### File Organization:
- `/docs/figures/figure1_architecture.svg`
- `/docs/figures/figure2_topology.svg`
- `/docs/figures/figure3_dataflow.svg`
- `/docs/figures/figure4_success_rate.pdf`
- `/docs/tables/all_tables.tex`

---

**Document Prepared**: 2025-09-26
**For Paper**: IEEE_PAPER_2025.md
**Target Conference**: IEEE ICC 2025