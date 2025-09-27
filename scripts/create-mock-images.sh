#!/bin/bash

# Create mock images for o2ims-api and mmtc services
# These will be simple HTTP servers that return mock responses

echo "Creating mock images for demonstration..."

# Create Dockerfiles for mock services
mkdir -p /tmp/mock-images/o2ims-api
mkdir -p /tmp/mock-images/mmtc

# O2IMS API mock service
cat > /tmp/mock-images/o2ims-api/Dockerfile << 'EOF'
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/
EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]
EOF

cat > /tmp/mock-images/o2ims-api/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head><title>O2IMS API Mock</title></head>
<body>
<h1>O2IMS API Service</h1>
<p>Status: Running</p>
<p>Version: v1.0.0-mock</p>
<pre>
{
  "api_version": "1.0.0",
  "service": "o2ims-api",
  "status": "healthy",
  "endpoints": [
    "/api/v1/deploymentManagers",
    "/api/v1/resourceTypes",
    "/api/v1/resources"
  ]
}
</pre>
</body>
</html>
EOF

# MMTC mock service
cat > /tmp/mock-images/mmtc/Dockerfile << 'EOF'
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/
EXPOSE 8082
CMD ["nginx", "-g", "daemon off;"]
EOF

cat > /tmp/mock-images/mmtc/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head><title>MMTC Service Mock</title></head>
<body>
<h1>Massive Machine Type Communication Service</h1>
<p>Status: Running</p>
<p>Service Type: massive-machine-type</p>
<pre>
{
  "service": "mmtc",
  "status": "active",
  "connections": 10000,
  "throughput": "10Mbps",
  "latency": "1ms"
}
</pre>
</body>
</html>
EOF

echo "Mock image files created in /tmp/mock-images/"
echo "Next: Build and tag these images with docker"