# Self Hosted Runners en GKE con ADC usando Workload Identity

Este repositorio esta basado en [GH-Runners by bharathkkb](https://github.com/bharathkkb/gh-runners). En este ejemplo se muestra como desplegar GitHub Actions Self Hosted Runners en GKE con Application Default Credentials usando Workload Identity.

## Paso a paso para desplegar este ejemplo

- Paso 1: Configurar la variables de entorno requeridas.

```sh
$ export PROJECT_ID=xxxxx
$ export CLUSTER_NAME=runner-cluster
$ export GITHUB_TOKEN=xxxxx
$ export REPO_OWNER=coordinadora-mercantil
$ export ACTION_URL=https://github.com/coordinadora-mercantil
$ export ACTION_TOKEN=xxxxx
```

**Nota:** Para la variable de ACTION_URL si eres organización la encontrarías en la pestañana Configuración > Actions > Agregar nuevo.
Si quieres mejor ejecutar un *runner* solo para un repositorio sería en Repositorio > Configuración > Actions > Agregar nuevo

- Paso 2: Habilitar las APIs de GCP requeridas.

```sh
$ gcloud config set project $PROJECT_ID
$ gcloud services enable container.googleapis.com \
    containerregistry.googleapis.com \
    cloudbuild.googleapis.com
```

- Paso 3: Contruir la imagen de Docker para Self Hosted Runner usando CloudBuild.

```sh
$ gcloud builds submit --tag gcr.io/${PROJECT_ID}/runner:XXX .
```
*Reemplazar XXX por la versión que desear utilizar*

*Ejemplo: 1.0.0*

- Paso 4: Crear un Cluster en GKE y generar el kubeconfig.

```sh
$ gcloud container clusters create ${CLUSTER_NAME} \
    --release-channel regular \
    --workload-pool=${PROJECT_ID}.svc.id.goog
$ gcloud container clusters get-credentials ${CLUSTER_NAME}
```

**Nota:** Para crear el cluster es necesario que tengas una region seleccionada o por lo contrario poner el flag --region en los pasos de creación y obtención del kubeconfig

- Paso 5: Crear la cuenta de servicios de Google que se usará como ADC dentros de los pods del runner.

```sh
$ gcloud iam service-accounts create runner-sa --display-name "runner-sa"
$ SA_EMAIL=$(gcloud iam service-accounts list --filter="displayName:runner-sa" --format='value(email)')
```

*Opcionalmente darle permisos de rol a la cuenta de servicios.*

```sh
$ gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member serviceAccount:$SA_EMAIL \
    --role roles/editor
```

- Paso 6: Enlazar la cuenta de servicios creada en el paso 5 con la cuenta de servicio de Kubernetes.

```sh
$ kubectl create serviceaccount gke-runner-sa
$ gcloud iam service-accounts add-iam-policy-binding \
    --role roles/iam.workloadIdentityUser \
    --member "serviceAccount:${PROJECT_ID}.svc.id.goog[default/gke-runner-sa]" \
    runner-sa@${PROJECT_ID}.iam.gserviceaccount.com
$ kubectl annotate serviceaccount \
    gke-runner-sa \
    iam.gke.io/gcp-service-account=runner-sa@${PROJECT_ID}.iam.gserviceaccount.com
```

- Paso 7: Guardar el token de Github en un secreto y configurar la imagen para el despliegue.

```sh
$ kubectl create secret generic runner-k8s-secret --from-literal=GITHUB_TOKEN=$GITHUB_TOKEN
$ kustomize edit set image gcr.io/PROJECT_ID/runner:latest=gcr.io/$PROJECT_ID/runner:XXX
```
*Reemplazar XXX por la versión que pusite en el paso 3*

- Paso 8: Crear el archivo de variables de entorno que usará Kustomize para generar un config map.

```sh
$ cat > runner.env << EOF
ACTION_URL=${ACTION_URL}
ACTION_TOKEN=${ACTION_TOKEN}
EOF
```

- Paso 9: Desplegar el Self Hosted Runner deployment **usando** Kustomize.

```sh
$ kustomize build . | kubectl apply -f -
```
