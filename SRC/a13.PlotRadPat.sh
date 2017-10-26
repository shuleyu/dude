#!/bin/bash

# ====================================================================
# This script plot phases piercing positions on according lower hemisphere
# radiation patten.
#
# Ed Garnero/Pei-Ying(Patty) Lin/Shule Yu
# ====================================================================

echo ""
echo "--> `basename $0` is running. `date`"
mkdir -p ${a13DIR}
cd ${a13DIR}

# ==================================================
#              ! Work Begin !
# ==================================================


for EQ in `cat ${OUTDIR}/tmpfile_EQs_${RunNumber}`
do

	# Ctrl+C action.
	trap "rm -f ${a13DIR}/${EQ}* ${OUTDIR}/*_${RunNumber}; exit 1" SIGINT


	# A. Check the existance of list file.
	if ! [ -s "${a01DIR}/${EQ}_FileList" ]
	then
		echo "    ~=> ${EQ} doesn't have FileList ..."
		continue
	else
		echo "    ==> Making Radiation plot(s) of ${EQ}."
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

	# C. Calculate radiation pattern grid value for P,SV,SH.

	# a. Grab CMT Info from website search result (connection required, http://www.globalcmt.org/CMTsearch.html).
	# Note: events before 2000 will cause problem in online search method because the event naming is different.

	SearchURL="http://www.globalcmt.org/cgi-bin/globalcmt-cgi-bin/CMT4/form?itype=ymd&yr=${YYYY}&mo=${MM}&day=${DD}&otype=ymd&oyr=${YYYY}&omo=${MM}&oday=${DD}&jyr=1976&jday=1&ojyr=1976&ojday=1&nday=1&lmw=0&umw=10&lms=0&ums=10&lmb=0&umb=10&llat=-90&ulat=90&llon=-180&ulon=180&lhd=0&uhd=1000&lts=-9999&uts=9999&lpe1=0&upe1=90&lpe2=0&upe2=90&list=2"
	curl ${SearchURL} > tmpfile_$$ 2>/dev/null
	CMTInfo=`grep ${EQ} tmpfile_$$ | head -n 1`

	if [ -z "${CMTInfo}" ]
	then
		echo "        ~=> Can't find ${EQ} CMT information..."
		rm -f tmpfile_$$
		continue
	fi

	Strike=`echo "${CMTInfo}" | awk '{print $3}'`
	Dip=`echo "${CMTInfo}" | awk '{print $4}'`
	Rake=`echo "${CMTInfo}" | awk '{print $5}'`

	rm -f tmpfile_$$

	# b. calculate grid value for P,SV,SH.

	${EXECDIR}/MakeGridRadPat.out 0 1 4 << EOF
