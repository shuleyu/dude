#!/bin/bash

set -a

# ====================================================================
# This script make ESW for each choosen phase.
#
# Ed Garnero/Pei-Ying(Patty) Lin/Shule Yu
# ====================================================================

echo ""
echo "--> `basename $0` is running. `date`"
mkdir -p ${a15DIR}
cd ${a15DIR}

# ==================================================
#              ! Work Begin !
# ==================================================


for EQ in `cat ${OUTDIR}/tmpfile_EQs_${RunNumber}`
do

	# Ctrl+C action.
	trap "rm -f ${a15DIR}/${EQ}* ${a15DIR}/tmpfile*$$ ${OUTDIR}/*_${RunNumber}; exit 1" SIGINT

	# A. Check the exist of list file.
	if ! [ -s "${a01DIR}/${EQ}_FileList" ]
	then
		echo "    ~=> ${EQ} doesn't have FileList ..."
		continue
	fi


	# A*. Pull information.
	keys="<EQ> <EVLA> <EVLO> <EVDP> <MAG>"
	${BASHCODEDIR}/Findfield.sh ${a01DIR}/EQInfo.txt "${keys}" | grep ${EQ} > ${EQ}_Info
	read EQ1 EVLA EVLO EVDP MAG < ${EQ}_Info

	YYYY=`echo ${EQ} | cut -c1-4 `
	MM=`  echo ${EQ} | cut -c5-6 `
	DD=`  echo ${EQ} | cut -c7-8 `
	HH=`  echo ${EQ} | cut -c9-10 `
	MIN=` echo ${EQ} | cut -c11-12 `

	NSTA_All=`wc -l < ${a01DIR}/${EQ}_FileList_Info`
	NSTA_All=$((NSTA_All/3))


	# Enter the ESW making loop.
	Num=0
	while read Phase COMP UseSNR DistMin DistMax AzMin AzMax F1 F2 NETWK
	do
		Num=$((Num+1))


		# Files.
		PLOTFILE=${PLOTDIR}/${EQ}.`basename ${0%.sh}`_${Num}.ps
		OUTFILE=${a15DIR}/${EQ}_${Phase}_${COMP}_${UseSNR}_${DistMin}_${DistMax}_${AzMin}_${AzMax}_${F1}_${F2}_${NETWK}.List
		OUTFILE_ESW=${a15DIR}/${EQ}_${Phase}_${COMP}_${UseSNR}_${DistMin}_${DistMax}_${AzMin}_${AzMax}_${F1}_${F2}_${NETWK}.ESW
		trap "rm -f ${a15DIR}/${EQ}* ${PLOTFILE} ${OUTFILE} ${a15DIR}/tmpfile*$$ ${OUTDIR}/*_${RunNumber}; exit 1" SIGINT
		echo "    ==> Making ESW of ${EQ}, Line ${Num}..."


		# Clean dir.
		for file in `ls ${a15DIR}/${EQ}* 2>/dev/null | grep -v List | grep -v ESW`
		do
			rm -f ${file}
		done

		# Basic set-ups.

		# Set up normalize & cross-correlation windows for this event, for this line of ESW parameters.
		# Default windows will be -10 ~ 15 second around PREM arrival.
		# Search the ESWWindow section for specific window parameters.
		Info=`grep "${EQ}" ${WORKDIR}/tmpfile_ESWWindow_${RunNumber} | awk -v L=${Num} '{if ($2==L || $2=="*") print $3,$4,$5,$6,$7}' | head -n 1`

		PREMBias=""
		TimeMin=""
		TimeMax=""
		NBegin=""
		NEnd=""

		PREMBias=`echo "${Info}" | awk '{print $1}'`
		TimeMin=`echo "${Info}"  | awk '{print $2}'`
		TimeMax=`echo "${Info}"  | awk '{print $3}'`
		NBegin=`echo "${Info}"   | awk '{print $4}'`
		NEnd=`echo "${Info}"     | awk '{print $5}'`

		[ -z ${PREMBias} ] && PREMBias=0
		[ -z ${TimeMin} ] && TimeMin="-10"
		[ -z ${TimeMax} ] && TimeMax="15"
		[ -z ${NBegin} ] && NBegin="-10"
		[ -z ${NEnd} ] && NEnd="15"


		# Convert COMP to RadPat component name.
		case ${COMP} in
			"R" )
				COMP1="SV"
				;;
			"T" )
				COMP1="SH"
				;;
			"Z" )
				COMP1="P"
				;;
			* )
				echo "        ~=> component error of input line # ${Num}..."
				continue
		esac


		# set up SAC operator.
		if [ `echo "${F1}==0.0" | bc` -eq 1 ] && [ `echo "${F2}==0.0" | bc` -eq 1 ]
		then
			SACCommand="mul 1"
			FrequencyContent="No filter"
		elif [ `echo "${F1}==0.0" | bc` -eq 1 ]
		then
			SACCommand="lp co ${F2} n 2 p 2"
			FrequencyContent="butterworth lp < ${F2} Hz."
		elif [ `echo "${F2}==0.0" | bc` -eq 1 ]
		then
			SACCommand="hp co ${F1} n 2 p 2"
			FrequencyContent="butterworth hp > ${F1} Hz."
		else
			SACCommand="bp co ${F1} ${F2} n 2 p 2"
			FrequencyContent="butterworth bp ${F1} ~ ${F2} Hz."
		fi


		# B. Check pre-calculated files.

		# a. check the existance of the phase arrival file.
		if ! [ -s "`ls ${a05DIR}/${EQ}_*_${Phase}.gmt_Enveloped 2>/dev/null`" ]
		then
			echo "        ~=> Can't find Firsta Arrival file for ${EQ}!"
			continue
		else
			PhaseFile=`ls ${a05DIR}/${EQ}_*_${Phase}.gmt_Enveloped`
			PhaseDistMin=`minmax -C ${PhaseFile} | awk '{print $1}'`
			PhaseDistMax=`minmax -C ${PhaseFile} | awk '{print $2}'`
		fi


		# b. check the existance of the radiation prediction file for this phase.
		if ! [ -s "`ls ${a12DIR}/${EQ}_${Phase}_${COMP1}_RadPat.List 2>/dev/null`" ]
		then
			echo "        ~=> Can't find radiation pattern prediction file for ${EQ}!"
			continue
		else
			RadPatFile=`ls ${a12DIR}/${EQ}_${Phase}_${COMP1}_RadPat.List`
		fi


		# c. check the existance of the SNR measurement (optional).

		if [ ${UseSNR} -eq 1 ] && ! [ -s "${a14DIR}/${EQ}_SNR.List" ]
		then
			echo "        ~=> Can't find SNR measurement file for ${EQ}!"
			continue
		else
			SNRFile="${a14DIR}/${EQ}_SNR.List"
		fi


		# C. Select stations which have the phase arrival using distance window (a),
		#    have radpat prediction(b),
		#    have a none-"nan" SNR measurement (c) (if required).


		# a. select according to min/max distance.
		keys="<FileName> <NETWK> <STNM> <Gcarc> <BeginTime> <EndTime> <Az>"
		${BASHCODEDIR}/Findfield.sh ${a01DIR}/${EQ}_FileList_Info "${keys}" \
		| awk -v N=${NETWK} '{if (N=="AllSt" || (N!="AllSt" && $2==N)) print $0}' \
		| awk -v D1=${PhaseDistMin} -v D2=${PhaseDistMax} '{if (D1<=$4 && $4<=D2) print $0}' \
		| awk -v D1=${DistMin} -v D2=${DistMax} -v A1=${AzMin} -v A2=${AzMax} '{if (D1<=$4 && $4<=D2 && ((A1<=A2 && A1<=$7 && $7<=A2) || (A1>A2 && (A1<=$7 || $7<=A2)))) {$7="";A=$0;print $2"_"$3" "A}}' \
		> ${EQ}_label_SelectedFiles

		NSTA=`wc -l < ${EQ}_label_SelectedFiles`
		if [ ${NSTA} -eq 0 ]
		then
			echo "        Number of records: ${NSTA}..."
			continue
		fi

		# b. select stations have radpat prediction.
		keys="<NETWK> <STNM> <RadPat>"
		${BASHCODEDIR}/Findfield.sh ${RadPatFile} "${keys}" | awk '{print $1"_"$2,$3}' > tmpfile_$$

		awk '{print $1}' ${EQ}_label_SelectedFiles | sort > tmpfile_label1_$$
		awk '{print $1}' tmpfile_$$ | sort > tmpfile_label2_$$
		comm -1 -2 tmpfile_label1_$$ tmpfile_label2_$$ > tmpfile_common_label_$$

		${BASHCODEDIR}/Findrow.sh ${EQ}_label_SelectedFiles tmpfile_common_label_$$ > tmpfile1_$$
		${BASHCODEDIR}/Findrow.sh tmpfile_$$ tmpfile_common_label_$$ > tmpfile2_$$

		rm -f ${EQ}_label_SelectedFiles
		touch ${EQ}_label_SelectedFiles
		while read label radpat
		do
			grep "^${label}\ " tmpfile1_$$ | awk -v R=${radpat} '{print $0,R}' >> ${EQ}_label_SelectedFiles
		done < tmpfile2_$$

		rm -f tmpfile1_$$ tmpfile2_$$ tmpfile_common_label_$$ tmpfile_$$ tmpfile_label1_$$ tmpfile_label2_$$


		NSTA=`wc -l < ${EQ}_label_SelectedFiles`
		if [ ${NSTA} -eq 0 ]
		then
			echo "        Number of records: ${NSTA}..."
			continue
		fi

		# c. a none-"nan" SNR measurement.

		if [ ${UseSNR} -eq 1 ]
		then

			keys="<NETWK> <STNM> <SNR_${COMP}>"
			${BASHCODEDIR}/Findfield.sh ${SNRFile} "${keys}" | awk '{if ($3!="nan") print $1"_"$2,$3}' > tmpfile_$$

			awk '{print $1}' ${EQ}_label_SelectedFiles | sort > tmpfile_label1_$$
			awk '{print $1}' tmpfile_$$ | sort > tmpfile_label2_$$
			comm -1 -2 tmpfile_label1_$$ tmpfile_label2_$$ > tmpfile_common_label_$$

			${BASHCODEDIR}/Findrow.sh ${EQ}_label_SelectedFiles tmpfile_common_label_$$ > tmpfile1_$$
			${BASHCODEDIR}/Findrow.sh tmpfile_$$ tmpfile_common_label_$$ > tmpfile2_$$
			touch tmpfile2_$$

			rm -f ${EQ}_label_SelectedFiles
			while read label radpat
			do
				grep "^${label}\ " tmpfile1_$$ | awk -v R=${radpat} '{print $0,R}' >> ${EQ}_label_SelectedFiles
			done < tmpfile2_$$

			rm -f tmpfile1_$$ tmpfile2_$$ tmpfile_common_label_$$ tmpfile_$$ tmpfile_label1_$$ tmpfile_label2_$$

		else

			rm -f tmpfile_$$
			while read line
			do
				echo "${line} 100" >> tmpfile_$$
			done < ${EQ}_label_SelectedFiles
			mv tmpfile_$$ ${EQ}_label_SelectedFiles

		fi

		awk '{$1="";$3="";$4=""; print $0}' ${EQ}_label_SelectedFiles > ${EQ}_SelectedFiles

		# current columns in ${EQ}_SelectedFiles:
		# FileName,Gcarc,BeginTime,EndTime,radpat,snr(snr is only valid for ${COMP})

		NSTA=`wc -l < ${EQ}_SelectedFiles`
		if [ ${NSTA} -eq 0 ]
		then
			echo "        Number of records: ${NSTA}..."
			continue
		fi


		# D. Select SAC file time window coverage.
		#	 a. get ${Phase} arrivals of these stations.
		#	 b. select sac files completely cover this time window:
		#       | 3*TimeMin + PREM  <----> PREM + 3*TimeMax |

		# a.
		awk '{print $2}' ${EQ}_SelectedFiles > tmpfile_gcarc_$$

	${EXECDIR}/Interpolate.out 0 3 0 << EOF
