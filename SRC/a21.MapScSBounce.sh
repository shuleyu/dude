#!/bin/bash

# ====================================================================
# This script make ScS bouncing points (using TauP), then plot the
# bouncing points on a map.
#
# Ed Garnero/Pei-Ying(Patty) Lin/Shule Yu
# ====================================================================

echo ""
echo "--> `basename $0` is running. `date`"
mkdir -p ${a21DIR}
cd ${a21DIR}

# ==================================================
#              ! Work Begin !
# ==================================================

# Set TauP precision.
echo "taup.distance.precision=3" > .taup
echo "taup.time.precision=3" >> .taup


for EQ in `cat ${OUTDIR}/tmpfile_EQs_${RunNumber}`
do

	# Ctrl+C action.
	trap "rm -f ${a21DIR}/${EQ}* ${OUTDIR}/*_${RunNumber}; exit 1" SIGINT


	# A. Check the exist of list file.
	if ! [ -s "${a01DIR}/${EQ}_FileList" ]
	then
		echo "    ~=> ${EQ} doesn't have FileList ..."
		continue
	else
		echo "    ==> Making ScS bouncing points map of ${EQ}."
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

	# C. Check phase file.

    if ! [ -s "`ls ${a05DIR}/${EQ}_*_ScS.gmt_Enveloped 2>/dev/null`" ]
    then
        echo "        ~=> Can't find Firsta Arrival file !"
        continue
    else
        PhaseFile=`ls ${a05DIR}/${EQ}_*_ScS.gmt_Enveloped`
        PhaseDistMin=`minmax -C ${PhaseFile} | awk '{print $1}'`
        PhaseDistMax=`minmax -C ${PhaseFile} | awk '{print $2}'`
    fi


    PLOTFILE=${PLOTDIR}/${EQ}.`basename ${0%.sh}`.ps

    # Clean dir.
    rm -f ${a21DIR}/${EQ}*

    # Ctrl+C action.
    trap "rm -f ${a21DIR}/${EQ}* ${PLOTFILE} ${OUTDIR}/*_${RunNumber}; exit 1" SIGINT


    # D. Select gcp distance window.
    keys="<NETWK> <STNM> <Gcarc> <STLO> <STLA>"
    ${BASHCODEDIR}/Findfield.sh ${a01DIR}/${EQ}_FileList_Info "${keys}" | sort | uniq \
    | awk -v D1=${PhaseDistMin} -v D2=${PhaseDistMax} '{if (D1<=$3 && $3<=D2) print $1,$2,$4,$5}' > ${EQ}_net_stn_stlo_stla

	if ! [ -s "${EQ}_net_stn_stlo_stla" ]
	then
		echo "        ~=>${EQ} has 0 ScS phase recorded in this data set..."
		continue
	fi


    # E. Call TauP to get bouncing point lon/lat.
    echo "<NETWK> <STNM> <STLO> <STLA> <ScS_HitLO> <ScS_HitLA>" > ${EQ}_ScSHit.List
    while read netwk stnm STLO STLA
    do
        taup_path -ph ScS -h ${EVDP} -sta ${STLA} ${STLO} -evt ${EVLA} ${EVLO} -mod ${Model_TT} -o stdout | awk -v stlo=${STLO} -v stla=${STLA} -v net=${netwk} -v stn=${stnm} '{if ($2==3480 && $3!="") print net,stn,stlo,stla,$4,$3}' >> ${EQ}_ScSHit.List
    done < ${EQ}_net_stn_stlo_stla

    NSTA=`wc -l < ${EQ}_ScSHit.List`
    NSTA=$((NSTA-1))

	# F. make a great circle path file.
	keys="<STLO> <STLA>"
	${BASHCODEDIR}/Findfield.sh ${EQ}_ScSHit.List "${keys}" > ${EQ}_stlo_stla

	keys="<ScS_HitLO> <ScS_HitLA>"
	${BASHCODEDIR}/Findfield.sh ${EQ}_ScSHit.List "${keys}" > ${EQ}_hitlo_hitla

	rm -f ${EQ}_gcpfile
	while read stlo stla
	do
		printf ">\n%f %f\n%f %f\n" ${EVLO} ${EVLA} ${stlo} ${stla} >> ${EQ}_gcpfile
	done < ${EQ}_stlo_stla

    # G. plot. (GMT-4)
    if [ ${GMTVERSION} -eq 4 ]
    then

        # basic gmt settings
        gmtset PAPER_MEDIA = letter
        gmtset ANNOT_FONT_SIZE_PRIMARY = 12p
        gmtset LABEL_FONT_SIZE = 16p
        gmtset LABEL_OFFSET = 0.1i
        gmtset BASEMAP_FRAME_RGB = +0/0/0
        gmtset GRID_PEN_PRIMARY = 0.5p,gray,-

		# projection and map range.
		REG="-R-180/180/-90/90"
		PROJ="-JR${EVLO}/9i"
        CPT="-C${SRCDIR}/ritsema.cpt"

        # plot title and tag.
        pstext -JX11i/1i -R-100/100/-1/1 -N -X0i -Y7i -K > ${PLOTFILE} << EOF
