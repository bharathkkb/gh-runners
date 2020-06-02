# Self Hosted Runners on GKE with ADC using Workload Identity

## Overview

This example showcases how to deploy GitHub Actions Self Hosted Runners on GKE with Application Default Credentials using Workload Identity.

## Steps to deploy this example

- Step 1: Set the required environment variables.

```sh
$ export PROJECT_ID=foo
$ export CLUSTER_NAME=runner-cluster
$ export GITHUB_TOKEN=foo
$ export REPO_OWNER=foo
$ export REPO_NAME=foo
$ export REPO_URL=foo
```

- Step 2: Enable the required GCP APIs.

```sh
$ gcloud config set project $PROJECT_ID
$ gcloud services enable container.googleapis.com \
    containerregistry.googleapis.com \
    cloudbuild.googleapis.com
```

- Step 3: Build the Docker image for the Self Hosted Runner using CloudBuild.

```sh
$ gcloud builds submit --tag gcr.io/${PROJECT_ID}/runner:latest .
```

- Step 4: Create a GKE Cluster and generate kubeconfig.

```sh
$ gcloud beta container clusters create ${CLUSTER_NAME} \
    --release-channel regular \
    --workload-pool=${PROJECT_ID}.svc.id.goog
$ gcloud container clusters get-credentials ${CLUSTER_NAME}
```

- Step 5: Create the Google Service Account that will used as ADC within the runner pods.

```sh
$ gcloud iam service-accounts create runner-sa --display-name "runner-sa"
$ SA_EMAIL=$(gcloud iam service-accounts list --filter="displayName:runner-sa" --format='value(email)')
```

Optionally grant the Google Service Account a role.

```sh
$ gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member serviceAccount:$SA_EMAIL \
    --role roles/editor
```

- Step 6: Bind the Google Service Account created in step 5 to a Kubernetes Service Account.

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

- Step 7: Store the Github Token in a secret and set the image for the deployment.

```sh
$ kubectl create secret generic runner-k8s-secret --from-literal=GITHUB_TOKEN=$GITHUB_TOKEN
$ kustomize edit set image gcr.io/PROJECT_ID/runner:latest=gcr.io/$PROJECT_ID/runner:latest
```

- Step 8: Create the env file which is used by Kustomize to generate a config map.

```sh
$ cat > runner.env  << EOF
REPO_OWNER=${REPO_OWNER}
REPO_NAME=${REPO_NAME}
ACTIONS_RUNNER_INPUT_URL=${REPO_URL}
EOF
```

- Step 9: Deploy the Self Hosted Runner deployment using Kustomize.

```sh
$ kustomize build . | kubectl apply -f -
```
