#!/bin/bash

echo "📦 Dynamic Filebeat Docker Setup for Log File Collection"

# Prompt for a unique directory name
read -p "Enter unique directory name (e.g., onelogin, apache, custom_logs): " DIR_NAME
if [[ -z "$DIR_NAME" ]]; then
    echo "❌ Directory name cannot be empty!"
    exit 1
fi

# Prompt for log file paths (comma-separated)
read -p "Enter full log file paths to monitor (comma-separated): " RAW_PATHS
IFS=',' read -ra PATH_ARRAY <<< "$RAW_PATHS"

# Prepare base directory
BASE_PATH="/opt/docker/${DIR_NAME}"
mkdir -p "${BASE_PATH}/registry"

# Generate YAML list for Filebeat `paths:` section
LOG_PATHS_PARSED=""
# Generate Docker volumes for each path
VOLUME_MOUNTS=""
for path in "${PATH_ARRAY[@]}"; do
  LOG_PATHS_PARSED+="      - \"${path}\"\n"
  VOLUME_MOUNTS+="      - ${path}:${path}:ro\n"
done

# Write docker-compose.yml
cat <<EOF > "${BASE_PATH}/docker-compose.yml"
version: '3.7'

services:
  ${DIR_NAME}:
    image: docker.elastic.co/beats/filebeat:6.8.7
    container_name: ${DIR_NAME}
    network_mode: host
    volumes:
$(echo -e "$VOLUME_MOUNTS")      
      - /opt/docker/${DIR_NAME}:/opt/docker/${DIR_NAME}
      - ${BASE_PATH}/${DIR_NAME}.yaml:/usr/share/filebeat/filebeat.yml
      - ${BASE_PATH}/registry:/usr/share/filebeat/data
    environment:
      - BEAT_PATH=/usr/share/filebeat
    user: root
    restart: always
EOF

# Write Filebeat config with corrected YAML
cat <<EOF > "${BASE_PATH}/${DIR_NAME}.yaml"
####################################################################################
##                   Filebeat Configuration - ${DIR_NAME}                         ##
####################################################################################

#======================= Inputs ============================
filebeat.inputs:
  - type: log
    enabled: true
    paths:
$(echo -e "$LOG_PATHS_PARSED")    
    close_inactive: 10s
    scan_frequency: 60s
    fields:
      log.type: "${DIR_NAME}"
    fields_under_root: true

#================== Global Options ==========================
filebeat.registry.path: /usr/share/filebeat/data

#========================= Modules ==========================
filebeat.config.modules:
  path: \${path.config}/modules.d/*.yml
  reload.enabled: true
  reload.period: 60s

#========================= Logstash Output ==================
#output.logstash:
#  hosts: ["127.0.0.1:12154"]
#  loadbalance: true
#  worker: 5
#  bulk_max_size: 8192

output.file:
  enabled: true
  path: "/opt/docker/${DIR_NAME}/var/log"
  filename: "${DIR_NAME}.log"
  rotate_every_kb: 10000
  number_of_files: 7

#============================= Logging =======================
logging.level: info
logging.to_files: true
logging.metrics.enabled: true
logging.metrics.period: 60s
logging.files:
  path: /var/log/filebeat/
  name: ${DIR_NAME}
  keepfiles: 7

#============================= Queue Settings ================
queue.mem:
  events: 4096
  flush.min_events: 512
  flush.timeout: 1s
EOF

# Secure the config
chmod 600 "${BASE_PATH}/${DIR_NAME}.yaml"

echo ""
echo "✅ Filebeat config for '${DIR_NAME}' is ready!"
echo "📁 Path: ${BASE_PATH}"
echo "🚀 Run it with:"
echo "   sudo docker-compose -f ${BASE_PATH}/docker-compose.yml up -d"
