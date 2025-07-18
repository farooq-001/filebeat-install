#!/bin/bash

echo "💎 Dynamic Filebeat Docker Setup for Log File Collection"

# Prompt for a unique directory name
read -p "📦 Enter unique directory name (e.g., onelogin, apache, custom_logs): " DIR_NAME
if [[ -z "$DIR_NAME" ]]; then
    echo "❌ Directory name cannot be empty!"
    exit 1
fi

# Prompt for log file paths interactively
PATH_ARRAY=()

read -p "📁 Enter a log file path to monitor: " input_path
if [[ -z "$input_path" ]]; then
    echo "❌ Log file path cannot be empty!"
    exit 1
fi
PATH_ARRAY+=("$input_path")

while true; do
    read -p "📁 Do you want to add another log file path? (y/n): " yn
    case $yn in
        [Yy]* )
            read -p "📁 Enter another log file path: " extra_path
            if [[ -n "$extra_path" ]]; then
                PATH_ARRAY+=("$extra_path")
            else
                echo "⚠️ Empty path skipped."
            fi
            ;;
        [Nn]* )
            break
            ;;
        * )
            echo "Please answer y or n."
            ;;
    esac
done

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
    image: docker.elastic.co/beats/filebeat:7.17.29
    container_name: ${DIR_NAME}
    network_mode: host
    volumes:
$(echo -e "$VOLUME_MOUNTS")      
      - /opt/docker/${DIR_NAME}:/opt/docker/${DIR_NAME}
      - ${BASE_PATH}/${DIR_NAME}.yaml:/usr/share/filebeat/filebeat.yml
      - ${BASE_PATH}/registry:/usr/share/filebeat/data
      - /opt/docker/${DIR_NAME}/var/tmp:/opt/docker/${DIR_NAME}/var/tmp
    environment:
      - BEAT_PATH=/usr/share/filebeat
    user: root
    restart: always
EOF

# Write Filebeat config
cat <<EOF > "${BASE_PATH}/${DIR_NAME}.yaml"
################################################################################
#                        Filebeat Configuration - ${DIR_NAME}                  #
################################################################################

#=============================== 📁 Inputs =================================#
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

#=========================== 🌏 Global Options =============================#
filebeat.registry.path: /usr/share/filebeat/data

#============================= 🧩 Modules ==================================#
filebeat.config.modules:
  path: \${path.config}/modules.d/*.yml
  reload.enabled: true
  reload.period: 60s

#============================== 🎯 Output ==================================#
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

#============================= 🛠️ Logging =================================#
logging.level: info
logging.to_files: true
logging.metrics.enabled: true
logging.metrics.period: 60s
logging.files:
  path: /opt/docker/${DIR_NAME}/var/tmp
  name: ${DIR_NAME}
  keepfiles: 7

#============================= ⚙️ Queue Settings ===========================#
queue.mem:
  events: 6144
  flush.min_events: 1024
  flush.timeout: 5s


EOF

# Secure the config
chmod 600 "${BASE_PATH}/${DIR_NAME}.yaml"

echo ""
echo "✅ Filebeat config for '${DIR_NAME}' is ready!"
echo "📁 Path: ${BASE_PATH}"
echo "Check Yml Cofig"
echo ""
echo "🚀 Then Run it with:"
echo ""
echo "   sudo docker-compose -f ${BASE_PATH}/docker-compose.yml up -d"
