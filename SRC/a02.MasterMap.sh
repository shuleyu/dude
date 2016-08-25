#!/bin/bash

# ====================================================================
# This script make an earthquake-station position plot.
#
# Ed Garnero/Pei-Ying(Patty) Lin/Shule Yu
# ====================================================================

echo ""
echo "--> `basename $0` is running. `date`"
mkdir -p ${a02DIR}
cd ${a02DIR}

# ==================================================
#              ! Work Begin !
# ==================================================


for EQ in `cat ${OUTDIR}/tmpfile_EQs_${RunNumber}`
do
	PLOTFILE="${PLOTDIR}/${EQ}.`basename ${0%.sh}`.ps"

	# Ctrl+C action.
	trap "rm -f ${a02DIR}/${EQ}* ${PLOTFILE} ${OUTDIR}/*_${RunNumber}; exit 1" SIGINT

	# A. Check the existance of list file.
	if ! [ -s ${a01DIR}/${EQ}_FileList ]
	then
		echo "    ~=> ${EQ} doesn't have FileList ..."
		continue
	else
		echo "    ==> Making MasterMap of ${EQ}."
	fi

	# B. Pull information.
	keys="<EQ> <EVLA> <EVLO> <EVDP> <MAG>"
	${BASHCODEDIR}/Findfield.sh ${a01DIR}/EQInfo.txt "${keys}" | grep ${EQ} > ${EQ}_Info
	read EQ EVLA EVLO EVDP MAG < ${EQ}_Info

	keys="<STLO> <STLA> <Gcarc>"
	${BASHCODEDIR}/Findfield.sh ${a01DIR}/${EQ}_FileList_Info "${keys}" | uniq > ${EQ}_stlo_stla_gcarc

	NSTA=`wc -l < ${EQ}_stlo_stla_gcarc`

	YYYY=`echo ${EQ} | cut -c1-4 `
	MM=`  echo ${EQ} | cut -c5-6 `
	DD=`  echo ${EQ} | cut -c7-8 `
	HH=`  echo ${EQ} | cut -c9-10 `
	MIN=` echo ${EQ} | cut -c11-12 `

	# C. Plot. (GMT-4)
	if [ ${GMTVERSION} -eq 4 ]
	then

		# basic gmt settings
		gmtset PAPER_MEDIA = letter
		gmtset ANNOT_FONT_SIZE_PRIMARY = 8p
		gmtset LABEL_FONT_SIZE = 9p
		gmtset LABEL_OFFSET = 0.1c
		gmtset GRID_PEN_PRIMARY = 0.05p,gray

		# projection and map range.
		REG="-R0/360/-90/90"
		PROJ="-JR${EVLO}/7.0i"

		# plot the coast lines
		pscoast ${REG} ${PROJ} -Ba0g45/a0g45wsne -Dl -A40000 -W3/100/100/100 -G200/200/200 -X0.70i -Y5.5i -P -K > ${PLOTFILE}

		# plot the GCPs.

		RGB[1]="30/30/30"
		RGB[2]="0/0/250"
		RGB[3]="0/130/255"
		RGB[4]="250/0/250"
		RGB[5]="120/250/250"
		RGB[6]="130/250/0"
		RGB[7]="255/255/0"
		RGB[8]="250/180/0"
		RGB[9]="250/0/0"
		RGB[10]="250/250/250"

		# decide which group each gcp path belongs to.
		rm -f ${EQ}_gcpfile_Group*
		while read STLO STLA GCARC
		do
			GroupNum=`echo "1+${GCARC}/20" | bc`
			printf ">\n%f %f\n%f %f\n" ${EVLO} ${EVLA} ${STLO} ${STLA} >> ${EQ}_gcpfile_Group${GroupNum}
		done < ${EQ}_stlo_stla_gcarc


		# plot each group.
		for GroupNum in `seq 1 10`
		do
			if [ -e ${EQ}_gcpfile_Group${GroupNum} ]
			then
				psxy ${EQ}_gcpfile_Group${GroupNum} ${REG} ${PROJ} -m -W0.5p,${RGB[${GroupNum}]} -O -K >> ${PLOTFILE}
			fi
		done


		# plot the EQ and stations
		psxy ${REG} ${PROJ} -Sa0.12i -O -K -W1/0/0/0 -G0 >> ${PLOTFILE} << EOF
${EVLO} ${EVLA}
EOF
		awk '{print $1,$2}' ${EQ}_stlo_stla_gcarc | psxy ${REG} ${PROJ} -St0.03i -O -K -W1/0/0/0 -G0 >> ${PLOTFILE}

		# plot title.
		pstext ${REG} ${PROJ} -N -O -K -Y0.8i >> ${PLOTFILE} << EOF
${EVLO} 90 20 0 0 CB ${MM}/${DD}/${YYYY} ${HH}:${MIN}
EOF
		pstext ${REG} ${PROJ} -N -O -K -Y-0.6i >> ${PLOTFILE} << EOF
${EVLO} 90 14 0 0 CB ${EQ} LAT=${EVLA} LON=${EVLO} Z=${EVDP} Mb=${MAG} NSTA=${NSTA}
EOF
		# plot gcp legend.
		psxy -J -R -X2.8i -Y-4i -O -K >> ${PLOTFILE} << EOF
EOF
		for GroupNum in `seq 1 9`
		do
			psxy -JX3.0i -R0/5/0/5 -Y-0.25i -W2p,${RGB[${GroupNum}]} -O -K >> ${PLOTFILE} << EOF
