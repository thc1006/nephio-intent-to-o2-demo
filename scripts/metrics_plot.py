#!/usr/bin/env python3
"""
Metrics Plotting Utility for Nightly Regression Reports
Generates comprehensive KPI visualizations and HTML reports
"""

import json
import argparse
import sys
import os
from datetime import datetime, timedelta
from pathlib import Path
import logging

# Import visualization libraries
try:
    import matplotlib
    matplotlib.use('Agg')  # Use non-interactive backend
    import matplotlib.pyplot as plt
    import matplotlib.patches as mpatches
    import matplotlib.dates as mdates
    import pandas as pd
    import seaborn as sns
    import numpy as np
except ImportError as e:
    print(f"Error: Required packages not installed. Run: pip install matplotlib pandas seaborn numpy")
    print(f"Missing: {e}")
    sys.exit(1)

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class MetricsPlotter:
    """Main class for generating KPI plots and reports"""

    def __init__(self, input_file, output_dir, title="Nightly Regression Report"):
        self.input_file = Path(input_file)
        self.output_dir = Path(output_dir)
        self.title = title

        # Create output directory
        self.output_dir.mkdir(parents=True, exist_ok=True)

        # Set style
        try:
            plt.style.use('seaborn')
        except:
            plt.style.use('default')

        sns.set_palette("husl")

    def load_data(self):
        """Load and validate metrics data"""
        try:
            with open(self.input_file, 'r') as f:
                data = json.load(f)

            if 'metrics' not in data:
                raise ValueError("No 'metrics' key found in data")

            self.data = data
            self.metrics = data['metrics']
            logger.info(f"Loaded {len(self.metrics)} metric records")

            return True

        except Exception as e:
            logger.error(f"Failed to load data: {e}")
            return False

    def create_performance_dashboard(self):
        """Create main performance dashboard with multiple charts"""
        logger.info("Generating performance dashboard...")

        # Create figure with subplots
        fig, axes = plt.subplots(3, 3, figsize=(18, 14))
        fig.suptitle(f'{self.title} - Performance Dashboard', fontsize=16, fontweight='bold')

        # Convert metrics to DataFrame for easier analysis
        df = pd.DataFrame(self.metrics)

        # Chart 1: Pipeline Success Rate by Site
        ax = axes[0, 0]
        if not df.empty:
            success_by_site = df.groupby('site')['metrics'].apply(
                lambda x: sum(m['pipeline_success'] for m in x) / len(x) * 100
            )
            bars = ax.bar(success_by_site.index, success_by_site.values,
                         color=['green' if x >= 95 else 'orange' if x >= 90 else 'red' for x in success_by_site.values],
                         alpha=0.7, edgecolor='black')
            ax.set_title('Pipeline Success Rate by Site')
            ax.set_ylabel('Success Rate (%)')
            ax.set_ylim(0, 105)
            ax.axhline(y=95, color='green', linestyle='--', alpha=0.5, label='Target: 95%')

            # Add value labels
            for bar, value in zip(bars, success_by_site.values):
                ax.text(bar.get_x() + bar.get_width()/2., bar.get_height() + 1,
                       f'{value:.1f}%', ha='center', va='bottom', fontweight='bold')
        ax.legend()
        ax.grid(True, alpha=0.3)

        # Chart 2: Duration Trends by Service Type
        ax = axes[0, 1]
        if not df.empty:
            for service_type in df['service_type'].unique():
                service_data = df[df['service_type'] == service_type]
                durations = [m['total_duration_ms'] for m in service_data['metrics']]
                ax.plot(range(len(durations)), durations, marker='o',
                       label=service_type.replace('-', '\n'), alpha=0.7, linewidth=2)

        ax.set_title('Pipeline Duration by Service Type')
        ax.set_xlabel('Test Run')
        ax.set_ylabel('Duration (ms)')
        ax.legend(bbox_to_anchor=(1.05, 1), loc='upper left')
        ax.grid(True, alpha=0.3)

        # Chart 3: Sync Latency Distribution
        ax = axes[0, 2]
        if not df.empty:
            all_sync_latencies = [m['sync_latency_ms'] for m in df['metrics']]
            ax.hist(all_sync_latencies, bins=15, alpha=0.7, color='skyblue', edgecolor='black')
            ax.axvline(np.mean(all_sync_latencies), color='red', linestyle='--',
                      label=f'Mean: {np.mean(all_sync_latencies):.1f}ms', linewidth=2)

        ax.set_title('GitOps Sync Latency Distribution')
        ax.set_xlabel('Latency (ms)')
        ax.set_ylabel('Frequency')
        ax.legend()
        ax.grid(True, alpha=0.3)

        # Chart 4: PR Ready Time Comparison
        ax = axes[1, 0]
        if not df.empty:
            pr_times_by_site = {}
            for site in df['site'].unique():
                site_data = df[df['site'] == site]
                pr_times_by_site[site] = [m['pr_ready_time_ms'] for m in site_data['metrics']]

            ax.boxplot(pr_times_by_site.values(), labels=pr_times_by_site.keys(),
                      patch_artist=True,
                      boxprops=dict(facecolor='lightgreen', alpha=0.7))

        ax.set_title('PR Ready Time by Site')
        ax.set_ylabel('Time (ms)')
        ax.grid(True, alpha=0.3)

        # Chart 5: Intent Processing Performance
        ax = axes[1, 1]
        if not df.empty:
            intent_times = [m['intent_generation_ms'] for m in df['metrics']]
            krm_times = [m['krm_translation_ms'] for m in df['metrics']]

            x = range(len(intent_times))
            width = 0.35

            ax.bar([i - width/2 for i in x], intent_times, width, label='Intent Gen', alpha=0.7)
            ax.bar([i + width/2 for i in x], krm_times, width, label='KRM Translation', alpha=0.7)

        ax.set_title('Intent Processing Components')
        ax.set_xlabel('Test Run')
        ax.set_ylabel('Time (ms)')
        ax.legend()
        ax.grid(True, alpha=0.3)

        # Chart 6: Success Rate Heatmap
        ax = axes[1, 2]
        if not df.empty:
            # Create success rate matrix
            sites = df['site'].unique()
            services = df['service_type'].unique()

            success_matrix = np.zeros((len(sites), len(services)))

            for i, site in enumerate(sites):
                for j, service in enumerate(services):
                    subset = df[(df['site'] == site) & (df['service_type'] == service)]
                    if not subset.empty:
                        success_rate = sum(m['pipeline_success'] for m in subset['metrics']) / len(subset)
                        success_matrix[i, j] = success_rate

            im = ax.imshow(success_matrix, cmap='RdYlGn', vmin=0, vmax=1, aspect='auto')
            ax.set_xticks(range(len(services)))
            ax.set_xticklabels([s.replace('-', '\n') for s in services], rotation=45, ha='right')
            ax.set_yticks(range(len(sites)))
            ax.set_yticklabels(sites)

            # Add text annotations
            for i in range(len(sites)):
                for j in range(len(services)):
                    text = ax.text(j, i, f'{success_matrix[i, j]:.1%}',
                                 ha="center", va="center", color="black", fontweight='bold')

            plt.colorbar(im, ax=ax, label='Success Rate')

        ax.set_title('Success Rate Heatmap\n(Site vs Service Type)')

        # Chart 7: Stage Completion Analysis
        ax = axes[2, 0]
        if not df.empty:
            stages_completed = [m['stages_completed'] for m in df['metrics']]
            stages_failed = [m['stages_failed'] for m in df['metrics']]

            x = range(len(stages_completed))
            ax.scatter(x, stages_completed, alpha=0.7, label='Completed', color='green', s=50)
            ax.scatter(x, stages_failed, alpha=0.7, label='Failed', color='red', s=50)

        ax.set_title('Pipeline Stage Analysis')
        ax.set_xlabel('Test Run')
        ax.set_ylabel('Number of Stages')
        ax.legend()
        ax.grid(True, alpha=0.3)

        # Chart 8: Performance Trends Over Time
        ax = axes[2, 1]
        if not df.empty:
            # Sort by timestamp for trend analysis
            df_sorted = df.sort_values('timestamp')
            timestamps = pd.to_datetime(df_sorted['timestamp'])
            avg_durations = [m['total_duration_ms'] for m in df_sorted['metrics']]

            ax.plot(timestamps.values, avg_durations, marker='o', color='purple', linewidth=2, alpha=0.7)

            # Add trend line
            z = np.polyfit(range(len(avg_durations)), avg_durations, 1)
            p = np.poly1d(z)
            ax.plot(timestamps.values, p(range(len(avg_durations))), "--", color='red', alpha=0.8,
                   label=f'Trend: {"↗" if z[0] > 0 else "↘"} {abs(z[0]):.1f}ms/run')

        ax.set_title('Performance Trend Analysis')
        ax.set_xlabel('Time')
        ax.set_ylabel('Duration (ms)')
        ax.legend()
        ax.grid(True, alpha=0.3)

        # Format x-axis for better time display
        ax.xaxis.set_major_formatter(mdates.DateFormatter('%H:%M'))
        ax.xaxis.set_major_locator(mdates.HourLocator(interval=1))
        plt.setp(ax.xaxis.get_majorticklabels(), rotation=45)

        # Chart 9: Overall Summary Stats
        ax = axes[2, 2]
        ax.axis('off')

        if not df.empty:
            # Calculate summary statistics
            total_runs = len(df)
            successful_runs = sum(m['pipeline_success'] for m in df['metrics'])
            avg_duration = np.mean([m['total_duration_ms'] for m in df['metrics']])
            avg_sync_latency = np.mean([m['sync_latency_ms'] for m in df['metrics']])
            avg_success_rate = np.mean([m['success_rate'] for m in df['metrics']])

            summary_text = f"""
NIGHTLY REGRESSION SUMMARY
{'='*30}

Total Test Runs: {total_runs}
Successful Runs: {successful_runs}
Overall Success Rate: {successful_runs/total_runs*100:.1f}%

Performance Metrics:
  Avg Duration: {avg_duration:.1f}ms
  Avg Sync Latency: {avg_sync_latency:.1f}ms
  Avg Stage Success: {avg_success_rate:.1%}

Sites Tested: {', '.join(df['site'].unique())}
Services Tested: {len(df['service_type'].unique())}

Status: {'✅ PASS' if successful_runs/total_runs >= 0.95 else '⚠️ DEGRADED' if successful_runs/total_runs >= 0.90 else '❌ FAIL'}

Generated: {datetime.now().strftime('%Y-%m-%d %H:%M UTC')}
            """

            ax.text(0.05, 0.5, summary_text, fontsize=10, family='monospace',
                   verticalalignment='center', transform=ax.transAxes,
                   bbox=dict(boxstyle='round,pad=0.5', facecolor='lightblue', alpha=0.8))

        plt.tight_layout()

        # Save the dashboard
        dashboard_path = self.output_dir / 'performance_dashboard.png'
        plt.savefig(dashboard_path, dpi=150, bbox_inches='tight', facecolor='white')
        logger.info(f"Dashboard saved to {dashboard_path}")

        plt.close()

        return dashboard_path

    def create_kpi_trends(self):
        """Create KPI trend charts"""
        logger.info("Generating KPI trend charts...")

        df = pd.DataFrame(self.metrics)

        if df.empty:
            logger.warning("No data available for KPI trends")
            return None

        fig, axes = plt.subplots(2, 2, figsize=(15, 10))
        fig.suptitle(f'{self.title} - KPI Trends', fontsize=16, fontweight='bold')

        # Sort by timestamp
        df_sorted = df.sort_values('timestamp')

        # Trend 1: Sync Latency Over Time
        ax = axes[0, 0]
        timestamps = pd.to_datetime(df_sorted['timestamp'])
        sync_latencies = [m['sync_latency_ms'] for m in df_sorted['metrics']]

        ax.plot(timestamps.values, sync_latencies, marker='o', color='blue', linewidth=2, markersize=6)
        ax.axhline(y=50, color='red', linestyle='--', alpha=0.7, label='SLA Limit: 50ms')
        ax.fill_between(timestamps.values, sync_latencies, alpha=0.3, color='blue')

        ax.set_title('GitOps Sync Latency Trend')
        ax.set_ylabel('Latency (ms)')
        ax.legend()
        ax.grid(True, alpha=0.3)

        # Trend 2: Success Rate Trend
        ax = axes[0, 1]
        success_rates = [m['success_rate'] * 100 for m in df_sorted['metrics']]

        ax.plot(timestamps.values, success_rates, marker='s', color='green', linewidth=2, markersize=6)
        ax.axhline(y=95, color='orange', linestyle='--', alpha=0.7, label='Target: 95%')
        ax.fill_between(timestamps.values, success_rates, alpha=0.3, color='green')

        ax.set_title('Pipeline Success Rate Trend')
        ax.set_ylabel('Success Rate (%)')
        ax.set_ylim(0, 105)
        ax.legend()
        ax.grid(True, alpha=0.3)

        # Trend 3: Duration by Service Type
        ax = axes[1, 0]
        for service_type in df['service_type'].unique():
            service_data = df_sorted[df_sorted['service_type'] == service_type]
            service_timestamps = pd.to_datetime(service_data['timestamp'])
            service_durations = [m['total_duration_ms'] for m in service_data['metrics']]

            ax.plot(service_timestamps.values, service_durations, marker='o',
                   label=service_type.replace('-', ' ').title(), linewidth=2, alpha=0.8)

        ax.set_title('Duration Trends by Service Type')
        ax.set_ylabel('Duration (ms)')
        ax.legend(bbox_to_anchor=(1.05, 1), loc='upper left')
        ax.grid(True, alpha=0.3)

        # Trend 4: PR Ready Time Distribution
        ax = axes[1, 1]
        pr_times = [m['pr_ready_time_ms'] for m in df_sorted['metrics']]

        # Create moving average
        window_size = min(5, len(pr_times))
        if window_size > 1:
            moving_avg = pd.Series(pr_times).rolling(window=window_size).mean()
            ax.plot(timestamps.values, pr_times, 'o-', alpha=0.6, label='Actual', color='purple')
            ax.plot(timestamps.values, moving_avg.values, '-', linewidth=3, label=f'{window_size}-run MA', color='red')
        else:
            ax.plot(timestamps.values, pr_times, 'o-', alpha=0.8, label='PR Ready Time', color='purple')

        ax.set_title('PR Ready Time Trend')
        ax.set_ylabel('Time (ms)')
        ax.legend()
        ax.grid(True, alpha=0.3)

        # Format all time axes
        for ax in axes.flat:
            ax.xaxis.set_major_formatter(mdates.DateFormatter('%H:%M'))
            ax.xaxis.set_major_locator(mdates.HourLocator(interval=2))
            plt.setp(ax.xaxis.get_majorticklabels(), rotation=45)

        plt.tight_layout()

        # Save KPI trends
        trends_path = self.output_dir / 'kpi_trends.png'
        plt.savefig(trends_path, dpi=150, bbox_inches='tight', facecolor='white')
        logger.info(f"KPI trends saved to {trends_path}")

        plt.close()

        return trends_path

    def generate_html_report(self, dashboard_path, trends_path):
        """Generate comprehensive HTML report"""
        logger.info("Generating HTML report...")

        df = pd.DataFrame(self.metrics)

        if df.empty:
            logger.warning("No data available for HTML report")
            return None

        # Calculate summary statistics
        total_runs = len(df)
        successful_runs = sum(m['pipeline_success'] for m in df['metrics'])
        overall_success_rate = successful_runs / total_runs * 100
        avg_duration = np.mean([m['total_duration_ms'] for m in df['metrics']])
        avg_sync_latency = np.mean([m['sync_latency_ms'] for m in df['metrics']])
        avg_pr_time = np.mean([m['pr_ready_time_ms'] for m in df['metrics']])

        # Determine overall status
        if overall_success_rate >= 95:
            status_class = "status-pass"
            status_text = "✅ ALL SYSTEMS OPERATIONAL"
        elif overall_success_rate >= 90:
            status_class = "status-warn"
            status_text = "⚠️ PERFORMANCE DEGRADED"
        else:
            status_class = "status-fail"
            status_text = "❌ SYSTEM FAILURE"

        # Get site and service breakdowns
        sites_tested = list(df['site'].unique())
        services_tested = list(df['service_type'].unique())

        html_content = f"""
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{self.title}</title>
    <style>
        * {{
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }}

        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }}

        .container {{
            max-width: 1400px;
            margin: 0 auto;
            background: white;
            border-radius: 15px;
            box-shadow: 0 25px 80px rgba(0,0,0,0.3);
            overflow: hidden;
        }}

        .header {{
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 40px;
            text-align: center;
        }}

        .header h1 {{
            font-size: 3em;
            margin-bottom: 10px;
            font-weight: 700;
        }}

        .header p {{
            font-size: 1.2em;
            opacity: 0.9;
        }}

        .status-banner {{
            background: #f8f9fa;
            padding: 20px 40px;
            text-align: center;
            border-bottom: 1px solid #dee2e6;
        }}

        .status-badge {{
            display: inline-block;
            padding: 12px 24px;
            border-radius: 25px;
            font-size: 1.1em;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 1px;
        }}

        .status-pass {{
            background: #d4edda;
            color: #155724;
            border: 2px solid #c3e6cb;
        }}

        .status-warn {{
            background: #fff3cd;
            color: #856404;
            border: 2px solid #ffeaa7;
        }}

        .status-fail {{
            background: #f8d7da;
            color: #721c24;
            border: 2px solid #f5c6cb;
        }}

        .metrics-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
            gap: 25px;
            padding: 40px;
            background: #f8f9fa;
        }}

        .metric-card {{
            background: white;
            border-radius: 12px;
            padding: 25px;
            box-shadow: 0 8px 25px rgba(0,0,0,0.1);
            border-left: 5px solid #667eea;
            transition: all 0.3s ease;
        }}

        .metric-card:hover {{
            transform: translateY(-5px);
            box-shadow: 0 15px 35px rgba(0,0,0,0.15);
        }}

        .metric-label {{
            color: #6c757d;
            font-size: 0.9em;
            text-transform: uppercase;
            letter-spacing: 1.2px;
            margin-bottom: 10px;
            font-weight: 600;
        }}

        .metric-value {{
            font-size: 2.5em;
            font-weight: bold;
            color: #212529;
            line-height: 1;
        }}

        .metric-unit {{
            color: #6c757d;
            font-size: 0.4em;
            margin-left: 5px;
            font-weight: normal;
        }}

        .metric-trend {{
            font-size: 0.8em;
            color: #6c757d;
            margin-top: 8px;
        }}

        .charts-section {{
            padding: 40px;
        }}

        .charts-section h2 {{
            text-align: center;
            margin-bottom: 30px;
            font-size: 2em;
            color: #333;
        }}

        .chart-container {{
            text-align: center;
            margin: 30px 0;
        }}

        .chart-container img {{
            max-width: 100%;
            border-radius: 10px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
        }}

        .summary-section {{
            background: linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%);
            padding: 40px;
        }}

        .summary-grid {{
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 30px;
        }}

        .summary-card {{
            background: white;
            padding: 25px;
            border-radius: 10px;
            box-shadow: 0 5px 15px rgba(0,0,0,0.1);
        }}

        .summary-card h3 {{
            color: #333;
            margin-bottom: 15px;
            font-size: 1.3em;
        }}

        .summary-list {{
            list-style: none;
            padding: 0;
        }}

        .summary-list li {{
            padding: 8px 0;
            border-bottom: 1px solid #eee;
            display: flex;
            justify-content: space-between;
        }}

        .summary-list li:last-child {{
            border-bottom: none;
        }}

        .footer {{
            background: #343a40;
            color: white;
            padding: 30px;
            text-align: center;
        }}

        .footer p {{
            margin: 5px 0;
            opacity: 0.8;
        }}

        .test-matrix {{
            margin: 20px 0;
        }}

        .matrix-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
            gap: 10px;
            margin-top: 15px;
        }}

        .matrix-item {{
            background: #e9ecef;
            padding: 10px;
            border-radius: 5px;
            text-align: center;
            font-size: 0.9em;
        }}

        @media (max-width: 768px) {{
            .header h1 {{
                font-size: 2em;
            }}

            .metrics-grid {{
                grid-template-columns: 1fr;
                padding: 20px;
            }}

            .summary-grid {{
                grid-template-columns: 1fr;
            }}
        }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 {self.title}</h1>
            <p>Automated Intent-to-O2IMS Pipeline Validation</p>
            <p>Generated on {datetime.now().strftime('%B %d, %Y at %H:%M UTC')}</p>
        </div>

        <div class="status-banner">
            <span class="status-badge {status_class}">{status_text}</span>
        </div>

        <div class="metrics-grid">
            <div class="metric-card">
                <div class="metric-label">Overall Success Rate</div>
                <div class="metric-value">
                    {overall_success_rate:.1f}
                    <span class="metric-unit">%</span>
                </div>
                <div class="metric-trend">{successful_runs}/{total_runs} runs successful</div>
            </div>

            <div class="metric-card">
                <div class="metric-label">Avg Pipeline Duration</div>
                <div class="metric-value">
                    {avg_duration:.0f}
                    <span class="metric-unit">ms</span>
                </div>
                <div class="metric-trend">End-to-end pipeline time</div>
            </div>

            <div class="metric-card">
                <div class="metric-label">Avg Sync Latency</div>
                <div class="metric-value">
                    {avg_sync_latency:.1f}
                    <span class="metric-unit">ms</span>
                </div>
                <div class="metric-trend">GitOps synchronization</div>
            </div>

            <div class="metric-card">
                <div class="metric-label">Avg PR Ready Time</div>
                <div class="metric-value">
                    {avg_pr_time:.0f}
                    <span class="metric-unit">ms</span>
                </div>
                <div class="metric-trend">ProvisioningRequest deployment</div>
            </div>
        </div>

        <div class="charts-section">
            <h2>📊 Performance Visualizations</h2>

            <div class="chart-container">
                <h3>Performance Dashboard</h3>
                <img src="{dashboard_path.name}" alt="Performance Dashboard">
            </div>

            <div class="chart-container">
                <h3>KPI Trends</h3>
                <img src="{trends_path.name}" alt="KPI Trends">
            </div>
        </div>

        <div class="summary-section">
            <div class="summary-grid">
                <div class="summary-card">
                    <h3>🎯 Test Coverage</h3>
                    <ul class="summary-list">
                        <li><span>Total Test Runs:</span> <strong>{total_runs}</strong></li>
                        <li><span>Sites Tested:</span> <strong>{len(sites_tested)}</strong></li>
                        <li><span>Service Types:</span> <strong>{len(services_tested)}</strong></li>
                        <li><span>Test Matrix:</span> <strong>{len(sites_tested) * len(services_tested)} combinations</strong></li>
                    </ul>

                    <div class="test-matrix">
                        <strong>Sites:</strong>
                        <div class="matrix-grid">
                            {' '.join(f'<div class="matrix-item">{site}</div>' for site in sites_tested)}
                        </div>

                        <strong>Services:</strong>
                        <div class="matrix-grid">
                            {' '.join(f'<div class="matrix-item">{service.replace("-", "-<br>")}</div>' for service in services_tested)}
                        </div>
                    </div>
                </div>

                <div class="summary-card">
                    <h3>📈 Performance Insights</h3>
                    <ul class="summary-list">
                        <li><span>Best Performing Site:</span> <strong>{max(set(df['site']), key=lambda x: sum(m['pipeline_success'] for m in df[df['site']==x]['metrics']))}</strong></li>
                        <li><span>Fastest Service Type:</span> <strong>{min(services_tested, key=lambda x: np.mean([m['total_duration_ms'] for m in df[df['service_type']==x]['metrics']])).replace('-', ' ').title()}</strong></li>
                        <li><span>Avg Stages Completed:</span> <strong>{np.mean([m['stages_completed'] for m in df['metrics']]):.1f}</strong></li>
                        <li><span>SLA Compliance:</span> <strong>{"✅ Met" if avg_sync_latency < 50 else "⚠️ At Risk"}</strong></li>
                    </ul>
                </div>
            </div>
        </div>

        <div class="footer">
            <p><strong>Report ID:</strong> {datetime.now().strftime('%Y%m%d_%H%M%S')}</p>
            <p><strong>Pipeline:</strong> Nephio Intent-to-O2IMS Demo</p>
            <p><strong>Generated by:</strong> GitHub Actions Nightly Workflow</p>
            <p><em>Next scheduled run: {(datetime.now() + timedelta(days=1)).strftime('%Y-%m-%d 02:00 UTC')}</em></p>
        </div>
    </div>
</body>
</html>
        """

        # Save HTML report
        html_path = self.output_dir / 'index.html'
        with open(html_path, 'w', encoding='utf-8') as f:
            f.write(html_content)

        logger.info(f"HTML report saved to {html_path}")

        return html_path

    def generate_json_summary(self):
        """Generate JSON summary for API consumption"""
        logger.info("Generating JSON summary...")

        df = pd.DataFrame(self.metrics)

        if df.empty:
            summary = {
                "error": "No data available",
                "timestamp": datetime.now().isoformat()
            }
        else:
            # Calculate comprehensive summary
            total_runs = len(df)
            successful_runs = sum(m['pipeline_success'] for m in df['metrics'])

            summary = {
                "timestamp": datetime.now().isoformat(),
                "report_title": self.title,
                "overview": {
                    "total_runs": total_runs,
                    "successful_runs": successful_runs,
                    "success_rate": successful_runs / total_runs if total_runs > 0 else 0,
                    "sites_tested": list(df['site'].unique()),
                    "services_tested": list(df['service_type'].unique())
                },
                "performance": {
                    "avg_duration_ms": float(np.mean([m['total_duration_ms'] for m in df['metrics']])),
                    "avg_sync_latency_ms": float(np.mean([m['sync_latency_ms'] for m in df['metrics']])),
                    "avg_pr_ready_time_ms": float(np.mean([m['pr_ready_time_ms'] for m in df['metrics']])),
                    "avg_intent_generation_ms": float(np.mean([m['intent_generation_ms'] for m in df['metrics']])),
                    "avg_krm_translation_ms": float(np.mean([m['krm_translation_ms'] for m in df['metrics']]))
                },
                "status": {
                    "overall": "PASS" if successful_runs / total_runs >= 0.95 else "WARN" if successful_runs / total_runs >= 0.90 else "FAIL",
                    "sla_compliance": bool(np.mean([m['sync_latency_ms'] for m in df['metrics']]) < 50)
                },
                "raw_data_count": total_runs
            }

        # Save JSON summary
        json_path = self.output_dir / 'summary.json'
        with open(json_path, 'w', encoding='utf-8') as f:
            json.dump(summary, f, indent=2)

        logger.info(f"JSON summary saved to {json_path}")

        return json_path

