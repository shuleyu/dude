#!/bin/bash

# ====================================================================
# This script make a map showing contours of constant epicentral
# distance from the earthquake, along with some major cities.
#
# Ed Garnero/Pei-Ying(Patty) Lin/Shule Yu
# ====================================================================

echo ""
echo "--> `basename $0` is running. `date`"
mkdir -p ${a03DIR}
cd ${a03DIR}

# City list.
cat > Cities.txt << EOF
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

# ==================================================
#              ! Work Begin !
# ==================================================

for EQ in `cat ${OUTDIR}/tmpfile_EQs_${RunNumber}`
do
	PLOTFILE="${PLOTDIR}/${EQ}.`basename ${0%.sh}`.ps"

	# Ctrl+C action.
	trap "rm -f ${a03DIR}/${EQ}* ${PLOTFILE} ${OUTDIR}/*_${RunNumber}; exit 1" SIGINT

	# A. Check the exist of list file.
	if ! [ -s ${a01DIR}/${EQ}_FileList ]
	then
		echo "    ~=> ${EQ} doesn't have FileList ..."
		continue
	else
		echo "    ==> Making CityMap of ${EQ}."
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

	# C. Calculate city distance.
	rm -f ${EQ}_CityDist.txt tmpfile_$$
	while read CityLO CityLA CityName
	do
		${EXECDIR}/GcpDistance.out 0 0 4 > tmpfile_$$ << EOF
${EVLO}
${EVLA}
${CityLO}
${CityLA}
EOF
		read Dist < tmpfile_$$
		echo ${Dist} ${CityName} >> ${EQ}_CityDist.txt
	done < Cities.txt

	sort -g -k 1,1 ${EQ}_CityDist.txt > tmpfile_$$
	mv tmpfile_$$ ${EQ}_CityDist.txt


	# D. Make event-city gcp files.
	rm -f ${EQ}_gcpfile
	while read CityLO CityLA CityName
	do
		printf ">\n%f %f\n%f %f\n" ${EVLO} ${EVLA} ${CityLO} ${CityLA} >> ${EQ}_gcpfile
	done < Cities.txt


	# D. Plot. (GMT-4)
	if [ ${GMTVERSION} -eq 4 ]
	then

		# basic gmt settings
		gmtset PAPER_MEDIA = letter
		gmtset ANNOT_FONT_SIZE_PRIMARY = 8p
		gmtset LABEL_FONT_SIZE = 9p
		gmtset LABEL_OFFSET = 0.1c
		gmtset BASEMAP_FRAME_RGB = 100/100/100

		# projection and map range.
		REG="-R0/360/-90/90"
		PROJ="-JR${EVLO}/7.0i"


		# plot the coast lines
		LAND="150/150/100"
		WATER="100/150/200"
		pscoast ${REG} ${PROJ} -Ba0g45/a0g45wsne -Dl -A40000 -W3/50 -G${LAND} -S${WATER} -X0.70i -Y5.5i -P -K > ${PLOTFILE}


		# plot basemap
		psbasemap ${REG} ${PROJ} -Bg45 -O -K >> ${PLOTFILE}


		# plot contour

		# 1. define color of distance contours and labels
		CONTCOL="220/220/220"

		# 2. the location of the numbering of contours is being defined
		# here to happen between event coords and some shift in longitude
		EVLA2="-80"
		EVLO2=`echo ${EVLO} | awk '{print 1.*$1 + 160}'`

		# 3. use GMT's grdmath to compute a file with distances across the
		# whole globe, from the EQ:
		grdmath ${REG} -I1 ${EVLO} ${EVLA} SDIST = dist.grd

		# 4. draw the equal distance contours (see the GMT man page for more
		# info on some of these choices. again, thanks to Kevin Eagar for this
		# idea of using gmtmath w/ grdcontour for this application
		grdcontour dist.grd ${PROJ} -A10+s11+f1+k${CONTCOL}+ap -Gl${EVLO}/${EVLA}/${EVLO2}/${EVLA2} \
		-S8 -W0.5/${CONTCOL} -B0 -O -K >> ${PLOTFILE}

		# plot gcp paths

		if [ -e ${EQ}_gcpfile ]
		then
			psxy ${EQ}_gcpfile ${REG} ${PROJ} -m -W8/blue -O -K >> ${PLOTFILE}
		fi

		# plot EQ and cities
		psxy ${REG} ${PROJ} -Sa0.2i -W3/0 -Gred -O -K >> ${PLOTFILE} << EOF
