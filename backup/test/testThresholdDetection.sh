#!/bin/bash

source $(dirname $0)/../bin/functions.sh

# arg1: file
# arg2: bytes
fill_with_bytes() {
	file=$1
	bytes=$2

	dd if=/dev/zero of=$file count=$bytes > /dev/null 2>&1
}

testThreshold_negative_WithDirectoryAndTwoFiles() {
	# create file to be tested. should be of size 0
	temp_dir=$(mktemp -d)
	
	touch $temp_dir/1
	touch $temp_dir/2

	dir_size_greater_than_threshold $temp_dir 0
	ret=$?

	# cleanup
	rm $temp_dir/1
	rm $temp_dir/2
	rmdir $temp_dir

	# expect to return 2
	if [ "$ret" -eq 2 ]; then
		echo " SUCCESS"
	else
		echo " FAIL"
	fi
}

testThreshold_negative_WithDirectoryAndTwoFilesOneFileBelow() {
	# create file to be tested. should be of size 0
	temp_dir=$(mktemp -d)
	
	f1=$temp_dir/1
	touch $f1
	f2=$temp_dir/2
	touch $f2
	fill_with_bytes $f1 10

	dir_size_greater_than_threshold $temp_dir 0
	ret=$?

	# cleanup
	rm $f1
	rm $f2
	rmdir $temp_dir

	# expect to return 2
	if [ "$ret" -eq 2 ]; then
		echo " SUCCESS"
	else
		echo " FAIL"
	fi
}

testThreshold_positive_WithDirectoryAndTwoFilesBothAbove() {
	# create file to be tested. should be of size 0
	temp_dir=$(mktemp -d)
	
	f1=$temp_dir/1
	touch $f1
	fill_with_bytes $f1 11
	f2=$temp_dir/2
	touch $f2
	fill_with_bytes $f2 11

	dir_size_greater_than_threshold $temp_dir 10
	ret=$?

	# cleanup
	rm $f1
	rm $f2
	rmdir $temp_dir

	# expect to return 0
	if [ "$ret" -eq 0 ]; then
		echo " SUCCESS"
	else
		echo " FAIL"
	fi
}

testThreshold_positive_WithOneFileAbove() {
	# create file to be tested. should be of size 0
	temp_dir=$(mktemp -d)
	
	f1=$temp_dir/1
	touch $f1
	fill_with_bytes $f1 11

	dir_size_greater_than_threshold $f1 10
	ret=$?

	# cleanup
	rm $f1
	rmdir $temp_dir

	# expect to return 2
	if [ "$ret" -eq 0 ]; then
		echo " SUCCESS"
	else
		echo " FAIL"
	fi
}

for fun in $(declare -F | grep 'testThreshold_' | awk '{print $3}'); do
	echo "=== Running test $fun"
	$fun
	echo
done
