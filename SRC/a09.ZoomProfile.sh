#!/bin/bash

# ====================================================================
# This script make profile plot of data.
#
# Ed Garnero/Pei-Ying(Patty) Lin/Shule Yu
# ====================================================================

echo ""
echo "--> `basename $0` is running. `date`"
mkdir -p ${a09DIR}
cd ${a09DIR}

# ==================================================
#              ! Work Begin !
# ==================================================


for EQ in `cat ${OUTDIR}/tmpfile_EQs_${RunNumber}`
do

	# Ctrl+C action.
	trap "rm -f ${a09DIR}/${EQ}* ${OUTDIR}/*_${RunNumber}; exit 1" SIGINT


	# A. Check the exist of list file.
	if ! [ -s "${a01DIR}/${EQ}_FileList" ]
	then
		echo "    ~=> ${EQ} doesn't have FileList ..."
		continue
	else
		echo "    ==> Making ZoomProfile plot(s) of ${EQ}."
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
	while read Phase COMP DISTMIN DISTMAX TIMEMIN TIMEMAX F1 F2 Normalize TravelCurve NetWork PlotOrient
	do
		Num=$((Num+1))
		PLOTFILE=${PLOTDIR}/${EQ}.`basename ${0%.sh}`_${Num}.ps

		# Check phase file.
		if ! [ -s "`ls ${a05DIR}/${EQ}_*_${Phase}.gmt_Enveloped 2>/dev/null`" ]
		then
			echo "        ~=> Plot ${Num}: can't find Firsta Arrival file !"
			continue
		else
			PhaseFile=`ls ${a05DIR}/${EQ}_*_${Phase}.gmt_Enveloped`
			PhaseDistMin=`minmax -C ${PhaseFile} | awk '{print $1}'`
			PhaseDistMax=`minmax -C ${PhaseFile} | awk '{print $2}'`
		fi


		if [ "${Normalize}" = Own ]
		then
			Normalize=1
		else
			Normalize=0
		fi


		# Clean dir.
		rm -f ${a09DIR}/${EQ}*

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


		# Ctrl+C action.
		trap "rm -f ${a09DIR}/${EQ}* ${PLOTFILE} ${OUTDIR}/*_${RunNumber}; exit 1" SIGINT


		# a. Select network and gcp distance window.
		keys="<FileName> <NETWK> <Gcarc> <BeginTime> <EndTime>"
		${BASHCODEDIR}/Findfield.sh ${a01DIR}/${EQ}_FileList_Info "${keys}" \
		| awk -v D1=${DISTMIN} -v D2=${DISTMAX} '{if (D1<=$3 && $3<=D2) print $0}' \
		| awk -v D1=${PhaseDistMin} -v D2=${PhaseDistMax} '{if (D1<=$3 && $3<=D2) print $0}' \
		| awk -v N=${NetWork} '{if (N=="AllSt") print $0; else if ($2==N) print $0}' \
		| sort -g -k 3,3 > ${EQ}_SelectedFiles


		# a*. select time window TIMEMIN TIMEMAX with respect to Phase arrival time.
		awk '{print $3}' ${EQ}_SelectedFiles > ${EQ}_gcarc_$$

		${EXECDIR}/Interpolate.out 0 3 0 << EOF
