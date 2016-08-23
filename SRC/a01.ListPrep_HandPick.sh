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

	# Hand selected traces.

	mysql -N ScS_CP > tmpfile_$$  << EOF
select eq,netwk,stnm from Master_a06 where wantit=1 and eq=${EQ};
EOF
	awk '{printf "%s\\.%s\\.%s\\.\n",$1,$2,$3}' tmpfile_$$ > tmpfile1_$$

	rm -f tmpfile_$$
	while read File
	do
		grep "${File}" ${a01DIR}/${EQ}_FileList   >> tmpfile_$$
		grep "${File}" ${a01DIR}/${EQ}_FileList_Z >> tmpfileZ_$$
		grep "${File}" ${a01DIR}/${EQ}_FileList_E >> tmpfileE_$$
		grep "${File}" ${a01DIR}/${EQ}_FileList_N >> tmpfileN_$$
		grep "${File}" ${a01DIR}/${EQ}_FileList_T >> tmpfileT_$$
		grep "${File}" ${a01DIR}/${EQ}_FileList_R >> tmpfileR_$$
	done < tmpfile1_$$
	rm -f tmpfile1_$$

	mv tmpfile_$$  ${a01DIR}/${EQ}_FileList
	mv tmpfileZ_$$ ${a01DIR}/${EQ}_FileList_Z
	mv tmpfileE_$$ ${a01DIR}/${EQ}_FileList_E
	mv tmpfileN_$$ ${a01DIR}/${EQ}_FileList_N
	mv tmpfileT_$$ ${a01DIR}/${EQ}_FileList_T
	mv tmpfileR_$$ ${a01DIR}/${EQ}_FileList_R

	# ============================
	#     B. Get stations Info.
	# ============================
	trap "rm -f ${a01DIR}/${EQ}_FileList_Info ${OUTDIR}/*_${RunNumber}; exit 1" SIGINT

	echo "<FileName> <STNM> <NETWK> <OMarker> <BeginTime> <EndTime> <COMP> <Gcarc> <Az> <BAz> <STLO> <STLA>" > ${a01DIR}/${EQ}_FileList_Info
	saclst kstnm knetwk o b npts delta kcmpnm gcarc az baz stlo stla f `cat ${a01DIR}/${EQ}_FileList` \
	| awk '{$6=$5+$6*$7;$7=""; print $0}' >> ${a01DIR}/${EQ}_FileList_Info


	# ============================
	#     C. Get EQs Info.
	# ============================

	trap "rm -f ${a01DIR}/EQInfo.txt ${OUTDIR}/*_${RunNumber}; exit 1" SIGINT

	saclst evla evlo evdp mag f `head -n 1 ${a01DIR}/${EQ}_FileList` \
	| awk -v E=${EQ} '{if ($4>1000) $4/=1000; print E,$2,$3,$4,$5}' \
	>> ${a01DIR}/EQInfo.txt



done # End of EQ loop.

exit 0