0 1 20 0 0 CB Event: ${MM}/${DD}/${YYYY} ${HH}:${MIN}  ScS CMB bounce points
0 0.5 15 0 0 CB ${EQ} LAT=${EVLA} LON=${EVLO} Z=${EVDP} Mb=${MAG} NSTA=${NSTA}/${NSTA_All}
0 0 12 0 0 CB Tomography model:  S20RTS (Ritsema) Z=2880 km
EOF
        pstext -J -R -N -Wored -G0 -Y-0.5i -O -K >> ${PLOTFILE} << EOF
0 0.5 10 0 0 CB SCRIPT: `basename ${0}` `date "+CREATION DATE: %m/%d/%y  %H:%M:%S"`
EOF
        # plot S20RTS @ 2891 km.
        xyz2grd ${SRCDIR}/ritsema.2880 -G2880.grd -I2 ${REG} -:
        grdimage 2880.grd ${CPT} ${REG} ${PROJ} -E40 -K -O -X1i -Y-5.3i >> ${PLOTFILE}

        # add a color scale for the tomography map
        psscale ${CPT} -D4.5i/-0.2i/3.0i/0.13ih -B2/:"@~\144@~Vs (%)": -O -K -N300 >> ${PLOTFILE}

		# plot the coast lines
		pscoast ${REG} ${PROJ} -Ba0g45/a0g45wsne -Dl -A40000 -W2 -O -K >> ${PLOTFILE}

        # then plot the great circle path file
        psxy ${EQ}_gcpfile ${REG} ${PROJ} -m -K -O -W1.0/250/0/200t5_15:0 >> ${PLOTFILE}

		# now plot the EQ and stations
		psxy ${REG} ${PROJ} -Sa0.12i -K -O -W1/0/0/0 -G0 >> ${PLOTFILE} << EOF
${EVLO} ${EVLA}
EOF
		psxy ${EQ}_stlo_stla ${REG} ${PROJ} -St0.03i -K -O -W1/0/0/0 -G0 >> ${PLOTFILE}

		# now plot the ScS bounce points:
		psxy ${EQ}_hitlo_hitla ${REG} ${PROJ} -Sx+0.15i -O -W3/yellow >> ${PLOTFILE}

    fi

    # G*. plot. (GMT-5)
    if [ ${GMTVERSION} -eq 5 ]
    then

        # basic gmt settings
        gmt gmtset PS_MEDIA letter
        gmt gmtset FONT_ANNOT_PRIMARY 12p
        gmt gmtset FONT_LABEL 16p
        gmt gmtset MAP_LABEL_OFFSET 0.1i
        gmt gmtset MAP_FRAME_PEN black
        gmt gmtset MAP_GRID_PEN_PRIMARY 0.5p,gray,-

		# projection and map range.
		REG="-R-180/180/-90/90"
		PROJ="-JR${EVLO}/9i"
        CPT="-C${SRCDIR}/ritsema.cpt"

        # plot title and tag.
        cat > ${EQ}_plottext.txt << EOF
0 1 Event: ${MM}/${DD}/${YYYY} ${HH}:${MIN}  ScS CMB bounce points
0 0.5 @:15:${EQ} LAT=${EVLA} LON=${EVLO} Z=${EVDP} Mb=${MAG} NSTA=${NSTA}/${NSTA_All}@::
0 0 @:12:Tomography model:  S20RTS (Ritsema) Z=2880 km@::
EOF
        gmt pstext ${EQ}_plottext.txt -JX11i/1i -R-100/100/-1/1 -F+jCB+f20p,Helvetica,black -N -Xf0i -Yf7i -K > ${PLOTFILE}

        cat > ${EQ}_plottext.txt << EOF
0 0.5 SCRIPT: `basename ${0}` `date "+CREATION DATE: %m/%d/%y  %H:%M:%S"`
EOF
        gmt pstext ${EQ}_plottext.txt -J -R -F+jCB+f10p,Helvetica,black -N -Wred -Y-0.5i -O -K >> ${PLOTFILE}

        # plot S20RTS @ 2891 km.
        gmt xyz2grd ${SRCDIR}/ritsema.2880 -G2880.grd -I2 ${REG} -:
        gmt grdimage 2880.grd ${CPT} ${REG} ${PROJ} -E40 -K -O -X1i -Y-5.3i >> ${PLOTFILE}

        # add a color scale for the tomography map
        gmt psscale ${CPT} -D4.5i/-0.2i/3.0i/0.13ih -B2/:"@~\144@~Vs (%)": -O -K -N300 >> ${PLOTFILE}

		# plot the coast lines
		gmt pscoast ${REG} ${PROJ} -Ba0g45/a0g45wsne -Dl -A40000 -W0.5 -O -K >> ${PLOTFILE}


        # then plot the great circle path file
        gmt psxy ${EQ}_gcpfile ${REG} ${PROJ} -K -O -W1.0,250/0/200,. >> ${PLOTFILE}

		# now plot the EQ and stations
		gmt psxy ${REG} ${PROJ} -Sa0.12i -K -O -W1,0/0/0 -G0 >> ${PLOTFILE} << EOF
${EVLO} ${EVLA}
EOF
		gmt psxy ${EQ}_stlo_stla ${REG} ${PROJ} -St0.03i -K -O -W1,0/0/0 -G0 >> ${PLOTFILE}

		# now plot the ScS bounce points:
		gmt psxy ${EQ}_hitlo_hitla ${REG} ${PROJ} -Sx+0.15i -O -W1,yellow >> ${PLOTFILE}


    fi

done # End of EQ loop.

cd ${OUTDIR}

exit 0