${PhaseFile}
tmpfile_gcarc_$$
tmpfile_$$
EOF

		paste ${EQ}_SelectedFiles tmpfile_$$ > ${EQ}_SelectedFiles_Arrivals
		rm -f tmpfile_$$ tmpfile_gcarc_$$

		# b.
		awk -v T1=${TimeMin} -v T2=${TimeMax} '{if ($3<=$7+3*T1 && $7+3*T2<=$4) {$2="";$3="";$4="";print $0}}' ${EQ}_SelectedFiles_Arrivals > ${EQ}_SelectedFiles
		# current columns in ${EQ}_SelectedFiles:
		# FileName,radpat,snr,arrivals

		NSTA=`wc -l < ${EQ}_SelectedFiles`
		if [ ${NSTA} -eq 0 ]
		then
			echo "        Number of records: ${NSTA}..."
			continue
		fi


		# E. Get the right component from the ${EQ}_SelectedFiles for this task.
		awk '{print $1}' ${EQ}_SelectedFiles > ${EQ}_Files.txt

		# a. Choose file already exists for this component.
		#    (get the filenames exists both in ${EQ}_SelectedFiles and ${a01DIR}/${EQ}_FileList_${COMP})
		${BASHCODEDIR}/Findrow.sh ${a01DIR}/${EQ}_FileList_${COMP} ${EQ}_Files.txt > ${EQ}_List1
		${BASHCODEDIR}/Findrow.sh ${EQ}_SelectedFiles ${EQ}_List1 > ${EQ}_filename_radpat_snr_arrival_List1
		saclst kstnm knetwk f `cat ${EQ}_List1` > tmpfile_$$
		paste ${EQ}_filename_radpat_snr_arrival_List1 tmpfile_$$ | awk '{$5="";print $0}' > ${EQ}_List1
		rm -f tmpfile_$$
		# current columns in ${EQ}_List1:
		# FileName,radpat,snr,arrivals,kstnm,knetwk



		# b. Choose files needed to be rotated for getting this component.
		if [ ${COMP} = "T" ] || [ ${COMP} = "R" ]
		then
			${BASHCODEDIR}/Findrow.sh ${a01DIR}/${EQ}_FileList_E ${EQ}_Files.txt > tmpfile1_$$
			${BASHCODEDIR}/Findrow.sh ${a01DIR}/${EQ}_FileList_N ${EQ}_Files.txt > tmpfile2_$$

			# If for some stations, either E or N didn't pass the selection above,
			# throw away these stations.

			saclst kstnm knetwk f `cat tmpfile1_$$` | awk '{print $2"_"$3}' | sort  > tmpfile1_label_$$
			saclst kstnm knetwk f `cat tmpfile2_$$` | awk '{print $2"_"$3}' | sort  > tmpfile2_label_$$
			comm -1 -2 tmpfile1_label_$$ tmpfile2_label_$$ > tmpfile_keep_label_$$

			saclst kstnm knetwk f `cat tmpfile1_$$` | awk '{print $2"_"$3,$1}' > tmpfile1_label_file_$$
			saclst kstnm knetwk f `cat tmpfile2_$$` | awk '{print $2"_"$3,$1}' > tmpfile2_label_file_$$

			${BASHCODEDIR}/Findrow.sh tmpfile1_label_file_$$ tmpfile_keep_label_$$ | awk '{print $2}' > tmpfile1_$$
			${BASHCODEDIR}/Findrow.sh tmpfile2_label_file_$$ tmpfile_keep_label_$$ | awk '{print $2}' > tmpfile2_$$


			# Deal with rotation npts problem.

			saclst npts f `cat tmpfile1_$$` > tmpfile3_$$
			saclst kstnm knetwk npts f `cat tmpfile2_$$` > tmpfile4_$$
			${BASHCODEDIR}/Findrow.sh ${EQ}_SelectedFiles tmpfile1_$$ | awk '{$1="";print $0}' > tmpfile2_$$
			paste tmpfile2_$$ tmpfile3_$$ tmpfile4_$$ > ${EQ}_List2
			# current columns in ${EQ}_List2:
			# radpat,snr,arrivals,fileE,nptsE,fileN,kstnm,knetwk,nptsN


			rm -f tmpfile1_$$ tmpfile2_$$ tmpfile3_$$ tmpfile4_$$ tmpfile1_label_$$ tmpfile2_label_$$ tmpfile1_label_file_$$ tmpfile2_label_file_$$ tmpfile_keep_label_$$

			[ ${COMP} = "R" ] && ReadIn="junk.R" || ReadIn="junk.T"

		fi

		touch ${EQ}_List2
		NSTA1=`wc -l < ${EQ}_List1`
		NSTA2=`wc -l < ${EQ}_List2`
		NSTA=$((NSTA1+NSTA2))
		#echo "        Number of stations: ${NSTA}..."

		if [ ${NSTA} -eq 0 ]
		then
			continue
		fi


		# F. Process data (to sac format) in ${EQ}_List1.
		rm -f ${EQ}_SACMacro1.m ${EQ}_ESW_infile ${EQ}_eq_netwk_stnm
		while read filename radpat snr arrival stnm netwk
		do

			T1=`echo "${arrival}+3*${TimeMin}" | bc -l`
			T2=`echo "${arrival}+3*${TimeMax}" | bc -l`
			echo "${EQ}.${netwk}.${stnm}.sac ${netwk} ${stnm} ${radpat} ${snr}" >> ${EQ}_ESW_infile
			echo "${EQ} ${netwk} ${stnm} ${arrival}" >> ${EQ}_eq_netwk_stnm

			cat >> ${EQ}_SACMacro1.m << EOF
