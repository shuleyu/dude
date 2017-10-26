#!/bin/bash

# ====================================================================
# This script plot aligned profile.
#
# Ed Garnero/Pei-Ying(Patty) Lin/Shule Yu
# ====================================================================

echo ""
echo "--> `basename $0` is running. `date`"
mkdir -p ${a17DIR}
cd ${a17DIR}

# ==================================================
#              ! Work Begin !
# ==================================================

for EQ in `cat ${OUTDIR}/tmpfile_EQs_${RunNumber}`
do

	# Ctrl+C action.
	trap "rm -f ${a17DIR}/${EQ}* ${a17DIR}/tmpfile*$$ ${OUTDIR}/*_${RunNumber}; exit 1" SIGINT

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
	while read PlotGap Phase COMP UseSNR DistMin DistMax F1 F2 NETWK TimeMin TimeMax TravelCurve PlotOrient
	do
		Num=$((Num+1))
		PLOTFILE=${PLOTDIR}/${EQ}.`basename ${0%.sh}`_${Num}.ps
		INFILE=${a15DIR}/${EQ}_${Phase}_${COMP}_${UseSNR}_${DistMin}_${DistMax}_${F1}_${F2}_${NETWK}.List

		# A**. Check a15 ESW file.
		if ! [ -s ${INFILE} ] || [ `wc -l < ${INFILE}` -eq 1 ]
		then
			echo "    ~=> ${EQ} can't find a15 result file on Line ${Num}..."
			continue
		else
			echo "    ==> Making AlignedProfileComb plot(s) of ${EQ}, Line ${Num}..."
		fi

		trap "rm -f ${a17DIR}/${EQ}* ${PLOTFILE} ${a17DIR}/tmpfile*$$ ${OUTDIR}/*_${RunNumber}; exit 1" SIGINT

		# Clean dir.
		rm -f ${a17DIR}/${EQ}*

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
		keys="<FileName> <NETWK> <STNM> <Gcarc> <BeginTime> <EndTime>"
		${BASHCODEDIR}/Findfield.sh ${a01DIR}/${EQ}_FileList_Info "${keys}" \
		| awk -v N=${NETWK} '{if (N=="AllSt" || (N!="AllSt" && $2==N)) print $0}' \
		| awk -v D1=${PhaseDistMin} -v D2=${PhaseDistMax} '{if (D1<=$4 && $4<=D2) print $0}' \
		| awk -v D1=${DistMin} -v D2=${DistMax} '{if (D1<=$4 && $4<=D2) {A=$0;print $2"_"$3" "A}}' \
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
		awk '{$2="";$3="";$4="";print $0}' ${EQ}_SelectedFiles_Arrivals > ${EQ}_SelectedFiles
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


			rm -f tmpfile1_$$ tmpfile2_$$ tmpfile3_$$ tmpfile4_$$ tmpfile1_label_$$ tmpfile2_label_$$ tmpfile1_label_file_$$ tmpfile2_label_file_$$

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

		# E*. Only get the stations in a15 result in List1 & List2.
		keys="<NETWK> <STNM>"
		${BASHCODEDIR}/Findfield.sh ${INFILE} "${keys}" | awk '{print $1"_"$2}' > tmpfile_label_$$

		awk '{print $6"_"$5,$0}' ${EQ}_List1 > tmpfile_label_list1_$$
		awk '{print $8"_"$7,$0}' ${EQ}_List2 > tmpfile_label_list2_$$

		${BASHCODEDIR}/Findrow.sh tmpfile_label_list1_$$ tmpfile_label_$$ \
		| awk '{$1="";$3="";$4=""; print $0}' > ${EQ}_List1

		${BASHCODEDIR}/Findrow.sh tmpfile_label_list2_$$ tmpfile_label_$$ \
		| awk '{$1="";$2="";$3=""; print $0}' > ${EQ}_List2

		# Current columns in ${EQ}_List1 ${EQ}_List2:
		# FileName,arrivals,kstnm,knetwk
		# arrivals,fileE,nptsE,fileN,kstnm,knetwk,nptsN


		# F. Process data (to sac format) in ${EQ}_List1.
		rm -f ${EQ}_SACMacro1.m ${EQ}_label_filename.txt
		while read filename cutcenter stnm netwk
		do

			T1=`echo "${cutcenter}+${TimeMin}" | bc -l`
			T2=`echo "${cutcenter}+${TimeMax}" | bc -l`
			echo "${netwk}_${stnm} ${EQ}.${netwk}.${stnm}.sac" >> ${EQ}_label_filename.txt

			cat >> ${EQ}_SACMacro1.m << EOF
