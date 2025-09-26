# LaTeX Conversion Guide
# IEEE ICC 2026 Paper Submission

**Status:** Main structure created, sections need population
**Target:** IEEE ICC 2026 (6-8 pages, two-column format)
**Current Progress:** 30% complete

---

## Files Created

### ✅ Completed Files

1. **`main.tex`** - Main LaTeX document with structure
   - IEEE conference template
   - All sections outlined
   - Proper packages included
   - Double-blind anonymization
   - Abstract and Introduction complete

2. **`references.bib`** - Complete BibTeX bibliography
   - 41 references in IEEE format
   - All 2025 state-of-the-art systems included
   - Properly formatted citations

3. **`figures/`** - All figure source files
   - `figure1_architecture.tex` - TikZ architecture diagram
   - `figure2_topology.tex` - TikZ network topology
   - `figure3_dataflow.tex` - TikZ data flow diagram
   - `figure4_performance.py` - Python performance charts

---

## Directory Structure

```
latex/
├── main.tex                    # Main document (COMPLETE)
├── references.bib              # Bibliography (COMPLETE)
├── IEEEtran.cls               # IEEE class file (DOWNLOAD NEEDED)
├── IEEEtran.bst               # IEEE bibliography style (DOWNLOAD NEEDED)
│
├── sections/                   # Section files (TO CREATE)
│   ├── 02-related-work.tex
│   ├── 03-architecture.tex
│   ├── 04-implementation.tex
│   ├── 05-evaluation.tex
│   ├── 06-discussion.tex
│   └── 07-conclusion.tex
│
└── figures/                    # Figures (MOSTLY COMPLETE)
    ├── figure1_architecture.tex    (COMPILE TO PDF)
    ├── figure1_architecture.pdf
    ├── figure2_topology.tex        (COMPILE TO PDF)
    ├── figure2_topology.pdf
    ├── figure3_dataflow.tex        (COMPILE TO PDF)
    ├── figure3_dataflow.pdf
    ├── figure4_performance.py      (RUN TO GENERATE)
    └── figure4_performance.pdf
```

---

## Step-by-Step Conversion Process

### Phase 1: Setup (15 minutes)

#### 1.1 Download IEEE Templates

```bash
cd /home/ubuntu/nephio-intent-to-o2-demo/docs/latex

# Download IEEE template from overleaf or IEEE website
# Option 1: From Overleaf
# Go to: https://www.overleaf.com/gallery/tagged/ieee
# Download IEEE Conference Template

# Option 2: From IEEE
wget http://www.ieee.org/conferences_events/conferences/publishing/templates.html

# Extract IEEEtran.cls and IEEEtran.bst to current directory
```

#### 1.2 Install LaTeX Dependencies

```bash
# On Ubuntu
sudo apt-get install texlive-full
sudo apt-get install texlive-latex-extra
sudo apt-get install texlive-fonts-recommended

# Verify installation
pdflatex --version
bibtex --version
```

#### 1.3 Compile Figures

```bash
cd figures/

# Compile TikZ figures
pdflatex figure1_architecture.tex
pdflatex figure2_topology.tex
pdflatex figure3_dataflow.tex

# Generate Python charts
python3 figure4_performance.py

# Verify PDFs created
ls -lh *.pdf
```

---

### Phase 2: Create Section Files (4-6 hours)

For each section, convert Markdown to LaTeX following IEEE format.

#### 2.1 Section 2: Related Work

**File:** `sections/02-related-work.tex`

**Conversion Steps:**

1. **Read Markdown source:**
   - Lines 54-124 in `IEEE_PAPER_2025_ANONYMOUS.md`

2. **Convert format:**
   - Subsections: `\subsection{}`
   - Subsubsections: `\subsubsection{}`
   - Citations: `\cite{author_year}`
   - Emphasis: `\textbf{}` or `\textit{}`
   - Lists: `\begin{itemize}...\end{itemize}`

3. **Example LaTeX:**

```latex
\subsection{Intent-Driven Networking Evolution}

Intent-driven networking has evolved from theoretical concepts to industry-grade implementations over the past decade. Early foundational work by Behringer et al.~\cite{behringer_rfc9315} established intent modeling principles, while subsequent research by Clemm et al.~\cite{clemm_intent2022} formalized intent-based networking definitions. The TM Forum's TMF921 Intent Management API~\cite{tmforum_intent_api} standardized intent representation and lifecycle management, becoming the de facto industry standard.

Recent advances in 2024-2025 have witnessed a paradigm shift toward LLM-integrated intent processing. The AGIR system~\cite{chen_agir2024} introduced automated intent generation and reasoning for O-RAN networks, achieving 92\% accuracy in intent interpretation. However, AGIR lacks production-grade reliability mechanisms and multi-site orchestration capabilities. Contemporary work by Zhang et al.~\cite{zhang_llm_networks2023} explored LLM applications for network configuration but remained limited to single-domain scenarios without standards compliance.

The MAESTRO framework~\cite{maestro2025}, published in 2025, represents a significant advancement in LLM-driven collaborative automation for 6G networks. MAESTRO utilizes large language models for automating intent-based operations with conflict resolution capabilities, achieving performance comparable to traditional optimization algorithms on 5G Open RAN testbeds. However, MAESTRO focuses on single-site scenarios and lacks the production-grade multi-site orchestration and SLO-gated deployment capabilities presented in this work.

% Continue with remaining subsections...
```

