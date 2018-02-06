#!/bin/bash
while :
do
	if curl -s --head  --request GET https://br-coffee.cfapps.io/ | grep "200 OK" > /dev/null  
	then 
   		echo "site is UP"
	else
  	 	echo "site is DOWN"
	fi
done