${EQ}_az_takeoff_P_SV_SH.txt
${EVDP}
${Strike}
${Dip}
${Rake}
EOF

	awk '{print $1,$2,$3}' ${EQ}_az_takeoff_P_SV_SH.txt > P.ascii
	awk '{print $1,$2,$4}' ${EQ}_az_takeoff_P_SV_SH.txt > SV.ascii
	awk '{print $1,$2,$5}' ${EQ}_az_takeoff_P_SV_SH.txt > SH.ascii

	if [ ${GMTVERSION} -eq 4 ]
	then
		xyz2grd P.ascii -GP.grd -I0.05 -R0/360/0/90
		xyz2grd SV.ascii -GSV.grd -I0.05 -R0/360/0/90
		xyz2grd SH.ascii -GSH.grd -I0.05 -R0/360/0/90
	else
		gmt xyz2grd P.ascii -GP.grd -I0.05 -R0/360/0/90
		gmt xyz2grd SV.ascii -GSV.grd -I0.05 -R0/360/0/90
		gmt xyz2grd SH.ascii -GSH.grd -I0.05 -R0/360/0/90
	fi

	rm -f ${EQ}_az_takeoff_P_SV_SH.txt P.ascii SV.ascii SH.ascii


	# D. Enter the plot loop.

	NLine=`wc -l < ${OUTDIR}/tmpfile_RP_${RunNumber}`
	for Num in `seq 0 ${NLine}`
	do
		PLOTFILE=${PLOTDIR}/${EQ}.`basename ${0%.sh}`_${Num}.ps

		if [ ${Num} -ne 0 ]
		then
			Phase=`awk -v N=${Num} 'NR==N {print $1}' ${OUTDIR}/tmpfile_RP_${RunNumber}`
			COMP=`awk -v N=${Num} 'NR==N {print $2}' ${OUTDIR}/tmpfile_RP_${RunNumber}`
		fi


		# Ctrl+C action.
		trap "rm -f ${a13DIR}/${EQ}* ${PLOTFILE} ${OUTDIR}/*_${RunNumber}; exit 1" SIGINT


		# a. check the existance of radiation pattern data file.
		if [ ${Num} -ne 0 ]
		then
			RadPatFile="${a12DIR}/${EQ}_${Phase}_${COMP}_RadPat.List"
			if ! [ -s "${RadPatFile}" ]
			then
				echo "        ~=> ${EQ}, phase ${Phase} has 0 stations ..."
				continue
			fi
			NSTA=`wc -l < ${RadPatFile}`
		fi


		# b. plot. (GMT-4)
		if [ ${GMTVERSION} -eq 4 ]
		then

			# basic gmt settings
			gmtset PAPER_MEDIA = letter
			gmtset ANNOT_FONT_SIZE_PRIMARY = 12p
			gmtset LABEL_FONT_SIZE = 16p
			gmtset LABEL_OFFSET = 0.1i
			gmtset BASEMAP_FRAME_RGB = +0/0/0
			gmtset GRID_PEN_PRIMARY = 0.5p,gray,-

			# make a color platte
			makecpt -Cpolar -T-1/1/0.02 -I -Z > RAD.cpt
			cat > BeachBall.cpt << EOF
-1	255	255	255 0	255	255	255
0	0	0	0	1	0	0	0
B	255	255	255
F	0	0	0
N	128	128	128
EOF


			# plot title and tag.
			[ "${Num}" -eq 0 ] && NSTA1="NSTA=${NSTA_All}" || NSTA1=""
			[ "${Num}" -eq 0 ] && DASH="" || DASH='(dashed lines: \261 10% of maximum)'

			pstext -JX8.5i/1i -R-100/100/-1/1 -N -X0i -Y9.5i -P -K > ${PLOTFILE} 2>/dev/null << EOF
0 1 20 0 0 CB Event: ${MM}/${DD}/${YYYY} ${HH}:${MIN} Strike=${Strike} Dip=${Dip} Rake=${Rake}
0 0.5 15 0 0 CB ${EQ} LAT=${EVLA} LON=${EVLO} Z=${EVDP} Mb=${MAG} ${NSTA1}
0 -0.5 20 0 6 CB ${DASH}
EOF
			pstext -J -R -N -Wored -G0 -Y-0.2i -O -K >> ${PLOTFILE} << EOF
0 0.5 10 0 0 CB SCRIPT: `basename ${0}` `date "+CREATION DATE: %m/%d/%y  %H:%M:%S"`
EOF


			# plot basemap.
			[ "${Num}" -eq 0 ] && SIZE="2.75" || SIZE="6.5"

			REG="-R0/360/0/90"
			PROJ="-JPa${SIZE}i"

			if [ ${Num} -eq 0 ]
			then

				echo "0.0 C" > CONT
				echo "-0.1 C" > CONT__0.1
				echo "0.1 C" > CONT_0.1

				grdimage ${REG} ${PROJ} P.grd -CBeachBall.cpt -X1i -Y-3i -K -O >> ${PLOTFILE} 2>/dev/null
				psbasemap -J -R -B0 -K -O >> ${PLOTFILE}

				grdimage ${REG} ${PROJ} P.grd -CRAD.cpt -X3.75i -K -O >> ${PLOTFILE} 2>/dev/null
				grdcontour P.grd -R -J -CCONT -W2/150 -K -O >> ${PLOTFILE}
				psbasemap -J -R -Ba45f15 -K -O >> ${PLOTFILE}
				pstext -J -R -N -K -O >> ${PLOTFILE} << EOF
