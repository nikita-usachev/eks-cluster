#!/bin/bash

set -o xtrace
/etc/eks/bootstrap.sh --apiserver-endpoint ${ENDPOINT} --b64-cluster-ca ${CERTIFICATE_AUTHORITY} ${CLUSTER_NAME}
