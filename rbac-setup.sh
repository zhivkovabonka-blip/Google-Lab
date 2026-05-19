#!/bin/bash

# --- Task 1-4: Namespace & Security Enforcement ---
echo "Enforcing Pod Security Standards..."
kubectl label namespace default pod-security.kubernetes.io/enforce=restricted --overwrite

# --- Task 6: RBAC Setup (ClusterRole and RoleBinding) ---
echo "Setting up RBAC..."
kubectl create clusterrolebinding clusteradmin \
  --clusterrole=cluster-admin \
  --user="$(gcloud config list account --format 'value(core.account)')" \
  --dry-run=client -o yaml | kubectl apply -f -

cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
   name: pod-security-manager
rules:
- apiGroups: ['policy']
  resources: ['podsecuritypolicies']
  resourceNames: ['privileged', 'baseline', 'restricted']
  verbs: ['use']
- apiGroups: ['']
  resources: ['namespaces']
  verbs: ['get', 'list', 'watch', 'label']
EOF

cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
   name: pod-security-modifier
   namespace: default
subjects:
- kind: Group
  apiGroup: rbac.authorization.k8s.io
  name: system:authenticated
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: pod-security-manager
EOF

# --- Task 7: PodSecurityPolicy Objects ---
echo "Deploying PSP objects..."
cat <<EOF | kubectl apply -f -
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: privileged
spec:
  privileged: true
  seLinux: {rule: RunAsAny}
  supplementalGroups: {rule: RunAsAny}
  runAsUser: {rule: RunAsAny}
  fsGroup: {rule: RunAsAny}
  volumes: ['*']
---
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: restricted
spec:
  privileged: false
  allowPrivilegeEscalation: false
  requiredDropCapabilities: ['ALL']
  seLinux: {rule: RunAsAny}
  supplementalGroups: {rule: RunAsAny}
  runAsUser: {rule: MustRunAsNonRoot}
  fsGroup: {rule: RunAsAny}
  volumes: ['configMap', 'emptyDir', 'projected']
EOF

# --- Task 8: Security Demo Pods ---
echo "Deploying Test Pods..."
# Secure Pod
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: hostpath-secure
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 2000
    seccompProfile: {type: RuntimeDefault}
  containers:
  - name: hostpath
    image: google/cloud-sdk:latest
    command: ["/bin/bash"]
    args: ["-c", "tail -f /dev/null"]
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
EOF

echo "Setup Complete!"
