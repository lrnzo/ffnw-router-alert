#!/bin/sh
#aus den emailadressen in ./subscribers wird die alert.json erstellt. dies geschieht per cronjob. siehe 'crontab -l' für zB das eingestellte Intervall
grep -v '#' subscribers > Subscribers
jq --slurpfile address Subscribers '.nodes[]|select(.nodeinfo.owner.contact|tostring|[.]|inside($address))|{nodeid: .nodeinfo.node_id, alertme: true}' nodes.json-lastseen | jq -s . > alert.json
rm Subscribers
