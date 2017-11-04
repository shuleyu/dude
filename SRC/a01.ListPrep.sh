#!/bin/bash

# ====================================================================
# This script make one file for each earthquake, including a list of
# file names of selected stations for this earthquake.
#
# Ed Garnero/Pei-Ying(Patty) Lin/Shule Yu
# ====================================================================

echo ""
echo "--> `basename $0` is running. `date`"
mkdir -p ${a01DIR}
cd ${a01DIR}

# ==================================================
#              ! Work Begin !
# ==================================================

echo "<EQ> <EVLA> <EVLO> <EVDP> <MAG>" > ${a01DIR}/EQInfo.txt

for EQ in `cat ${OUTDIR}/tmpfile_EQs_${RunNumber}`
do

	rm -f ${a01DIR}/${EQ}*

	# ============================
	#     A. Select Stations.
	# ============================

	echo "    ==> Making selected file list of ${EQ}."

	# Ctrl+C action.
	trap "rm -f ${a01DIR}/tmpfile*$$ ${a01DIR}/${EQ}_FileList* ${OUTDIR}/*_${RunNumber}; exit 1" SIGINT

	# Gather information.
	find ${DATADIR}/${EQ}/ -iname "*sac" -exec saclst knetwk kstnm kcmpnm stla stlo f '{}' \; > ${a01DIR}/tmpfile_$$

	# C++ code.
	${EXECDIR}/ListPrep.out 1 2 0 << EOF
${UseBH}
${a01DIR}/tmpfile_$$
${a01DIR}/${EQ}_FileList
EOF
	rm -f tmpfile_$$


	if [ $? -ne 0 ]
	then
		echo "    !=> ListPrep.out C++ code failed on ${EQ} ..."
		echo "" > ${a01DIR}/${EQ}_FileList
		continue
	fi

	# ============================
	#     B. Get stations Info.
	# ============================
	trap "rm -f ${a01DIR}/${EQ}_FileList_Info ${OUTDIR}/*_${RunNumber}; exit 1" SIGINT

	echo "<FileName> <STNM> <NETWK> <OMarker> <BeginTime> <EndTime> <COMP> <Gcarc> <Az> <BAz> <STLO> <STLA>" > ${a01DIR}/${EQ}_FileList_Info

	# The ridiculous repeating kcmpnm here is needed
	# because sometimes two numveric outputs of saclst has no white seperation characters between them.
	saclst kstnm knetwk o kcmpnm b kcmpnm npts kcmpnm delta kcmpnm gcarc kcmpnm az kcmpnm baz kcmpnm stlo kcmpnm stla f `cat ${a01DIR}/${EQ}_FileList` \
	| awk '{$5="";$7="";$9="";$13="";$15="";$17="";$19=""; print $0}' \
	| awk '{$6=$5+$6*$7;$7=""; if ($10<0) $10+=360; print $0}' >> ${a01DIR}/${EQ}_FileList_Info


	# ============================
	#     C. Get EQs Info.
	# ============================

	trap "rm -f ${OUTDIR}/*_${RunNumber}; exit 1" SIGINT

	saclst evla evlo evdp mag f `head -n 1 ${a01DIR}/${EQ}_FileList` \
	| awk -v E=${EQ} '{if ($4>1000) $4/=1000; print E,$2,$3,$4,$5}' \
	>> ${a01DIR}/EQInfo.txt



done # End of EQ loop.

exit 0