cut off
r ${filename}
rmean
rtr
taper
${SACCommand}
interp d ${Delta_ESW}
w junk.sac
cut O ${T1} ${T2}
r junk.sac
w ${EQ}.${netwk}.${stnm}.sac
EOF
		done < ${EQ}_List1

		if [ -s "${EQ}_SACMacro1.m" ]
		then

			sac >/dev/null 2>&1  << EOF
m ${EQ}_SACMacro1.m
q
EOF
			rm -f junk.sac
		fi

		# F*. Process data (to sac format) in ${EQ}_List2, for COMP="R" or "T".
		if [ ${COMP} = "T" ] || [ ${COMP} = "R" ]
		then

			rm -f ${EQ}_SACMacro2.m
			while read radpat snr arrival Efile ENpts Nfile stnm netwk NNpts
			do
				if [ ${ENpts} -ge ${NNpts} ]
				then
					SACCut="cut b n ${NNpts}"
				else
					SACCut="cut b n ${ENpts}"
				fi

				T1=`echo "${arrival}+3*${TimeMin}" | bc -l`
				T2=`echo "${arrival}+3*${TimeMax}" | bc -l`
				echo "${EQ}.${netwk}.${stnm}.sac ${netwk} ${stnm} ${radpat} ${snr}" >> ${EQ}_ESW_infile
			    echo "${EQ} ${netwk} ${stnm} ${arrival}" >> ${EQ}_eq_netwk_stnm

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
interp d ${Delta_ESW}
w junk.sac
cut O ${T1} ${T2}
r junk.sac
w ${EQ}.${netwk}.${stnm}.sac
EOF
			done < ${EQ}_List2

			if [ -s "${EQ}_SACMacro2.m" ]
			then

				sac >/dev/null 2>&1 << EOF
