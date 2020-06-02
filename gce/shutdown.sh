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

# access secret from secretsmanager
secrets=$(gcloud secrets versions access latest --secret="runner-secret")
# set secrets as env vars
# shellcheck disable=SC2206
secretsConfig=($secrets)
for var in "${secretsConfig[@]}"; do
export "${var?}"
done
#stop and uninstall the runner service
cd /runner || exit
./svc.sh stop
./svc.sh uninstall
#remove the runner configuration
RUNNER_ALLOW_RUNASROOT=1  /runner/config.sh remove --unattended --token "$(curl -sS --request POST --url "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/actions/runners/remove-token" --header "authorization: Bearer ${GITHUB_TOKEN}"  --header "content-type: application/json" | jq -r .token)"
