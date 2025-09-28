# Makefile for IEEE ICC 2026 Paper Compilation
# Intent-Driven O-RAN Network Orchestration with GenAI Integration

# Default target
.PHONY: all clean help main supplementary

# LaTeX compiler settings
LATEX = pdflatex
BIBTEX = bibtex
MAIN_TEX = main.tex
MAIN_PDF = main.pdf
SUPP_TEX = supplementary.tex
SUPP_PDF = supplementary.pdf

# Default target - build main paper
all: $(MAIN_PDF)

# Build main paper
main: $(MAIN_PDF)

# Build supplementary materials
supplementary: $(SUPP_PDF)

# Build both main paper and supplementary materials
both: $(MAIN_PDF) $(SUPP_PDF)

# Main paper compilation
$(MAIN_PDF): $(MAIN_TEX) references.bib sections/*.tex
	@echo "Building main paper..."
	$(LATEX) $(MAIN_TEX)
	$(BIBTEX) main
	$(LATEX) $(MAIN_TEX)
	$(LATEX) $(MAIN_TEX)
	@echo "Main paper compilation complete: $(MAIN_PDF)"

# Supplementary materials compilation
$(SUPP_PDF): $(SUPP_TEX) references.bib
	@echo "Building supplementary materials..."
	$(LATEX) $(SUPP_TEX)
	$(BIBTEX) supplementary
	$(LATEX) $(SUPP_TEX)
	$(LATEX) $(SUPP_TEX)
	@echo "Supplementary materials compilation complete: $(SUPP_PDF)"

# Quick build (no bibliography)
quick:
	@echo "Quick build (no bibliography)..."
	$(LATEX) $(MAIN_TEX)

# Clean auxiliary files
clean:
	@echo "Cleaning auxiliary files..."
	rm -f *.aux *.log *.bbl *.blg *.out *.toc *.lof *.lot *.synctex.gz
	rm -f sections/*.aux

# Clean all generated files including PDFs
distclean: clean
	@echo "Cleaning all generated files..."
	rm -f *.pdf

# Validate compilation environment
validate:
	@echo "Validating compilation environment..."
	@which $(LATEX) > /dev/null || (echo "Error: pdflatex not found" && exit 1)
	@which $(BIBTEX) > /dev/null || (echo "Error: bibtex not found" && exit 1)
	@test -f $(MAIN_TEX) || (echo "Error: $(MAIN_TEX) not found" && exit 1)
	@test -f references.bib || (echo "Error: references.bib not found" && exit 1)
	@test -d sections || (echo "Error: sections directory not found" && exit 1)
	@echo "Environment validation passed!"

# Count words in main paper (approximate)
wordcount:
	@echo "Estimating word count..."
	@detex $(MAIN_TEX) sections/*.tex | wc -w
	@echo "Note: This is an approximation. IEEE conference papers should be 6-8 pages."

# Check for common LaTeX issues
check:
	@echo "Checking for common issues..."
	@grep -n "TODO\|FIXME\|XXX" $(MAIN_TEX) sections/*.tex || echo "No TODO/FIXME markers found"
	@grep -n "\\cite{}" $(MAIN_TEX) sections/*.tex || echo "No empty citations found"
	@grep -n "Figure~\\ref{fig:}" $(MAIN_TEX) sections/*.tex > /dev/null && echo "Figure references found" || echo "Warning: No figure references found"
	@grep -n "Table~\\ref{tab:}" $(MAIN_TEX) sections/*.tex > /dev/null && echo "Table references found" || echo "Warning: No table references found"

# Generate spell check report
spellcheck:
	@echo "Running spell check (requires aspell)..."
	@which aspell > /dev/null || (echo "aspell not found, skipping spell check" && exit 0)
	@for file in $(MAIN_TEX) sections/*.tex; do \
		echo "Checking $$file..."; \
		aspell --mode=tex --lang=en_US list < $$file | sort | uniq; \
	done

# Show help
help:
	@echo "Available targets:"
	@echo "  all         - Build main paper (default)"
	@echo "  main        - Build main paper"
	@echo "  supplementary - Build supplementary materials"
	@echo "  both        - Build both main paper and supplementary materials"
	@echo "  quick       - Quick build without bibliography"
	@echo "  clean       - Remove auxiliary files"
	@echo "  distclean   - Remove all generated files"
	@echo "  validate    - Validate compilation environment"
	@echo "  wordcount   - Estimate word count"
	@echo "  check       - Check for common issues"
	@echo "  spellcheck  - Run spell check (requires aspell)"
	@echo "  help        - Show this help message"

# Dependencies for sections
sections/abstract.tex: ;
sections/introduction.tex: ;
sections/related-work.tex: ;
sections/methodology.tex: ;
sections/implementation.tex: ;
sections/evaluation.tex: ;
sections/results.tex: ;
sections/conclusion.tex: ;

# Mark targets that don't create files
.PHONY: quick clean distclean validate wordcount check spellcheck help