m ${EQ}_SACMacro2.m
q
EOF
				rm -f junk.sac junk.R junk.T
			fi
		fi

		# G. Make ESW from the cut (therefore aligned) SAC data.
		${EXECDIR}/ESW.out 0 6 6 << EOF
${EQ}
${EQ}_ESW_infile
tmpfile_out_$$
tmpfile_badlist_$$
${OUTFILE_ESW}
tmpfile_NSTA_$$
${TimeMin}
${TimeMax}
${PREMBias}
${NBegin}
${NEnd}
${Delta_ESW}
EOF

		if [ $? -ne 0 ]
		then
			echo "    !=> ESW.out C++ code failed on ${EQ}, line ${Num} ..."
			rm -f ${a15DIR}/${EQ}* ${OUTFILE}
			exit 1
		fi

		echo "<EQ> <NETWK> <STNM> <Arrival> <DT> <CCC> <Weight> <PeakTime> <PeakAmp>" > ${OUTFILE}
		while read nt st
		do
			grep -v "${nt} ${st}" ${EQ}_eq_netwk_stnm > tmpfile_$$
			mv tmpfile_$$ ${EQ}_eq_netwk_stnm
		done < tmpfile_badlist_$$
		paste ${EQ}_eq_netwk_stnm tmpfile_out_$$ >> ${OUTFILE}
		read NSTA < tmpfile_NSTA_$$
		rm -f tmpfile_out_$$ tmpfile_NSTA_$$

		# H. Plot. (GMT-4)
		if [ ${GMTVERSION} -eq 4 ]
		then

			# basic gmt settings
			gmtset PAPER_MEDIA = letter
			gmtset ANNOT_FONT_SIZE_PRIMARY = 12p
			gmtset LABEL_FONT_SIZE = 16p
			gmtset LABEL_OFFSET = 0.1i
			gmtset BASEMAP_FRAME_RGB = +0/0/0
			gmtset GRID_PEN_PRIMARY = 0.5p,gray,-


			# plot title and tag.

			pstext -JX8.5i/1i -R-100/100/-1/1 -N -X0i -Y9.5i -P -K > ${PLOTFILE} << EOF
