#!/bin/bash

# ====================================================================
# This script make 3 historgrams (gcarc, az ,baz) for each EQs.
#
# Ed Garnero/Pei-Ying(Patty) Lin/Shule Yu
# ====================================================================

echo ""
echo "--> `basename $0` is running. `date`"
mkdir -p ${a04DIR}
cd ${a04DIR}

# ==================================================
#              ! Work Begin !
# ==================================================


for EQ in `cat ${OUTDIR}/tmpfile_EQs_${RunNumber}`
do
	PLOTFILE=${PLOTDIR}/${EQ}.`basename ${0%.sh}`.ps

	# Ctrl+C action.
	trap "rm -f ${a04DIR}/${EQ}* ${PLOTFILE} ${OUTDIR}/*_${RunNumber}; exit 1" SIGINT


	# A. Check the exist of list file.
	if ! [ -s "${a01DIR}/${EQ}_FileList" ]
	then
		echo "    ~=> ${EQ} doesn't have FileList ..."
		continue
	else
		echo "    ==> Making Histogram of ${EQ}."
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

	keys="<Gcarc> <Az> <BAz> <NETWK> <STNM>"
	${BASHCODEDIR}/Findfield.sh ${a01DIR}/${EQ}_FileList_Info "${keys}" | sort -u -k 4,5 | awk '{print $1,$2,$3}' > ${EQ}_gcarc_az_baz

	NSTA=`wc -l < ${EQ}_gcarc_az_baz`

	# C. Plot. (GMT-4)
	if [ ${GMTVERSION} -eq 4 ]
	then

		# basic gmt settings
		gmtset PAPER_MEDIA = letter
		gmtset ANNOT_FONT_SIZE_PRIMARY = 12p
		gmtset LABEL_FONT_SIZE = 16p
		gmtset LABEL_OFFSET = 0.1c
		gmtset BASEMAP_FRAME_RGB = +0/0/0
		gmtset GRID_PEN_PRIMARY = 0.5p,gray,-


		# Count:
		# A. gcarc histogram info with a bin width of 5 deg.
		# B. az histogram info with a bin width of 5 deg.
		# C. baz histogram info with a bin width of 5 deg.

		# A. gcarc

		XINC=5
		awk '{print $1}' ${EQ}_gcarc_az_baz | pshistogram -W${XINC} -IO > ${EQ}_Count_gcarc

		# B. az

		XINC=5
		awk '{print $2}' ${EQ}_gcarc_az_baz | pshistogram -W${XINC} -IO > ${EQ}_Count_az

		# C. baz

		XINC=5
		awk '{print $3}' ${EQ}_gcarc_az_baz | pshistogram -W${XINC} -IO > ${EQ}_Count_baz

		# Plot:
		# title.
		# A. gcarc from 0 to 180 deg, add 20% to maximum count.
		# B. az from 0 to 360 deg, add 20% to maximum count.
		# C. baz from 0 to 360 deg, add 20% to maximum count.

		# title.
		pstext -JX8.5i/1i -R-100/100/-1/1 -X0i -Y9.5i -N -P -K > ${PLOTFILE} << EOF
