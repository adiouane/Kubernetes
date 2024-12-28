k3d cluster create iot-mel-hada -p 8080:80@loadbalancer -p 8443:443@loadbalancer -p 8888:8888@loadbalancer
kubectl create namespace argocd
kubectl create namespace dev
k3d kubeconfig get iot-mel-hada > ~/.kube/config
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
kubectl -n argocd rollout status deployment argocd-server
echo "This is the password for the admin account:=====> $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)"
kubectl apply -f ../Confs/argocd.yaml -n argocd