0 1 20 0 0 CB Event: ${MM}/${DD}/${YYYY} ${HH}:${MIN} ESW NetWork: ${NETWK} Phase: ${Phase} Comp: ${COMP}
0 0.5 12 0 0 CB @;red;${FrequencyContent}@;;
0 0 15  0 0 CB ${EQ} LAT=${EVLA} LON=${EVLO} Z=${EVDP} Mb=${MAG} NSTA=${NSTA}/${NSTA_All}
EOF
			pstext -J -R -N -Wored -G0 -Y-0.5i -O -K >> ${PLOTFILE} << EOF
0 0.5 10 0 0 CB SCRIPT: `basename ${0}` `date "+CREATION DATE: %m/%d/%y  %H:%M:%S"`
EOF

			# plot projection.
			PROJ="-JX6.5i/3.3i"
			REG="-R${TimeMin}/${TimeMax}/-1.5/1.5"


			# plot horizontal grid.
			rm -f tmpfile_$$

			for Y in `seq -1.4 0.1 1.5`
			do
				printf ">\n%f %f\n%f %f\n" ${TimeMin} ${Y} ${TimeMax} ${Y} >> tmpfile_$$
			done

			psxy tmpfile_$$ ${PROJ} ${REG} -m -Wthin,200/200/200,- -X1.1i -Y-3i -K -O >> ${PLOTFILE}
			rm -f tmpfile_$$


			# plot Std of Stack 2.
			keys="<Time> <Stack2> <Std>"
			${BASHCODEDIR}/Findfield.sh ${OUTFILE_ESW} "${keys}" | awk '{print $1,$2+$3}' > tmpfile1_$$
			${BASHCODEDIR}/Findfield.sh ${OUTFILE_ESW} "${keys}" | awk '{print $1,$2-$3}' | tac > tmpfile2_$$
			cat tmpfile1_$$ tmpfile2_$$ | psxy ${PROJ} ${REG} -G200/200/200 -L -N -K -O >> ${PLOTFILE}
			rm -f tmpfile1_$$ tmpfile2_$$


			# plot Zero line.
			psxy -J -R -W1p,yellow -O -K >> ${PLOTFILE} << EOF
