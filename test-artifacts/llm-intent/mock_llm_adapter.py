#!/usr/bin/env python3
import json
from http.server import HTTPServer, BaseHTTPRequestHandler

class MockLLMHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path == '/api/v1/intent':
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            
            # Return mock intent response
            response = {
                "serviceIntent": {
                    "id": "mock-intent-001",
                    "name": "Mock 5G Slice Intent",
                    "category": "NetworkSlice",
                    "serviceCharacteristic": [
                        {"name": "maxBandwidth", "value": "500", "valueType": "Mbps"},
                        {"name": "latency", "value": "15", "valueType": "ms"}
                    ]
                }
            }
            
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(response).encode())
        else:
            self.send_response(404)
            self.end_headers()
    
    def log_message(self, format, *args):
        pass  # Suppress log messages

if __name__ == '__main__':
    server = HTTPServer(('localhost', 8081), MockLLMHandler)
    print(f"Mock LLM adapter running on port {8081}")
    server.serve_forever()
