#!/bin/bash

# ====================================================================
# This script 
#
# input file has 6 columns:
# filename | network name | station name | component name | lat | lon.
#
# Shule Yu
# Jan 30 2016
# ====================================================================

echo ""
echo "--> `basename $0` is running."
mkdir -p ${OUTDIR}
cd ${OUTDIR}

# ==================================================
#              ! Work Begin !
# ==================================================


for EQ in `cat ${OUTDIR}/tmpfile_EQs_${RunNumber}`
do
	# Commands after press Ctrl+C.
	trap "rm -f ${OUTDIR}/tmpfile*$$ ${PLOTDIR}/${EQ}*`basename ${0%.sh}`*.ps ${OUTDIR}/*_${RunNumber}; exit 1" SIGINT


	# Check list file.
	if ! [ -s ${FileListDIR}/${EQ}_FileList ]
	then
		echo "    ~=> ${EQ} doesn't have FileList ..."
		continue
	else
		echo "    ==> Making MasterMap for ${EQ}."
		OUTFILE=${PLOTDIR}/${EQ}.`basename ${0%.sh}`.ps
	fi

	# Prepare C++ input.
	SampleTrace=`head -n 1 ${FileListDIR}/${EQ}_FileList`
	EVLA=`saclst evla f ${SampleTrace} | awk '{printf "%.2f",$2}'`
	EVLO=`saclst evlo f ${SampleTrace} | awk '{printf "%.2f",$2}'`
	EVDP=`saclst evdp f ${SampleTrace} | awk '{if ($2>1000) printf "%.1f",$2/1000; else printf "%.1f",$2}'`
	EVMA=`saclst mag  f ${SampleTrace} | awk '{printf "%1.f",$2}'`

	saclst stlo stla gcarc f `cat ${FileListDIR}/${EQ}_FileList_Z` | awk '{print $2,$3,$4}'> tmpfile_stlo_stla_gcarc_$$

	# C++ Code.
	${EXECDIR}/MasterMap.out 0 4 4 << EOF
tmpfile_stlo_stla_gcarc_$$
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
rm -f ${OUTDIR}/tmpfile*$$

cd ${OUTDIR}

exit 0