${PhaseFile}
${EQ}_gcarc_$$
${EQ}_FirstArrival_$$
EOF

		if [ $? -ne 0 ]
		then
			echo "    !=> Interpolate.out C++ code failed on ${EQ}, plot ${Num} ..."
			rm -f ${a09DIR}/${EQ}* ${PLOTFILE}
			exit 1
		fi

		paste ${EQ}_SelectedFiles ${EQ}_FirstArrival_$$ \
		| awk -v T1=${TIMEMIN} -v T2=${TIMEMAX} '{if (T2<=($4-$6) || T1>=($5-$6)) ; else print $1}' > tmpfile_$$

		mv tmpfile_$$ ${EQ}_SelectedFiles


		if ! [ -s "${EQ}_SelectedFiles" ]
		then
			echo "        ~=> No selected files for parameter line ${Num}..."
			continue
		fi


		# b. Choose file already exists for this component.
		#    (get the filenames exists both in ${EQ}_SelectedFiles and ${a01DIR}/${EQ}_FileList_${COMP})
		${BASHCODEDIR}/Findrow.sh ${a01DIR}/${EQ}_FileList_${COMP} ${EQ}_SelectedFiles > ${EQ}_List1
		saclst kstnm knetwk gcarc f `cat ${EQ}_List1` > tmpfile_$$

		sort -g -k 4,4 tmpfile_$$ > ${EQ}_List1
		rm -f tmpfile_$$

		# c. Choose files needed to be rotated for getting this component.
		if [ ${COMP} = "T" ] || [ ${COMP} = "R" ]
		then
			${BASHCODEDIR}/Findrow.sh ${a01DIR}/${EQ}_FileList_E ${EQ}_SelectedFiles > tmpfile1_$$
			${BASHCODEDIR}/Findrow.sh ${a01DIR}/${EQ}_FileList_N ${EQ}_SelectedFiles > tmpfile2_$$

			saclst npts f `cat tmpfile1_$$` > tmpfile3_$$
			saclst kstnm knetwk npts gcarc f `cat tmpfile2_$$` > tmpfile4_$$
			paste tmpfile3_$$ tmpfile4_$$ | sort -g -k 7,7 > ${EQ}_List2

			rm -f tmpfile*$$

			[ ${COMP} = "R" ] && ReadIn="junk.R" || ReadIn="junk.T"

		fi

		if [ ${COMP} = "E" ] || [ ${COMP} = "N" ]
		then
			${BASHCODEDIR}/Findrow.sh ${a01DIR}/${EQ}_FileList_R ${EQ}_SelectedFiles > tmpfile1_$$
			${BASHCODEDIR}/Findrow.sh ${a01DIR}/${EQ}_FileList_T ${EQ}_SelectedFiles > tmpfile2_$$

			saclst npts f `cat tmpfile1_$$` > tmpfile3_$$
			saclst kstnm knetwk npts gcarc f `cat tmpfile2_$$` > tmpfile4_$$
			paste tmpfile3_$$ tmpfile4_$$ | sort -g -k 7,7 > ${EQ}_List2

			rm -f tmpfile*$$

			[ ${COMP} = "E" ] && ReadIn="junk.E" || ReadIn="junk.N"

		fi


		# c*.get (by interpolate) the first arrival for this phase.
		awk '{print $4}' ${EQ}_List1 > ${EQ}_gcarc_$$

		${EXECDIR}/Interpolate.out 0 3 0 << EOF
${PhaseFile}
${EQ}_gcarc_$$
${EQ}_FirstArrival_$$
EOF


		if [ $? -ne 0 ]
		then
			echo "    !=> Interpolate.out C++ code failed on ${EQ}, plot ${Num} ..."
			rm -f ${a09DIR}/${EQ}* ${PLOTFILE}
			exit 1
		fi

		awk '{print $1,$2,$3}' ${EQ}_List1 > tmpfile_$$
		paste tmpfile_$$ ${EQ}_FirstArrival_$$ > ${EQ}_List1

		rm -f tmpfile_$$

		# c**.get (by interpolate) the first arrival for this phase.
		if [ -s "${EQ}_List2" ]
		then
			awk '{print $7}' ${EQ}_List2 > ${EQ}_gcarc_$$

			${EXECDIR}/Interpolate.out 0 3 0 << EOF
${PhaseFile}
${EQ}_gcarc_$$
${EQ}_FirstArrival_$$
EOF


			if [ $? -ne 0 ]
			then
				echo "    !=> Interpolate.out C++ code failed on ${EQ}, plot ${Num} ..."
				rm -f ${a09DIR}/${EQ}* ${PLOTFILE}
				exit 1
			fi

			awk '{$7=""; print $0}' ${EQ}_List2 > tmpfile_$$
			paste tmpfile_$$ ${EQ}_FirstArrival_$$ > ${EQ}_List2

			rm -f tmpfile_$$

		fi



		# d. Process data (to sac format) in ${EQ}_List1.
		rm -f ${EQ}_SACMacro1.m
		while read filename stnm netwk ArrivalTime
		do

			cat >> ${EQ}_SACMacro1.m << EOF
cut off
r ${filename}
rmean
rtr
taper
${SACCommand}
interp d ${Delta_ZP}
ch t1 ${ArrivalTime}
w junk.sac
cut t1 ${TIMEMIN} ${TIMEMAX}
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
			while read Efile ENpts Nfile stnm netwk NNpts ArrivalTime
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
interp d ${Delta_ZP}
ch t1 ${ArrivalTime}
w junk.sac
cut t1 ${TIMEMIN} ${TIMEMAX}
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
			while read Rfile RNpts Tfile stnm netwk TNpts ArrivalTime
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
interp d ${Delta_ZP}
ch t1 ${ArrivalTime}
w junk.sac
cut t1 ${TIMEMIN} ${TIMEMAX}
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
		saclst gcarc t1 f `ls ${EQ}*sac` > ${EQ}_PlotList_Gcarc


		# tighten the Distance range, take amplitude in consideration.
		[ ${PlotOrient} = "Portrait" ] && PlotHeight=8.5 || PlotHeight=6
		awk '{print $2}' ${EQ}_PlotList_Gcarc | minmax -C | awk -v D=${Amplitude_ZP} -v P=${PlotHeight} '{X=(D*($2-$1))/(P-2*D);$1-=X;$2+=X; print $0}' > tmpfile_$$
		read DISTMIN DISTMAX < tmpfile_$$
        if [ `echo "${DISTMIN}==${DISTMAX}"|bc` -eq 1 ]
        then
            DISTMIN=`echo "${DISTMIN}" | awk '{print $1-1}'`
            DISTMAX=`echo "${DISTMAX}" | awk '{print $1+1}'`
        fi
		rm -f tmpfile_$$


		# Decide the amplitude scale (in deg),
		# in this c++ code, sac files are converted into a big ascii file.

		AmpScale=`echo "${Amplitude_ZP}/${PlotHeight}*(${DISTMAX}- ${DISTMIN})" | bc -l`

		${EXECDIR}/ZoomProfile.out 1 3 1 << EOF
