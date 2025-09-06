"""
Job Query Adapter - Minimal Flask app for SLO metrics.

Provides /metrics endpoint with latency_p95_ms, success_rate, throughput_p95_mbps.
Implements configurable metrics for testing and JSON logging for machine parsing.
"""

import json
import logging
import os
from datetime import datetime
from dataclasses import dataclass
from typing import Dict, Any

from flask import Flask, jsonify


# Configure JSON logging for machine parsing
class JSONFormatter(logging.Formatter):
    """Custom formatter for JSON log output."""
    
    def format(self, record):
        log_data = {
            'timestamp': datetime.utcnow().isoformat() + 'Z',
            'level': record.levelname,
            'message': record.getMessage(),
            'module': record.module,
            'function': record.funcName
        }
        
        # Add extra fields if present
        if hasattr(record, 'metrics'):
            log_data['metrics'] = record.metrics
        if hasattr(record, 'duration_ms'):
            log_data['duration_ms'] = record.duration_ms
            
        return json.dumps(log_data)


# Configure logger
logger = logging.getLogger(__name__)
handler = logging.StreamHandler()
handler.setFormatter(JSONFormatter())
logger.addHandler(handler)
logger.setLevel(logging.INFO)


@dataclass
class MetricsConfig:
    """Configuration for metrics values."""
    latency_p95_ms: float = 10.0
    success_rate: float = 0.998
    throughput_p95_mbps: float = 250.0
    
    def __post_init__(self):
        """Validate metrics ranges."""
        if self.latency_p95_ms < 0:
            raise ValueError("Latency cannot be negative")
        if not 0 <= self.success_rate <= 1:
            raise ValueError("Success rate must be between 0 and 1")
        if self.throughput_p95_mbps < 0:
            raise ValueError("Throughput cannot be negative")


# Global configuration - can be patched for testing
current_metrics_config = MetricsConfig(
    latency_p95_ms=float(os.environ.get('ADAPTER_LATENCY_P95_MS', '10.0')),
    success_rate=float(os.environ.get('ADAPTER_SUCCESS_RATE', '0.998')),
    throughput_p95_mbps=float(os.environ.get('ADAPTER_THROUGHPUT_P95_MBPS', '250.0'))
)


def create_app() -> Flask:
    """Create and configure Flask application."""
    app = Flask(__name__)
    
    # Configuration from environment (following .env.example pattern)
    app.config.update(
        HOST=os.environ.get('ADAPTER_HOST', '0.0.0.0'),
        PORT=int(os.environ.get('ADAPTER_PORT', '8080')),
        DEBUG=os.environ.get('ADAPTER_DEBUG', 'false').lower() == 'true'
    )
    
    @app.route('/health')
    def health():
        """Health check endpoint."""
        return jsonify({'status': 'healthy'})
    
    @app.route('/metrics')
    def metrics():
        """
        Metrics endpoint providing SLO metrics.
        
        Returns:
            JSON with latency_p95_ms, success_rate, throughput_p95_mbps
        """
        start_time = datetime.utcnow()
        
        metrics_data = {
            'timestamp': start_time.isoformat() + 'Z',
            'latency_p95_ms': current_metrics_config.latency_p95_ms,
            'success_rate': current_metrics_config.success_rate,
            'throughput_p95_mbps': current_metrics_config.throughput_p95_mbps,
            'metadata': {
                'adapter_version': '1.0.0',
                'source': 'job-query-adapter'
            }
        }
        
        # Log metrics request in JSON format for machine parsing
        duration_ms = (datetime.utcnow() - start_time).total_seconds() * 1000
        logger.info('Metrics request served', extra={
            'metrics': metrics_data,
            'duration_ms': duration_ms,
            'endpoint': '/metrics'
        })
        
        return jsonify(metrics_data)
    
    @app.errorhandler(404)
    def not_found(error):
        """Handle 404 errors."""
        logger.warning('Endpoint not found', extra={
            'endpoint': error.description,
            'method': 'GET'
        })
        return jsonify({'error': 'Endpoint not found'}), 404
    
    @app.errorhandler(500)
    def internal_error(error):
        """Handle 500 errors."""
        logger.error('Internal server error', extra={
            'error': str(error),
            'endpoint': '/metrics'
        })
        return jsonify({'error': 'Internal server error'}), 500
    
    return app


def main():
    """Main entry point for running the adapter."""
    app = create_app()
    
    host = app.config.get('HOST', '0.0.0.0')
    port = app.config.get('PORT', 8080)
    debug = app.config.get('DEBUG', False)
    
    logger.info('Starting job-query-adapter', extra={
        'host': host,
        'port': port,
        'debug': debug,
        'config': {
            'latency_p95_ms': current_metrics_config.latency_p95_ms,
            'success_rate': current_metrics_config.success_rate,
            'throughput_p95_mbps': current_metrics_config.throughput_p95_mbps
        }
    })
    
    app.run(host=host, port=port, debug=debug)


if __name__ == '__main__':
    main()