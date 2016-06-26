#!/bin/sh
#wget -O nodes.json http://map.ffnw.de/nodelist_api/nodes.json
mydate=$(($(date +%s)-300))
sed 's/\(lastseen.*[0-9]\)\.[0-9]*Z/\1Z/g;s/\(lastseen.*[0-9]\)\"/\1Z\"/g' ../nodelist_api/nodes.json > nodes.json-lastseen
jq-linux64 --arg Mydate $mydate '.nodes[]|
select(.nodeinfo.owner.contact|tostring|contains("lrnzo@"))|
select((.lastseen|strptime("%Y-%m-%dT%H:%M:%SZ")|mktime)<($Mydate|tonumber))|
{name: .nodeinfo.hostname, contact: .nodeinfo.owner.contact, lastseen: .lastseen, flags: .flags, v6: .nodeinfo.network.addresses, nodeid: .nodeinfo.node_id}' nodes.json-lastseen > failed-nodes
csplit -s failed-nodes /"name"/ {*}
rm xx00
for i in xx*; do
	mailto=$(grep -oP '[^"]*@[^"]*' $i)
	replyto=lrnzo@osnabrueck.freifunk.net
	node=$(grep name $i|awk '{print $2}'|grep -oP '[^",]*')
	nodeid=$(grep nodeid $i | awk '{print $2}' | grep -oP '[^",]*')
	pubv6=$(grep -oP '2a03[^"]*' $i)
	mailsubject="Freifunkrouter $node nicht mehr erreichbar"
	echo "To: $mailto\nFrom:alert@ffnw.de\nSubject: $mailsubject\nHallo Freifunka,\n\nDein/Ihr Router $node ist seit mindestens 5 Minuten\nnicht erreichbar. Hier einige Details, die dir/Ihnen helfen können, dies zu ändern:\n\nurl:\thttp://map.ffnw.de/#!v:m;n:$nodeid\nipv6:\t$pubv6\n\nDies ist eine automatische benachrichtigung." | msmtp $mailto
	rm $i
	done
