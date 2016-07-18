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
mkdir -p ${FileListDIR}
cd ${FileListDIR}

# ==================================================
#              ! Work Begin !
# ==================================================

for EQ in `cat ${WORKDIR}/tmpfile_EQs_${RunNumber}`
do
	# Commands after press Ctrl+C.
	echo "    ==> Making FileList for ${EQ}."
	trap "rm -f ${FileListDIR}/tmpfile*$$ ${FileListDIR}/${EQ}* ${WORKDIR}/*_${RunNumber}; exit 1" SIGINT

	# Prepare C++ input.
	find ${DATADIR}/${EQ} -iname "*sac" -exec saclst knetwk kstnm kcmpnm stla stlo f '{}' \; > tmpfile_${EQ}_$$

	# C++ code.
	${EXECDIR}/ListPrep.out 1 2 0 << EOF
${USE_BH}
tmpfile_${EQ}_$$
${FileListDIR}/${EQ}_FileList
EOF

	if [ $? -ne 0 ]
	then
		echo "    !=> C++ code failed ..."
		rm -f tmpfile*$$
		exit 1
	fi

done # End of EQ loop.

# Clean up.
rm -f tmpfile*$$

cd ${WORKDIR}

exit 0
