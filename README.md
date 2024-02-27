# QWC Helm chart

Repo: <https://artifacthub.io/packages/helm/>

## TODO

* qwc2 assets/dist mount points demo vs client
* admin ui
* auth

## Dev side

### Kubenetes

#### Installation

As `root`:

```bash
snap install microk8s --classic
ufw allow in on cni0 && sudo ufw allow out on cni0
ufw default allow routed
microk8s enable dns dashboard hostpath-storage ingress registry
sudo usermod -a -G microk8s MY_USER
```

#### Check

```bash
microk8s kubectl get all --all-namespaces
```

#### Access to Dashboard

* retrieve dashboard token: `token=$(microk8s kubectl -n kube-system get secret | grep default-token | cut -d " " -f1)`
* display dashboard token (to be used in HTML UI): `microk8s kubectl -n kube-system describe secret $token`
* retrieve dashboard IP: `microk8s kubectl get all --all-namespaces | grep 'service/kubernetes-dashboard'`
* connect to dashboard via <https://IP> with obtained token

### Helm

#### Installation

* As `root`:

  ```bash
  apt install helm
  ```

* Adjust `values.yaml`
* copy `config-in.sample` volume: `cp -a volumes/config-in.sample volumes/config-in`

#### Run

```bash
helm upgrade --debug --kubeconfig ~/.kube/config -f values.yaml -f secret-values.yaml --install qwc-test . | less -i
```

To set values onthefly: `--set  qwcDb.volumes[0].hostPath.path=$(pwd)/volumes/db-init/setup-qwc.sh`

### Test

* Qgis Server : <http://QGIS_SERVER_HOST/ows/qwc_demo?service=WMS&request=GetCapabilities>

### Gateway API

<https://docs.nginx.com/nginx-gateway-fabric/installation/installing-ngf/helm/>

Install Gateway API resources:

```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/standard-install.yaml
```

Install NGINX Gateway Fabric

```bash
helm install ngf oci://ghcr.io/nginxinc/charts/nginx-gateway-fabric --create-namespace -n nginx-gateway --set service.type=NodePort
```

Wait for the deployment to be ready

```bash
kubectl wait --timeout=5m -n nginx-gateway deployment/ngf-nginx-gateway-fabric --for=condition=Available
```

<https://artifacthub.io/packages/helm/nginx-gateway-fabric/nginx-gateway-fabric>