${Normalize}
${EQ}_PlotList_Gcarc
${EQ}_PlotFile.txt
${EQ}_ValidTraceNum.txt
${AmpScale}
EOF
		if [ $? -ne 0 ]
		then
			echo "    1=> ZoomProfile.out C++ code failed on ${EQ}, plot ${Num} ..."
			rm -f ${a09DIR}/${EQ}* ${PLOTFILE}
			exit 1
		fi

		read NSTA < ${EQ}_ValidTraceNum.txt


		# g. prepare travel times.

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
${TIMEMIN}
${TIMEMAX}
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

			[ `echo "(${TIMEMAX}- ${TIMEMIN})>2000" | bc` -eq 1 ] && XAXIS="a500f100"
			[ `echo "(${TIMEMAX}- ${TIMEMIN})<=2000" | bc` -eq 1 ] && XAXIS="a200f20"
			[ `echo "(${TIMEMAX}- ${TIMEMIN})<1000" | bc` -eq 1 ] && XAXIS="a100f10"
			XLABEL="Time after ${Model_TT} ${Phase}-wave time (sec)"

			[ `echo "(${DISTMAX}- ${DISTMIN})>5" | bc` -eq 1 ] && YAXIS=`echo ${DISTMIN} ${DISTMAX} | awk '{print (int(int(($2-$1)/10)/5)+1)*5 }' |  awk '{print "a"$1"f"$1/5}'`
			[ `echo "(${DISTMAX}- ${DISTMIN})<=5" | bc` -eq 1 ] && YAXIS="a0.5f0.1"
			[ `echo "(${DISTMAX}- ${DISTMIN})<1" | bc` -eq 1 ] && YAXIS="a0.1f0.1"
			YLABEL="Distance (deg)"

			[ ${PlotOrient} = "Portrait" ] && XP="-X1.2i" || XP="-X1.2i"
			[ ${PlotOrient} = "Portrait" ] && YP="-Y-8i" || YP="-Y-5.5i"

			REG="-R${TIMEMIN}/${TIMEMAX}/${DISTMIN}/${DISTMAX}"

			psbasemap ${PROJ} ${REG} -B${XAXIS}:"${XLABEL}":/${YAXIS}:"${YLABEL}":WSne ${XP} ${YP} -K -O >> ${PLOTFILE}

			# add travel time curve (or not). (_WithTC)
			cp ${PLOTFILE} ${PLOTFILE}_WithTC
			cp ${PLOTFILE} ${PLOTFILE}_TCandText

			# add 5 sec + 10 sec + 5 sec time window around PREM.

			psxy -J -R -L -Glightyellow -K -O >> ${PLOTFILE}_WithTC << EOF
-10 ${DISTMIN}
-10 ${DISTMAX}
-5 ${DISTMAX}
-5 ${DISTMIN}
EOF

			psxy -J -R -L -Glightblue -K -O >> ${PLOTFILE}_WithTC << EOF
-5 ${DISTMIN}
-5 ${DISTMAX}
5 ${DISTMAX}
5 ${DISTMIN}
EOF
			psxy -J -R -L -Glightgreen -K -O >> ${PLOTFILE}_WithTC << EOF
