#!/usr/bin/env python3
"""
Figure 1: Enhanced System Architecture with GenAI Integration
Five-layer architecture diagram showing OrchestRAN-style orchestration with GenAI components
"""

import matplotlib.pyplot as plt
import matplotlib.patches as patches
from matplotlib.patches import FancyBboxPatch, ConnectionPatch
import numpy as np

def create_genai_architecture_figure():
    # Create figure with high DPI for publication quality
    fig, ax = plt.subplots(1, 1, figsize=(17.5/2.54, 12/2.54), dpi=300)  # Convert cm to inches

    # Define colors for layers (AI gradient: teal to purple, then blues)
    colors = {
        'genai': '#20B2AA',           # Teal
        'intent': '#8A2BE2',          # Purple
        'krm': '#4682B4',             # Medium blue
        'o2ims': '#2F4F4F',           # Dark blue
        'infra': '#191970',           # Navy blue
        'arrows': '#FF6347',          # Orange for feedback
        'data_flow': '#32CD32',       # Green for GitOps
        'coordination': '#FFD700'     # Gold for OrchestRAN
    }

    # Layer dimensions and positions
    layer_height = 0.18
    layer_spacing = 0.02
    start_y = 0.9

    layers = [
        {'name': 'GenAI Intelligence Layer', 'color': colors['genai'], 'y': start_y},
        {'name': 'Intent Orchestration Layer', 'color': colors['intent'], 'y': start_y - (layer_height + layer_spacing)},
        {'name': 'Knowledge Representation & Management Layer', 'color': colors['krm'], 'y': start_y - 2*(layer_height + layer_spacing)},
        {'name': 'O2IMS v3.0 Integration Layer', 'color': colors['o2ims'], 'y': start_y - 3*(layer_height + layer_spacing)},
        {'name': 'Distributed Infrastructure Layer', 'color': colors['infra'], 'y': start_y - 4*(layer_height + layer_spacing)}
    ]

    # Draw layer backgrounds with gradients
    for i, layer in enumerate(layers):
        # Main layer rectangle
        rect = FancyBboxPatch((0.05, layer['y'] - layer_height), 0.9, layer_height,
                             boxstyle="round,pad=0.01",
                             facecolor=layer['color'], alpha=0.7,
                             edgecolor='black', linewidth=1)
        ax.add_patch(rect)

        # Layer title
        ax.text(0.5, layer['y'] - 0.02, layer['name'],
                ha='center', va='top', fontsize=10, fontweight='bold', color='white')

    # Add components for each layer
    component_data = [
        # GenAI Layer
        {
            'layer': 0, 'components': [
                ('LLM Core', 0.15, '🧠'),
                ('Intent Engine', 0.3, '🔍'),
                ('Knowledge Base', 0.45, '📊'),
                ('Reasoning Engine', 0.6, '⚡'),
                ('Context Memory', 0.8, '💾')
            ]
        },
        # Intent Orchestration Layer
        {
            'layer': 1, 'components': [
                ('Claude Code CLI v3.0', 0.15, '🤖'),
                ('TMF921 v3.0 Adapter', 0.3, '🛡️'),
                ('OrchestRAN Coordinator', 0.5, '🎼'),
                ('Intent Validation', 0.7, '✅'),
                ('Multi-modal Interface', 0.85, '🎤')
            ]
        },
        # KRM Layer
        {
            'layer': 2, 'components': [
                ('Nephio R4 Controller', 0.15, '☸️'),
                ('KRM Compiler v2.0', 0.3, '⚙️'),
                ('Porch PackageRevision', 0.5, '📦'),
                ('GitOps Orchestrator', 0.7, '🔄'),
                ('Policy Engine', 0.85, '🔒')
            ]
        },
        # O2IMS Layer
        {
            'layer': 3, 'components': [
                ('O2IMS v3.0 API Gateway', 0.15, '🌐'),
                ('Resource Pool Manager', 0.3, '🎯'),
                ('Infrastructure Inventory', 0.5, '📋'),
                ('Deployment Templates', 0.7, '📄'),
                ('SLO/SLA Monitor', 0.85, '📈')
            ]
        },
        # Infrastructure Layer
        {
            'layer': 4, 'components': [
                ('VM-1 OrchestRAN Controller', 0.15, '🖥️'),
                ('VM-2 Edge Site 1', 0.3, '📡'),
                ('VM-4 Edge Site 2', 0.5, '📡'),
                ('Edge3/Edge4 Sites', 0.7, '📱'),
                ('O2IMS v3.0 Agents', 0.85, '🤝')
            ]
        }
    ]

    # Draw components
    for layer_data in component_data:
        layer_idx = layer_data['layer']
        layer_y = layers[layer_idx]['y']

        for comp_name, x_pos, icon in layer_data['components']:
            # Component box
            comp_rect = FancyBboxPatch((x_pos-0.06, layer_y - layer_height + 0.02), 0.12, 0.08,
                                      boxstyle="round,pad=0.005",
                                      facecolor='white', alpha=0.9,
                                      edgecolor='black', linewidth=0.5)
            ax.add_patch(comp_rect)

            # Component icon
            ax.text(x_pos, layer_y - layer_height + 0.1, icon,
                   ha='center', va='center', fontsize=12)

            # Component label
            ax.text(x_pos, layer_y - layer_height + 0.04, comp_name,
                   ha='center', va='center', fontsize=6, wrap=True)

    # Add data flow arrows
    # Intent flow (thick teal arrows cascading down)
    for i in range(len(layers)-1):
        y_start = layers[i]['y'] - layer_height - 0.01
        y_end = layers[i+1]['y'] + 0.01
        arrow = patches.FancyArrowPatch((0.5, y_start), (0.5, y_end),
                                       arrowstyle='->', mutation_scale=20,
                                       color=colors['genai'], linewidth=3,
                                       alpha=0.8)
        ax.add_patch(arrow)

    # Feedback loops (orange arrows upward)
    for i in range(1, len(layers)):
        y_start = layers[i]['y'] - layer_height/2
        y_end = layers[i-1]['y'] - layer_height/2
        arrow = patches.FancyArrowPatch((0.85, y_start), (0.85, y_end),
                                       arrowstyle='->', mutation_scale=15,
                                       color=colors['arrows'], linewidth=2,
                                       alpha=0.7, linestyle='--')
        ax.add_patch(arrow)

    # GitOps sync (dotted green lines)
    arrow = patches.FancyArrowPatch((0.15, layers[2]['y'] - layer_height/2),
                                   (0.15, layers[4]['y'] - layer_height/2),
                                   arrowstyle='<->', mutation_scale=15,
                                   color=colors['data_flow'], linewidth=2,
                                   alpha=0.7, linestyle=':')
    ax.add_patch(arrow)

    # Add technology annotations
    annotations = [
        ('GenAI-Powered Intent Understanding', 0.95, 0.9),
        ('OrchestRAN v2.0 Architecture', 0.95, 0.7),
        ('Nephio R4 Native Integration', 0.95, 0.5),
        ('O2IMS v3.0 Compliant', 0.95, 0.3),
        ('ATIS MVP V2 Validated', 0.95, 0.1)
    ]

    for text, x, y in annotations:
        ax.text(x, y, text, ha='right', va='center', fontsize=8,
               bbox=dict(boxstyle="round,pad=0.3", facecolor='yellow', alpha=0.7))

    # Add legend for arrow types
    legend_elements = [
        plt.Line2D([0], [0], color=colors['genai'], linewidth=3, label='Intent Flow'),
        plt.Line2D([0], [0], color=colors['arrows'], linewidth=2, linestyle='--', label='Feedback Loops'),
        plt.Line2D([0], [0], color=colors['data_flow'], linewidth=2, linestyle=':', label='GitOps Sync'),
        plt.Line2D([0], [0], color=colors['coordination'], linewidth=2, label='OrchestRAN Coordination')
    ]

    ax.legend(handles=legend_elements, loc='upper left', bbox_to_anchor=(0.02, 0.98),
             fontsize=8, framealpha=0.9)

    # Set title and clean up
    ax.set_title('Enhanced System Architecture with GenAI Integration\n(Five-layer OrchestRAN Architecture)',
                fontsize=14, fontweight='bold', pad=20)

    ax.set_xlim(0, 1)
    ax.set_ylim(0, 1)
    ax.axis('off')

    plt.tight_layout()
    return fig

if __name__ == "__main__":
    # Generate the figure
    fig = create_genai_architecture_figure()

    # Save in multiple formats for different use cases
    fig.savefig('/home/ubuntu/nephio-intent-to-o2-demo/docs/figures/figure1_genai_architecture.png',
                dpi=300, bbox_inches='tight', facecolor='white')
    fig.savefig('/home/ubuntu/nephio-intent-to-o2-demo/docs/figures/figure1_genai_architecture.pdf',
                dpi=300, bbox_inches='tight', facecolor='white')
    fig.savefig('/home/ubuntu/nephio-intent-to-o2-demo/docs/figures/figure1_genai_architecture.svg',
                bbox_inches='tight', facecolor='white')

    print("Figure 1 (GenAI Architecture) generated successfully!")
    print("Files saved:")
    print("- figure1_genai_architecture.png (for viewing)")
    print("- figure1_genai_architecture.pdf (for LaTeX)")
    print("- figure1_genai_architecture.svg (for editing)")

    plt.show()