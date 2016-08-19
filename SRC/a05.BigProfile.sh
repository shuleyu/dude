#!/bin/bash

# ====================================================================
# This script make profile plot of data.
#
# Ed Garnero/Pei-Ying(Patty) Lin/Shule Yu
# ====================================================================

echo ""
echo "--> `basename $0` is running. `date`"
mkdir -p ${a05DIR}
cd ${a05DIR}

# ==================================================
#              ! Work Begin !
# ==================================================


for EQ in `cat ${OUTDIR}/tmpfile_EQs_${RunNumber}`
do

	# Ctrl+C action.
	trap "rm -f ${a05DIR}/${EQ}* ${OUTDIR}/*_${RunNumber}; exit 1" SIGINT


	# A. Check the exist of list file.
	if ! [ -s ${a01DIR}/${EQ}_FileList_Info ]
	then
		echo "    ~=> ${EQ} doesn't have FileList ..."
		continue
	else
		echo "    ==> Making BigProfile plot(s) of ${EQ}."
	fi

	# B. Pull information.
	keys="<EQ> <EVLA> <EVLO> <EVDP> <MAG>"
	${BASHCODEDIR}/Findfield.sh ${a01DIR}/EQInfo.txt "${keys}" | grep ${EQ} > ${EQ}_Info
	read EQ EVLA EVLO EVDP MAG < ${EQ}_Info

	YYYY=`echo ${EQ} | cut -c1-4 `
	MM=`  echo ${EQ} | cut -c5-6 `
	DD=`  echo ${EQ} | cut -c7-8 `
	HH=`  echo ${EQ} | cut -c9-10 `
	MIN=` echo ${EQ} | cut -c11-12 `

	NSTA_All=`wc -l < ${a01DIR}/${EQ}_FileList_Info`
	NSTA_All=$((NSTA_All/3))

	# C. Enter the plot loop.
	Num=0
	while read COMP DISTMIN DISTMAX TIMEMIN TIMEMAX F1 F2 Normalize TravelCurve NetWork PlotOrient
	do


		Num=$((Num+1))
		PLOTFILE=${PLOTDIR}/${EQ}.`basename ${0%.sh}`_${Num}.ps
		rm -f ${a05DIR}/${EQ}*


		# set up SAC operator.
		if [ `echo "${F1}==0.0" | bc` -eq 1 ] && [ `echo "${F2}==0.0" | bc` -eq 1 ]
		then
			SACCommand="mul 1"
		elif [ `echo "${F1}==0.0" | bc` -eq 1 ]
		then
			SACCommand="lp co ${F2} n 2 p 2"
		elif [ `echo "${F2}==0.0" | bc` -eq 1 ]
		then
			SACCommand="hp co ${F1} n 2 p 2"
		else
			SACCommand="bp co ${F1} ${F2} n 2 p 2"
		fi


		# Ctrl+C action.
		trap "rm -f ${a05DIR}/${EQ}* ${PLOTFILE} ${OUTDIR}/*_${RunNumber}; exit 1" SIGINT


		# a. Select network and gcp distance window.
		keys="<FileName> <NETWK> <Gcarc> <OMarker> <BeginTime> <EndTime>"
		${BASHCODEDIR}/Findfield.sh ${a01DIR}/${EQ}_FileList_Info "${keys}" \
		| awk -v T1=${TIMEMIN} -v T2=${TIMEMAX} '{if (T2<=($5-$4) || T1>=($6-$4)) ; else print $1,$2,$3}' \
		| awk -v D1=${DISTMIN} -v D2=${DISTMAX} '{if (D1<=$3 && $3<=D2) print $1,$2}' \
		| awk -v N=${NetWork} '{if (N=="All") print $1; else if ($2==N) print $1}' \
		> ${EQ}_SelectedFiles

		if ! [ -s ${EQ}_SelectedFiles ]
		then
			echo "        ~=> No selected files for parameter line ${Num}..."
			continue
		fi


		# b. Choose file already exists for this component.
		#    (get the filenames exists both in ${EQ}_SelectedFiles and ${a01DIR}/${EQ}_FileList_${COMP})
		${BASHCODEDIR}/Findrow.sh ${a01DIR}/${EQ}_FileList_${COMP} ${EQ}_SelectedFiles > ${EQ}_List1
		saclst kstnm knetwk f `cat ${EQ}_List1` > tmpfile_$$
		mv tmpfile_$$ ${EQ}_List1


		# c. Choose files needed to be rotated for getting this component.
		if [ ${COMP} = "T" ] || [ ${COMP} = "R" ]
		then
			${BASHCODEDIR}/Findrow.sh ${a01DIR}/${EQ}_FileList_E ${EQ}_SelectedFiles > tmpfile1_$$
			${BASHCODEDIR}/Findrow.sh ${a01DIR}/${EQ}_FileList_N ${EQ}_SelectedFiles > tmpfile2_$$

			saclst npts f `cat tmpfile1_$$` > tmpfile3_$$
			saclst kstnm knetwk npts f `cat tmpfile2_$$` > tmpfile4_$$
			paste tmpfile3_$$ tmpfile4_$$ > ${EQ}_List2

			rm -f tmpfile*$$

			[ ${COMP} = "R" ] && ReadIn="junk.R" || ReadIn="junk.T"

		fi

		if [ ${COMP} = "E" ] || [ ${COMP} = "N" ]
		then
			${BASHCODEDIR}/Findrow.sh ${a01DIR}/${EQ}_FileList_R ${EQ}_SelectedFiles > tmpfile1_$$
			${BASHCODEDIR}/Findrow.sh ${a01DIR}/${EQ}_FileList_T ${EQ}_SelectedFiles > tmpfile2_$$

			saclst npts f `cat tmpfile1_$$` > tmpfile3_$$
			saclst kstnm knetwk npts f `cat tmpfile2_$$` > tmpfile4_$$
			paste tmpfile3_$$ tmpfile4_$$ > ${EQ}_List2

			rm -f tmpfile*$$

			[ ${COMP} = "E" ] && ReadIn="junk.E" || ReadIn="junk.N"

		fi

		# d. Process data (to sac format) in ${EQ}_List1.
		rm -f ${EQ}_SACMacro1.m
		while read filename stnm netwk
		do
			cat >> ${EQ}_SACMacro1.m << EOF