0 130 20 0 1 CB P
EOF
				psscale -CRAD.cpt -D-0.5i/-0.5i/1.5i/0.1ih -O -K -B1.0:Amplitude: >> ${PLOTFILE}

				grdimage ${REG} ${PROJ} SV.grd -CRAD.cpt -X-3.75i -Y-4.5i -K -O >> ${PLOTFILE} 2>/dev/null
				grdcontour SV.grd -R -J -CCONT -W2/150 -K -O >> ${PLOTFILE}
				psbasemap -J -R -Ba45f15 -K -O >> ${PLOTFILE}
				pstext -J -R -N -K -O >> ${PLOTFILE} << EOF
180 150 20 0 1 CB SV
EOF

				grdimage ${REG} ${PROJ} SH.grd -CRAD.cpt -X3.75i -K -O >> ${PLOTFILE} 2>/dev/null
				grdcontour SH.grd -R -J -CCONT -W2/150 -K -O >> ${PLOTFILE}
				psbasemap -J -R -Ba45f15 -K -O >> ${PLOTFILE}
				pstext -J -R -N -K -O >> ${PLOTFILE} << EOF
180 150 20 0 1 CB SH
EOF

			else

				keys="<Az> <TakeOff>"
				${BASHCODEDIR}/Findfield.sh ${RadPatFile} "${keys}" > ${EQ}_PLOTFILE

				grdimage ${REG} ${PROJ} ${COMP}.grd -CRAD.cpt -X1i -Y-7.5i -K -O >> ${PLOTFILE} 2>/dev/null
				grdcontour ${COMP}.grd -R -J -CCONT -W2/150 -K -O >> ${PLOTFILE}
				grdcontour ${COMP}.grd -R -J -CCONT__0.1 -W0.5/220/0/0t8_20:0 -K -O >> ${PLOTFILE}
				grdcontour ${COMP}.grd -R -J -CCONT_0.1 -W0.5/0/0/200t8_20:0 -K -O >> ${PLOTFILE}
				psxy -J -R ${EQ}_PLOTFILE -Sx0.2i -K -O >> ${PLOTFILE}
				psbasemap -J -R -Ba45f15 -K -O >> ${PLOTFILE}
				pstext -J -R -N -K -O >> ${PLOTFILE} << EOF
0 105 20 0 1 CB ${Phase} on ${COMP}, NSTA=$((NSTA-1))/${NSTA_All}
EOF
				psscale -CRAD.cpt -D3.25i/-0.5i/2.5i/0.1ih -O -K -B1.0:Amplitude: >> ${PLOTFILE}

			fi

			psxy -J -R -O >> ${PLOTFILE} << EOF
EOF

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

			# make a color platte
			gmt makecpt -Cpolar -T-1/1/0.02 -I -Z > RAD.cpt
			cat > BeachBall.cpt << EOF
-1	white 0	white
0	black	1	black
B	255	255	255
F	0	0	0
N	128	128	128
EOF


			# plot title and tag.
			[ "${Num}" -eq 0 ] && NSTA1="NSTA=${NSTA_All}" || NSTA1=""
			[ "${Num}" -eq 0 ] && DASH="" || DASH='(dashed lines: \261 10% of maximum)'


			cat > ${EQ}_plottext.txt << EOF
0 1 Event: ${MM}/${DD}/${YYYY} ${HH}:${MIN} Strike=${Strike} Dip=${Dip} Rake=${Rake}
0 0.5 @:15:${EQ} LAT=${EVLA} LON=${EVLO} Z=${EVDP} Mb=${MAG} ${NSTA1}@::
0 -0.5 @%6%${DASH}@%%
EOF
			gmt pstext ${EQ}_plottext.txt -JX8.5i/1i -R-100/100/-1/1 -F+jCB+f20p,Helvetica,black -N -Xf0i -Yf9.5i -P -K > ${PLOTFILE}

			cat > ${EQ}_plottext.txt << EOF