${EVLO} ${EVLA}
EOF
		awk '{print $1,$2}' Cities.txt | psxy ${REG} ${PROJ} -St0.15i -W1/0 -Gyellow -O -K >> ${PLOTFILE}

		# plot titles
		pstext ${REG} ${PROJ} -N -O -K -Y0.8i >> ${PLOTFILE} << EOF
${EVLO} 90 20 0 0 CB ${MM}/${DD}/${YYYY} ${HH}:${MIN}
EOF
		pstext ${REG} ${PROJ} -N -O -K -Y-0.6i >> ${PLOTFILE} << EOF
${EVLO} 90 14 0 0 CB ${EQ} LAT=${EVLA} LON=${EVLO} Z=${EVDP} Mb=${MAG}
EOF

		# plot city names
		awk '{$1=$1+5;$2=$2" 11 0 5 ML"; print $0}' Cities.txt > Cities_Plot.txt
		pstext Cities_Plot.txt ${REG} ${PROJ} -N -Y-0.2i -O -K >> ${PLOTFILE}


		# plot city distance

		# shift cursor position. Add auxilliary grid: -Ba10g10/a10g10
		psxy -JX7.1i/4i -R-100/100/-100/100 -Y-4.5i -O -K >> ${PLOTFILE} << EOF
EOF
		pstext -J -R -N -O -K >> ${PLOTFILE} << EOF
-10 100 14 0 7 RM City
10 100 14 0 7 LM Distance (deg)
EOF

		while read Dist City
		do
			pstext -J -R -N -Y-0.25i -O -K >> ${PLOTFILE} << EOF
-10 100 12 0 0 RM ${City}
10 100 12 0 0 LM ${Dist}
EOF
		done < ${EQ}_CityDist.txt

		# script name and date tag.
		pstext -J -R -N -Wored -G0 -O -Y-1.0i >> ${PLOTFILE} << EOF