${TimeMin} 0
${TimeMax} 0
EOF

			# plot Stack 1.
			keys="<Time> <Stack1>"
			${BASHCODEDIR}/Findfield.sh ${OUTFILE_ESW} "${keys}" | psxy -J -R -W1p,black -O -K >> ${PLOTFILE}

			# plot Stack 2.
			keys="<Time> <Stack2>"
			${BASHCODEDIR}/Findfield.sh ${OUTFILE_ESW} "${keys}" | psxy -J -R -W2p,red -K -O >> ${PLOTFILE}

			# plot lengends.

			psxy -J -R-20/20/-20/20 -W2p,red -O -K >> ${PLOTFILE} << EOF
10 -9
14 -9
EOF
			psxy -J -R -W1p,black -O -K >> ${PLOTFILE} << EOF
10 -11
14 -11
EOF
			psxy -J -R -G200/200/200 -L -N -O -K >> ${PLOTFILE} << EOF
10 -12.5
14 -12.5
14 -14.5
10 -14.5
EOF
			pstext -J -R -O -K >> ${PLOTFILE} << EOF
15 -9 10 0 0 LM 2nd Stack
15 -11 10 0 0 LM 1st Stack
15 -13.5 11 0 12 LM \261 1 \163
EOF


			# plot basemap.
			XAXIS="a5f1"
			YAXIS="a0.5f0.1"
			XLABEL="Relative time (sec)"
			YLABEL="Relative ampiltude"

			psbasemap ${PROJ} ${REG} -B${XAXIS}:"${XLABEL}":/${YAXIS}:"${YLABEL}":SW -O -K >> ${PLOTFILE}


			# plot histogram CCC.
			keys="<CCC>"
			${BASHCODEDIR}/Findfield.sh ${OUTFILE} "${keys}" > tmpfile_ccc_$$

			XINC=0.05
			pshistogram tmpfile_ccc_$$ -W${XINC} -IO > ${EQ}_Count_CCC

			XMIN="-1"
			XMAX=1
			XNUM=0.5

			YMIN=0
			YMAX=`minmax -C ${EQ}_Count_CCC | awk '{print $4}'`
			YMAX=` echo ${YMAX} | awk '{if ($1<45) print 45; else print 10*int(1.2*$1/10) }' `
			YNUM=` echo ${YMAX} | awk '{if ($1<100) print 20; else print 20*int(1.0*$1/100.0)}' `
			YINC=` echo ${YNUM} | awk '{print int(1.0*$1/2.0)}' `

			XLABEL='Cross correlation coefficient between each record and the 2nd stack'
			YLABEL="Frequency"

			psbasemap -Ba${XNUM}f${XINC}:"${XLABEL}":/a${YNUM}f${YINC}g${YNUM}:"${YLABEL}":WS \
			-R${XMIN}/${XMAX}/${YMIN}/${YMAX} -JX6.5i/1.5i -Y-2.5i -O -K >> ${PLOTFILE}

			pshistogram tmpfile_ccc_$$ -R -J -W${XINC} -L0.5p -G50/50/250 -O -K >> ${PLOTFILE}
			rm -f tmpfile_ccc_$$


			# plot histogram DT.
			keys="<DT>"
			${BASHCODEDIR}/Findfield.sh ${OUTFILE} "${keys}" > tmpfile_dt_$$

			XINC=1
			pshistogram tmpfile_dt_$$ -W${XINC} -IO > ${EQ}_Count_DT

			XMIN="${TimeMin}"
			XMAX="${TimeMax}"
			XNUM="5"

			YMIN=0
			YMAX=`minmax -C ${EQ}_Count_DT | awk '{print $4}'`
			YMAX=` echo ${YMAX} | awk '{if ($1<45) print 45; else print 10*int(1.2*$1/10) }' `
			YNUM=` echo ${YMAX} | awk '{if ($1<100) print 20; else print 20*int(1.0*$1/100.0)}' `
			YINC=` echo ${YNUM} | awk '{print int(1.0*$1/2.0)}' `

			XLABEL='Time shift of each record to construct the 2nd stack (sec)'
			YLABEL="Frequency"

			psbasemap -Ba${XNUM}f${XINC}:"${XLABEL}":/a${YNUM}f${YINC}g${YNUM}:"${YLABEL}":WS \
			-R${XMIN}/${XMAX}/${YMIN}/${YMAX} -JX6.5i/1.5i -Y-2.5i -O -K >> ${PLOTFILE}

			pshistogram tmpfile_dt_$$ -R -J -W${XINC} -L0.5p -G50/50/250 -O >> ${PLOTFILE}

			rm -f tmpfile_dt_$$

		fi


		# H*. Plot. (GMT-5)
		if [ ${GMTVERSION} -eq 5 ]
		then

			# basic gmt settings
			gmt gmtset PS_MEDIA letter
			gmt gmtset FONT_ANNOT_PRIMARY 12p
			gmt gmtset FONT_LABEL 16p
			gmt gmtset MAP_LABEL_OFFSET 0.1i
			gmt gmtset MAP_FRAME_PEN black
			gmt gmtset MAP_GRID_PEN_PRIMARY 0.5p,gray,-


			# plot title and tag.

			cat > ${EQ}_plottext.txt << EOF
