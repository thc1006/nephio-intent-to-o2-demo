# IEEE Paper Figure Generation Suite

This directory contains automated scripts to generate all figures for the IEEE paper: "Intent-Driven O-RAN Network Orchestration with GenAI Integration: A Production-Ready Multi-Site System Implementing OrchestRAN Architecture for Autonomous Infrastructure Management"

## 📋 Overview

The suite generates 5 publication-quality figures in multiple formats (PNG, PDF, SVG) suitable for IEEE conference papers with 300 DPI resolution and colorblind-safe color schemes.

## 🎯 Generated Figures

### Figure 1: Enhanced System Architecture with GenAI Integration
**File**: `figure1_genai_architecture.py`
- **Description**: Five-layer architecture diagram showing OrchestRAN-style orchestration
- **Layers**: GenAI Intelligence → Intent Orchestration → KRM → O2IMS v3.0 → Infrastructure
- **Features**: AI gradient colors, data flow arrows, technology annotations
- **Size**: 17.5cm × 12cm (two-column width)

### Figure 3: OrchestRAN vs Traditional Orchestration Comparison
**File**: `figure3_orchestran_comparison.py`
- **Description**: Side-by-side comparison of traditional vs autonomous orchestration
- **Features**: Performance metrics, visual indicators, improvement statistics
- **Highlights**: 126x faster deployment, 98.5% success rate, autonomous operations
- **Size**: 17.5cm × 10cm (two-column width)

### Figure 4: 2025 Industry Timeline and Evolution
**File**: `figure4_industry_timeline.py`
- **Description**: Timeline from 2020-2025 showing technology evolution
- **Milestones**: O-RAN formation, Nephio launch, TMF921 standards, LLM integration
- **Features**: Adoption curves, version evolution, breakthrough indicators
- **Size**: 17.5cm × 8cm (two-column width)

### Figure 5: Multi-Site Network Topology with Enhanced Connectivity
**File**: `figure5_network_topology.py`
- **Description**: Network diagram with 4 edge sites and advanced connectivity
- **Components**: VM-1 orchestrator, VM-2/VM-4 edge sites, Edge3/Edge4 compact nodes
- **Features**: Dark background, connectivity legends, performance metrics
- **Size**: 17.5cm × 12cm (two-column width)

### Figure 6: Enhanced AI-Driven Workflow with Decision Points
**File**: `figure6_ai_workflow.py`
- **Description**: 8-step pipeline with AI decision points and feedback loops
- **Workflow**: Intent Input → AI Understanding → KRM Generation → GitOps → Orchestration → Validation → Quality Gates → Success/Recovery
- **Features**: AI decision diamonds, performance metrics, feedback loops
- **Size**: 17.5cm × 14cm (two-column width)

## 🚀 Quick Start

### 1. Install Dependencies
```bash
# Navigate to figures directory
cd docs/figures

# Install Python dependencies
pip install -r requirements.txt

# Optional: Install system dependencies for enhanced features
# Ubuntu/Debian:
sudo apt-get install graphviz graphviz-dev

# macOS:
brew install graphviz

# Windows:
# Download from https://graphviz.org/download/
```

### 2. Generate All Figures
```bash
# Generate all figures at once
./generate_all_figures.sh

# Or generate individual figures
python figure1_genai_architecture.py
python figure3_orchestran_comparison.py
python figure4_industry_timeline.py
python figure5_network_topology.py
python figure6_ai_workflow.py
```

### 3. Verify Output
```bash
# Check generated files
ls -la *.png *.pdf *.svg

# Expected output for each figure:
# - figure{N}_*.png (300 DPI for viewing)
# - figure{N}_*.pdf (vector format for LaTeX)
# - figure{N}_*.svg (editable vector format)
```

## 📁 Output Formats

### PNG Files (300 DPI)
- **Purpose**: High-resolution viewing, presentations, web display
- **Quality**: Publication-ready 300 DPI
- **Size**: Optimized for file size while maintaining quality

### PDF Files (Vector)
- **Purpose**: LaTeX document inclusion, print publishing
- **Quality**: Scalable vector graphics
- **Compatibility**: IEEE template compatible

### SVG Files (Editable)
- **Purpose**: Further editing, customization, web display
- **Quality**: Scalable vector graphics with text editability
- **Tools**: Compatible with Inkscape, Illustrator, web browsers

## 🎨 Styling Guidelines

### Color Schemes
- **AI Components**: Teal to purple gradient (`#20B2AA` → `#8A2BE2`)
- **Infrastructure**: Blue gradient (`#4682B4` → `#191970`)
- **Success Indicators**: Green tones (`#32CD32`, `#228B22`)
- **Warning/Recovery**: Orange/red tones (`#FF6347`, `#DC143C`)
- **Connections**: Gold (`#FFD700`) and coordinated colors

### Typography
- **Titles**: Bold, 12-14pt
- **Labels**: 8-10pt, clear fonts
- **Annotations**: 6-8pt
- **Technical specs**: 5-6pt, monospace where appropriate

### IEEE Compliance
- **Dimensions**: Metric measurements (cm)
- **Resolution**: 300 DPI minimum
- **Color**: Colorblind-safe palettes
- **Fonts**: Standard fonts (Arial, Helvetica, Times)

