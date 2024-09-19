#!/bin/bash

# This is obsolete example how to create testing DB
# The actual DB for scalability test has different structure of hosts
for i in `seq 11 1499` ; do
	echo -n "Doing host $i..."
	onehost create host-$i -i dummy -v dummy > /dev/null 2>&1
        for x in `seq 0 3` ; do
            onetemplate instantiate 0 --name vm-$i-$x > /dev/null 2>&1
	    onevm deploy vm-$i-$x host-$i > /dev/null 2>&1
        done
	echo "done"
done
