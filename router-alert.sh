#!/bin/sh
#we need time five minutes ago and we need it as integer (number of seconds since 1970-01-01:00:00:00) because we want to compare it with the present farther down
mydate=$(($(date +%s)-300))

#many of the timestamps in the lastseen fields in nodes.json contain milliseconds and i didn't find a way to parse them correctly with jq, so i simply cut out the milliseconds and store the modified data to ./nodes.json-lastseen
sed 's/\(lastseen.*[0-9]\)\.[0-9]*Z/\1Z/g;s/\(lastseen.*[0-9]\)\"/\1Z\"/g' ../nodelist_api/nodes.json > nodes.json-lastseen

#alert.json contains all nodeids their owner has opted in to be alerted by email. only those nodeids get stored in ./nodeids.
jq '.[]|select(.alertme==true)| {id: .nodeid}' alert.json | grep -oP '"[a-f0-9]{12}"' > nodeids

#go through nodes.json-lastseen and filter out relevant data for all alerts and store it in ./failed_nodes
jq-linux64 --arg Mydate $mydate --slurpfile nodeid nodeids '.nodes[]|
select(.nodeinfo.owner.contact|tostring|contains("@"))|
select((.nodeinfo.node_id|[.]|inside($nodeid)))|
select((.lastseen|strptime("%Y-%m-%dT%H:%M:%SZ")|mktime)<($Mydate|tonumber))|
{name: .nodeinfo.hostname, contact: .nodeinfo.owner.contact, lastseen: .lastseen, flags: .flags, v6: .nodeinfo.network.addresses, nodeid: .nodeinfo.node_id}' nodes.json-lastseen > failed-nodes

#"measure" if there any failed nodes
numfailednodes=$(wc -l failed-nodes|awk '{print $1}')

#if so, do your magic
if [ $numfailednodes !=  "0" ]; then
	#separate the data of the potentially failed nodes by splitting up the .failed-nodes into many files xx00, xx01, xx02 ,...
	csplit -s failed-nodes /"name"/ {*}

	#xx00 contains crap. so get it out of our way
	rm xx00

	#generate an email out of every file matching xx*, send it to he node owner and delete the no longer needed xx<this><node>
	for i in xx*; do
		thisnodeid=$(grep nodeid $i | awk '{print $2}' | grep -oP '[^",]*')
		mailto=$(grep -oP '[^"]*@[^"]*' $i)
		replyto=lrnzo@osnabrueck.freifunk.net
		node=$(grep name $i|awk '{print $2}'|grep -oP '[^",]*')
		pubv6=$(grep -oP '2a03[^"]*' $i)
		mailsubject="Freifunkrouter $node (ID $thisnodeid) nicht mehr erreichbar?"
		echo "To: $mailto\nFrom:alert@ffnw.de\nSubject: $mailsubject\nHallo Freifunka,\n\nDein/Ihr Router $node ist seit mindestens 5 Minuten\nnicht erreichbar. Hier einige Details, die dir/Ihnen helfen können, dies zu ändern:\n\nurl:\thttp://map.ffnw.de/#!v:m;n:$nodeid\nipv6:\t$pubv6\n\nDies ist eine automatische Benachrichtigung." | msmtp $mailto
		jq-linux64 --arg Nodeid $thisnodeid '.[]| if (.nodeid|tostring==$Nodeid) or (.alertme!=true) then (.alertme |= false) else (.alertme |= true) end' alert.json | jq -s . > alert.json.tmp
		mv alert.json.tmp alert.json
		rm $i
	done
fi
