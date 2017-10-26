#!/bin/bash

# ====================================================================
# This script make a catalogue plot of data used in a15.
#
# Ed Garnero/Pei-Ying(Patty) Lin/Shule Yu
# ====================================================================

echo "        ==> `basename $0` is running. `date`"
mkdir -p ${a15DIR}/tmpdir_$$
cd ${a15DIR}/tmpdir_$$

# ==================================================
#              ! Work Begin !
# ==================================================


# Ctrl+C action.
trap "rm -rf ${a15DIR}/tmpdir_$$ ${OUTDIR}/*_${RunNumber}; exit 1" SIGINT
GMTVERSION=4 # Only support GMT-4 for now.

# A. Check the exist of list file.
if ! [ -s "${a01DIR}/${EQ}_FileList" ]
then
	echo "        !=> ${EQ} doesn't have FileList ..."
	exit 1
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
DISTMIN="${DistMin}"
DISTMAX="${DistMax}"
TIMEMIN="-1000"
TIMEMAX="1000"
Normalize="Own"
NetWork="${NETWK}"
TravelCurve="NO"
PlotOrient="Portrait"
Delta="${Delta_ESW}"
PlotAmp="0.375"

PLOTHEIGHT=7.4
PLOTWIDTH=8
TEXTWIDTH=2.5
PLOTPERPAGE=12
PLOTTIMEMIN=-100
PLOTTIMEMAX=200

Tick1=5
Tick2=50
height=`echo ${PLOTHEIGHT}/${PLOTPERPAGE}| bc -l`
halfh=`echo ${height}/2 | bc -l`

for T in `seq -50 50`
do
	echo "${T} ${Tick1}" | awk '{print $1*$2" 0"}' >> tmptime1_$$
	echo "${T} ${Tick2}" | awk '{print $1*$2" 0"}' >> tmptime2_$$
done

# Specific phases marked in catalogue here.
# These phase names should be in a05 INPUT list.
cat > ${EQ}_tmpfile_WantedArrival_$$ << EOF
S
Sdiff
P
SP
PP
pP
sP
PPP
Pdiff
ScP
PcS
pScP
EOF


PLOTFILE=${PLOTDIR}/${EQ}.`basename ${0%.sh}`_${Num}.ps

# Check phase file.
if ! [ -s "`ls ${a05DIR}/${EQ}_*_${Phase}.gmt_Enveloped 2>/dev/null`" ]
then
	echo "        !=> can't find Firsta Arrival file !"
	exit 1
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
trap "rm -rf ${a15DIR}/tmpdir_$$ ${PLOTFILE} ${OUTDIR}/*_${RunNumber}; exit 1" SIGINT


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
	echo "    !=> Interpolate.out C++ code failed on ${EQ}..."
	rm -f ${a15DIR}/tmpdir_$$/${EQ}* ${PLOTFILE}
	exit 1
fi

paste ${EQ}_SelectedFiles ${EQ}_FirstArrival_$$ \
| awk -v T1=${TIMEMIN} -v T2=${TIMEMAX} '{if (T2<=($4-$6) || T1>=($5-$6)) ; else print $1}' > tmpfile_$$

mv tmpfile_$$ ${EQ}_SelectedFiles


if ! [ -s "${EQ}_SelectedFiles" ]
then
	echo "        !=> No selected files..."
	exit 1
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
	echo "    !=> Interpolate.out C++ code failed ..."
	rm -f ${a15DIR}/tmpdir_$$/${EQ}* ${PLOTFILE}
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
		echo "    !=> Interpolate.out C++ code failed on ${EQ}..."
		rm -f ${a15DIR}/tmpdir_$$/${EQ}* ${PLOTFILE}
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

	# Do the PREMBias shift.
	ArrivalTime=`echo ${ArrivalTime} ${PREMBias} | awk '{print $1+$2}'`

	cat >> ${EQ}_SACMacro1.m << EOF