0 1 Event: ${MM}/${DD}/${YYYY} ${HH}:${MIN} ESW Phase: ${Phase} Comp: ${COMP}
0 0.5 @:12:@;red;${FrequencyContent}@;;@::
0 0 @:15:${EQ} LAT=${EVLA} LON=${EVLO} Z=${EVDP} Mb=${MAG} NSTA=${NSTA}/${NSTA_All}@::
EOF
			gmt pstext ${EQ}_plottext.txt -JX8.5i/1i -R-100/100/-1/1 -F+jCB+f20p,Helvetica,black -N -Xf0i -Y9.5i -P -K > ${PLOTFILE}

			cat > ${EQ}_plottext.txt << EOF
0 0.5 SCRIPT: `basename ${0}` `date "+CREATION DATE: %m/%d/%y  %H:%M:%S"`
EOF
			gmt pstext ${EQ}_plottext.txt -J -R -F+jCB+f10p,Helvetica,black -N -Wred -Y-0.5i -O -K >> ${PLOTFILE}


			# plot projection.
			PROJ="-JX6.5i/3.3i"
			REG="-R${TimeMin}/${TimeMax}/-1.5/1.5"


			# plot horizontal grid.
			rm -f tmpfile_$$

			for Y in `seq -1.4 0.1 1.5`
			do
				printf ">\n%f %f\n%f %f\n" ${TimeMin} ${Y} ${TimeMax} ${Y} >> tmpfile_$$
			done

			gmt psxy tmpfile_$$ ${PROJ} ${REG} -Wthin,200/200/200,- -X1.1i -Y-3i -K -O >> ${PLOTFILE}
			rm -f tmpfile_$$


			# plot Std of Stack 2.
			keys="<Time> <Stack2> <Std>"
			${BASHCODEDIR}/Findfield.sh ${OUTFILE_ESW} "${keys}" | gmt psxy ${PROJ} ${REG} -G200/200/200 -L+d -N -K -O >> ${PLOTFILE}


			# plot Zero line.
			gmt psxy -J -R -W1p,yellow -O -K >> ${PLOTFILE} << EOF
${TimeMin} 0
${TimeMax} 0
EOF

			# plot Stack 1.
			keys="<Time> <Stack1>"
			${BASHCODEDIR}/Findfield.sh ${OUTFILE_ESW} "${keys}" | gmt psxy -J -R -W1p,black -O -K >> ${PLOTFILE}

			# plot Stack 2.
			keys="<Time> <Stack2>"
			${BASHCODEDIR}/Findfield.sh ${OUTFILE_ESW} "${keys}" | gmt psxy -J -R -W2p,red -K -O >> ${PLOTFILE}

			# plot lengends.

			gmt psxy -J -R-20/20/-20/20 -W2p,red -O -K >> ${PLOTFILE} << EOF
