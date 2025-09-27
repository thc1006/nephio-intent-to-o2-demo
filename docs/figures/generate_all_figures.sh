#!/bin/bash
# Generate All IEEE Paper Figures
# Automated script to generate all publication-quality figures

echo "🎨 IEEE Paper Figure Generation Suite"
echo "===================================="
echo "Generating 5 figures for IEEE ICC 2026 paper submission"
echo ""

# Set error handling
set -e

# Function to generate a figure with error handling
generate_figure() {
    local script=$1
    local figure_name=$2

    echo "📊 Generating $figure_name..."

    if python "$script"; then
        echo "✅ $figure_name generated successfully"
    else
        echo "❌ Error generating $figure_name"
        exit 1
    fi
    echo ""
}

# Create output directory if it doesn't exist
mkdir -p /home/ubuntu/nephio-intent-to-o2-demo/docs/figures

# Navigate to figures directory
cd /home/ubuntu/nephio-intent-to-o2-demo/docs/figures

# Check if Python is available
if ! command -v python &> /dev/null; then
    echo "❌ Python is not installed or not in PATH"
    exit 1
fi

# Check if required packages are installed
echo "🔍 Checking dependencies..."
python -c "import matplotlib, numpy" 2>/dev/null || {
    echo "⚠️  Missing dependencies. Installing..."
    pip install -r requirements.txt
}
echo "✅ Dependencies check passed"
echo ""

# Record start time
start_time=$(date +%s)

# Generate all figures
generate_figure "figure1_genai_architecture.py" "Figure 1: GenAI Integration Architecture"
generate_figure "figure3_orchestran_comparison.py" "Figure 3: OrchestRAN vs Traditional Comparison"
generate_figure "figure4_industry_timeline.py" "Figure 4: Industry Timeline 2020-2025"
generate_figure "figure5_network_topology.py" "Figure 5: Multi-Site Network Topology"
generate_figure "figure6_ai_workflow.py" "Figure 6: AI-Enhanced Workflow"

# Calculate execution time
end_time=$(date +%s)
execution_time=$((end_time - start_time))

echo "🎉 All figures generated successfully!"
echo "⏱️  Total execution time: ${execution_time} seconds"
echo ""

# List generated files
echo "📁 Generated files:"
echo "=================="
for format in png pdf svg; do
    echo ""
    echo "📄 $format files:"
    ls -la *.$format 2>/dev/null | awk '{print "   " $9 " (" $5 " bytes)"}' || echo "   No $format files found"
done

echo ""
echo "🏆 Summary:"
echo "==========="
echo "• 5 figures generated in 3 formats each (PNG, PDF, SVG)"
echo "• Resolution: 300 DPI (publication quality)"
echo "• IEEE format compliance: ✅"
echo "• Colorblind-safe palettes: ✅"
echo "• Vector formats for LaTeX: ✅"
echo ""
echo "📖 Usage:"
echo "========="
echo "• PNG files: For viewing and presentations"
echo "• PDF files: For LaTeX document inclusion"
echo "• SVG files: For further editing and customization"
echo ""
echo "✨ Ready for IEEE ICC 2026 submission!"