cut off
r ${filename}
rmean
rtr
taper
${SACCommand}
interp d ${Delta}
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

		# Do the PREMBias shift.
		ArrivalTime=`echo ${ArrivalTime} ${PREMBias} | awk '{print $1+$2}'`


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
interp d ${Delta}
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

		# Do the PREMBias shift.
		ArrivalTime=`echo ${ArrivalTime} ${PREMBias} | awk '{print $1+$2}'`

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
interp d ${Delta}
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


# g. prepare travel times for each phases.

# get a netwk_stnm_gcarc file.
ls *sac > tmpfile_$$
saclst knetwk kstnm knetwk gcarc f `cat tmpfile_$$`  | awk '{$4=""; print $1,$2"_"$3,$5}' > tmpfile_filename_nt_st_gcarc_$$

# for each phase, get a netwk_stnm_arrival file.
for phase in `cat ${EQ}_tmpfile_WantedArrival_$$`
do

	PhaseFile=`ls ${a05DIR}/${EQ}_*_${phase}.gmt_Enveloped`
	! [ -s ${PhaseFile} ] && echo "       ~=> No travel time frist arrival file in a05 for Phase ${phase}..." && continue
	awk '{print $3}' tmpfile_filename_nt_st_gcarc_$$ > ${EQ}_gcarc_$$
	awk '{print $2}' tmpfile_filename_nt_st_gcarc_$$ > tmpfile_$$

	${EXECDIR}/Interpolate.out 0 3 0 << EOF
${PhaseFile}
${EQ}_gcarc_$$
${EQ}_FirstArrival_$$
EOF

	paste tmpfile_$$ ${EQ}_FirstArrival_$$ > ${phase}.premtime

done

# g*. prepare a "sorted.lst" for the catalogue plotting loop.

keys="<NETWK> <STNM>"
${BASHCODEDIR}/Findfield.sh ${a15DIR}/${EQ}_${Phase}_${COMP}_${UseSNR}_${DistMin}_${DistMax}_${F1}_${F2}_${NETWK}.List "${keys}" | awk '{print $1"_"$2}' > tmpfile_filelist_$$

keys="<NETWK> <STNM> <Gcarc> <Az> <BAz> <STLO> <STLA>"
${BASHCODEDIR}/Findfield.sh ${a01DIR}/${EQ}_FileList_Info "${keys}" | awk '{print $1"_"$2,$3,$4,$5,$6,$7}' | sort -u -k1,1 > tmpfile_$$
${BASHCODEDIR}/Findrow.sh tmpfile_$$ tmpfile_filelist_$$ | awk '{$1="";print $0}' > tmpfile1_$$

keys="<NETWK> <STNM> <DT> <CCC> <Weight> <PeakTime> <PeakAmp>"
${BASHCODEDIR}/Findfield.sh ${a15DIR}/${EQ}_${Phase}_${COMP}_${UseSNR}_${DistMin}_${DistMax}_${F1}_${F2}_${NETWK}.List "${keys}" | awk '{print $1"_"$2,$3,$4,$5,$6,$7}' > tmpfile_$$
${BASHCODEDIR}/Findrow.sh tmpfile_$$ tmpfile_filelist_$$ | awk '{$1="";print $0}' > tmpfile2_$$

[ ${COMP} = "Z" ] && COMP1="P"
[ ${COMP} = "R" ] && COMP1="SV"
[ ${COMP} = "T" ] && COMP1="SH"
[ ${COMP} = "E" ] && COMP1="SV" # These two are error-pro
[ ${COMP} = "N" ] && COMP1="SH"
keys="<NETWK> <STNM> <RadPat>"
${BASHCODEDIR}/Findfield.sh ${a12DIR}/${EQ}_${Phase}_${COMP1}_RadPat.List "${keys}" | awk '{print $1"_"$2,$3}' > tmpfile_$$
${BASHCODEDIR}/Findrow.sh tmpfile_$$ tmpfile_filelist_$$ | awk '{$1="";print $0}' > tmpfile3_$$

