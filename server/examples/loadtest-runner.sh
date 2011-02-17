#!/bin/sh

run_batch() {
	zone="$1"

	n=0
	while [ $n -lt 10000 ]; do
		./loadtest.pl "$zone"
		n=$(($n+1))
	done
}

if [ -z "$1" ]; then
	echo "usage: $0 zone"
	exit 1
fi

batch=0
while [ $batch -lt 10 ]; do
	run_batch "$1" &
	batch=$(($batch+1))
done

wait
exit 0