## 🔧 Customization

### Modifying Colors
```python
# Edit color dictionaries in each script
colors = {
    'genai': '#20B2AA',           # Teal
    'intent': '#8A2BE2',          # Purple
    'krm': '#4682B4',             # Medium blue
    # Add your custom colors
}
```

### Adjusting Dimensions
```python
# Modify figure size (width_cm, height_cm)
fig, ax = plt.subplots(1, 1, figsize=(17.5/2.54, 12/2.54), dpi=300)
```

### Adding Components
```python
# Add new components to existing layers/steps
new_component = {
    'name': 'Your Component',
    'position': (x, y),
    'icon': '🔧',
    'color': colors['custom']
}
```

## 🧪 Testing and Validation

### Quality Checks
```bash
# Verify all figures generate without errors
python -m pytest test_figure_generation.py

# Check DPI and dimensions
python validate_figures.py

# Visual inspection
python preview_all_figures.py
```

### Common Issues and Solutions

#### Issue: Low Resolution Output
```python
# Solution: Ensure DPI is set correctly
fig, ax = plt.subplots(figsize=(width, height), dpi=300)
fig.savefig('output.png', dpi=300, bbox_inches='tight')
```

#### Issue: Font Rendering Problems
```bash
# Solution: Install required fonts or use system fonts
# Linux:
sudo apt-get install fonts-liberation

# Use safe font fallbacks in code
plt.rcParams['font.family'] = ['DejaVu Sans', 'Arial', 'sans-serif']
```

#### Issue: Missing Icons/Symbols
```python
# Solution: Use Unicode symbols or simple shapes
# Instead of complex symbols, use basic Unicode
icon_map = {
    'ai': '🧠',
    'network': '🌐',
    'server': '🖥️',
    'security': '🔒'
}
```

## 🔍 Advanced Features

### Interactive Development
```bash
# Launch Jupyter for interactive development
jupyter notebook figure_development.ipynb

# Real-time preview with auto-reload
python figure_preview_server.py
```

### Batch Processing
```bash
# Generate figures with different parameters
python batch_generate.py --config production.json

# Generate with specific color themes
python generate_all_figures.py --theme ieee-blue
python generate_all_figures.py --theme colorblind-safe
```

### Export for Different Venues
```bash
# IEEE format (default)
python generate_all_figures.py --format ieee

# ACM format
python generate_all_figures.py --format acm

# Springer format
python generate_all_figures.py --format springer
```

## 📊 Performance Metrics

### Generation Times (approximate)
- Figure 1 (Architecture): ~3-5 seconds
- Figure 3 (Comparison): ~2-3 seconds
- Figure 4 (Timeline): ~3-4 seconds
- Figure 5 (Topology): ~4-6 seconds
- Figure 6 (Workflow): ~5-7 seconds
- **Total**: ~17-25 seconds for all figures

### File Sizes (typical)
- PNG files: 500KB - 2MB each
- PDF files: 200KB - 800KB each
- SVG files: 100KB - 500KB each

## 🤝 Contributing

### Adding New Figures
1. Create new script: `figure{N}_description.py`
2. Follow existing naming conventions
3. Include all three output formats (PNG, PDF, SVG)
4. Add entry to this README
5. Update `generate_all_figures.sh`

### Improving Existing Figures
1. Test changes with multiple Python versions
2. Verify output quality at 300 DPI
3. Check colorblind accessibility
4. Validate IEEE format compliance

## 📚 Dependencies Reference

### Core Requirements
- **matplotlib**: Primary plotting library
- **numpy**: Numerical computations
- **scipy**: Scientific computing (for advanced curves)

### Optional Enhancements
- **plotly**: Interactive plotting (for development)
- **networkx**: Network diagram layouts
- **graphviz**: Professional diagram generation
- **Pillow**: Image processing and optimization

### Development Tools
- **black**: Code formatting
- **flake8**: Code linting
- **pytest**: Testing framework

## 📄 License and Usage

These figure generation scripts are part of the IEEE paper submission. Usage guidelines:

1. **Academic Use**: Free for research and educational purposes
2. **Modification**: Encouraged for improving figure quality
3. **Attribution**: Please cite the original paper when using
4. **Distribution**: Share improvements back to the community

## 🆘 Support and Troubleshooting

### Common Error Messages

**"ModuleNotFoundError: No module named 'matplotlib'"**
```bash
# Solution: Install requirements
pip install -r requirements.txt
```

**"UserWarning: Glyph missing from current font"**
```python
# Solution: Use alternative fonts or Unicode symbols
plt.rcParams['font.family'] = 'DejaVu Sans'
```

**"Figure is too large to save"**
```python
# Solution: Reduce DPI or figure size
fig.savefig('output.png', dpi=200)  # Reduce from 300
```

### Getting Help

1. **Check Issues**: Review common problems above
2. **Documentation**: Read matplotlib and numpy docs
3. **Community**: Ask on Stack Overflow with tags: matplotlib, python, ieee
4. **Contact**: Reach out to paper authors for specific questions

---

**Generated**: 2025-09-27
**For Paper**: IEEE ICC 2026 Submission
**Standards**: O2IMS v3.0, OrchestRAN v2.0, ATIS MVP V2, Nephio R4