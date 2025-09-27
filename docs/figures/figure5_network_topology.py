#!/usr/bin/env python3
"""
Figure 5: Multi-Site Network Topology with Enhanced Connectivity
Network diagram showing expanded topology with edge3/edge4 sites and enhanced connectivity patterns
"""

import matplotlib.pyplot as plt
import matplotlib.patches as patches
from matplotlib.patches import FancyBboxPatch, Circle, FancyArrowPatch, ConnectionPatch
import numpy as np

def create_network_topology_figure():
    # Create figure with publication quality DPI
    fig, ax = plt.subplots(1, 1, figsize=(17.5/2.54, 12/2.54), dpi=300)

    # Define colors
    colors = {
        'vm1': '#4169E1',        # Royal Blue for central orchestrator
        'edge': '#32CD32',       # Lime Green for edge sites
        'compact': '#FF6347',    # Tomato for compact edge nodes
        'connection': '#FFD700', # Gold for connections
        'service': '#9370DB',    # Medium Purple for services
        'security': '#DC143C',   # Crimson for security
        'background': '#F0F8FF'  # Alice Blue for background
    }

    # Set dark background for network visualization
    ax.set_facecolor('#001122')

    # Define node positions (x, y coordinates)
    nodes = {
        'vm1': {'pos': (0.5, 0.7), 'type': 'orchestrator', 'ip': '172.16.0.78'},
        'vm2': {'pos': (0.2, 0.4), 'type': 'edge', 'ip': '172.16.4.45'},
        'vm4': {'pos': (0.8, 0.4), 'type': 'edge', 'ip': '172.16.4.176'},
        'edge3': {'pos': (0.2, 0.1), 'type': 'compact', 'ip': '172.16.5.81'},
        'edge4': {'pos': (0.8, 0.1), 'type': 'compact', 'ip': '172.16.1.252'}
    }

    # Draw connections first (so they appear behind nodes)
    connections = [
        ('vm1', 'vm2', 'primary', '10Gbps Fiber'),
        ('vm1', 'vm4', 'primary', '10Gbps Fiber'),
        ('vm1', 'edge3', 'backup', '1Gbps Backup'),
        ('vm1', 'edge4', 'backup', '1Gbps Backup'),
        ('vm2', 'edge3', 'mesh', '5G Mesh'),
        ('vm4', 'edge4', 'mesh', '5G Mesh'),
        ('vm2', 'vm4', 'cross', 'SD-WAN'),
        ('edge3', 'edge4', 'cross', 'Edge Mesh')
    ]

    for src, dst, conn_type, label in connections:
        src_pos = nodes[src]['pos']
        dst_pos = nodes[dst]['pos']

        # Choose connection style based on type
        if conn_type == 'primary':
            color = colors['connection']
            linewidth = 4
            linestyle = '-'
            alpha = 1.0
        elif conn_type == 'backup':
            color = '#FF6347'
            linewidth = 2
            linestyle = '--'
            alpha = 0.7
        elif conn_type == 'mesh':
            color = '#00CED1'
            linewidth = 2
            linestyle = ':'
            alpha = 0.8
        else:  # cross
            color = '#9370DB'
            linewidth = 1.5
            linestyle = '-.'
            alpha = 0.6

        # Draw connection line
        line = ConnectionPatch(src_pos, dst_pos, "data", "data",
                              arrowstyle="<->", shrinkA=15, shrinkB=15,
                              mutation_scale=20, fc=color, ec=color,
                              linewidth=linewidth, linestyle=linestyle, alpha=alpha)
        ax.add_patch(line)

        # Add connection label
        mid_x = (src_pos[0] + dst_pos[0]) / 2
        mid_y = (src_pos[1] + dst_pos[1]) / 2

        # Offset label slightly to avoid overlap
        if src_pos[0] != dst_pos[0]:  # Not vertical
            label_y = mid_y + 0.03
        else:  # Vertical line
            label_y = mid_y

        ax.text(mid_x, label_y, label, ha='center', va='center', fontsize=6,
               bbox=dict(boxstyle="round,pad=0.2", facecolor='white', alpha=0.8),
               color='black')

    # Draw nodes
    for node_id, node_data in nodes.items():
        x, y = node_data['pos']
        node_type = node_data['type']
        ip = node_data['ip']

        if node_type == 'orchestrator':
            # VM-1 Central Orchestrator
            # Main server box
            server_box = FancyBboxPatch((x-0.08, y-0.06), 0.16, 0.12,
                                       boxstyle="round,pad=0.01",
                                       facecolor=colors['vm1'], alpha=0.9,
                                       edgecolor='white', linewidth=2)
            ax.add_patch(server_box)

            # High-availability indicator
            ha_box = FancyBboxPatch((x-0.06, y+0.08), 0.12, 0.03,
                                   boxstyle="round,pad=0.005",
                                   facecolor='#FFD700', alpha=0.9,
                                   edgecolor='black', linewidth=1)
            ax.add_patch(ha_box)
            ax.text(x, y+0.095, 'HA Cluster', ha='center', va='center',
                   fontsize=6, fontweight='bold')

            # Server icon and specs
            ax.text(x, y+0.02, '🖥️', ha='center', va='center', fontsize=20)
            ax.text(x, y-0.02, 'VM-1', ha='center', va='center',
                   fontsize=10, fontweight='bold', color='white')
            ax.text(x, y-0.04, '8vCPU, 16GB RAM', ha='center', va='center',
                   fontsize=6, color='white')

            # IP address
            ax.text(x, y-0.08, ip, ha='center', va='center',
                   fontsize=8, color='yellow', fontweight='bold')

            # Service ports around the node
            services = [
                ('8002: Claude AI v3.0', x-0.15, y+0.04, '🧠'),
                ('8889: TMF921 v3.0', x+0.15, y+0.04, '🛡️'),
                ('8888: GitOps', x-0.15, y, '🔄'),
                ('6444: K3s API', x+0.15, y, '☸️'),
                ('9090: Prometheus', x-0.15, y-0.04, '📊'),
                ('3000: Grafana', x+0.15, y-0.04, '📈')
            ]

            for service, sx, sy, icon in services:
                ax.text(sx, sy, icon, ha='center', va='center', fontsize=8)
                ax.text(sx + (0.02 if sx > x else -0.02), sy, service.split(':')[0],
                       ha='left' if sx > x else 'right', va='center', fontsize=5, color='cyan')

        elif node_type == 'edge':
            # Edge Computing Nodes (VM-2, VM-4)
            # Main edge box with antenna
            edge_box = FancyBboxPatch((x-0.06, y-0.05), 0.12, 0.1,
                                     boxstyle="round,pad=0.01",
                                     facecolor=colors['edge'], alpha=0.9,
                                     edgecolor='white', linewidth=2)
            ax.add_patch(edge_box)

            # 5G antenna
            antenna_lines = [
                [(x-0.01, y+0.05), (x-0.01, y+0.08)],
                [(x+0.01, y+0.05), (x+0.01, y+0.08)],
                [(x, y+0.05), (x, y+0.08)]
            ]
            for line in antenna_lines:
                ax.plot([line[0][0], line[1][0]], [line[0][1], line[1][1]],
                       'white', linewidth=2)

            # Signal waves
            for i, radius in enumerate([0.02, 0.04, 0.06]):
                circle = Circle((x, y+0.08), radius, fill=False,
                               edgecolor='yellow', linewidth=1, alpha=0.7-i*0.2)
                ax.add_patch(circle)

            # Node icon and label
            ax.text(x, y+0.01, '📡', ha='center', va='center', fontsize=16)
            node_name = 'VM-2' if node_id == 'vm2' else 'VM-4'
            ax.text(x, y-0.02, node_name, ha='center', va='center',
                   fontsize=8, fontweight='bold', color='white')
            ax.text(x, y-0.035, '8vCPU, 16GB RAM', ha='center', va='center',
                   fontsize=5, color='white')

            # IP address
            ax.text(x, y-0.06, ip, ha='center', va='center',
                   fontsize=7, color='yellow', fontweight='bold')

            # Edge capabilities
            capabilities = ['O2IMS v3.0', 'Edge ML', 'Real-time Analytics']
            for i, cap in enumerate(capabilities):
                ax.text(x, y-0.08-i*0.015, f'• {cap}', ha='center', va='center',
                       fontsize=4, color='lightgreen')

        else:  # compact edge nodes
            # Compact Edge Nodes (Edge3, Edge4)
            compact_box = FancyBboxPatch((x-0.04, y-0.03), 0.08, 0.06,
                                        boxstyle="round,pad=0.005",
                                        facecolor=colors['compact'], alpha=0.9,
                                        edgecolor='white', linewidth=1.5)
            ax.add_patch(compact_box)

            # Compact antenna
            ax.plot([x, x], [y+0.03, y+0.05], 'white', linewidth=1.5)

            # Node icon and label
            ax.text(x, y, '📱', ha='center', va='center', fontsize=12)
            node_name = 'Edge3' if node_id == 'edge3' else 'Edge4'
            ax.text(x, y-0.015, node_name, ha='center', va='center',
                   fontsize=7, fontweight='bold', color='white')
            ax.text(x, y-0.025, '4vCPU, 8GB RAM', ha='center', va='center',
                   fontsize=4, color='white')

            # IP address
            ax.text(x, y-0.04, ip, ha='center', va='center',
                   fontsize=6, color='yellow', fontweight='bold')

            # Compact capabilities
            compact_caps = ['Federated Learning', 'Local AI Cache']
            for i, cap in enumerate(compact_caps):
                ax.text(x, y-0.055-i*0.01, f'• {cap}', ha='center', va='center',
                       fontsize=3.5, color='lightblue')

    # Add network services overlay
    overlay_services = [
        ('Service Mesh', 0.5, 0.9, '🕸️'),
        ('Zero-Trust Security', 0.1, 0.9, '🔒'),
        ('AI Model Sync', 0.9, 0.9, '🧠'),
        ('Real-time Telemetry', 0.5, 0.05, '📊'),
        ('Disaster Recovery', 0.1, 0.05, '🔄'),
        ('Load Balancing', 0.9, 0.05, '⚖️')
    ]

    for service, x, y, icon in overlay_services:
        ax.text(x, y, icon, ha='center', va='center', fontsize=12)
        ax.text(x, y-0.02, service, ha='center', va='center', fontsize=6,
               bbox=dict(boxstyle="round,pad=0.2", facecolor='purple', alpha=0.7),
               color='white', fontweight='bold')

    # Add legend for connection types
    legend_x = 0.02
    legend_y = 0.6
    legend_items = [
        ('Primary Fiber (10Gbps)', colors['connection'], '-', 4),
        ('Backup Connection (1Gbps)', '#FF6347', '--', 2),
        ('5G Mesh Network', '#00CED1', ':', 2),
        ('SD-WAN Overlay', '#9370DB', '-.', 1.5)
    ]

    ax.text(legend_x, legend_y+0.08, 'Network Connections:', fontweight='bold',
           fontsize=8, color='white')

    for i, (label, color, style, width) in enumerate(legend_items):
        y_pos = legend_y + 0.05 - i*0.025
        ax.plot([legend_x, legend_x+0.03], [y_pos, y_pos],
               color=color, linestyle=style, linewidth=width)
        ax.text(legend_x+0.04, y_pos, label, va='center', fontsize=6, color='white')

    # Add performance metrics box
    metrics_x = 0.02
    metrics_y = 0.35
    metrics_box = FancyBboxPatch((metrics_x-0.01, metrics_y-0.12), 0.25, 0.15,
                                boxstyle="round,pad=0.01",
                                facecolor='black', alpha=0.8,
                                edgecolor='white', linewidth=1)
    ax.add_patch(metrics_box)

    ax.text(metrics_x+0.115, metrics_y+0.05, 'Network Performance:',
           ha='center', va='center', fontsize=8, fontweight='bold', color='cyan')

    metrics = [
        'Avg Latency: 23ms',
        'Success Rate: 99.75%',
        'AI Optimization: 100%',
        'Resource Usage: 77.5%'
    ]

    for i, metric in enumerate(metrics):
        ax.text(metrics_x+0.01, metrics_y+0.02-i*0.025, f'• {metric}',
               fontsize=6, color='lightgreen')

    # Add title
    ax.set_title('Multi-Site Network Topology with Enhanced Connectivity\n(OrchestRAN Architecture with AI-Optimized Edge Computing)',
                fontsize=12, fontweight='bold', color='white', pad=20)

    ax.set_xlim(0, 1)
    ax.set_ylim(0, 1)
    ax.axis('off')

    plt.tight_layout()
    return fig

if __name__ == "__main__":
    # Generate the figure
    fig = create_network_topology_figure()

    # Save in multiple formats
    fig.savefig('/home/ubuntu/nephio-intent-to-o2-demo/docs/figures/figure5_network_topology.png',
                dpi=300, bbox_inches='tight', facecolor='#001122')
    fig.savefig('/home/ubuntu/nephio-intent-to-o2-demo/docs/figures/figure5_network_topology.pdf',
                dpi=300, bbox_inches='tight', facecolor='#001122')
    fig.savefig('/home/ubuntu/nephio-intent-to-o2-demo/docs/figures/figure5_network_topology.svg',
                bbox_inches='tight', facecolor='#001122')

    print("Figure 5 (Network Topology) generated successfully!")
    print("Files saved:")
    print("- figure5_network_topology.png (for viewing)")
    print("- figure5_network_topology.pdf (for LaTeX)")
    print("- figure5_network_topology.svg (for editing)")

    plt.show()