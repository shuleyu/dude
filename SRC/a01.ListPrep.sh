#!/bin/bash

# ====================================================================
# This script make one file for each earthquake, including a list of
# file names of selected stations for this earthquake.
#
# Shule Yu
# ====================================================================

echo ""
echo "--> `basename $0` is running. `date`"
ScriptName=`basename $0`
a01DIR=${OUTDIR}/${ScriptName%.sh}
mkdir -p ${a01DIR}

# ==================================================
#              ! Work Begin !
# ==================================================

for EQ in `cat ${OUTDIR}/tmpfile_EQs_${RunNumber}`
do
	echo "    ==> Making selected file list of ${EQ}."

	# Ctrl+C action.
	trap "rm -f ${a01DIR}/tmpfile*$$ ${a01DIR}/${EQ}* ${OUTDIR}/*_${RunNumber}; exit 1" SIGINT

	# Gather information.
	find ${DATADIR}/${EQ} -iname "*sac" -exec saclst knetwk kstnm kcmpnm stla stlo f '{}' \; > ${a01DIR}/tmpfile_$$

	# C++ code.
	${EXECDIR}/ListPrep.out 1 2 0 << EOF
${USE_BH}
${a01DIR}/tmpfile_$$
${a01DIR}/${EQ}_FileList
EOF

	if [ $? -ne 0 ]
	then
		echo "    !=> ListPrep.out C++ code failed on ${EQ} ..."
		echo "" > ${a01DIR}/${EQ}_FileList
		continue
	fi

done # End of EQ loop.

# Clean up.
rm -f ${a01DIR}/tmpfile_$$

exit 0
