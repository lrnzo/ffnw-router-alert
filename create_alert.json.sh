#!/bin/sh
jq --slurpfile address subscribers '.nodes[]|select(.nodeinfo.owner.contact|tostring|[.]|inside($address))|{nodeid: .nodeinfo.node_id, alertme: true}' nodes.json-lastseen | jq -s . > alert.json