0.0 100.0 10 0 0 CB SCRIPT: `basename ${0}` `date "+CREATION DATE: %m/%d/%y  %H:%M:%S"`
EOF

	fi

	# D*. Plot. (GMT-5)
	if [ ${GMTVERSION} -eq 5 ]
	then

		# basic gmt settings
		gmt gmtset PS_MEDIA letter
		gmt gmtset FONT_ANNOT_PRIMARY 8p
		gmt gmtset FONT_LABEL 9p
		gmt gmtset MAP_LABEL_OFFSET 6p
		gmt gmtset MAP_FRAME_PEN 2p,black
		gmt gmtset MAP_GRID_PEN_PRIMARY 0.25p,100/100/100

		# projection and map range.
		REG="-R0/360/-90/90"
		PROJ="-JR${EVLO}/7.0i"


		# plot title.
		echo "0 -1 ${MM}/${DD}/${YYYY} ${HH}:${MIN}" > ${EQ}_pstext.txt
		gmt pstext ${EQ}_pstext.txt -JX8.5i/1i -R-1/1/-1/1 -F+jCB+f20p,Helvetica,black -N -Xf0i -Yf10i -P -K > ${PLOTFILE}

		echo "0 -1 ${EQ} LAT=${EVLA} LON=${EVLO} Z=${EVDP} Mb=${MAG}" > ${EQ}_pstext.txt
		gmt pstext ${EQ}_pstext.txt -J -R -F+jCB+f14p,Helvetica,black -N -Xf0i -Yf9.5i -O -K >> ${PLOTFILE}


		# plot script name and date tag.
		echo "0 -1 SCRIPT: `basename ${0}` `date "+CREATION DATE: %m/%d/%y  %H:%M:%S"`" > ${EQ}_pstext.txt
		gmt pstext ${EQ}_pstext.txt -J -R -F+jCB+f10p,Helvetica,black -W0.1p,red -N -Xf0i -Yf0.5i -O -K >> ${PLOTFILE}


		# plot the coast lines
		LAND="150/150/100"
		WATER="100/150/200"
		gmt pscoast ${REG} ${PROJ} -Ba0g45/a0g45wsne -Dl -A40000 -W0.1p,50 -G${LAND} -S${WATER} -X0.70i -Yf4.5i -O -K >> ${PLOTFILE}

		# plot contour

		# 1. define color of distance contours and labels
		CONTCOL="220/220/220"

		# 2. the location of the numbering of contours is being defined
		# here to happen between event coords and some shift in longitude
		EVLA2="-80"
		EVLO2=`echo ${EVLO} | awk '{print 1.*$1 + 160}'`

		# 3. use GMT's grdmath to compute a file with distances across the
		# whole globe, from the EQ: (for GMT-5, they use km in unit -_-|.. )
		gmt grdmath -Rg -I1deg ${EVLO} ${EVLA} SDIST = dist.grd
		gmt grdmath -Rg dist.grd 111.195 DIV = dist.grd

		# 4. draw the equal distance contours (see the GMT man page for more
		# info on some of these choices. again, thanks to Kevin Eagar for this
		# idea of using gmtmath w/ grdcontour for this application
		gmt grdcontour dist.grd ${PROJ} -A10+f11p,Helvetica,${CONTCOL}+ap -Gl${EVLO}/${EVLA}/${EVLO2}/${EVLA2} \
		-S8 -W0.5p,${CONTCOL} -B0 -O -K >> ${PLOTFILE}


		# plot the GCPs.

		if [ -e ${EQ}_gcpfile ]
		then
			gmt psxy ${EQ}_gcpfile ${REG} ${PROJ} -W2p,blue -O -K >> ${PLOTFILE}
		fi

		# plot the EQ and cities
		gmt psxy ${REG} ${PROJ} -Sa0.2i -O -K -W0.1p,black -Gred >> ${PLOTFILE} << EOF
${EVLO} ${EVLA}
EOF
		awk '{print $1,$2}' Cities.txt | gmt psxy ${REG} ${PROJ} -St0.15i -O -K -W1,black -Gyellow >> ${PLOTFILE}


		# plot city names
		awk '{$1=$1+5;print $0}' Cities.txt > Cities_Plot.txt
		gmt pstext Cities_Plot.txt -J -R -F+jLM+f11p,Times-Bold,black -N -O -K >> ${PLOTFILE}


		# plot city distance
		echo "-10 110 City" > ${EQ}_pstext1.txt
		echo "10 110 Distance (deg)" > ${EQ}_pstext2.txt

		# Shift plot origin. Auxilliary grid: -Ba10g10/a10g10
		gmt pstext ${EQ}_pstext1.txt -JX8.5i/3i -R-100/100/-100/100 -F+jRB+f14p,Times-BoldItalic,black -N -Xf0i -Yf1.0i -O -K >> ${PLOTFILE}
		gmt pstext ${EQ}_pstext2.txt -J -R -F+jLB+f14p,Times-BoldItalic,black -N -O -K >> ${PLOTFILE}

		rm -f ${EQ}_pstext1.txt ${EQ}_pstext2.txt
		YPosition=90
		while read Dist City
		do
			echo "-10 ${YPosition} ${City}" >> ${EQ}_pstext1.txt
			echo "10 ${YPosition} ${Dist}" >> ${EQ}_pstext2.txt
			YPosition=$((YPosition-15))
		done < ${EQ}_CityDist.txt
		gmt pstext ${EQ}_pstext1.txt -J -R -F+jRB+f12p,Helvetica,black -N -O -K >> ${PLOTFILE}
		gmt pstext ${EQ}_pstext2.txt -J -R -F+jLB+f12p,Helvetica,black -N -O -K >> ${PLOTFILE}


		# seal the plot.
		gmt psxy -J -R -O >> ${PLOTFILE} << EOF
EOF

	fi

done # End of EQ loop.

cd ${OUTDIR}

exit 0
