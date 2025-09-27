#!/usr/bin/env python3
"""
Figure 4: 2025 Industry Timeline and Evolution
Timeline showing the evolution of network orchestration from 2020 to 2025 with key technology milestones
"""

import matplotlib.pyplot as plt
import matplotlib.patches as patches
from matplotlib.patches import FancyBboxPatch, Circle
import numpy as np

def create_industry_timeline_figure():
    # Create figure with publication quality DPI
    fig, ax = plt.subplots(1, 1, figsize=(17.5/2.54, 8/2.54), dpi=300)

    # Define timeline data
    years = [2020, 2021, 2022, 2023, 2024, 2025]
    year_labels = ['2020', '2021', '2022', '2023', '2024', '2025']

    # Define color progression from blue to green
    colors = {
        2020: '#4169E1',  # Royal Blue
        2021: '#1E90FF',  # Dodge Blue
        2022: '#00CED1',  # Dark Turquoise
        2023: '#20B2AA',  # Light Sea Green
        2024: '#32CD32',  # Lime Green
        2025: '#228B22'   # Forest Green
    }

    # Technology milestones for each year
    milestones = {
        2020: {
            'title': 'Traditional OSS/BSS',
            'description': 'Manual network management\nLegacy orchestration systems',
            'icon': '🔧',
            'adoption': 20
        },
        2021: {
            'title': 'O-RAN Alliance Formation',
            'description': 'Open RAN specifications\nVendor interoperability',
            'icon': '🌐',
            'adoption': 35
        },
        2022: {
            'title': 'Nephio Project Launch',
            'description': 'Kubernetes native orchestration\nCloud-native automation',
            'icon': '☸️',
            'adoption': 55
        },
        2023: {
            'title': 'TMF921 Intent Standards',
            'description': 'Intent-based management\nStandardized interfaces',
            'icon': '📋',
            'adoption': 70
        },
        2024: {
            'title': 'LLM Integration Emergence',
            'description': 'AI-powered orchestration\nNatural language interfaces',
            'icon': '🧠',
            'adoption': 85
        },
        2025: {
            'title': 'OrchestRAN Production',
            'description': 'Autonomous orchestration\nProduction AI deployment',
            'icon': '🚀',
            'adoption': 95
        }
    }

    # Draw main timeline
    timeline_y = 0.5
    ax.plot([0.1, 0.9], [timeline_y, timeline_y], 'k-', linewidth=3, alpha=0.8)

    # Calculate positions for years
    x_positions = np.linspace(0.15, 0.85, len(years))

    # Draw year markers and milestones
    for i, (year, x_pos) in enumerate(zip(years, x_positions)):
        milestone = milestones[year]

        # Year marker
        circle = Circle((x_pos, timeline_y), 0.02,
                       facecolor=colors[year], edgecolor='black', linewidth=2)
        ax.add_patch(circle)

        # Year label
        ax.text(x_pos, timeline_y - 0.08, str(year), ha='center', va='top',
               fontsize=10, fontweight='bold')

        # Milestone box (alternating above/below)
        box_y = timeline_y + 0.25 if i % 2 == 0 else timeline_y - 0.25
        box_height = 0.15

        # Milestone box
        milestone_box = FancyBboxPatch((x_pos - 0.08, box_y - box_height/2), 0.16, box_height,
                                      boxstyle="round,pad=0.01",
                                      facecolor=colors[year], alpha=0.8,
                                      edgecolor='black', linewidth=1)
        ax.add_patch(milestone_box)

        # Connection line from timeline to milestone
        connection_y = timeline_y + 0.02 if i % 2 == 0 else timeline_y - 0.02
        ax.plot([x_pos, x_pos], [connection_y, box_y - box_height/2 + 0.01 if i % 2 == 0 else box_y + box_height/2 - 0.01],
               'k-', linewidth=1, alpha=0.7)

        # Milestone icon
        icon_y = box_y + (0.05 if i % 2 == 0 else -0.05)
        ax.text(x_pos, icon_y, milestone['icon'], ha='center', va='center', fontsize=16)

        # Milestone title
        title_y = box_y + (0.02 if i % 2 == 0 else -0.02)
        ax.text(x_pos, title_y, milestone['title'], ha='center', va='center',
               fontsize=8, fontweight='bold', color='white', wrap=True)

        # Milestone description
        desc_y = box_y - (0.04 if i % 2 == 0 else 0.04)
        ax.text(x_pos, desc_y, milestone['description'], ha='center', va='center',
               fontsize=6, color='white', wrap=True)

    # Technology adoption curves
    curve_y_base = 0.15

    # Manual Processes (declining red line)
    manual_adoption = [80, 70, 55, 40, 25, 15]
    ax.plot(x_positions, [curve_y_base - 0.05 + val/1000 for val in manual_adoption],
           'r-', linewidth=3, alpha=0.8, label='Manual Processes')

    # Cloud-Native Orchestration (rising blue line)
    cloud_adoption = [10, 25, 45, 65, 80, 90]
    ax.plot(x_positions, [curve_y_base + val/1000 for val in cloud_adoption],
           'b-', linewidth=3, alpha=0.8, label='Cloud-Native Orchestration')

    # AI/ML Integration (exponential green curve)
    ai_adoption = [0, 5, 15, 35, 70, 95]
    ax.plot(x_positions, [curve_y_base + 0.05 + val/1000 for val in ai_adoption],
           'g-', linewidth=3, alpha=0.8, label='AI/ML Integration')

    # Standards Compliance (steady purple line)
    standards_adoption = [20, 30, 50, 70, 85, 95]
    ax.plot(x_positions, [curve_y_base + 0.1 + val/1000 for val in standards_adoption],
           'm-', linewidth=3, alpha=0.8, label='Standards Compliance')

    # Add version evolution indicators
    version_data = [
        ('O2IMS v1.0', 2022, 0.8),
        ('O2IMS v2.0', 2024, 0.8),
        ('O2IMS v3.0', 2025, 0.8),
        ('Nephio R1', 2023, 0.85),
        ('Nephio R3', 2024, 0.85),
        ('Nephio R4', 2025, 0.85),
        ('ATIS MVP V1', 2024, 0.9),
        ('ATIS MVP V2', 2025, 0.9)
    ]

    for version, year, y_pos in version_data:
        # Find x position for the year
        year_idx = years.index(year)
        x_pos = x_positions[year_idx]

        # Version indicator
        ax.text(x_pos, y_pos, version, ha='center', va='center', fontsize=7,
               bbox=dict(boxstyle="round,pad=0.2", facecolor='yellow', alpha=0.7),
               rotation=45)

    # Add key breakthrough indicators
    breakthroughs = [
        ('AI Integration Begins', 2024, 0.75, 'lightblue'),
        ('Production AI Deployment', 2025, 0.75, 'lightgreen')
    ]

    for breakthrough, year, y_pos, color in breakthroughs:
        year_idx = years.index(year)
        x_pos = x_positions[year_idx]

        ax.text(x_pos, y_pos, breakthrough, ha='center', va='center', fontsize=8,
               bbox=dict(boxstyle="round,pad=0.3", facecolor=color, alpha=0.8),
               fontweight='bold')

    # Add legend for adoption curves
    ax.legend(loc='upper left', bbox_to_anchor=(0.02, 0.35), fontsize=8, framealpha=0.9)

    # Add title and labels
    ax.set_title('2025 Industry Timeline: Network Orchestration Evolution',
                fontsize=14, fontweight='bold', pad=20)

    # Add annotations for major trends
    ax.text(0.5, 0.05, 'Key Evolution: Manual → Cloud-Native → AI-Powered → Autonomous',
           ha='center', va='center', fontsize=10, fontweight='bold',
           bbox=dict(boxstyle="round,pad=0.5", facecolor='lightgray', alpha=0.8))

    ax.set_xlim(0, 1)
    ax.set_ylim(0, 1)
    ax.axis('off')

    plt.tight_layout()
    return fig

if __name__ == "__main__":
    # Generate the figure
    fig = create_industry_timeline_figure()

    # Save in multiple formats
    fig.savefig('/home/ubuntu/nephio-intent-to-o2-demo/docs/figures/figure4_industry_timeline.png',
                dpi=300, bbox_inches='tight', facecolor='white')
    fig.savefig('/home/ubuntu/nephio-intent-to-o2-demo/docs/figures/figure4_industry_timeline.pdf',
                dpi=300, bbox_inches='tight', facecolor='white')
    fig.savefig('/home/ubuntu/nephio-intent-to-o2-demo/docs/figures/figure4_industry_timeline.svg',
                bbox_inches='tight', facecolor='white')

    print("Figure 4 (Industry Timeline) generated successfully!")
    print("Files saved:")
    print("- figure4_industry_timeline.png (for viewing)")
    print("- figure4_industry_timeline.pdf (for LaTeX)")
    print("- figure4_industry_timeline.svg (for editing)")

    plt.show()