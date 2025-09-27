#!/usr/bin/env python3
"""
Figure 6: Enhanced Data Flow with AI Decision Points
Updated workflow showing AI-enhanced decision points and autonomous operations in the 8-step pipeline
"""

import matplotlib.pyplot as plt
import matplotlib.patches as patches
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch, Circle, Polygon
import numpy as np

def create_ai_workflow_figure():
    # Create figure with publication quality DPI
    fig, ax = plt.subplots(1, 1, figsize=(17.5/2.54, 14/2.54), dpi=300)

    # Define colors
    colors = {
        'standard': '#4682B4',      # Steel Blue for standard flow
        'ai_decision': '#8A2BE2',   # Blue Violet for AI decisions
        'success': '#32CD32',       # Lime Green for success path
        'recovery': '#FF6347',      # Tomato for recovery path
        'feedback': '#FFD700',      # Gold for feedback loops
        'multimodal': '#20B2AA',    # Light Sea Green for inputs
        'box_bg': '#F0F8FF'         # Alice Blue for boxes
    }

    # Define step positions and data
    steps = [
        {
            'id': 1, 'title': 'Multi-Modal Intent Input', 'pos': (0.2, 0.9),
            'description': 'Voice, text, API, visual diagrams',
            'example': '"Deploy eMBB slice <10ms latency"',
            'icon': '🎤', 'color': colors['multimodal']
        },
        {
            'id': 2, 'title': 'AI Intent Understanding', 'pos': (0.5, 0.9),
            'description': 'GenAI processing with context enrichment',
            'example': '85ms avg, 95th percentile: 150ms',
            'icon': '🧠', 'color': colors['ai_decision']
        },
        {
            'id': 3, 'title': 'Intelligent KRM Generation', 'pos': (0.8, 0.9),
            'description': 'AI-driven template selection & optimization',
            'example': 'Optimized K8s manifests with AI recommendations',
            'icon': '⚙️', 'color': colors['ai_decision']
        },
        {
            'id': 4, 'title': 'Enhanced GitOps with AI Review', 'pos': (0.8, 0.7),
            'description': 'Automated code review & security scanning',
            'example': 'AI-generated commit messages',
            'icon': '🔍', 'color': colors['ai_decision']
        },
        {
            'id': 5, 'title': 'Intelligent Multi-Site Orchestration', 'pos': (0.8, 0.5),
            'description': 'Site selection optimization & load distribution',
            'example': 'Parallel deployment coordination',
            'icon': '🎼', 'color': colors['ai_decision']
        },
        {
            'id': 6, 'title': 'AI-Enhanced SLO Validation', 'pos': (0.8, 0.3),
            'description': 'Real-time metrics analysis & anomaly detection',
            'example': 'Success: 98.7% / Warning: 1.1% / Failure: 0.2%',
            'icon': '📊', 'color': colors['ai_decision']
        },
        {
            'id': 7, 'title': 'Intelligent Quality Gates', 'pos': (0.5, 0.3),
            'description': 'ML-powered acceptance testing',
            'example': 'Performance benchmarking & UX validation',
            'icon': '🚪', 'color': colors['ai_decision']
        },
        {
            'id': '8A', 'title': 'Autonomous Success Management', 'pos': (0.2, 0.5),
            'description': 'Performance optimization & right-sizing',
            'example': 'Continuous monitoring & proactive maintenance',
            'icon': '✅', 'color': colors['success']
        },
        {
            'id': '8B', 'title': 'Intelligent Recovery', 'pos': (0.2, 0.1),
            'description': 'Root cause analysis & automated rollback',
            'example': 'Recovery time: 1.8min avg (improved from 3.2min)',
            'icon': '🔧', 'color': colors['recovery']
        }
    ]

    # Draw process steps
    for step in steps:
        x, y = step['pos']

        # Step box
        step_box = FancyBboxPatch((x-0.08, y-0.05), 0.16, 0.1,
                                 boxstyle="round,pad=0.01",
                                 facecolor=step['color'], alpha=0.8,
                                 edgecolor='black', linewidth=1.5)
        ax.add_patch(step_box)

        # Step number/ID
        id_circle = Circle((x-0.06, y+0.03), 0.015,
                          facecolor='white', edgecolor='black', linewidth=1)
        ax.add_patch(id_circle)
        ax.text(x-0.06, y+0.03, str(step['id']), ha='center', va='center',
               fontsize=8, fontweight='bold')

        # Step icon
        ax.text(x+0.04, y+0.02, step['icon'], ha='center', va='center', fontsize=14)

        # Step title
        ax.text(x, y, step['title'], ha='center', va='center',
               fontsize=7, fontweight='bold', color='white', wrap=True)

        # Step description
        ax.text(x, y-0.025, step['description'], ha='center', va='center',
               fontsize=5, color='white', wrap=True)

        # Performance example
        ax.text(x, y-0.07, step['example'], ha='center', va='center',
               fontsize=4, color='yellow', style='italic', wrap=True)

    # AI Decision Points (Purple diamonds)
    ai_decisions = [
        {'pos': (0.35, 0.85), 'label': 'Intent\nClarity?'},
        {'pos': (0.65, 0.8), 'label': 'Resource\nOptimal?'},
        {'pos': (0.85, 0.6), 'label': 'Deploy\nStrategy?'},
        {'pos': (0.65, 0.25), 'label': 'Quality\nPassed?'},
        {'pos': (0.35, 0.35), 'label': 'Recovery\nNeeded?'}
    ]

    for decision in ai_decisions:
        x, y = decision['pos']

        # Diamond shape for decision point
        diamond_points = np.array([[x, y+0.03], [x+0.025, y], [x, y-0.03], [x-0.025, y]])
        diamond = Polygon(diamond_points, facecolor=colors['ai_decision'],
                         edgecolor='white', linewidth=2, alpha=0.9)
        ax.add_patch(diamond)

        # Decision label
        ax.text(x, y, decision['label'], ha='center', va='center',
               fontsize=5, fontweight='bold', color='white')

    # Main flow arrows (blue gradient)
    main_flow = [
        ((0.28, 0.9), (0.42, 0.9)),    # 1 → 2
        ((0.58, 0.9), (0.72, 0.9)),    # 2 → 3
        ((0.8, 0.85), (0.8, 0.75)),    # 3 → 4
        ((0.8, 0.65), (0.8, 0.55)),    # 4 → 5
        ((0.8, 0.45), (0.8, 0.35)),    # 5 → 6
        ((0.72, 0.3), (0.58, 0.3)),    # 6 → 7
        ((0.42, 0.3), (0.28, 0.4)),    # 7 → 8A (success)
    ]

    for (start, end) in main_flow:
        arrow = FancyArrowPatch(start, end, arrowstyle='->', mutation_scale=20,
                               color=colors['standard'], linewidth=3, alpha=0.8)
        ax.add_patch(arrow)

    # Recovery path (red arrows)
    recovery_arrows = [
        ((0.42, 0.25), (0.28, 0.15)),   # 7 → 8B (failure)
        ((0.2, 0.45), (0.2, 0.2))       # 8A → 8B (if issues detected)
    ]

    for (start, end) in recovery_arrows:
        arrow = FancyArrowPatch(start, end, arrowstyle='->', mutation_scale=15,
                               color=colors['recovery'], linewidth=2, alpha=0.8,
                               linestyle='--')
        ax.add_patch(arrow)

    # Feedback loops (orange curved arrows)
    feedback_loops = [
        # From recovery back to understanding (learning)
        ((0.2, 0.2), (0.35, 0.4), (0.45, 0.8)),
        # From success back to optimization (continuous improvement)
        ((0.2, 0.6), (0.1, 0.7), (0.4, 0.85)),
        # From validation back to orchestration (real-time adjustment)
        ((0.75, 0.35), (0.9, 0.4), (0.85, 0.45))
    ]

    for loop in feedback_loops:
        if len(loop) == 3:  # Curved feedback
            start, mid, end = loop
            # Draw curved arrow using bezier-like path
            t = np.linspace(0, 1, 50)
            x_curve = (1-t)**2 * start[0] + 2*(1-t)*t * mid[0] + t**2 * end[0]
            y_curve = (1-t)**2 * start[1] + 2*(1-t)*t * mid[1] + t**2 * end[1]

            ax.plot(x_curve, y_curve, color=colors['feedback'], linewidth=2, alpha=0.7, linestyle=':')

            # Add arrow head at the end
            arrow_head = FancyArrowPatch((x_curve[-5], y_curve[-5]), (x_curve[-1], y_curve[-1]),
                                        arrowstyle='->', mutation_scale=12,
                                        color=colors['feedback'], alpha=0.7)
            ax.add_patch(arrow_head)

    # Add performance metrics boxes
    metrics_data = [
        {
            'title': 'AI Processing Performance',
            'pos': (0.05, 0.8),
            'metrics': [
                'Intent Understanding: 85ms ± 12ms',
                'Template Generation: 120ms ± 18ms',
                'Anomaly Detection: 50ms ± 8ms',
                'Auto-optimization: 200ms ± 25ms'
            ]
        },
        {
            'title': 'Quality Assurance Results',
            'pos': (0.05, 0.5),
            'metrics': [
                'Success Rate: 98.7%',
                'False Positive Rate: 1.1%',
                'Recovery Success: 99.7%',
                'Mean Recovery Time: 1.8min'
            ]
        },
        {
            'title': 'AI Enhancement Impact',
            'pos': (0.05, 0.2),
            'metrics': [
                'Deployment Speed: 126x faster',
                'Resource Efficiency: +67%',
                'Error Reduction: 67% fewer',
                'Human Intervention: Optional'
            ]
        }
    ]

    for metrics_box in metrics_data:
        x, y = metrics_box['pos']

        # Metrics box background
        box = FancyBboxPatch((x-0.02, y-0.08), 0.22, 0.12,
                            boxstyle="round,pad=0.01",
                            facecolor='white', alpha=0.9,
                            edgecolor='black', linewidth=1)
        ax.add_patch(box)

        # Metrics title
        ax.text(x+0.09, y+0.03, metrics_box['title'], ha='center', va='center',
               fontsize=7, fontweight='bold', color='navy')

        # Metrics list
        for i, metric in enumerate(metrics_box['metrics']):
            ax.text(x, y+0.01-i*0.02, f'• {metric}', ha='left', va='center',
                   fontsize=5, color='darkgreen')

    # Add legend for flow types
    legend_items = [
        ('Main Process Flow', colors['standard'], '-', 3),
        ('AI Decision Points', colors['ai_decision'], 'o', 8),
        ('Recovery Path', colors['recovery'], '--', 2),
        ('Feedback Loops', colors['feedback'], ':', 2)
    ]

    legend_x = 0.6
    legend_y = 0.15

    ax.text(legend_x, legend_y+0.08, 'Workflow Legend:', fontweight='bold',
           fontsize=8, color='black')

    for i, (label, color, style, width) in enumerate(legend_items):
        y_pos = legend_y + 0.05 - i*0.02
        if style == 'o':  # Decision point marker
            ax.scatter([legend_x+0.01], [y_pos], c=color, s=50, marker='D')
        else:
            ax.plot([legend_x, legend_x+0.03], [y_pos, y_pos],
                   color=color, linestyle=style, linewidth=width)
        ax.text(legend_x+0.04, y_pos, label, va='center', fontsize=6)

    # Add title
    ax.set_title('Enhanced AI-Driven Workflow with Autonomous Decision Points\n(8-Step OrchestRAN Pipeline with GenAI Integration)',
                fontsize=12, fontweight='bold', pad=20)

    # Add workflow statistics
    ax.text(0.5, 0.05, 'Overall Pipeline Performance: 98.7% success rate | 5-minute avg deployment | 1.8-minute recovery | 67% resource savings',
           ha='center', va='center', fontsize=8, fontweight='bold',
           bbox=dict(boxstyle="round,pad=0.5", facecolor='lightblue', alpha=0.8))

    ax.set_xlim(0, 1)
    ax.set_ylim(0, 1)
    ax.axis('off')

    plt.tight_layout()
    return fig

if __name__ == "__main__":
    # Generate the figure
    fig = create_ai_workflow_figure()

    # Save in multiple formats
    fig.savefig('/home/ubuntu/nephio-intent-to-o2-demo/docs/figures/figure6_ai_workflow.png',
                dpi=300, bbox_inches='tight', facecolor='white')
    fig.savefig('/home/ubuntu/nephio-intent-to-o2-demo/docs/figures/figure6_ai_workflow.pdf',
                dpi=300, bbox_inches='tight', facecolor='white')
    fig.savefig('/home/ubuntu/nephio-intent-to-o2-demo/docs/figures/figure6_ai_workflow.svg',
                bbox_inches='tight', facecolor='white')

    print("Figure 6 (AI Workflow) generated successfully!")
    print("Files saved:")
    print("- figure6_ai_workflow.png (for viewing)")
    print("- figure6_ai_workflow.pdf (for LaTeX)")
    print("- figure6_ai_workflow.svg (for editing)")

    plt.show()