4. **Convert Table I:**

```latex
\begin{table*}[!t]
\centering
\caption{Comprehensive Comparison of Intent-Driven O-RAN Orchestration Systems (2024-2025)}
\label{tab:system_comparison}
\begin{tabular}{@{}lcccccccc@{}}
\toprule
\textbf{System} & \textbf{Intent} & \textbf{LLM} & \textbf{Multi-Site} & \textbf{Standards} & \textbf{Rollback} & \textbf{GitOps} & \textbf{Prod.} & \textbf{Year} \\
\midrule
ONAP~\cite{onap2024} & Limited & None & Federation & Partial TMF & Manual & No & Yes & 2024 \\
OSM~\cite{osm2024} & Basic & None & Yes & Limited & Manual & No & Yes & 2024 \\
Platform~\cite{platform2024} & K8s-native & None & Yes & O-RAN O2 & Limited & Partial & Emerging & 2024 \\
AGIR~\cite{chen_agir2024} & Advanced & Rule-based & No & TMF921 only & No & No & No & 2024 \\
MAESTRO~\cite{maestro2025} & Advanced & LLM & No & Partial & No & No & No & 2025 \\
Hermes~\cite{hermes2024} & Modeling & LLM & No & None & No & No & No & 2024 \\
Tech Mahindra~\cite{techmahindra_llm2025} & Anomaly & Llama 3.1 & Yes & Partial & Yes & No & Yes & 2025 \\
Nokia MantaRay~\cite{nokia_mantaray2025} & AI-powered & ML-based & Yes & TM Forum L4 & Yes & No & Yes & 2025 \\
\textbf{This System} & \textbf{Complete NLP} & \textbf{Claude LLM} & \textbf{GitOps} & \textbf{Complete} & \textbf{SLO-gated} & \textbf{Full} & \textbf{Yes} & \textbf{2025} \\
\bottomrule
\end{tabular}
\end{table*}
```

#### 2.2 Section 3: System Architecture

**File:** `sections/03-architecture.tex`

**Key Elements:**
- Reference Figure 1: `Figure~\ref{fig:architecture}`
- Reference Figure 2: `Figure~\ref{fig:topology}`
- Convert bullet lists to `\begin{itemize}`
- Code blocks to `\begin{lstlisting}`

**Example:**

```latex
\subsection{Design Principles}

The architecture follows several key design principles:

\begin{itemize}
\item \textbf{Standards Compliance}: Full adherence to TMF921, 3GPP TS 28.312, and O-RAN specifications
\item \textbf{Declarative Management}: All infrastructure represented as Kubernetes resources
\item \textbf{Continuous Validation}: SLO gates prevent invalid deployments
\item \textbf{Multi-Site Consistency}: GitOps ensures synchronized state across edge sites
\item \textbf{Evidence-Based Operations}: Complete audit trails for compliance and debugging
\end{itemize}
```

#### 2.3 Section 4: Implementation Details

**Key Elements:**
- Code listings with syntax highlighting
- Algorithms (if needed)
- Convert YAML to `\begin{lstlisting}[language=yaml]`
- Convert Python to `\begin{lstlisting}[language=Python]`

**Example:**

```latex
\subsection{Intent Processing Component}

\subsubsection{Claude Code CLI Integration}

The intent processing component integrates Claude Code CLI through a production-ready service wrapper:

\begin{lstlisting}[language=Python, caption=Claude Headless Service Implementation, label=lst:claude]
class ClaudeHeadlessService:
    def __init__(self):
        self.claude_path = self._detect_claude_cli()
        self.timeout = 30
        self.cache = {}

    async def process_intent(self, prompt: str,
                            use_cache: bool = True) -> Dict:
        cache_key = self._generate_cache_key(prompt)
        if use_cache and cache_key in self.cache:
            return self.cache[cache_key]

        result = await self._call_claude_with_retry(prompt)
        if use_cache:
            self.cache[cache_key] = result
        return result
\end{lstlisting}
```

#### 2.4 Section 5: Experimental Results

