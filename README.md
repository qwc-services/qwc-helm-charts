# QWC Helm chart

Repo: <https://artifacthub.io/packages/helm/>

## TODO

* qwc2 assets/dist mount points demo vs client

## Dev side

### Kubernetes with microk8s

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

See also <https://artifacthub.io/packages/helm/nginx-gateway-fabric/nginx-gateway-fabric>

### Chart installation

#### Helm

* As `root`:

  ```bash
  apt install helm
  ```

#### Setup

* copy `values.sample.yaml` to `values.yaml` and adjust it
  * adjust instance name: the prefix 'my-qwc-instance' is the name of the helm instance used when deploying the chart

  * adjust volumes:
    * In production mode:
      * volumes are created by administrator and won't be created by this chart ==> `createVolumes: false`
      * `volumePaths` should be empty
    * In dev mode:
      * volumes could be created by this chart with: `createVolumes: true`
      * `volumePaths` must be defined

  * adjust claims: claims are automatically generated but you can for each subchart define `claimOverrides` to define your own names, for example for qgis server:

    ```yaml
    qwcQgisServer:
      claimOverrides:
        projectResourceVolumeClaim: claim-01
    ```

* postgresql services are configured according to 2 files: `pg_service_rw.conf` (read write) and `pg_service_ro.conf` (read only). Samples are provided.
  One mandatory service is `qwc_configdb` in the `pg_service_ro.conf`. In this two files, the variables in `{{ }}` will be replaced by `global_secrets.yaml` with values found in the `global` parameter section (see `secret-values.sample.yaml`).

  To match the final user needs, one may creates its own files and concat them with mlxckv lkx mlkxc lklmlkxc  to produce the 2 needed files: `pg_service_rw.conf` and `pg_service_ro.conf`

* copy `config-in.sample` volume: `cp -a volumes/config-in.sample volumes/config-in`

### Deploy

```bash
helm upgrade --debug -f values.yaml -f secret-values.yaml --install my-qwc-instance . | less -i
```

To set values onthefly: `--set qwcDb.volumes[0].hostPath.path=$(pwd)/volumes/db-init/setup-qwc.sh`

### Test

* Qgis Server : <http://QGIS_SERVER_HOST/ows/qwc_demo?service=WMS&request=GetCapabilities>
