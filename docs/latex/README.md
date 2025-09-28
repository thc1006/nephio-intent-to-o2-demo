# IEEE ICC 2026 Paper - LaTeX Compilation Guide

**Paper Title**: Intent-Driven O-RAN Network Orchestration: A Production-Ready Multi-Site System Integrating Large Language Models with GitOps for Autonomous Infrastructure Management

**Conference**: IEEE International Conference on Communications (ICC) 2026

**Document Status**: Ready for submission (Anonymous version for double-blind review)

## Quick Start

```bash
# Validate environment
make validate

# Compile main paper
make main

# Compile supplementary materials
make supplementary

# Compile both documents
make both
```

## Repository Structure

```
docs/latex/
├── main.tex                  # Main IEEE conference paper
├── supplementary.tex         # Supplementary materials document
├── references.bib           # Bibliography with 35 references
├── IEEEtran.cls            # IEEE conference template class
├── Makefile                # Build automation
├── README.md               # This file
├── sections/               # Individual paper sections
│   ├── abstract.tex
│   ├── introduction.tex
│   ├── related-work.tex
│   ├── methodology.tex
│   ├── implementation.tex
│   ├── evaluation.tex
│   ├── results.tex
│   └── conclusion.tex
└── figures/                # Symlink to ../figures/
    ├── figure1_genai_architecture.pdf
    ├── figure3_orchestran_comparison.pdf
    ├── figure4_industry_timeline.pdf
    ├── figure5_network_topology.pdf
    └── figure6_ai_workflow.pdf
```

## Prerequisites

### Required Software

1. **TeX Distribution**:
   - **Linux**: `sudo apt-get install texlive-full`
   - **macOS**: Install MacTeX from https://www.tug.org/mactex/
   - **Windows**: Install MiKTeX from https://miktex.org/

2. **Essential LaTeX Packages**:
   - `pdflatex` (PDF compilation)
   - `bibtex` (Bibliography processing)
   - IEEE class files (included: `IEEEtran.cls`)

3. **Optional Tools**:
   - `aspell` (spell checking): `sudo apt-get install aspell aspell-en`
   - `detex` (word counting): `sudo apt-get install detex`
   - `make` (build automation): Usually pre-installed

### Verification

```bash
# Check LaTeX installation
pdflatex --version
bibtex --version

# Validate environment
cd docs/latex
make validate
```

## Compilation Instructions

### Method 1: Using Makefile (Recommended)

```bash
cd docs/latex

# Main paper compilation
make main

# Supplementary materials
make supplementary

# Both documents
make both

# Quick compilation (no bibliography)
make quick

# Clean auxiliary files
make clean

# Clean all generated files
make distclean
```

### Method 2: Manual Compilation

```bash
cd docs/latex

# Main paper
pdflatex main.tex
bibtex main
pdflatex main.tex
pdflatex main.tex

# Supplementary materials
pdflatex supplementary.tex
bibtex supplementary
pdflatex supplementary.tex
pdflatex supplementary.tex
```

### Method 3: One-Command Build

```bash
# For main paper
make main

# For supplementary materials
make supplementary
```

## Quality Assurance

### Validation Checks

```bash
# Environment validation
make validate

# Check for common issues
make check

# Word count estimation
make wordcount

# Spell check (requires aspell)
make spellcheck
```

### Manual Checks

1. **References**: Ensure all `\cite{}` commands have corresponding entries in `references.bib`
2. **Figures**: Verify all `\ref{fig:}` commands point to valid figure labels
3. **Tables**: Check all `\ref{tab:}` commands point to valid table labels
4. **Page Limit**: IEEE ICC papers should be 6-8 pages maximum
5. **Anonymity**: Ensure all author information is anonymized for double-blind review

## Expected Output

### Main Paper (`main.pdf`)
- **Pages**: 6-8 pages (IEEE conference format)
- **Content**: Complete research paper with figures and tables
- **Format**: Two-column IEEE conference layout
- **References**: 35 references in IEEE format

### Supplementary Materials (`supplementary.pdf`)
- **Pages**: 10-15 pages
- **Content**: Additional technical details, code samples, reproducibility guide
- **Format**: IEEE conference layout
- **Purpose**: Support for reviewers and reproducibility

## Troubleshooting

### Common Issues

1. **Missing Packages**:
   ```bash
   # Install missing LaTeX packages
   sudo apt-get install texlive-latex-extra texlive-science
   ```