5 ${DISTMIN}
5 ${DISTMAX}
10 ${DISTMAX}
10 ${DISTMIN}
EOF



			# plot arrivals lines.
			for file in `cat ${EQ}_PhaseArrivalFiles.txt`
			do
				Polarity=`basename ${file}`
				Polarity=${Polarity#*_}
				Polarity=${Polarity%%_*}
				PenColor=`grep -w ${Polarity} ${EQ}_PlotPen.txt | awk '{print $2}'`
				psxy ${file} -J -R -W1p/${PenColor} -: -K -O >> ${PLOTFILE}_WithTC
				psxy ${file} -J -R -W1p/${PenColor} -: -K -O >> ${PLOTFILE}_TCandText
			done


			# plot seismogram.
			psxy ${EQ}_PlotFile.txt -J -R -W0.005i/0 -m -O >> ${PLOTFILE}
			psxy ${EQ}_PlotFile.txt -J -R -W0.005i/0 -m -O >> ${PLOTFILE}_WithTC


			# plot phase names. (_TCandText)
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

			[ `echo "(${TIMEMAX}- ${TIMEMIN})>2000" | bc` -eq 1 ] && XAXIS="a500f100"
			[ `echo "(${TIMEMAX}- ${TIMEMIN})<=2000" | bc` -eq 1 ] && XAXIS="a200f20"
			[ `echo "(${TIMEMAX}- ${TIMEMIN})<1000" | bc` -eq 1 ] && XAXIS="a100f10"
			XLABEL="Time after ${Model_TT} ${Phase}-wave time (sec)"

			[ `echo "(${DISTMAX}- ${DISTMIN})>5" | bc` -eq 1 ] && YAXIS=`echo ${DISTMIN} ${DISTMAX} | awk '{print (int(int(($2-$1)/10)/5)+1)*5 }' |  awk '{print "a"$1"f"$1/5}'`
			[ `echo "(${DISTMAX}- ${DISTMIN})<=5" | bc` -eq 1 ] && YAXIS="a0.5f0.1"
			[ `echo "(${DISTMAX}- ${DISTMIN})<1" | bc` -eq 1 ] && YAXIS="a0.1f0.1"
			YLABEL="Distance (deg)"

			[ ${PlotOrient} = "Portrait" ] && XP="-X1.2i" || XP="-X1.2i"
			[ ${PlotOrient} = "Portrait" ] && YP="-Y-8i" || YP="-Y-5.5i"

			REG="-R${TIMEMIN}/${TIMEMAX}/${DISTMIN}/${DISTMAX}"

			gmt psbasemap ${PROJ} ${REG} -B${XAXIS}:"${XLABEL}":/${YAXIS}:"${YLABEL}":WSne ${XP} ${YP} -K -O >> ${PLOTFILE}


			# add travel time curve (or not). (_WithTC)
			cp ${PLOTFILE} ${PLOTFILE}_WithTC
			cp ${PLOTFILE} ${PLOTFILE}_TCandText

			# add 5 sec + 10 sec + 5 sec time window around PREM.

			gmt psxy -J -R -L -Glightyellow -K -O >> ${PLOTFILE}_WithTC << EOF
-10 ${DISTMIN}
-10 ${DISTMAX}
-5 ${DISTMAX}
-5 ${DISTMIN}
EOF

			gmt psxy -J -R -L -Glightblue -K -O >> ${PLOTFILE}_WithTC << EOF
-5 ${DISTMIN}
-5 ${DISTMAX}
5 ${DISTMAX}
5 ${DISTMIN}
EOF
			gmt psxy -J -R -L -Glightgreen -K -O >> ${PLOTFILE}_WithTC << EOF
5 ${DISTMIN}
5 ${DISTMAX}
10 ${DISTMAX}
10 ${DISTMIN}
EOF

			# plot arrival lines.
			for file in `cat ${EQ}_PhaseArrivalFiles.txt`
			do
				Polarity=`basename ${file}`
				Polarity=${Polarity#*_}
				Polarity=${Polarity%%_*}
				PenColor=`grep -w ${Polarity} ${EQ}_PlotPen.txt | awk '{print $2}'`
				gmt psxy ${file} -J -R -W1p,${PenColor} -: -K -O >> ${PLOTFILE}_WithTC
				gmt psxy ${file} -J -R -W1p,${PenColor} -: -K -O >> ${PLOTFILE}_TCandText
			done


			# plot seismogram.
			gmt psxy ${EQ}_PlotFile.txt -J -R -W0.005i,black -O >> ${PLOTFILE}
			gmt psxy ${EQ}_PlotFile.txt -J -R -W0.005i,black -O >> ${PLOTFILE}_WithTC


			# plot phase names. (_TCandText)
			awk '{print $1,$2,$7}' ${EQ}_Phases.txt > ${EQ}_plottext.txt
			gmt pstext ${EQ}_plottext.txt -J -R -F+jLM+f12p,Helvetica-Narrow-Bold,black -N -O >> ${PLOTFILE}_TCandText


			# get rid of traveltime plots if we don't want plot it.
			[ ${TravelCurve} = "NO" ] && rm -f ${PLOTFILE}_WithTC ${PLOTFILE}_TCandText

		fi

	done < ${OUTDIR}/tmpfile_ZP_${RunNumber} # End of plot loop.

done # End of EQ loop.

cd ${OUTDIR}

exit 0
