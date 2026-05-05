Configuration Details
1. The Routing Strategy
The traffic is split between two backend services using a YAML-based URL Map configuration. This allows for testing a new "Green" version before a full release.

YAML
routeAction:
  weightedBackendServices:
    - backendService: regions/us-central1/backendServices/blue-service
      weight: 70
    - backendService: regions/us-central1/backendServices/green-service
      weight: 30
2. Networking Setup
Frontend IP: 10.10.30.5 (assigned to subnet-b)

Proxy-only Subnet: 10.10.40.0/24 (required for Regional Envoy-based load balancers)

Health Checks: Dedicated TCP health checks on port 80 to ensure zero-downtime.

🧪 Testing the Deployment
To verify the load balancer, a utility-vm was used to simulate internal traffic:

Bash
for i in {1..10}; do 
  echo -n "Request $i: "
  curl -s 10.10.30.5 | grep "Server Hostname" -A 1 | tail -n 1
done
💡 Lessons Learned
Subnet Isolation: Learned the importance of the proxy-only subnet for regional L7 load balancers in GCP.

Advanced Routing: Gained experience in using YAML to define complex path-based and weighted routing rules.

Troubleshooting: Debugged regional vs. global resource conflicts and strict CIDR range requirements for forwarding rules.
