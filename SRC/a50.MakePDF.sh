#!/bin/bash

# ====================================================================
# This script Make a clean list of stations.
#
# input file has 6 columns:
# filename | network name | station name | component name | lat | lon.
#
# Shule Yu
# Jan 30 2016
# ====================================================================

echo ""
echo "--> `basename $0` is running."
cd ${PLOTDIR}

# ==================================================
#              ! Work Begin !
# ==================================================

for EQ in `cat ${WORKDIR}/tmpfile_EQs_${RunNumber}`
do

	rm -f tmpfile_$$

	for file in `ls -rt ${EQ}*ps 2>/dev/null`
	do
		cat ${file} >> tmpfile_$$
	done

	if [ -s tmpfile_$$ ]
	then
		ps2pdf tmpfile_$$ ${EQ}.pdf
	fi

done # End of EQ loop.

# Clean up.
rm -f ${PLOTDIR}/tmpfile*$$

cd ${WORKDIR}

exit 0