0 1 20 0 0 CB ${MM}/${DD}/$YYYY ${HH}:${MIN}
0 0 14 0 0 CB ${EQ} LAT=${EVLA} LON=${EVLO} Z=${EVDP} Mb=${MAG} NSTA=${NSTA}
EOF


		# A. gcarc
		XMIN=0
		XMAX=180
		XINC=5
		XNUM=20

		YMIN=0
		YMAX=`minmax -C ${EQ}_Count_gcarc | awk '{print $4}'`
		YMAX=` echo ${YMAX} | awk '{if ($1<45) print 45; else print 10*int(1.2*$1/10) }' `
		YNUM=` echo ${YMAX} | awk '{if ($1<100) print 20; else print 20*int(1.0*$1/100.0)}' `
		YINC=` echo ${YNUM} | awk '{print int(1.0*$1/2.0)}' `

		XLABEL="Epicentral Distance (deg)"
		YLABEL="Frequency"

		psbasemap -Ba${XNUM}f${XINC}:"${XLABEL}":/a${YNUM}f${YINC}g${YNUM}:"${YLABEL}":WS \
		-R${XMIN}/${XMAX}/${YMIN}/${YMAX} -JX6.0i/1.5i -X1.25i -Y-1.75i -O -K >> ${PLOTFILE}

		awk '{print $1}' ${EQ}_gcarc_az_baz | pshistogram -R -J -W${XINC} -L0.5p -G50/50/250 -O -K >> ${PLOTFILE}

		# B. az
		XMIN=0
		XMAX=360
		XINC=5
		XNUM=40

		YMIN=0
		YMAX=`minmax -C ${EQ}_Count_az | awk '{print $4}'`

		YMAX=` echo ${YMAX} | awk '{if ($1<45) print 45; else print 10*int(1.2*$1/10) }' `
		YNUM=` echo ${YMAX} | awk '{if ($1<100) print 20; else print 20*int(1.0*$1/100.0)}' `
		YINC=` echo ${YNUM} | awk '{print int(1.0*$1/2.0)}' `


		XLABEL="Source Azimuth (deg)"
		YLABEL="Frequency"

		psbasemap -Ba${XNUM}f${XINC}:"${XLABEL}":/a${YNUM}f${YINC}g${YNUM}:"${YLABEL}":WS \
		-R${XMIN}/${XMAX}/${YMIN}/${YMAX} -JX6.0i/2i -Y-3i -O -K >> ${PLOTFILE}

		awk '{print $2}' ${EQ}_gcarc_az_baz | pshistogram -R -J -W${XINC} -L0.5p -G50/50/250 -O -K >> ${PLOTFILE}

		# C. baz
		XMIN=0
		XMAX=360
		XINC=5
		XNUM=40

		YMIN=0
		YMAX=`minmax -C ${EQ}_Count_baz | awk '{print $4}'`

		YMAX=` echo ${YMAX} | awk '{if ($1<45) print 45; else print 10*int(1.2*$1/10) }' `
		YNUM=` echo ${YMAX} | awk '{if ($1<100) print 20; else print 20*int(1.0*$1/100.0)}' `
		YINC=` echo ${YNUM} | awk '{print int(1.0*$1/2.0)}' `

		XLABEL="Station Back Azimuth (deg)"
		YLABEL="Frequency"

		psbasemap -Ba${XNUM}f${XINC}:"${XLABEL}":/a${YNUM}f${YINC}g${YNUM}:"${YLABEL}":WS \
		-R${XMIN}/${XMAX}/${YMIN}/${YMAX} -JX6.0i/2i -Y-3i -O -K >> ${PLOTFILE}

		awk '{print $3}' ${EQ}_gcarc_az_baz | pshistogram -R -J -W${XINC} -L0.5p -G50/50/250 -O -K >> ${PLOTFILE}

		# plot tag
		pstext -J -R -N -Wored -G0 -O -Y-1.0i >> ${PLOTFILE} << EOF
