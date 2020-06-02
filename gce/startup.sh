#!/bin/bash
# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# install jq
apt-get update
apt-get -y install jq

# access secret from secretsmanager
secrets=$(gcloud secrets versions access latest --secret="runner-secret")
# set secrets as env vars
# shellcheck disable=SC2206
secretsConfig=($secrets)
for var in "${secretsConfig[@]}"; do
export "${var?}"
done
# github runner version
GH_RUNNER_VERSION="2.263.0"
# get actions binary
curl -o actions.tar.gz --location "https://github.com/actions/runner/releases/download/v${GH_RUNNER_VERSION}/actions-runner-linux-x64-${GH_RUNNER_VERSION}.tar.gz"
mkdir /runner
mkdir /runner-tmp
tar -zxf actions.tar.gz --directory /runner
rm -f actions.tar.gz
/runner/bin/installdependencies.sh
# get actions token
# shellcheck disable=SC2034
# ACTIONS_RUNNER_INPUT_NAME is used by config.sh
ACTIONS_RUNNER_INPUT_NAME=$HOSTNAME
ACTIONS_RUNNER_INPUT_TOKEN="$(curl -sS --request POST --url "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/actions/runners/registration-token" --header "authorization: Bearer ${GITHUB_TOKEN}"  --header 'content-type: application/json' | jq -r .token)"
# configure runner
RUNNER_ALLOW_RUNASROOT=1 /runner/config.sh --unattended --replace --work "/runner-tmp" --url "$REPO_URL" --token "$ACTIONS_RUNNER_INPUT_TOKEN" --labels gce-runner
# install and start runner service
cd /runner || exit
./svc.sh install
./svc.sh start
