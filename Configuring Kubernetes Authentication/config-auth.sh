master_ip=$(aws ec2 describe-instances --region us-west-2 \
 --filters "Name=tag:Name,Values=k8s-master" \
 --query "Reservations[*].Instances[*].PrivateIpAddress" \
 --output text)  # get the master's IP address using the AWS CLI
ssh $master_ip

echo "source <(kubectl completion bash)" >> ~/.bashrc
source ~/.bashrc

mkdir certs  # create certificate directory
openssl genrsa -out certs/andy.key 2048  # generate private key
chmod 400 certs/andy.key  # make the key read-only by file owner

openssl req -new -key certs/andy.key -out certs/andy.csr -subj "/CN=andy/O=network-admin"

cat > certs/andy-csr.k8s <<EOF
apiVersion: certificates.k8s.io/v1beta1
kind: CertificateSigningRequest
metadata:
  name: new-user-request
spec:
  request: $(cat certs/andy.csr | base64 | tr -d '\n')
  usages:
  - digital signature
  - key encipherment
  - client auth
EOF

kubectl create -f certs/andy-csr.k8s

kubectl get csr

kubectl certificate approve new-user-request

kubectl get csr

kubectl get csr new-user-request -o jsonpath='{.status.certificate}' \
  | base64 --decode > certs/andy.crt
  
openssl x509 -noout -text -in certs/andy.crt

rm certs/andy.csr certs/andy-csr.k8s

kubectl config set-credentials andy \
  --client-certificate=certs/andy.crt \
  --client-key=certs/andy.key \
  --embed-certs
  
kubectl config set-context network-admin --cluster=kubernetes --user=andy

kubectl config use-context network-admin

kubectl get networkpolicy

kubectl config use-context kubernetes-admin@kubernetes

kubectl get rolebinding --all-namespaces

kubectl get clusterrolebinding

kubectl get clusterrolebinding cluster-admin -o yaml

kubectl describe clusterrole cluster-admin

kubectl describe clusterrole admin

kubectl get clusterrole cluster-admin -o yaml

api_endpoint=$(kubectl get endpoints kubernetes | tail -1 | awk '{print "https://" $2}')
sudo curl \
  --cacert /etc/kubernetes/pki/ca.crt \
  --cert /etc/kubernetes/pki/apiserver-kubelet-client.crt \
  --key /etc/kubernetes/pki/apiserver-kubelet-client.key \
  $api_endpoint
  
sudo curl \
  --cacert /etc/kubernetes/pki/ca.crt \
  --cert /etc/kubernetes/pki/apiserver-kubelet-client.crt \
  --key /etc/kubernetes/pki/apiserver-kubelet-client.key \
  $api_endpoint/apis/authorization.k8s.io
  
sudo curl \
  --cacert /etc/kubernetes/pki/ca.crt \
  --cert /etc/kubernetes/pki/apiserver-kubelet-client.crt \
  --key /etc/kubernetes/pki/apiserver-kubelet-client.key \
  $api_endpoint/api/v1 \
  | more
  
 sudo curl \
  --cacert /etc/kubernetes/pki/ca.crt \
  --cert /etc/kubernetes/pki/apiserver-kubelet-client.crt \
  --key /etc/kubernetes/pki/apiserver-kubelet-client.key \
  $api_endpoint/swaggerapi/api/v1 > swagger.txt
  
cat > network-admin-role.yaml <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: network-admin
rules:
- apiGroups:
  - networking.k8s.io
  resources:
  - networkpolicies
  verbs:
  - '*'
- apiGroups:
  - extensions
  resources:
  - networkpolicies
  verbs:
  - '*'
EOF

kubectl create -f network-admin-role.yaml

kubectl create clusterrolebinding network-admin --clusterrole=network-admin --group=network-admin

kubectl config use-context network-admin
kubectl get networkpolicy

kubectl config use-context kubernetes-admin@kubernetes

kubectl get networkpolicy deny-metadata -o yaml

kubectl explain networkpolicy.spec.egress

kubectl explain networkpolicy.spec.egress.to

kubectl explain networkpolicy.spec.egress.to.ipBlock

kubectl run busybox --image=busybox --rm -it /bin/sh

