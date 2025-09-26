#!/usr/bin/env python3
"""Intent to KRM Translator"""

import json
import yaml
import sys

def compile_intent(intent_json):
    intent = json.loads(intent_json)
    manifests = []
    
    # Create deployment
    deployment = {
        'apiVersion': 'apps/v1',
        'kind': 'Deployment',
        'metadata': {'name': intent.get('service', 'app')},
        'spec': {
            'replicas': intent.get('replicas', 1),
            'selector': {'matchLabels': {'app': intent.get('service', 'app')}},
            'template': {
                'metadata': {'labels': {'app': intent.get('service', 'app')}},
                'spec': {
                    'containers': [{
                        'name': intent.get('service', 'app'),
                        'image': 'nginx:alpine',
                        'ports': [{'containerPort': 80}]
                    }]
                }
            }
        }
    }
    manifests.append(deployment)
    
    return manifests

if __name__ == '__main__':
    if len(sys.argv) < 2 or sys.argv[1] == '-':
        intent_json = sys.stdin.read()
    else:
        intent_json = open(sys.argv[1]).read()
    for manifest in compile_intent(intent_json):
        print("---")
        yaml.dump(manifest, sys.stdout)