0 5
1 5
EOF
			pstext -J -R -N -O -K >> ${PLOTFILE} << EOF
1.2 5.0 10 0 0 LM `echo "(${GroupNum}-1)*20" | bc`-`echo "${GroupNum}*20" | bc` deg
EOF
		done

		# plot script name and date tag.
		pstext -JX3.0i -R0/5/0/5 -N -Wored -G0 -O -X-1.4i -Y-1.0i >> ${PLOTFILE} << EOF
0.0 4.2 10 0 0 LM SCRIPT: `basename ${0}` `date "+CREATION DATE: %m/%d/%y  %H:%M:%S"`
EOF

	fi

	# C*. Plot. (GMT-5)

	if [ ${GMTVERSION} -eq 5 ]
	then

		# basic gmt settings
		gmt gmtset PS_MEDIA letter
		gmt gmtset FONT_ANNOT_PRIMARY 8p
		gmt gmtset FONT_LABEL 9p
		gmt gmtset MAP_LABEL_OFFSET 6p

		# projection and map range.
		REG="-R0/360/-90/90"
		PROJ="-JR${EVLO}/7.0i"

		# plot title.
		cat > ${EQ}_pstext.txt << EOF
0 -1 ${MM}/${DD}/${YYYY} ${HH}:${MIN}
EOF
		gmt pstext ${EQ}_pstext.txt -JX8.5i/1i -R-1/1/-1/1 -F+jCB+f20p,Helvetica,black -N -Xf0i -Yf10i -P -K > ${PLOTFILE}

		cat > ${EQ}_pstext.txt << EOF
0 -1 ${EQ} LAT=${EVLA} LON=${EVLO} Z=${EVDP} Mb=${MAG} NSTA=${NSTA}
EOF
		gmt pstext ${EQ}_pstext.txt -J -R -F+jCB+f14p,Helvetica,black -N -Xf0i -Yf9.5i -O -K >> ${PLOTFILE}


		# plot script name and date tag.
		cat > ${EQ}_pstext.txt << EOF
0 -1 SCRIPT: `basename ${0}` `date "+CREATION DATE: %m/%d/%y  %H:%M:%S"`
EOF
		gmt pstext ${EQ}_pstext.txt -J -R -F+jCB+f10p,Helvetica,black -W0.1p,red -N -Xf0i -Yf1.0i -O -K >> ${PLOTFILE}


		# plot the coast lines
		gmt pscoast ${REG} ${PROJ} -Ba0g45/a0g45wsne -Dl -A40000 -W0.01p,100/100/100 \
		-G200/200/200 -X0.70i -Yf4.5i -O -K >> ${PLOTFILE}


		# plot the GCPs.

		RGB[1]="30/30/30"
		RGB[2]="0/0/250"
		RGB[3]="0/130/255"
		RGB[4]="250/0/250"
		RGB[5]="120/250/250"
		RGB[6]="130/250/0"
		RGB[7]="255/255/0"
		RGB[8]="250/180/0"
		RGB[9]="250/0/0"
		RGB[10]="250/250/250"

		# decide which group each gcp path belongs to.
		rm -f ${EQ}_gcpfile_Group*
		while read STLO STLA GCARC
		do
			GroupNum=`echo "1+${GCARC}/20" | bc`
			printf ">\n%f %f\n%f %f\n" ${EVLO} ${EVLA} ${STLO} ${STLA} >> ${EQ}_gcpfile_Group${GroupNum}
		done < ${EQ}_stlo_stla_gcarc

		# plot each group.
		for GroupNum in `seq 1 10`
		do
			if [ -e ${EQ}_gcpfile_Group${GroupNum} ]
			then
				gmt psxy ${EQ}_gcpfile_Group${GroupNum} ${REG} ${PROJ} -W0.5p,${RGB[${GroupNum}]} -O -K >> ${PLOTFILE}
			fi
		done


		# plot the EQ and stations
		gmt psxy ${REG} ${PROJ} -Sa0.12i -O -K -W0.1p,black -G0 >> ${PLOTFILE} << EOF
${EVLO} ${EVLA}
EOF
		awk '{print $1,$2}' ${EQ}_stlo_stla_gcarc | gmt psxy ${REG} ${PROJ} -St0.03i -O -K -W0.1p,black -G0 >> ${PLOTFILE}


		# plot gcp legend.
		for GroupNum in `seq 1 9`
		do
			YPosition=`echo "4.2-${GroupNum}*0.25" | bc -l`
			gmt psxy -JX4.15i/0.1i -R-100/100/-1/1 -Xf0i -Yf${YPosition}i -W1p,${RGB[${GroupNum}]} -O -K >> ${PLOTFILE} << EOF
80 0
100 0
EOF
			cat > ${EQ}_pstext.txt << EOF
-100 0 `echo "(${GroupNum}-1)*20" | bc`-`echo "${GroupNum}*20" | bc` deg
EOF
			gmt pstext ${EQ}_pstext.txt -J -R -F+jLM+f8p,Helvetica,black -N -Xf4.35i -Yf${YPosition}i -O -K >> ${PLOTFILE}
		done

		# seal the plot.
		gmt psxy -J -R -O >> ${PLOTFILE} << EOF
EOF


	fi

done # End of EQ loop.

cd ${OUTDIR}

exit 0