cut off
r ${filename}
rmean
rtr
taper
${SACCommand}
interp d ${Delta_APC}
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
			while read cutcenter Efile ENpts Nfile stnm netwk NNpts
			do
				if [ ${ENpts} -ge ${NNpts} ]
				then
					SACCut="cut b n ${NNpts}"
				else
					SACCut="cut b n ${ENpts}"
				fi

				T1=`echo "${cutcenter}+${TimeMin}" | bc -l`
				T2=`echo "${cutcenter}+${TimeMax}" | bc -l`
				echo "${netwk}_${stnm} ${EQ}.${netwk}.${stnm}.sac" >> ${EQ}_label_filename.txt

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
interp d ${Delta_APC}
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

		# G. Integrate the shift time, weight to ${EQ}_label_filename.txt.
		#    Also, the gcarc of each station.
		keys="<NETWK> <STNM> <DT> <Weight>"
		${BASHCODEDIR}/Findfield.sh ${INFILE} "${keys}" | awk '{print $1"_"$2,$3,$4}' > tmpfile_label_dt_weight_$$

		awk '{print $1}' ${EQ}_label_filename.txt > tmpfile_label_$$
		${BASHCODEDIR}/Findrow.sh tmpfile_label_dt_weight_$$ tmpfile_label_$$ > tmpfile_$$
		paste ${EQ}_label_filename.txt tmpfile_$$ > tmpfile_label_filename_label_dt_weight_$$
		awk '{print $2,$4,$5}' tmpfile_label_filename_label_dt_weight_$$ > ${EQ}_in_$$

		awk '{print $1}' ${EQ}_in_$$ > tmpfile_filename_$$
		saclst gcarc f `cat tmpfile_filename_$$` | awk '{print $2}' > tmpfile_gcarc_$$
		paste ${EQ}_in_$$ tmpfile_gcarc_$$ | sort -k 4,4 > ${EQ}_AlignedIn_$$
		# current columns in ${EQ}_AlignedIn_$$
		# FileName,dt,weight,gcarc
		rm -f tmpfile*$$


		# tighten the Distance range, take amplitude in consideration.
		[ ${PlotOrient} = "Portrait" ] && PlotHeight=8.5 || PlotHeight=6
		awk '{print $4}' ${EQ}_AlignedIn_$$ | minmax -C | awk -v D=${Amplitude_APC} -v P=${PlotHeight} '{X=(D*($2-$1))/(P-2*D);$1-=X;$2+=X; print $0}' > tmpfile_$$
		read DISTMIN DISTMAX < tmpfile_$$
        if [ `echo "${DISTMIN}==${DISTMAX}"|bc` -eq 1 ]
        then
            DISTMIN=`echo "${DISTMIN}" | awk '{print $1-1}'`
            DISTMAX=`echo "${DISTMAX}" | awk '{print $1+1}'`
        fi
		AmpScale=`echo "${Amplitude_APC}/${PlotHeight}*(${DISTMAX}- ${DISTMIN})" | bc -l`
		rm -f tmpfile_$$


		# H. Make Plot file.

		${EXECDIR}/AlignedProfileComb.out 0 3 4 << EOF
${EQ}_AlignedIn_$$
${EQ}_PlotFile.txt
${EQ}_ValidTraceNum.txt
${AmpScale}
${TimeMin}
${Delta_APC}
${PlotGap}
EOF

		if [ $? -ne 0 ]
		then
			echo "    !=> AlignedProfileComb.out C++ code failed on ${EQ}, line ${Num} ..."
			rm -f ${a17DIR}/${EQ}* ${OUTFILE}
			exit 1
		fi

		read NSTA < ${EQ}_ValidTraceNum.txt


		# I. prepare travel times.

		# prepare travel time curves files.

		[ `echo "${EVDP}<50"|bc` -eq 1 ] && DepthPhase="[[:upper:]]" || DepthPhase=""

		# (uncomment this line to plot all phase disregard of event depth.)
