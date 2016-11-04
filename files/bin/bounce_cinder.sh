#!/bin/bash

# Keep track of the devstack directory
SCRIPT_DIR=$(dirname "$(readlink -e "${BASH_SOURCE[0]}")")
TOP_DIR=$(dirname $SCRIPT_DIR)


source $TOP_DIR/functions
source $TOP_DIR/stackrc

# Set some necessary variables that are normally handled by stack.sh
SERVICE_TIMEOUT=${SERVICE_TIMEOUT:-60}
ENABLE_DEBUG_LOG_LEVEL=${ENABLE_DEBUG_LOG_LEVEL:-True}
SERVICE_HOST=${SERVICE_HOST:-$HOST_IP}

source $TOP_DIR/lib/database
source $TOP_DIR/lib/rpc_backend
source $TOP_DIR/lib/tls
source $TOP_DIR/lib/keystone
source $TOP_DIR/lib/cinder

# Use standard openstack functions for stoping and starting
stop_cinder
start_cinder
