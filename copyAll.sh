#!/bin/sh


for i in "$@"
do
#	echo $i; echo "--"
	if [[ -f $i ]]; then 
	    docker cp $i $1:root/LOML/
	fi
done
