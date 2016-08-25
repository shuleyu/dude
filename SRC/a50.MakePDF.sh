#!/bin/bash

# ====================================================================
# This script combine all *ps file and make a PDF file.
#
# Ed Garnero/Pei-Ying(Patty) Lin/Shule Yu
# ====================================================================

echo ""
echo "--> `basename $0` is running. `date`"
cd ${PLOTDIR}

# ==================================================
#              ! Work Begin !
# ==================================================

# Ctrl+C action.
trap "rm -f ${PLOTDIR}/tmpfile_$$ ${EQ}.pdf ${OUTDIR}/*_${RunNumber}; exit 1" SIGINT

for EQ in `cat ${OUTDIR}/tmpfile_EQs_${RunNumber}`
do

	rm -f tmpfile_$$

	for file in `ls -rt ${EQ}.a* 2>/dev/null`
	do
		cat ${file} >> tmpfile_$$
	done

	if [ -s tmpfile_$$ ]
	then
		echo "    ==> Combining ps plot from ${EQ}."
		ps2pdf tmpfile_$$ ${EQ}.pdf
	fi

	rm -f tmpfile_$$

done # End of EQ loop.

cd ${OUTDIR}

exit 0