**Key Elements:**
- Multiple tables (Tables III-VI)
- Performance figures
- Statistical notation: `$\mu$`, `$\sigma$`, `$p < 0.001$`
- Confidence intervals: `[145, 155]ms`

**Example:**

```latex
\subsection{Performance Evaluation}

\subsubsection{Intent Processing Performance}

\begin{table}[!t]
\centering
\caption{Intent Processing Latency Analysis with Statistical Validation}
\label{tab:latency}
\begin{tabular}{@{}lcccc@{}}
\toprule
\textbf{Intent Type} & \textbf{NLP (ms)} & \textbf{TMF921 (ms)} & \textbf{Total (ms)} & \textbf{95\% CI} \\
\midrule
eMBB Slice & $95 \pm 8.2$ & $35 \pm 3.1$ & $130 \pm 11.3$ & [119, 141] \\
URLLC Service & $110 \pm 9.5$ & $40 \pm 3.8$ & $150 \pm 13.3$ & [137, 163] \\
mMTC Deploy & $105 \pm 7.8$ & $38 \pm 2.9$ & $143 \pm 10.7$ & [132, 154] \\
Multi-Site & $125 \pm 11.2$ & $45 \pm 4.2$ & $170 \pm 15.4$ & [155, 185] \\
\textbf{Baseline} & \textbf{N/A} & \textbf{14,400 $\pm$ 3,600} & \textbf{14,400 $\pm$ 3,600} & \textbf{[10,800, 18,000]} \\
\bottomrule
\end{tabular}
\end{table}

Statistical analysis ($n=400$ per intent type, $\alpha=0.05$) demonstrates significant performance improvement over manual processes ($p < 0.001$, Cohen's $d = 4.2$). All automated intent types achieve 92-98\% latency reduction compared to manual workflows.

\begin{figure}[!t]
\centering
\includegraphics[width=\columnwidth]{figures/figure4_performance.pdf}
\caption{Deployment Success Rate Over 30 Days showing 98.5\% average with trend analysis, incident period, and automatic recovery. Total of 1,033 deployment cycles with 95\% confidence interval overlay.}
\label{fig:performance}
\end{figure}

Figure~\ref{fig:performance} illustrates the deployment success rate over the 30-day evaluation period.
```

#### 2.5 Section 6: Discussion

Convert comparative analysis, lessons learned, and limitations.

#### 2.6 Section 7: Conclusion

Convert conclusion and future work.

---

### Phase 3: Compilation and Testing (1 hour)

#### 3.1 First Compilation

```bash
cd /home/ubuntu/nephio-intent-to-o2-demo/docs/latex

# Compile main document
pdflatex main.tex

# Compile bibliography
bibtex main

# Recompile to resolve references (twice)
pdflatex main.tex
pdflatex main.tex

# View PDF
evince main.pdf &
# or
okular main.pdf &
```

#### 3.2 Common Errors and Fixes

**Error 1: Missing .cls file**
```
! LaTeX Error: File `IEEEtran.cls' not found.
```
**Fix:** Download IEEEtran.cls from IEEE website

**Error 2: Undefined references**
```
LaTeX Warning: Reference `fig:architecture' on page X undefined.
```
**Fix:** Run pdflatex multiple times (at least twice)

**Error 3: Figure not found**
```
! LaTeX Error: File `figure1.pdf' not found.
```
**Fix:** Compile all TikZ figures first

**Error 4: Bibliography errors**
```
! Undefined control sequence.
```
**Fix:** Check references.bib for syntax errors

#### 3.3 Page Count Check

```bash
# Count pages in PDF
pdfinfo main.pdf | grep Pages

# IEEE ICC limit: 6-8 pages
# If > 8 pages:
#   1. Reduce figure sizes
#   2. Tighten text (remove redundancy)
#   3. Use two-column tables (table* environment)
#   4. Move details to supplementary materials
```

---

### Phase 4: Quality Assurance (2 hours)

#### 4.1 Visual Inspection

- [ ] All figures display correctly
- [ ] Tables are readable (not squeezed)
- [ ] No overfull/underfull hbox warnings
- [ ] Page breaks are reasonable
- [ ] Equations are properly formatted
- [ ] Citations appear correctly [1], [2], etc.
- [ ] References section complete

#### 4.2 IEEE PDF eXpress Check

```bash
# Upload PDF to IEEE PDF eXpress
# URL: https://ieee-pdf-express.org/