# 		DepthPhase=""

		case "${TravelCurve}" in
			NO | ALL )
				ls ${a05DIR}/${EQ}_*_${DepthPhase}*.gmt > ${EQ}_PhaseArrivalFiles.txt
				;;
			* )
				ls ${a05DIR}/${EQ}_*${TravelCurve}*_${DepthPhase}*.gmt > ${EQ}_PhaseArrivalFiles.txt
				;;
		esac

		# get a Phase-Shifted version of these traveltime curves.

		rm -f tmpfile_$$
		for file in `cat ${EQ}_PhaseArrivalFiles.txt`
		do
			NewFile=`basename ${file}`
			echo "${NewFile}" >> tmpfile_$$

			awk '{print $1}' ${file} > ${EQ}_gcarc_$$
			${EXECDIR}/Interpolate.out 0 3 0 << EOF
${PhaseFile}
${EQ}_gcarc_$$
${EQ}_FirstArrival_$$
EOF
			paste ${file} ${EQ}_FirstArrival_$$ | grep -v "nan" | awk '{printf "%.3lf %.3lf\n",$1,$2-$3}' > ${NewFile}

			awk '{print $1}' ${file}_Enveloped > ${EQ}_gcarc_$$
			${EXECDIR}/Interpolate.out 0 3 0 << EOF
${PhaseFile}
${EQ}_gcarc_$$
${EQ}_FirstArrival_$$
EOF
			paste ${file}_Enveloped ${EQ}_FirstArrival_$$ | grep -v "nan" | awk '{printf "%.3lf %.3lf\n",$1,$2-$3}' > ${NewFile}_Enveloped


		done

		mv tmpfile_$$ ${EQ}_PhaseArrivalFiles.txt


		# set travel time color.

		cat > ${EQ}_PlotPen.txt << EOF