cut off
r ${filename}
rmean
rtr
taper
${SACCommand}
interp d ${Delta_BP}
w junk.sac
cut O ${TIMEMIN} ${TIMEMAX}
r junk.sac
w ${EQ}.${netwk}.${stnm}.sac
EOF
		done < ${EQ}_List1

		sac >/dev/null 2>&1  << EOF
m ${EQ}_SACMacro1.m
q
EOF
		rm -f junk.sac


		# e. Process data (to sac format) in ${EQ}_List2, for COMP="R" or "T".
		if [ ${COMP} = "T" ] || [ ${COMP} = "R" ]
		then
			rm -f ${EQ}_SACMacro2.m
			while read Efile ENpts Nfile stnm netwk NNpts
			do
				if [ ${ENpts} -ge ${NNpts} ]
				then
					SACCut="cut b n ${NNpts}"
				else
					SACCut="cut b n ${ENpts}"
				fi

				cat >> ${EQ}_SACMacro2.m << EOF
${SACCut}
r ${Nfile} ${Efile}
rotate to GCP
w junk.R junk.T
r ${ReadIn}
rmean
rtr
taper
${SACCommand}
interp d ${Delta_BP}
w junk.sac
cut O ${TIMEMIN} ${TIMEMAX}
r junk.sac
w ${EQ}.${netwk}.${stnm}.sac
EOF
			done < ${EQ}_List2

			sac >/dev/null 2>&1  << EOF
m ${EQ}_SACMacro2.m
q
EOF
			rm -f junk.sac junk.R junk.T

		fi

		# e*. Process data (to sac format) in ${EQ}_List2, for COMP="E" or "N".
		if [ ${COMP} = "E" ] || [ ${COMP} = "N" ]
		then
			rm -f ${EQ}_SACMacro2.m
			while read Rfile RNpts Tfile stnm netwk TNpts
			do
				if [ ${RNpts} -ge ${TNpts} ]
				then
					SACCut="cut b n ${RNpts}"
				else
					SACCut="cut b n ${TNpts}"
				fi

				cat >> ${EQ}_SACMacro2.m << EOF
${SACCut}
r ${Rfile} ${Tfile}
rotate to 0
w junk.N junk.E
r ${ReadIn}
rmean
rtr
taper
${SACCommand}
interp d ${Delta_BP}
w junk.sac
cut O ${TIMEMIN} ${TIMEMAX}
r junk.sac
w ${EQ}.${netwk}.${stnm}.sac
EOF
			done < ${EQ}_List2

			sac >/dev/null 2>&1  << EOF
m ${EQ}_SACMacro2.m
q
EOF
			rm -f junk.sac junk.N junk.E

		fi


		# f. Process data (from sac to ascii).
		saclst gcarc f `ls ${EQ}*sac` > ${EQ}_PlotList_Gcarc
		NSTA=`wc -l < ${EQ}_PlotList_Gcarc`

# 		${EXECDIR}/BigProfile.cpp 1 2 3 << EOF
# ${Normalize}
# ${EQ}_PlotList_Gcarc
# ${EQ}_PlotFile.txt
# ${Amplitude_BP}
# ${DISTMIN}
# ${DISTMAX}
# EOF



	done < ${OUTDIR}/tmpfile_BP_${RunNumber} # End of plot loop.

done # End of EQ loop.

cd ${OUTDIR}

exit 0
