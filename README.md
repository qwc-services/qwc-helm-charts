# QWC Helm chart

Repo: <https://artifacthub.io/packages/helm/>

## TODO

* how the databases are created?
* how the users are created?

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
helm upgrade --debug --kubeconfig ~/.kube/config -f values.yaml -f secret-values.yaml --install qwc-test . --set  qwcDb.volumes[0].hostPath.path=$(pwd)/volumes/db-init/setup-qwc.sh | less -i
```