paste tmpfile_filelist_$$ tmpfile1_$$ tmpfile2_$$ tmpfile3_$$ | sort -g -k 2,2 > sorted.lst
NSTA=`wc -l < sorted.lst`

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

	page=0
	plot=$(($PLOTPERPAGE+1))
	while read NETNM_STNM Gcarc AZ BAZ STLO STLA D_T CCC Weight Peak AMP Rad_Pat
	do
		netwk=${NETNM_STNM%_*}
		stnm=${NETNM_STNM#*_}
		PhaseTime=`grep ${NETNM_STNM} ${Phase}.premtime | awk '{print $2}'`

		## 4.2 check if need to plot on a new page.
		if [ ${plot} -eq $(($PLOTPERPAGE+1)) ]
		then

			### 4.2.1. if this isn't first page, seal the last page.
			if [ ${page} -gt 0 ]
			then
				psxy -J -R -O >> ${OUTFILE} << EOF
EOF
			fi

			### 4.2.2 plot titles and legends
			plot=1
			page=$((page+1))
			OUTFILE=${page}.ps
			title1="${MM}/${DD}/${YYYY}  PHASE: ${Phase}  COMP: ${COMP}  Page: ${page}"
			title2="${EQ}  ELAT/ELON: ${EVLA} ${EVLO}  Depth: ${EVDP} km. Mag: ${MAG}  NSTA: ${NSTA}"
			title3="Time tick interval: ${Tick1} sec."
			title4="NETNM.STNM AZ BAZ"
			title5="Gcarc D_T Rad_Pat"
			title6="CCC Weight"

			pstext -JX${PLOTWIDTH}i/0.7i -R-1/1/-1/1 -X0.75i -Y8i -K > ${OUTFILE} << EOF
0 -0.5 14 0 0 CB ${title1}
EOF
			pstext -J -R -Y-0.35i -O -K >> ${OUTFILE} << EOF
0 0 10 0 0 CB ${title2}
EOF
			pstext -J -R -Y-0.15i -Wored -O -K >> ${OUTFILE} << EOF
0 0 8 0 0 CB ${SACCommand}
EOF
			psxy -J -R -Y0.7i -O -K >> ${OUTFILE} << EOF
EOF
			#### 4.2.3 add legends of station info.
			pstext -JX${TEXTWIDTH}i/${height}i -R-1/1/-1/1 -X${PLOTWIDTH}i -Y-${height}i -N -O -K >> ${OUTFILE} << EOF
0 0.5 8 0 0 CB ${title3}
0 0 8 0 0 CB ${title4}
0 -0.5 8 0 0 CB ${title5}
0 -1 8 0 0 CB ${title6}
EOF
		fi # end new page test.

		## go to the right position to plot seismograms.
		psxy -JX${PLOTWIDTH}i/${height}i -R${PLOTTIMEMIN}/${PLOTTIMEMAX}/-1/1 -X-${PLOTWIDTH}i -Y-${height}i -O -K >> ${OUTFILE} << EOF
EOF

		### 4.4.0 plot Checkbox.
		psxy -J -R -O -K -Y${halfh}i >> ${OUTFILE} << EOF
EOF
		if [ ${page} -eq 1 ] && [ ${plot} -eq 1 ]
		then
			cat >> ${OUTFILE} << EOF
[ /_objdef {ZaDb} /type /dict /OBJ pdfmark
[ {ZaDb} <<
/Type /Font
/Subtype /Type1
/Name /ZaDb
/BaseFont /ZapfDingbats
>> /PUT pdfmark
[ /_objdef {Helv} /type /dict /OBJ pdfmark
[ {Helv} <<
/Type /Font
/Subtype /Type1
/Name /Helv
/BaseFont /Helvetica
>> /PUT pdfmark
[ /_objdef {aform} /type /dict /OBJ pdfmark
[ /_objdef {afields} /type /array /OBJ pdfmark
[ {aform} <<
/Fields {afields}
/DR << /Font << /ZaDb {ZaDb} /Helv {Helv} >> >>
/DA (/Helv 0 Tf 0 g)
/NeedAppearances true
>> /PUT pdfmark
[ {Catalog} << /AcroForm {aform} >> /PUT pdfmark
EOF
		fi

		if [ `echo "${Weight}>0" |bc` -eq 1 ]
		then
			cat >> ${OUTFILE} << EOF
[
/T (${EQ}_${stnm})
/FT /Btn
/Rect [-180 -65 -50 65]
/F 4 /H /O
/BS << /W 1 /S /S >>
/MK << /CA (8) /BC [ 0 ] /BG [ 1 ] >>
/DA (/ZaDb 0 Tf 1 0 0 rg)
/AP << /N << /${EQ}_${stnm} /null >> >>
/Subtype /Widget
/ANN pdfmark
EOF
		else
			cat >> ${OUTFILE} << EOF
[
/T (${EQ}_${stnm})
/V /${EQ}_${stnm}
/FT /Btn
/Rect [-180 -65 -50 65]
/F 4 /H /O
/BS << /W 1 /S /S >>
/MK << /CA (8) /BC [ 0 ] /BG [ 1 ] >>
/DA (/ZaDb 0 Tf 1 0 0 rg)
/AP << /N << /${EQ}_${stnm} /null >> >>
/Subtype /Widget
/ANN pdfmark
EOF
		fi
		psxy -J -R -O -K -Y-${halfh}i >> ${OUTFILE} << EOF
EOF

        ### plot normalize window.
        psxy -J -R -W200/200/200 -G200/200/200 -L -O -K >> ${OUTFILE} << EOF
`echo "${PREMBias} + ${NormalizeBegin} " | bc -l` -1
`echo "${PREMBias} + ${NormalizeBegin} " | bc -l` 1
`echo "${PREMBias} + ${NormalizeEnd} " | bc -l` 1
`echo "${PREMBias} + ${NormalizeEnd} " | bc -l` -1
EOF

        ### plot ESF window.
        psxy -J -R -W100/100/200 -G100/100/200 -L -O -K >> ${OUTFILE} << EOF
`echo "${D_T} + ${TimeMin} " | bc -l` -1
`echo "${D_T} + ${TimeMin} " | bc -l` 1
`echo "${D_T} + ${TimeMax} " | bc -l` 1
`echo "${D_T} + ${TimeMax} " | bc -l` -1
EOF

		### plot zero line with time marker.
		psxy -J -R -W0.3p,. -O -K >> ${OUTFILE} << EOF
${PLOTTIMEMIN} 0
${PLOTTIMEMAX} 0
EOF
		psxy tmptime1_$$ -J -R -Sy0.02i -Gred -O -K >> ${OUTFILE}
		psxy tmptime2_$$ -J -R -Sy0.05i -Gblack -O -K >> ${OUTFILE}

		### PREM arrivals. (t=zero)
		for phase in `cat ${EQ}_tmpfile_WantedArrival_$$`
		do
			T=`grep ${NETNM_STNM} ${phase}.premtime | awk -v P=${PhaseTime} '{print $2-P}'`
			[[ ${T} = *nan* ]] && continue
			psvelo -J -R -Wblack -Gpurple -Se${halfh}i/0.2/18 -O -K >> ${OUTFILE} << EOF
${T} -0.4 0 0.4
EOF
			pstext -J -R -O -K >> ${OUTFILE} << EOF
${T} -0.45 5 0 6 CT ${phase}
EOF
		done

		### picked arrival.
		psvelo -J -R -Wblack -Gred -Se${halfh}i/0.2/18 -N -O -K >> ${OUTFILE} << EOF
${D_T} 0.5 0 -0.5
EOF

		### plot data.
		echo ${EQ}.${netwk}.${stnm}.sac > filelist
		${EXECDIR}/SAC2XY.out 0 1 0 << EOF
filelist
EOF

		### data. (flipped and normalize within plot window).
		file=${EQ}.${netwk}.${stnm}.sac.waveform
		Polarity=`echo ${AMP} | awk '{if ($1>0) print 1;else print -1}'`
		AMP_All=`echo ${AMP} ${Polarity} | awk '{print $1*$2}'`
		if [ "${Normalize}" -eq 1 ]
		then
			awk -v T1=${PLOTTIMEMIN} -v T2=${PLOTTIMEMAX} -v P=${PhaseTime} '{if ( T1<$1-P && $1-P<T2 ) print $2}' ${file} > tmpfile_$$
			AMP_All=`${BASHCODEDIR}/amplitude.sh tmpfile_$$`
		fi
		AMP_Scale=`echo ${AMP} ${AMP_All} | awk '{print $1/$2}'`

		#### peak position.
		psxy -J -R -Sa0.06i -Gblue -N -O -K >> ${OUTFILE} << EOF
`echo ${Peak} ${PhaseTime} | awk '{print $1-$2}'` ${AMP_Scale}
EOF
		### shifted empirical source. (normalize to AMP, flip according to polarity)
		${BASHCODEDIR}/Findfield.sh ${a15DIR}/${EQ}_${Phase}_${COMP}_${UseSNR}_${DistMin}_${DistMax}_${F1}_${F2}_${NETWK}.ESW "<Time> <Stack2>" > esw
		awk -v S=${D_T} -v A=${AMP_Scale} -v C=${Polarity} -v T1=${TimeMin} -v T2=${TimeMax} '{if (T1<$1 && $1<T2) print $1+S,$2*C/A}' esw |  psxy -J -R -W0.3p,red,- -O -K >> ${OUTFILE}
		#### waveform
		awk -v T1=${PLOTTIMEMIN} -v T2=${PLOTTIMEMAX} -v P=${PhaseTime} -v A=${AMP_All} '{ if ($1-P>T1 && $1-P<T2) print $1-P,$2/A}' ${file} | psxy -J -R -W0.5p -O -K >> ${OUTFILE}

		### flip mark.
		[ "${Polarity}" -eq 1 ] && Color=red || Color=blue
		psxy -J -R -Sc0.08i -G${Color} -N -O -K >> ${OUTFILE} << EOF
${PLOTTIMEMIN} 0
EOF
		## station info.
		pstext -JX${TEXTWIDTH}i/${height}i -R/-1/1/-1/1 -X${PLOTWIDTH}i -N -O -K >> ${OUTFILE} << EOF
0 0 10 0 0 CB ${netwk}.${stnm}  `echo ${AZ} | awk '{printf "%.2f",$1}'`@~\260@~  `echo ${BAZ} | awk '{printf "%.2f",$1}'`@~\260@~
0 -0.5 10 0 0 CB `echo ${Gcarc} | awk '{printf "%.2f",$1}'`@~\260@~  ${D_T} sec. ${Rad_Pat}
0 -1 10 0 0 CB ${CCC}  ${SNR}   ${Weight}
EOF
		pstext -J -R/-1/1/-1/1 -N -O -K >> ${OUTFILE} << EOF
EOF

		plot=$((plot+1))

	done < sorted.lst # end of plot loop.

	psxy -J -R -O >> ${OUTFILE} << EOF
EOF

fi

PLOTFILE=${PLOTDIR}/${EQ}.`basename ${0%.sh}`_${Num}.ps
cat `ls -rt *.ps` > ${PLOTFILE}
ps2pdf ${PLOTFILE}

# Clean up.
rm -rf ${a15DIR}/tmpdir_$$

exit 0
