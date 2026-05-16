#!/bin/bash
# Filename: traffic_generator.sh

echo "Starting heavy traffic generation... Press [CTRL+C] to stop."
# Infinite loop to flood the web server with requests
while true; do 
    curl -s http://<YOUR_WEB_SERVER_IP> > /dev/null
done
SQL
-- Filename: analyze_traffic.sql
-- standardSQL

SELECT
  jsonPayload.connection.src_ip,
  jsonPayload.connection.dest_ip,
  SUM(CAST(jsonPayload.bytes_sent AS INT64)) AS bytes,
  jsonPayload.connection.dest_port,
  jsonPayload.connection.protocol
FROM
  `YOUR_PROJECT_ID.vpc_flows_dataset.compute_googleapis_com_vpc_flows`
WHERE 
  jsonPayload.reporter = 'DEST'
GROUP BY
  jsonPayload.connection.src_ip,
  jsonPayload.connection.dest_ip,
  jsonPayload.connection.dest_port,
  jsonPayload.connection.protocol
ORDER BY
  bytes DESC
LIMIT 15;
