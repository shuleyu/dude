#!/bin/bash

# ====================================================================
# This script make traveltime files using TauP.
#
# Ed Garnero/Pei-Ying(Patty) Lin/Shule Yu
# ====================================================================

echo ""
echo "--> `basename $0` is running. `date`"
mkdir -p ${a05DIR}
cd ${a05DIR}

echo "taup.distance.precision=3" > .taup
echo "taup.time.precision=3" >> .taup

# ==================================================
#              ! Work Begin !
# ==================================================

for EQ in `cat ${OUTDIR}/tmpfile_EQs_${RunNumber}`
do
	rm -f ${a05DIR}/${EQ}*

	# Ctrl+C action.
	trap "rm -f ${a05DIR}/${EQ}* ${OUTDIR}/*_${RunNumber}; exit 1" SIGINT


	# A. Check the exist of list file.
	if ! [ -s ${a01DIR}/${EQ}_FileList_Info ]
	then
		echo "    ~=> ${EQ} doesn't have FileList ..."
		continue
	else
		echo "    ==> Making TravelTime data of ${EQ}."
	fi


	# B. Pull information.
	keys="<EQ> <EVDP>"
	${BASHCODEDIR}/Findfield.sh ${a01DIR}/EQInfo.txt "${keys}" | grep ${EQ} > ${EQ}_Info
	read EQ EVDP < ${EQ}_Info

	# C. Make travel time data using TauP.
	while read COMP PhaseName
	do
		OUTFILE=${a05DIR}/${EQ}_${COMP}_${PhaseName}
		[ ${PhaseName} = "4.0kmps" ] && OUTFILE=${a05DIR}/${EQ}_${COMP}_Rayleigh
		[ ${PhaseName} = "4.5kmps" ] && OUTFILE=${a05DIR}/${EQ}_${COMP}_Love

		# make the traveltime data.
		taup_curve -ph ${PhaseName} -mod ${Model_TT} -h ${EVDP} -o ${OUTFILE}
		OUTFILE=${OUTFILE}.gmt

		# loose the first line.
		if ! [ -s "${OUTFILE}" ]
		then
			echo "        ~=> Warning: Phase ${PhaseName} is not exists ..."
			rm -f ${OUTFILE}
			continue
		else
			awk 'NR>1 {print $0}' ${OUTFILE} > tmpfile_$$
			mv tmpfile_$$ ${OUTFILE}
		fi

		# make a "First Arrival" version of travel time curve. (do an envelope)
		${EXECDIR}/FirstArrival.out 0 2 0 << EOF
${OUTFILE}
${OUTFILE}_Enveloped
EOF

		if [ $? -ne 0 ]
		then
			echo "    ~=> FirstArrival.out C++ code failed on ${OUTFILE} ..."
			continue
		fi

	done < ${OUTDIR}/tmpfile_PhaseList_${RunNumber} # End of phase loop

done # End of EQ loop.

exit 0