# Create account with conference ID (TBD for ICC 2026)
# Upload main.pdf
# Fix any errors reported
# Download IEEE-compliant PDF
```

#### 4.3 Plagiarism Check

```bash
# Use iThenticate or Turnitin (through IEEE)
# Expected similarity: < 15% (excluding references)
```

#### 4.4 Final Proofreading

- [ ] Re-read entire paper
- [ ] Check all numbers match across sections
- [ ] Verify figure captions are descriptive
- [ ] Ensure table labels are consistent
- [ ] Check acronym consistency
- [ ] Verify double-blind anonymization

---

## Conversion Automation Tools

### Pandoc (Partial Automation)

```bash
# Install pandoc
sudo apt-get install pandoc

# Convert Markdown to LaTeX (basic structure)
pandoc -f markdown -t latex \
    --biblatex \
    -o draft.tex \
    IEEE_PAPER_2025_ANONYMOUS.md

# WARNING: Manual cleanup required!
# - Fix citations
# - Adjust figure placements
# - Format tables properly
# - Add IEEE-specific formatting
```

### Search-and-Replace Patterns

```bash
# Convert Markdown bold to LaTeX
sed -i 's/\*\*\([^*]*\)\*\*/\\textbf{\1}/g' sections/*.tex

# Convert Markdown italic to LaTeX
sed -i 's/\*\([^*]*\)\*/\\textit{\1}/g' sections/*.tex

# Convert inline code to LaTeX
sed -i 's/`\([^`]*\)`/\\code{\1}/g' sections/*.tex
```

---

## Estimated Time Breakdown

| Task | Time | Status |
|------|------|--------|
| Setup (templates, figures) | 15 min | ✅ Ready |
| Section 2 (Related Work) | 1 hour | 🔲 To Do |
| Section 3 (Architecture) | 1 hour | 🔲 To Do |
| Section 4 (Implementation) | 1.5 hours | 🔲 To Do |
| Section 5 (Evaluation) | 1.5 hours | 🔲 To Do |
| Section 6 (Discussion) | 45 min | 🔲 To Do |
| Section 7 (Conclusion) | 30 min | 🔲 To Do |
| Compilation & Testing | 1 hour | 🔲 To Do |
| Quality Assurance | 2 hours | 🔲 To Do |
| **Total** | **~10 hours** | **30% Done** |

---

## Parallelization Strategy

To speed up conversion, multiple people can work on different sections simultaneously:

**Person 1:** Sections 2-3 (Related Work + Architecture)
**Person 2:** Sections 4-5 (Implementation + Evaluation)
**Person 3:** Sections 6-7 (Discussion + Conclusion) + QA

**Estimated Parallel Time:** 4-5 hours (vs. 10 hours sequential)

---

## Tips for Efficient Conversion

### 1. Use LaTeX Editor with Live Preview

- **Overleaf** (online, collaborative)
- **TeXstudio** (offline, feature-rich)
- **VS Code** with LaTeX Workshop extension

### 2. Start with Hardest Sections First

- Section 5 (Evaluation) - Most tables and figures
- Section 4 (Implementation) - Code listings

### 3. Reuse LaTeX Snippets

Create a `snippets.tex` file with common patterns:

```latex
% Table template
\begin{table}[!t]
\centering
\caption{}
\label{tab:}
\begin{tabular}{@{}lcc@{}}
\toprule
\textbf{} & \textbf{} & \textbf{} \\
\midrule
 &  &  \\
\bottomrule
\end{tabular}
\end{table}

% Figure template
\begin{figure}[!t]
\centering
\includegraphics[width=\columnwidth]{figures/}
\caption{}
\label{fig:}
\end{figure}
```

### 4. Validate Early and Often

```bash
# Quick compile check (skip bibliography)
pdflatex -interaction=nonstopmode main.tex

# Full compile
./build.sh  # Create this script
```

**build.sh:**
```bash
#!/bin/bash
pdflatex main.tex
bibtex main
pdflatex main.tex
pdflatex main.tex
echo "Done! Pages: $(pdfinfo main.pdf | grep Pages)"
```

---

## Final Checklist Before Submission

- [ ] All sections converted and proofread
- [ ] All figures compiled and included
- [ ] All tables formatted correctly
- [ ] Bibliography complete (41 references)
- [ ] PDF < 8 pages
- [ ] IEEE PDF eXpress approved
- [ ] Double-blind anonymization verified
- [ ] Supplementary materials linked
- [ ] Source files backed up

---

## Next Steps After LaTeX Conversion

1. **Internal Review** (Week 5-8 in timeline)
2. **External Review** (Week 9-10)
3. **Final Revisions** (Week 11-12)
4. **arXiv Preprint** (Week 13-14)
5. **IEEE ICC 2026 Submission** (January 2026)

---

**Document Version:** 1.0
**Last Updated:** September 26, 2025
**Estimated Completion:** October 2025 (Week 1-2)

*This guide provides complete instructions for converting the Markdown paper to IEEE LaTeX format. Main structure is complete; section files need population following the examples provided.*