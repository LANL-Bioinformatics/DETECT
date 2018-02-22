#!/usr/bin/env bash
set -e
rootdir=$( cd $(dirname $0) ; pwd -P )

test_result(){
	Test=$rootdir/TestOutput/stats/test.report.txt
	Expect=$rootdir/report.txt
	testName="run test";
	if cmp -s "$Test" "$Expect"
	then
		echo "$testName passed!"
		touch "$rootdir/TestOutput/test.success"
	else
		echo "$testName failed!"
		touch "$rootdir/TestOutput/test.fail"
	fi
}

cd $rootdir
echo "Working Dir: $rootdir";
echo "Running Test ..."
if [ ! -f "$rootdir/TestOutput/test.success" ]
then
	rm -rf $rootdir/TestOutput
fi

perl $rootdir/../DETECT  --quite --ref $rootdir/targeted_reference.fa --indir $rootdir --samples $rootdir/sample_test.txt --outdir TestOutput --prefix test || true

test_result;
