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
		echo "    ==> Making CityMap for ${EQ}."
		OUTFILE=${PLOTDIR}/${EQ}.`basename ${0%.sh}`.ps
	fi

	# Prepare C++ input.
	SampleTrace=`head -n 1 ${FileListDIR}/${EQ}_FileList`
	EVLA=`saclst evla f ${SampleTrace} | awk '{printf "%.2f",$2}'`
	EVLO=`saclst evlo f ${SampleTrace} | awk '{printf "%.2f",$2}'`
	EVDP=`saclst evdp f ${SampleTrace} | awk '{if ($2>1000) printf "%.1f",$2/1000; else printf "%.1f",$2}'`
	EVMA=`saclst mag  f ${SampleTrace} | awk '{printf "%1.f",$2}'`

	cat > tmpfile_Cities_$$ << EOF 
72.7 19 Bombay
-67 10.5 Caracas
-17.3 40.2 Dakar
112.2 22.3 Hong Kong
-157.8 21.3 Honolulu
0 51.5 London
-99 19.5 Mexico City
37.5 55.7 Moscow
37 -1.5 Nairobi
-74 40.8 New York
151 -34 Sydney
-70.7 -33.5 Santiago
-122.7 37.8 San Francisco
139.7 35.7 Tokyo
EOF

	# C++ Code.
	${EXECDIR}/CityMap.out 0 4 4 << EOF
tmpfile_Cities_$$
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