10 -9
14 -9
EOF
			gmt psxy -J -R -W1p,black -O -K >> ${PLOTFILE} << EOF
10 -11
14 -11
EOF
			gmt psxy -J -R -G200/200/200 -L -N -O -K >> ${PLOTFILE} << EOF
10 -12.5
14 -12.5
14 -14.5
10 -14.5
EOF
			cat > ${EQ}_plottext.txt << EOF
15 -9 2nd Stack
15 -11 1st Stack
15 -13.5 @:11: @%12%\261@%% 1 @%12%\163@%% @::
EOF
			gmt pstext ${EQ}_plottext.txt -J -R -F+jLM+f10p,Helvetica,black -N -O -K >> ${PLOTFILE}


			# plot basemap.
			XAXIS="a5f1"
			YAXIS="a0.5f0.1"
			XLABEL="Relative time (sec)"
			YLABEL="Relative ampiltude"

			gmt psbasemap ${PROJ} ${REG} -B${XAXIS}:"${XLABEL}":/${YAXIS}:"${YLABEL}":SW -O -K >> ${PLOTFILE}


			# plot histogram CCC.
			keys="<CCC>"
			${BASHCODEDIR}/Findfield.sh ${OUTFILE} "${keys}" > tmpfile_ccc_$$

			XINC=0.05
			gmt pshistogram tmpfile_ccc_$$ -W${XINC} -IO > ${EQ}_Count_CCC

			XMIN="-1"
			XMAX=1
			XNUM=0.5

			YMIN=0
			YMAX=`minmax -C ${EQ}_Count_CCC | awk '{print $4}'`
			YMAX=` echo ${YMAX} | awk '{if ($1<45) print 45; else print 10*int(1.2*$1/10) }' `
			YNUM=` echo ${YMAX} | awk '{if ($1<100) print 20; else print 20*int(1.0*$1/100.0)}' `
			YINC=` echo ${YNUM} | awk '{print int(1.0*$1/2.0)}' `

			XLABEL='Cross correlation coefficient between each record and the 2nd stack'
			YLABEL="Frequency"

			gmt psbasemap -Ba${XNUM}f${XINC}:"${XLABEL}":/a${YNUM}f${YINC}g${YNUM}:"${YLABEL}":WS \
			-R${XMIN}/${XMAX}/${YMIN}/${YMAX} -JX6.5i/1.5i -Y-2.5i -O -K >> ${PLOTFILE}

			gmt pshistogram tmpfile_ccc_$$ -R -J -W${XINC} -L0.5p -G50/50/250 -O -K >> ${PLOTFILE}
			rm -f tmpfile_ccc_$$


			# plot histogram DT.
			keys="<DT>"
			${BASHCODEDIR}/Findfield.sh ${OUTFILE} "${keys}" > tmpfile_dt_$$

			XINC=1
			gmt pshistogram tmpfile_dt_$$ -W${XINC} -IO > ${EQ}_Count_DT

			XMIN="${TimeMin}"
			XMAX="${TimeMax}"
			XNUM="5"

			YMIN=0
			YMAX=`minmax -C ${EQ}_Count_DT | awk '{print $4}'`
			YMAX=` echo ${YMAX} | awk '{if ($1<45) print 45; else print 10*int(1.2*$1/10) }' `
			YNUM=` echo ${YMAX} | awk '{if ($1<100) print 20; else print 20*int(1.0*$1/100.0)}' `
			YINC=` echo ${YNUM} | awk '{print int(1.0*$1/2.0)}' `

			XLABEL='Time shift of each record to construct the 2nd stack (sec)'
			YLABEL="Frequency"

			gmt psbasemap -Ba${XNUM}f${XINC}:"${XLABEL}":/a${YNUM}f${YINC}g${YNUM}:"${YLABEL}":WS \
			-R${XMIN}/${XMAX}/${YMIN}/${YMAX} -JX6.5i/1.5i -Y-2.5i -O -K >> ${PLOTFILE}

			gmt pshistogram tmpfile_dt_$$ -R -J -W${XINC} -L0.5p -G50/50/250 -O >> ${PLOTFILE}

			rm -f tmpfile_dt_$$

		fi

# 		bash ${SRCDIR}/a15.EmpiricalSourceWavelets_Catalogue.sh

	done < ${OUTDIR}/tmpfile_PhaseESW_${RunNumber}

done # End of EQ loop.

cd ${OUTDIR}

exit 0