P    100/100/255
PSV  160/255/160
SV   255/160/160
SVSH 255/100/100
SH   255/130/130
EOF

		# prepare travel time texts.
		rm -f ${EQ}_Phases.txt
		touch ${EQ}_Phases.txt
		for file in `cat ${EQ}_PhaseArrivalFiles.txt`
		do
			Polarity=`basename ${file}`
			PhaseName=${Polarity##*_}
			PhaseName=${PhaseName%.gmt}
			Polarity=${Polarity#*_}
			Polarity=${Polarity%%_*}
			TextColor=`grep -w ${Polarity} ${EQ}_PlotPen.txt | awk '{print $2}'`

			# get a random plot position.
			${EXECDIR}/TextPosition.out 0 2 4 << EOF
${file}_Enveloped
tmpfile_$$
${TimeMin}
${TimeMax}
${DISTMIN}
${DISTMAX}
EOF
			if [ $? -ne 0 ]
			then
				echo "    !=> TextPosition.out C++ code failed on ${EQ}, plot ${Num} ..."
				rm -f ${a09DIR}/${EQ}* tmpfile_$$ ${PLOTFILE}
				exit 1
			fi

			read X Y < tmpfile_$$
			! [ -z "${X}" ] && echo "${X} ${Y} 12 0 22 LM @;${TextColor};${PhaseName}@;;" >> ${EQ}_Phases.txt

		done
		rm -f tmpfile_$$


		# h. plot. (GMT-4)
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
			[ ${PlotOrient} = "Portrait" ] && XSIZE=8.5 || XSIZE=11
			[ ${PlotOrient} = "Portrait" ] && Ori="-P" || Ori=""
			[ ${PlotOrient} = "Portrait" ] && YP="-Y9.5i" || YP="-Y7i"

			pstext -JX${XSIZE}i/1i -R-100/100/-1/1 -N -X0i ${YP} ${Ori} -K > ${PLOTFILE} << EOF
0 1 20 0 0 CB Event: ${MM}/${DD}/${YYYY} ${HH}:${MIN} NetWork: ${NetWork} Comp: ${COMP}
0 0.5 12 0 0 CB @;red;${FrequencyContent}@;;
0 0 15  0 0 CB ${EQ} LAT=${EVLA} LON=${EVLO} Z=${EVDP} Mb=${MAG} NSTA=${NSTA}/${NSTA_All}
EOF
			pstext -J -R -N -Wored -G0 -Y-0.5i -O -K >> ${PLOTFILE} << EOF
0 0.5 10 0 0 CB SCRIPT: `basename ${0}` `date "+CREATION DATE: %m/%d/%y  %H:%M:%S"`
EOF

			# plot basemap.
			[ ${PlotOrient} = "Portrait" ] && PROJ="-JX6.5i/-${PlotHeight}i" || PROJ="-JX9i/-${PlotHeight}i"

			[ `echo "(${TimeMax}- ${TimeMin})>2000" | bc` -eq 1 ] && XAXIS="a500f100"
			[ `echo "(${TimeMax}- ${TimeMin})<=2000" | bc` -eq 1 ] && XAXIS="a200f20"
			[ `echo "(${TimeMax}- ${TimeMin})<1000" | bc` -eq 1 ] && XAXIS="a100f10"
			XLABEL="Time after shifted ${Model_TT} ${Phase}-wave time (sec)"

			[ `echo "(${DISTMAX}- ${DISTMIN})>5" | bc` -eq 1 ] && YAXIS=`echo ${DISTMIN} ${DISTMAX} | awk '{print (int(int(($2-$1)/10)/5)+1)*5 }' |  awk '{print "a"$1"f"$1/5}'`
			[ `echo "(${DISTMAX}- ${DISTMIN})<=5" | bc` -eq 1 ] && YAXIS="a0.5f0.1"
			[ `echo "(${DISTMAX}- ${DISTMIN})<1" | bc` -eq 1 ] && YAXIS="a0.1f0.1"
			YLABEL="Distance (deg)"

			[ ${PlotOrient} = "Portrait" ] && XP="-X1.2i" || XP="-X1.2i"
			[ ${PlotOrient} = "Portrait" ] && YP="-Y-8i" || YP="-Y-5.5i"

			REG="-R${TimeMin}/${TimeMax}/${DISTMIN}/${DISTMAX}"

			psbasemap ${PROJ} ${REG} -B${XAXIS}:"${XLABEL}":/${YAXIS}:"${YLABEL}":WSne ${XP} ${YP} -K -O >> ${PLOTFILE}

			# add travel time curve (or not). (_WithTC)
			cp ${PLOTFILE} ${PLOTFILE}_WithTC

			for file in `cat ${EQ}_PhaseArrivalFiles.txt`
			do
				Polarity=`basename ${file}`
				Polarity=${Polarity#*_}
				Polarity=${Polarity%%_*}
				PenColor=`grep -w ${Polarity} ${EQ}_PlotPen.txt | awk '{print $2}'`
				psxy ${file} -J -R -W1p/${PenColor} -: -K -O >> ${PLOTFILE}_WithTC
			done


			# plot seismogram.
			cp ${PLOTFILE}_WithTC ${PLOTFILE}_TCandText
			psxy ${EQ}_PlotFile.txt -J -R -W0.005i/0 -m -O >> ${PLOTFILE}
			psxy ${EQ}_PlotFile.txt -J -R -W0.005i/0 -m -O >> ${PLOTFILE}_WithTC


			# plot a arrival page, with phase name, without seismogram. (_TCandText)
			pstext ${EQ}_Phases.txt -J -R -N -O >> ${PLOTFILE}_TCandText


			# get rid of traveltime plots if we don't want plot it.
			[ ${TravelCurve} = "NO" ] && rm -f ${PLOTFILE}_WithTC ${PLOTFILE}_TCandText

		fi

		# h*. plot. (GMT-5)
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
			[ ${PlotOrient} = "Portrait" ] && XSIZE=8.5 || XSIZE=11
			[ ${PlotOrient} = "Portrait" ] && Ori="-P" || Ori=""
			[ ${PlotOrient} = "Portrait" ] && YP="-Yf9.5i" || YP="-Yf7i"


			cat > ${EQ}_plottext.txt << EOF
0 1 Event: ${MM}/${DD}/${YYYY} ${HH}:${MIN} NetWork: ${NetWork} Comp: ${COMP}
0 0.5 @:12:@;red;${FrequencyContent}@;;@::
0 0 @:15:${EQ} LAT=${EVLA} LON=${EVLO} Z=${EVDP} Mb=${MAG} NSTA=${NSTA}/${NSTA_All}@::
EOF
			gmt pstext ${EQ}_plottext.txt -JX${XSIZE}i/1i -R-100/100/-1/1 -F+jCB+f20p,Helvetica,black -N -Xf0i ${YP} ${Ori} -K > ${PLOTFILE}

			cat > ${EQ}_plottext.txt << EOF
0 0.5 SCRIPT: `basename ${0}` `date "+CREATION DATE: %m/%d/%y  %H:%M:%S"`
EOF
			gmt pstext ${EQ}_plottext.txt -J -R -F+jCB+f10p,Helvetica,black -N -Wred -Y-0.5i -O -K >> ${PLOTFILE}


			# plot basemap.
			[ ${PlotOrient} = "Portrait" ] && PROJ="-JX6.5i/-${PlotHeight}i" || PROJ="-JX9i/-${PlotHeight}i"

			[ `echo "(${TimeMax}- ${TimeMin})>2000" | bc` -eq 1 ] && XAXIS="a500f100"
			[ `echo "(${TimeMax}- ${TimeMin})<=2000" | bc` -eq 1 ] && XAXIS="a200f20"
			[ `echo "(${TimeMax}- ${TimeMin})<1000" | bc` -eq 1 ] && XAXIS="a100f10"
			XLABEL="Time after shifted ${Model_TT} ${Phase}-wave time (sec)"

			[ `echo "(${DISTMAX}- ${DISTMIN})>5" | bc` -eq 1 ] && YAXIS=`echo ${DISTMIN} ${DISTMAX} | awk '{print (int(int(($2-$1)/10)/5)+1)*5 }' |  awk '{print "a"$1"f"$1/5}'`
			[ `echo "(${DISTMAX}- ${DISTMIN})<=5" | bc` -eq 1 ] && YAXIS="a0.5f0.1"
			[ `echo "(${DISTMAX}- ${DISTMIN})<1" | bc` -eq 1 ] && YAXIS="a0.1f0.1"
			YLABEL="Distance (deg)"

			[ ${PlotOrient} = "Portrait" ] && XP="-X1.2i" || XP="-X1.2i"
			[ ${PlotOrient} = "Portrait" ] && YP="-Y-8i" || YP="-Y-5.5i"

			REG="-R${TimeMin}/${TimeMax}/${DISTMIN}/${DISTMAX}"

			gmt psbasemap ${PROJ} ${REG} -B${XAXIS}:"${XLABEL}":/${YAXIS}:"${YLABEL}":WSne ${XP} ${YP} -K -O >> ${PLOTFILE}


			# add travel time curve (or not). (_WithTC)
			cp ${PLOTFILE} ${PLOTFILE}_WithTC

			for file in `cat ${EQ}_PhaseArrivalFiles.txt`
			do
				Polarity=`basename ${file}`
				Polarity=${Polarity#*_}
				Polarity=${Polarity%%_*}
				PenColor=`grep -w ${Polarity} ${EQ}_PlotPen.txt | awk '{print $2}'`
				gmt psxy ${file} -J -R -W1p,${PenColor} -: -K -O >> ${PLOTFILE}_WithTC
			done


			# plot seismogram.
			cp ${PLOTFILE}_WithTC ${PLOTFILE}_TCandText
			gmt psxy ${EQ}_PlotFile.txt -J -R -W0.005i,black -O >> ${PLOTFILE}
			gmt psxy ${EQ}_PlotFile.txt -J -R -W0.005i,black -O >> ${PLOTFILE}_WithTC


			# plot a arrival page, with phase name, without seismogram. (_TCandText)
			awk '{print $1,$2,$7}' ${EQ}_Phases.txt > ${EQ}_plottext.txt
			gmt pstext ${EQ}_plottext.txt -J -R -F+jLM+f12p,Helvetica-Narrow-Bold,black -N -O >> ${PLOTFILE}_TCandText


			# get rid of traveltime plots if we don't want plot it.
			[ ${TravelCurve} = "NO" ] && rm -f ${PLOTFILE}_WithTC ${PLOTFILE}_TCandText

		fi


	done < ${OUTDIR}/tmpfile_APC_${RunNumber}

done # End of EQ loop.

cd ${OUTDIR}

exit 0
