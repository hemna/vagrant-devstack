#!/bin/bash

# This script connects to keystone, obtains a project-scoped token,
# and sets environment variables to facilitate connecting to OpenStack
# services with curl.  
#
# It uses the OS_USERNAME, OS_PASSWORD, and OS_TENANT, and OS_AUTH_URL
# in order to connect to keystone.  After connecting, it sets the following
# environment variables:
#
# OS_TOKEN   : the keystone auth token for future connections
# CINDER_URL : the v2 URL to cinder, including the tenant_id
#
# These variables are also echod to the screen in a format that permits
# copying and pasting or capturing in an eval
#
# For example:
#
# eval $(./auth.sh)
# curl -s -H "X-Auth-Token: $OS_TOKEN" $CINDER_URL/volumes
#
# or for nicer formatting,
# curl -s -H "X-Auth-Token: $OS_TOKEN" $CINDER_URL/volumes | python -mjson.tool
#
OS_USERNAME=${OS_USERNAME:-admin}
OS_PASSWORD=${OS_PASSWORD:-openstack}
OS_TENANT_NAME=${OS_TENANT_NAME:-demo}

# Save the keystone output into a tempfile
t=$(tempfile -p auth.)

# Use keystone v3 for authentication, even if OS_AUTH_URL specifies v2
# The output from curl includes a header, X-Subject-Token, which contains the token
# to pass on to the rest of the services.  The payload also contains a json
# structure containing service endpoint URLs
KEYSTONE_URL=${OS_AUTH_URL/v2.0/v3}/auth/tokens
( curl -i -H "Content-Type: application/json" -d @- $KEYSTONE_URL | tr -d "\r" > $t) <<EOF
{
    "auth": {
        "identity": {
            "methods": [
                "password"
            ],
            "password": {
                "user": {
                    "domain": {
                        "id": "default"
                    },
                    "name": "$OS_USERNAME",
                    "password": "$OS_PASSWORD"
                }
            }
        },
        "scope": {
            "project": {
                "domain": {
                    "id": "default"
                },
                "name": "$OS_TENANT_NAME"
            }
        }
    }
}
EOF

# Grab the token
sed -n 's/^X-Subject-Token: /OS_TOKEN=/p' $t

# Parse the json to get the endpoing URLs of interest
python <<EOF
import json
with open("$t", 'r') as f:
    for line in f:
        if line[0] == '{':
            payload = json.loads(line)
            break
catalog = payload['token']['catalog']
for c in catalog:
    if c['name'] == 'cinderv2':
        for e in c['endpoints']:
            if e['interface'] == 'admin':
                print 'CINDER_URL=' + e['url']
EOF

rm $t
