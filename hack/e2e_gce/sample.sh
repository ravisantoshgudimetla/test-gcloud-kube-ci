#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

DESCHEDULER_ROOT=$(dirname "${BASH_SOURCE}")./../
E2E_GCE_HOME=$DESCHEDULER_ROOT/hack/e2e_gce
cat $E2E_GCE_HOME/sample.sh
