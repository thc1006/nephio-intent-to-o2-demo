#!/bin/bash
# Compile all figures for IEEE ICC 2026 paper
# Run this script to generate all PDFs and PNGs

set -e  # Exit on error

echo "================================================"
echo "  IEEE ICC 2026 Figure Generation Script"
echo "================================================"
echo ""

# Check dependencies
echo "[1/5] Checking dependencies..."

# Check pdflatex
if ! command -v pdflatex &> /dev/null; then
    echo "❌ ERROR: pdflatex not found. Please install TeX Live:"
    echo "   sudo apt-get install texlive-full"
    exit 1
fi

# Check Python and required packages
if ! command -v python3 &> /dev/null; then
    echo "❌ ERROR: python3 not found"
    exit 1
fi

echo "✓ pdflatex found"
echo "✓ python3 found"
echo ""

# Compile TikZ figures
echo "[2/5] Compiling TikZ figures..."

for fig in figure1_architecture.tex figure2_topology.tex figure3_dataflow.tex; do
    if [ -f "$fig" ]; then
        echo "  Compiling $fig..."
        pdflatex -interaction=nonstopmode "$fig" > /dev/null 2>&1 || {
            echo "❌ ERROR compiling $fig"
            exit 1
        }
        # Clean up auxiliary files
        rm -f *.aux *.log *.out
        echo "  ✓ ${fig%.tex}.pdf generated"
    else
        echo "  ⚠️  Warning: $fig not found, skipping"
    fi
done

echo ""

# Generate Python figures
echo "[3/5] Generating Python figures..."

if [ -f "figure4_performance.py" ]; then
    echo "  Running figure4_performance.py..."

    # Check if required Python packages are installed
    python3 -c "import matplotlib, numpy, pandas, scipy" 2>/dev/null || {
        echo "  ⚠️  Installing required Python packages..."
        pip3 install matplotlib numpy pandas scipy seaborn --quiet
    }

    python3 figure4_performance.py || {
        echo "❌ ERROR running figure4_performance.py"
        exit 1
    }
    echo "  ✓ Figure 4 generated"
else
    echo "  ⚠️  Warning: figure4_performance.py not found"
fi

echo ""

# Convert PDFs to PNGs for preview (300 DPI)
echo "[4/5] Converting PDFs to PNGs (300 DPI)..."

if command -v convert &> /dev/null; then
    for pdf in figure{1,2,3}_*.pdf; do
        if [ -f "$pdf" ]; then
            png="${pdf%.pdf}.png"
            echo "  Converting $pdf to $png..."
            convert -density 300 -quality 100 "$pdf" "$png" 2>/dev/null || {
                echo "  ⚠️  ImageMagick conversion failed for $pdf"
            }
        fi
    done
else
    echo "  ⚠️  ImageMagick not found, skipping PNG conversion"
    echo "     Install with: sudo apt-get install imagemagick"
fi

echo ""

# Summary
echo "[5/5] Summary of generated figures:"
echo ""
echo "  TikZ Figures (LaTeX source):"
ls -lh figure{1,2,3}_*.tex 2>/dev/null | awk '{print "    " $9 " (" $5 ")"}'

echo ""
echo "  PDF Outputs (for paper):"
ls -lh figure*.pdf 2>/dev/null | awk '{print "    " $9 " (" $5 ")"}'

echo ""
echo "  PNG Previews:"
ls -lh figure*.png 2>/dev/null | awk '{print "    " $9 " (" $5 ")"}'

echo ""
echo "================================================"
echo "  ✓ All figures generated successfully!"
echo "================================================"
echo ""
echo "Next steps:"
echo "  1. Review PDFs for quality and accuracy"
echo "  2. Insert into LaTeX paper using \\includegraphics"
echo "  3. Add captions and references"
echo ""
echo "Example LaTeX usage:"
echo "  \\begin{figure}[ht]"
echo "    \\centering"
echo "    \\includegraphics[width=0.9\\columnwidth]{figures/figure1_architecture.pdf}"
echo "    \\caption{System Architecture Overview - Four-Layer Architecture}"
echo "    \\label{fig:architecture}"
echo "  \\end{figure}"
echo ""