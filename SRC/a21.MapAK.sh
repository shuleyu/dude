#!/bin/bash

# ====================================================================
# This script uses GMT to plot a map of TA stations, great circle
# paths, and equi-distance contour lines.
#
# Ed Garnero/Pei-Ying(Patty) Lin/Shule Yu
# ====================================================================

echo ""
echo "--> `basename $0` is running. `date`"
mkdir -p ${a20DIR}
cd ${a20DIR}


# ==================================================
#              ! Work Begin !
# ==================================================

for EQ in `cat ${OUTDIR}/tmpfile_EQs_${RunNumber}`
do
	PLOTFILE="${PLOTDIR}/${EQ}.`basename ${0%.sh}`.ps"

	# Ctrl+C action.
	trap "rm -f ${a20DIR}/${EQ}* ${PLOTFILE} ${OUTDIR}/*_${RunNumber}; exit 1" SIGINT

	# A. Check the exist of list file.
	if ! [ -s "${a01DIR}/${EQ}_FileList" ]
	then
		echo "    ~=> ${EQ} doesn't have FileList ..."
		continue
	else
		echo "    ==> Making TA NetWK map of ${EQ}."
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

	# C. Select only TA station.
	keys="<STLO> <STLA>"
	${BASHCODEDIR}/Findfield.sh ${a01DIR}/${EQ}_FileList_Info "${keys}" | uniq \
	| awk '{if (-115<=$1 && $1<=-109 && 32<=$2 && $2<=37) print $1,$2}' > ${EQ}_stlo_stla

	if ! [ -s ${EQ}_stlo_stla ]
	then
		echo "    ~=> ${EQ} doesn't have TA stations..."
		continue
	else
		NSTA=`wc -l < ${EQ}_stlo_stla`
	fi

	# D. Make event-station gcp files.
	rm -f ${EQ}_gcpfile
	while read stlo stla
	do
		printf ">\n%f %f\n%f %f\n" ${EVLO} ${EVLA} ${stlo} ${stlo} >> ${EQ}_gcpfile
	done < ${EQ}_stlo_stla

	# D. Plot. (GMT-4)
	if [ ${GMTVERSION} -eq 4 ]
	then

		# basic gmt settings
		gmtset PAPER_MEDIA = letter
		gmtset ANNOT_FONT_SIZE_PRIMARY = 8p
		gmtset LABEL_FONT_SIZE = 9p
		gmtset LABEL_OFFSET = 0.1c
		gmtset BASEMAP_FRAME_RGB = +0/0/0
		gmtset GRID_PEN_PRIMARY = 0.05p,100/100/100

		# projection and map range.
		REG="-R-120/20/-60/50r"
		PROJ="-JA-90/38/7.2i"


		# topography grd file and color platte.
		# resample the grid, as my etopo is rough (1x1):

		grdsample ${SRCDIR}/etopo5.grd -GTopo.grd -I0.3/0.3
		makecpt -Cglobe -T-6000/6000/200 -Z > Topo.cpt

		# use GMT's grdmath to compute a file with distances across the
		# whole globe, from the EQ:
		grdmath ${REG} -I1 ${EVLO} ${EVLA} SDIST = dist.grd


		# plot title.
		pstext -JX8.5i/1i -R-100/100/-1/1 -N -X0i -Y9.5i -P -K > ${PLOTFILE} << EOF
0 1 20 0 0 CB Event: ${MM}/${DD}/${YYYY} ${HH}:${MIN} USArray Transportable Array Stations
0 0.5 15  0 0 CB ${EQ} LAT=${EVLA} LON=${EVLO} Z=${EVDP} Mb=${MAG} NSTA=${NSTA}
EOF
		pstext -J -R -N -Wored -G0 -Y-0.3i -O -K >> ${PLOTFILE} << EOF
0 0.5 10 0 0 CB SCRIPT: `basename ${0}` `date "+CREATION DATE: %m/%d/%y  %H:%M:%S"`
EOF


		# plot topography.
		grdimage ${REG} ${PROJ} Topo.grd -CTopo.cpt -Sb -X0.50i -X1i -Y-7.5i -O -K >> ${PLOTFILE}


		# plot the state political boundaries
		gmtset BASEMAP_FRAME_RGB = 100/210/100
		pscoast ${REG} ${PROJ} -N2 -O -K >> ${PLOTFILE}

		# plot the national political boundaries
		gmtset BASEMAP_FRAME_RGB = orange
		pscoast ${REG} ${PROJ} -Dl -A10000 -N1 -O -K >> ${PLOTFILE}
		gmtset BASEMAP_FRAME_RGB = +0/0/0

		# brute force a lon/lat grid background file.
		rm -f ${EQ}_grid

		## lat line
		for lon in `seq -170 10 0`
		do
			for lat in `seq 0 2 80`
			do
				 echo ${lon} ${lat} >> ${EQ}_grid
			done
			echo ">" >> ${EQ}_grid
		done

		# lon line
		for lat in `seq 0 2 80`
		do
			for lon in `seq -170 10 0`
			do
				 echo ${lon} ${lat} >> ${EQ}_grid
			done
			echo ">" >> ${EQ}_grid
		done



		# plot our little grid (ya gotta love brute force)
		psxy ${EQ}_grid ${REG} ${PROJ} -m -B0 -W5/20/20/20t5_20:0 -O -K >> ${PLOTFILE}


		# plot the GCPs
		psxy ${REG} ${PROJ} ${EQ}_gcpfile -m -K -O -W0.01/100/30/100 >> ${PLOTFILE}

		# plot the EQ and stations
		psxy ${REG} ${PROJ} -Sa0.12i -K -O -W1/0/0/0 -G0 >> ${PLOTFILE} << EOF
${EVLO} ${EVLA}
EOF
		psxy ${EQ}_stlo_stla ${REG} ${PROJ} -St0.08i -K -O -W0.01/0 -G0 >> ${PLOTFILE}



		# draw the equal distance contours (see the GMT man page for more
		# info on some of these choices). again, thanks to Kevin Eagar for this
		# idea of using gmtmath w/ grdcontour for this application
		grdcontour dist.grd ${PROJ} ${REG} -A5+s14+f1+k255/0/0+ap -Gl-140/50/-60/0 \
            -C5 -S8 -W0.5,red -B0 -O >> ${PLOTFILE}


	fi

done

cd ${OUTDIR}

exit 0
