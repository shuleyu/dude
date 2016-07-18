#!/bin/bash

# ====================================================================
# This script
#
#
# Shule Yu
# Feb 04 2016
# ====================================================================

echo ""
echo "--> `basename $0` is running."
mkdir -p ${WORKDIR}
cd ${WORKDIR}

# ==================================================
#              ! Work Begin !
# ==================================================


for EQ in `cat ${WORKDIR}/tmpfile_EQs_${RunNumber}`
do
	# Commands after press Ctrl+C.
	trap "rm -f ${WORKDIR}/tmpfile*$$ ${PLOTDIR}/${EQ}*`basename ${0%.sh}`*.ps ${WORKDIR}/*_${RunNumber}; exit 1" SIGINT


	# Check list file.
	if ! [ -s ${FileListDIR}/${EQ}_FileList ]
	then
		echo "    ~=> ${EQ} doesn't have FileList ..."
		continue
	fi

	# Prepare C++ input.
	SampleTrace=`head -n 1 ${FileListDIR}/${EQ}_FileList`
	EVLA=`saclst evla f ${SampleTrace} | awk '{printf "%.2f",$2}'`
	EVLO=`saclst evlo f ${SampleTrace} | awk '{printf "%.2f",$2}'`
	EVDP=`saclst evdp f ${SampleTrace} | awk '{if ($2>1000) printf "%.1f",$2/1000; else printf "%.1f",$2}'`
	EVMA=`saclst mag  f ${SampleTrace} | awk '{printf "%1.f",$2}'`

	while read Num COMP DISTMIN DISTMAX TIMEMIN TIMEMAX F1 F2 filter_flag normalize_flag PlotOrient
	do

		# Check list file.
		if ! [ -s ${FileListDIR}/${EQ}_FileList_${COMP} ]
		then
			echo "    ~=> ${EQ}_${COMP} doesn't have FileList ..."
			continue
		else
			echo "    ==> Making big profile of ${EQ}, Num=${Num}."
			OUTFILE=${PLOTDIR}/${EQ}.`basename ${0%.sh}`_${Num}.ps
		fi

		# C++ Code.
		${EXECDIR}/BigProfile.out 3 5 11 << EOF
${PlotOrient}
${filter_flag}
${normalize_flag}
${FileListDIR}/${EQ}_FileList_${COMP}
${OUTFILE}
${EQ}
Script: `basename $0``date "+ DATE: %m/%d/%y  %H:%M:%S"`
${COMP}
${EVLA}
${EVLO}
${EVDP}
${EVMA}
${DISTMIN}
${DISTMAX}
${TIMEMIN}
${TIMEMAX}
${F1}
${F2}
${Delta_BP}
EOF

		if [ $? -ne 0 ]
		then
			echo "    !=> C++ code failed on ${EQ}_${COMP}..."
			rm -f ${WORKDIR}/tmpfile*$$
			exit 1
		fi

	done < ${WORKDIR}/tmpfile_BP_${RunNumber} # End of plot loop.

done # End of EQ loop.

# Clean up.
rm -f ${WORKDIR}/tmpfile*$$

cd ${WORKDIR}

exit 0