0 0.5 SCRIPT: `basename ${0}` `date "+CREATION DATE: %m/%d/%y  %H:%M:%S"`
EOF
			gmt pstext ${EQ}_plottext.txt -J -R -F+jCB+f10p,Helvetica,black -N -Wred -Y-0.2i -O -K >> ${PLOTFILE}


			# plot basemap.
			[ "${Num}" -eq 0 ] && SIZE="2.75" || SIZE="6.5"

			REG="-R0/360/0/90"
			PROJ="-JPa${SIZE}i"

			if [ ${Num} -eq 0 ]
			then

				echo "0.0 C" > CONT
				echo "-0.1 C" > CONT__0.1
				echo "0.1 C" > CONT_0.1

				gmt grdimage ${REG} ${PROJ} P.grd -CBeachBall.cpt -X1i -Y-3i -K -O >> ${PLOTFILE} 2>/dev/null
				gmt psbasemap -J -R -B0 -K -O >> ${PLOTFILE}

				gmt grdimage ${REG} ${PROJ} P.grd -CRAD.cpt -X3.75i -K -O >> ${PLOTFILE} 2>/dev/null
				gmt grdcontour P.grd -R -J -CCONT -W0.5p,150/150/150 -K -O >> ${PLOTFILE}
				gmt psbasemap -J -R -Ba45f15 -K -O >> ${PLOTFILE}

				gmt psscale -CRAD.cpt -D-0.5i/-0.5i/1.5i/0.1ih -O -K -B1.0:Amplitude: >> ${PLOTFILE}

				gmt grdimage ${REG} ${PROJ} SV.grd -CRAD.cpt -X-3.75i -Y-4.5i -K -O >> ${PLOTFILE} 2>/dev/null
				gmt grdcontour SV.grd -R -J -CCONT -W0.5p,150/150/150 -K -O >> ${PLOTFILE}
				gmt psbasemap -J -R -Ba45f15 -K -O >> ${PLOTFILE}

				gmt grdimage ${REG} ${PROJ} SH.grd -CRAD.cpt -X3.75i -K -O >> ${PLOTFILE} 2>/dev/null
				gmt grdcontour SH.grd -R -J -CCONT -W0.5p,150/150/150 -K -O >> ${PLOTFILE}
				gmt psbasemap -J -R -Ba45f15 -K -O >> ${PLOTFILE}


				cat > ${EQ}_plottext.txt << EOF
90 145 P
-90 -160 SV
90 -160 SH
EOF
				gmt pstext ${EQ}_plottext.txt -JX8.5i/11i -R-200/200/-200/200 -F+jCB+f20p,Helvetica-Bold,black -N -Xf0i -Yf0i -O >> ${PLOTFILE}

			else

				keys="<Az> <TakeOff>"
				${BASHCODEDIR}/Findfield.sh ${RadPatFile} "${keys}" > ${EQ}_PLOTFILE

				gmt grdimage ${REG} ${PROJ} ${COMP}.grd -CRAD.cpt -X1i -Y-7.5i -K -O >> ${PLOTFILE} 2>/dev/null
				gmt grdcontour ${COMP}.grd -R -J -CCONT -W0.5p,150/150/150 -K -O >> ${PLOTFILE}
				gmt grdcontour ${COMP}.grd -R -J -CCONT__0.1 -W0.5p,220/0/0,- -K -O >> ${PLOTFILE}
				gmt grdcontour ${COMP}.grd -R -J -CCONT_0.1 -W0.5p,0/0/200,- -K -O >> ${PLOTFILE}
				gmt psxy -J -R ${EQ}_PLOTFILE -Sx0.2i -K -O >> ${PLOTFILE}
				gmt psbasemap -J -R -Ba45f15 -K -O >> ${PLOTFILE}
				gmt psscale -CRAD.cpt -D3.25i/-0.5i/2.5i/0.1ih -O -K -B1.0:Amplitude: >> ${PLOTFILE}

				cat > ${EQ}_plottext.txt << EOF
0 130 ${Phase} on ${COMP}, NSTA=$((NSTA-1))/${NSTA_All}
EOF
				gmt pstext ${EQ}_plottext.txt -JX8.5i/11i -R-200/200/-200/200 -F+jCB+f20p,Helvetica-Bold,black -N -Xf0i -Yf0i -O >> ${PLOTFILE}

			fi

		fi

	done # End of plot loop.

	rm -f P.grd SV.grd SH.grd

done # End of EQ loop.

cd ${OUTDIR}

exit 0