180.0 0.0 10 0 0 CB SCRIPT: `basename ${0}` `date "+CREATION DATE: %m/%d/%y  %H:%M:%S"`
EOF

	fi


	# C*. Plot. (GMT-5)
	if [ ${GMTVERSION} -eq 5 ]
	then

		# basic gmt settings
		gmt gmtset PS_MEDIA letter
		gmt gmtset FONT_ANNOT_PRIMARY 12p
		gmt gmtset FONT_LABEL 16p
		gmt gmtset MAP_LABEL_OFFSET 6p
		gmt gmtset MAP_FRAME_PEN black
		gmt gmtset MAP_GRID_PEN_PRIMARY 0.5p,gray,-


		# Count:
		# A. gcarc histogram info with a bin width of 5 deg.
		# B. az histogram info with a bin width of 5 deg.
		# C. baz histogram info with a bin width of 5 deg.

		# A. gcarc

		XINC=5
		awk '{print $1}' ${EQ}_gcarc_az_baz | gmt pshistogram -W${XINC} -IO > ${EQ}_Count_gcarc

		# B. az

		XINC=5
		awk '{print $2}' ${EQ}_gcarc_az_baz | gmt pshistogram -W${XINC} -IO > ${EQ}_Count_az

		# C. baz

		XINC=5
		awk '{print $3}' ${EQ}_gcarc_az_baz | gmt pshistogram -W${XINC} -IO > ${EQ}_Count_baz

		# Plot:
		# title.
		# A. gcarc from 0 to 180 deg, add 20% to maximum count.
		# B. az from 0 to 360 deg, add 20% to maximum count.
		# C. baz from 0 to 360 deg, add 20% to maximum count.

		# title.
		echo "0 1 ${MM}/${DD}/$YYYY ${HH}:${MIN}" > ${EQ}_text.txt
		gmt pstext ${EQ}_text.txt -JX8.5i/1i -R-100/100/-1/1 -F+jCB+f20p,Helvetica,black -Xf0i -Yf9.5i -N -P -K > ${PLOTFILE}
		echo "0 0 ${EQ} LAT=${EVLA} LON=${EVLO} Z=${EVDP} Mb=${MAG} NSTA=${NSTA}" > ${EQ}_text.txt
		gmt pstext ${EQ}_text.txt -JX8.5i/1i -R-100/100/-1/1 -F+jCB+f14p,Helvetica,black -Xf0i -Yf9.5i -N -O -K >> ${PLOTFILE}

		# A. gcarc
		XMIN=0
		XMAX=180
		XINC=5
		XNUM=20

		YMIN=0
		YMAX=`minmax -C ${EQ}_Count_gcarc | awk '{print $4}'`

		YMAX=` echo ${YMAX} | awk '{if ($1<45) print 45; else print 10*int(1.2*$1/10) }' `
		YNUM=` echo ${YMAX} | awk '{if ($1<100) print 20; else print 20*int(1.0*$1/100.0)}' `
		YINC=` echo ${YNUM} | awk '{print int(1.0*$1/2.0)}' `

		XLABEL="Epicentral Distance (deg)"
		YLABEL="Frequency"

		gmt psbasemap -Ba${XNUM}f${XINC}:"${XLABEL}":/a${YNUM}f${YINC}g${YNUM}:"${YLABEL}":WS \
		-R${XMIN}/${XMAX}/${YMIN}/${YMAX} -JX6.0i/1.5i -X1.25i -Y-1.75i -O -K >> ${PLOTFILE}

		awk '{print $1}' ${EQ}_gcarc_az_baz | gmt pshistogram -R -J -W${XINC} -L0.5p -G50/50/250 -O -K >> ${PLOTFILE}

		# B. az
		XMIN=0
		XMAX=360
		XINC=5
		XNUM=40

		YMIN=0
		YMAX=`minmax -C ${EQ}_Count_az | awk '{print $4}'`

		YMAX=` echo ${YMAX} | awk '{if ($1<45) print 45; else print 10*int(1.2*$1/10) }' `
		YNUM=` echo ${YMAX} | awk '{if ($1<100) print 20; else print 20*int(1.0*$1/100.0)}' `
		YINC=` echo ${YNUM} | awk '{print int(1.0*$1/2.0)}' `

		XLABEL="Source Azimuth (deg)"
		YLABEL="Frequency"

		gmt psbasemap -Ba${XNUM}f${XINC}:"${XLABEL}":/a${YNUM}f${YINC}g${YNUM}:"${YLABEL}":WS \
		-R${XMIN}/${XMAX}/${YMIN}/${YMAX} -JX6.0i/2i -Y-3i -O -K >> ${PLOTFILE}

		awk '{print $2}' ${EQ}_gcarc_az_baz | gmt pshistogram -R -J -W${XINC} -L0.5p -G50/50/250 -O -K >> ${PLOTFILE}

		# C. baz
		XMIN=0
		XMAX=360
		XINC=5
		XNUM=40

		YMIN=0
		YMAX=`minmax -C ${EQ}_Count_baz | awk '{print $4}'`

		YMAX=` echo ${YMAX} | awk '{if ($1<45) print 45; else print 10*int(1.2*$1/10) }' `
		YNUM=` echo ${YMAX} | awk '{if ($1<100) print 20; else print 20*int(1.0*$1/100.0)}' `
		YINC=` echo ${YNUM} | awk '{print int(1.0*$1/2.0)}' `

		XLABEL="Station Back Azimuth (deg)"
		YLABEL="Frequency"

		gmt psbasemap -Ba${XNUM}f${XINC}:"${XLABEL}":/a${YNUM}f${YINC}g${YNUM}:"${YLABEL}":WS \
		-R${XMIN}/${XMAX}/${YMIN}/${YMAX} -JX6.0i/2i -Y-3i -O -K >> ${PLOTFILE}

		awk '{print $3}' ${EQ}_gcarc_az_baz | gmt pshistogram -R -J -W${XINC} -L0.5p -G50/50/250 -O -K >> ${PLOTFILE}

		# plot tag
		echo "180.0 0.0 SCRIPT: `basename ${0}` `date "+CREATION DATE: %m/%d/%y  %H:%M:%S"`" > ${EQ}_text.txt
		gmt pstext ${EQ}_text.txt -J -R -F+jCB+f10p,Helvetica,black -N -Wred -O -Y-1.0i >> ${PLOTFILE}


	fi

done # End of EQ loop.

cd ${OUTDIR}

exit 0