def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description='Generate KPI plots and reports for nightly regression')
    parser.add_argument('--input', '-i', required=True, help='Input JSON file with aggregated metrics')
    parser.add_argument('--output', '-o', required=True, help='Output directory for reports')
    parser.add_argument('--title', '-t', default='Nightly Regression Report', help='Report title')
    parser.add_argument('--verbose', '-v', action='store_true', help='Verbose logging')

    args = parser.parse_args()

    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)

    # Initialize plotter
    plotter = MetricsPlotter(args.input, args.output, args.title)

    # Load data
    if not plotter.load_data():
        logger.error("Failed to load data, exiting")
        sys.exit(1)

    try:
        # Generate visualizations
        dashboard_path = plotter.create_performance_dashboard()
        trends_path = plotter.create_kpi_trends()

        # Generate reports
        html_path = plotter.generate_html_report(dashboard_path, trends_path)
        json_path = plotter.generate_json_summary()

        logger.info("Report generation completed successfully!")
        logger.info(f"Output files:")
        logger.info(f"  - Dashboard: {dashboard_path}")
        logger.info(f"  - Trends: {trends_path}")
        logger.info(f"  - HTML Report: {html_path}")
        logger.info(f"  - JSON Summary: {json_path}")

    except Exception as e:
        logger.error(f"Report generation failed: {e}", exc_info=True)
        sys.exit(1)

if __name__ == '__main__':
    main()