2. **Bibliography Errors**:
   ```bash
   # Clear cache and rebuild
   make clean
   make main
   ```

3. **Figure Not Found**:
   ```bash
   # Check symlink
   ls -la figures/
   # Recreate if needed
   ln -sf ../figures ./figures
   ```

4. **Permission Errors**:
   ```bash
   # Fix permissions
   chmod +x Makefile
   chmod -R 644 *.tex sections/*.tex
   ```

### LaTeX Compilation Errors

1. **Undefined References**:
   - Run compilation 2-3 times to resolve cross-references
   - Check that all `\ref{}` commands have corresponding `\label{}` commands

2. **Bibliography Issues**:
   - Ensure `references.bib` is properly formatted
   - Check that all citations in text exist in bibliography

3. **Figure Issues**:
   - Verify PDF figures exist in `figures/` directory
   - Check figure file names match those in `\includegraphics{}`

### Memory Issues (Large Documents)

```bash
# Increase LaTeX memory limits
export max_print_line=1000
export error_line=254
export half_error_line=238
```

## File Descriptions

### Main Files

- **`main.tex`**: Primary document with IEEE conference formatting
- **`supplementary.tex`**: Additional materials for reviewers
- **`references.bib`**: Complete bibliography with 35 references
- **`IEEEtran.cls`**: IEEE conference document class

### Section Files

- **`sections/abstract.tex`**: Paper abstract (150-250 words)
- **`sections/introduction.tex`**: Introduction with problem statement and contributions
- **`sections/related-work.tex`**: Literature review and related work analysis
- **`sections/methodology.tex`**: System architecture and design principles
- **`sections/implementation.tex`**: Technical implementation details
- **`sections/evaluation.tex`**: Experimental setup and methodology
- **`sections/results.tex`**: Results discussion and analysis
- **`sections/conclusion.tex`**: Conclusions and future work

### Figures

All figures are linked from `../figures/` and include:
- **Figure 1**: System architecture with GenAI integration
- **Figure 2**: OrchestRAN vs traditional orchestration comparison
- **Figure 3**: Industry timeline and evolution
- **Figure 4**: Multi-site network topology
- **Figure 5**: AI-enhanced data flow diagram

## Quality Standards

### IEEE Requirements

- **Page Limit**: 6-8 pages for conference papers
- **Format**: Two-column, 10pt font, IEEE conference style
- **References**: IEEE citation format (numbered, not author-date)
- **Figures**: Professional quality, referenced in text
- **Tables**: Clear formatting with captions

### Content Requirements

- **Abstract**: 150-250 words summarizing contributions
- **Keywords**: 5-8 relevant technical keywords
- **Introduction**: Clear problem statement and contributions
- **Related Work**: Comprehensive literature review
- **Methodology**: Detailed system design
- **Evaluation**: Rigorous experimental validation
- **Results**: Statistical analysis and discussion
- **Conclusion**: Summary and future work

## Submission Checklist

- [ ] Paper compiles without errors
- [ ] All figures are properly referenced and display correctly
- [ ] All tables are properly formatted and referenced
- [ ] Bibliography is complete and properly formatted
- [ ] Page count is within IEEE limits (6-8 pages)
- [ ] Author information is anonymized for double-blind review
- [ ] AI usage is properly disclosed (as required by IEEE 2025)
- [ ] Supplementary materials compile successfully
- [ ] All code examples are properly formatted
- [ ] Statistical analysis is correctly presented
- [ ] References follow IEEE format exactly

## Performance Metrics

### Compilation Time
- **Main Paper**: ~30-45 seconds (with bibliography)
- **Supplementary**: ~25-35 seconds (with bibliography)
- **Quick Build**: ~10-15 seconds (no bibliography)

### File Sizes
- **main.pdf**: ~2-3 MB (with figures)
- **supplementary.pdf**: ~1-2 MB
- **Source files**: ~500 KB total

## Support

For technical issues with compilation:

1. Check this README first
2. Run `make validate` to check environment
3. Run `make check` to identify common issues
4. Check LaTeX log files (`.log`) for detailed error messages

For content questions, refer to the main paper and supplementary materials.

---

**Last Updated**: 2025-09-27
**LaTeX Version**: IEEE ICC 2026 Conference Format
**Document Version**: v1.2.0
**Compilation Tested**: Ubuntu 22.04 LTS, macOS 14, Windows 11