wget https://google.com

wget 169.254.169.254

# ctrl + c 
exit

kubectl create namespace test
kubectl run busybox --image=busybox --rm -it -n test /bin/sh
wget 169.254.169.254

role=$(wget -qO- 169.254.169.254/latest/meta-data/iam/security-credentials)
wget -qO- 169.254.169.254/latest/meta-data/iam/security-credentials/$role

exit

cat > app-policy.yaml <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: app-tiers
  namespace: test
spec:
  podSelector:
    matchLabels:
      app-tier: web
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app-tier: cache
    ports:
    - port: 80
EOF

kubectl create -f app-policy.yaml

kubectl run web-server -n test -l app-tier=web --image=nginx:1.15.1 --port 80

# Get the web server pod's IP address
web_ip=$(kubectl get pod -n test -o jsonpath='{.items[0].status.podIP}')
# Pass in the web server IP addpress as an environment variable
kubectl run busybox -n test -l app-tier=cache --image=busybox --env="web_ip=$web_ip" --rm -it /bin/sh
# Send a requst to the web server on port 80
wget $web_ip
exit

kubectl run busybox -n test --image=busybox --env="web_ip=$web_ip" --rm -it /bin/sh
wget $web_ip

# ctrl + c
exit
kubectl delete pods -n test web-server

kubectl explain pod.spec.securityContext

cat > pod.yaml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: security-context-test-1
  namespace: test
spec:
  containers:
  - image: busybox
    name: busybox
    args:
    - sleep
    - "3600"
EOF

kubectl create -f pod.yaml
kubectl exec -n test security-context-test-1 -it -- ls /dev

kubectl delete -f pod.yaml

cat > pod.yaml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: security-context-test-2
  namespace: test
spec:
  containers:
  - image: busybox
    name: busybox
    args:
    - sleep
    - "3600"
    securityContext:
      privileged: true
EOF

kubectl create -f pod.yaml

kubectl exec -n test security-context-test-2 -it -- /bin/sh
ls /dev

mkdir /hd
mount /dev/xvda1 /hd
cat /hd/etc/kubernetes/kubelet.conf
exit

kubectl delete -f pod.yaml

cat > pod.yaml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: security-context-test-3
  namespace: test
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
  containers:
  - image: busybox
    name: busybox
    args:
    - sleep
    - "3600"
    securityContext:
      runAsUser: 2000
      readOnlyRootFilesystem: true
EOF

kubectl create -f pod.yaml

kubectl exec -n test security-context-test-3 -it -- /bin/sh

ps

touch /tmp/test-file
exit

kubectl delete -f pod.yaml

cat > pod.yaml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test
  namespace: test
spec:
  containers:
  - image: ubuntu:16.04
    name: ubuntu
    args:
    - sleep
    - "3600"
EOF

kubectl create -f pod.yaml

kubectl get pod -n test test -o yaml --export

kubectl get secret --all-namespaces

kubectl exec -n test test -it -- bash
ls /var/run/secrets/kubernetes.io/serviceaccount/

apt-get update
apt-get install -y curl
cd /var/run/secrets/kubernetes.io/serviceaccount/
curl --cacert ca.crt \
     --header "Authorization: Bearer $(cat token)" \
     https://kubernetes.default.svc/api

curl --cacert ca.crt \
     --header "Authorization: Bearer $(cat token)" \
     https://kubernetes.default.svc/api/v1/namespaces/test/secrets

kubectl delete -f pod.yaml

kubectl create secret generic app-secret -n test \
  --from-literal="our-secret=almost finished"
  
kubectl get secret -n test app-secret -o yaml --export


kubectl get secret -n test app-secret -o jsonpath="{.data.our-secret}" \
  | base64 --decode \
  && echo
  
cat > pod.yaml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test
  namespace: test
spec:
  containers:
  - image: busybox
    name: busybox
    args:
    - sleep
    - "3600"
    env:
    - name: OUR_SECRET      # Name of environment variable
      valueFrom:
        secretKeyRef:
          name: app-secret  # Name of secret
          key: our-secret   # Name of secret key
EOF

kubectl create -f pod.yaml

kubectl exec -n test test -- /bin/sh -c 'echo $OUR_SECRET'

