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
	else
		echo "    ==> Making Histogram for ${EQ}."
		OUTFILE=${PLOTDIR}/${EQ}.`basename ${0%.sh}`.ps
	fi

	# Prepare C++ input.
	SampleTrace=`head -n 1 ${FileListDIR}/${EQ}_FileList`
	EVLA=`saclst evla f ${SampleTrace} | awk '{printf "%.2f",$2}'`
	EVLO=`saclst evlo f ${SampleTrace} | awk '{printf "%.2f",$2}'`
	EVDP=`saclst evdp f ${SampleTrace} | awk '{if ($2>1000) printf "%.1f",$2/1000; else printf "%.1f",$2}'`
	EVMA=`saclst mag  f ${SampleTrace} | awk '{printf "%1.f",$2}'`

	saclst az baz gcarc f `cat ${FileListDIR}/${EQ}_FileList_Z` | awk '{print $2,$3,$4}'> tmpfile_az_baz_gcarc_$$

	# C++ Code.
	${EXECDIR}/Histogram.out 0 4 4 << EOF
tmpfile_az_baz_gcarc_$$
${OUTFILE}
${EQ}
Script: `basename $0``date "+ DATE: %m/%d/%y  %H:%M:%S"`
${EVLA}
${EVLO}
${EVDP}
${EVMA}
EOF

	if [ $? -ne 0 ]
	then
		echo "    !=> C++ code failed ..."
		rm -f tmpfile*$$
		exit 1
	fi


done # End of EQ loop.

# Clean up.
rm -f ${WORKDIR}/tmpfile*$$

cd ${WORKDIR}

exit 0
