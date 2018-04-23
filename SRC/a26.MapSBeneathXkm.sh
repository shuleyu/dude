#!/bin/bash

# ====================================================================
# This script make S travel path (using TauP), then plot the
# path section below X km on a map.
#
# Ed Garnero/Pei-Ying(Patty) Lin/Shule Yu
# ====================================================================

echo ""
echo "--> `basename $0` is running. `date`"
mkdir -p ${a26DIR}
cd ${a26DIR}

# ==================================================
#              ! Work Begin !
# ==================================================

# Set TauP precision.
echo "taup.distance.precision=3" > .taup
echo "taup.time.precision=3" >> .taup


for EQ in `cat ${OUTDIR}/tmpfile_EQs_${RunNumber}`
do

	# Ctrl+C action.
	trap "rm -f ${a26DIR}/${EQ}* ${OUTDIR}/*_${RunNumber}; exit 1" SIGINT


	# A. Check the exist of list file.
	if ! [ -s "${a01DIR}/${EQ}_FileList" ]
	then
		echo "    ~=> ${EQ} doesn't have FileList ..."
		continue
	else
		echo "    ==> Making S,Sdiff path section beneath ${XDepth} km of ${EQ}."
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

    if ! [ -s "`ls ${a05DIR}/${EQ}_*_S.gmt_Enveloped 2>/dev/null`" ] || ! [ -s "`ls ${a05DIR}/${EQ}_*_Sdiff.gmt_Enveloped 2>/dev/null`" ]
    then
        echo "        ~=> Can't find Firsta Arrival file !"
        continue
    else
        cat ${a05DIR}/${EQ}_*_S.gmt_Enveloped ${a05DIR}/${EQ}_*_Sdiff.gmt_Enveloped > tmpfile_$$
        PhaseDistMin=`minmax -C tmpfile_$$ | awk '{print $1}'`
        PhaseDistMax=`minmax -C tmpfile_$$ | awk '{print $2}'`
    fi

    PLOTFILE=${PLOTDIR}/${EQ}.`basename ${0%.sh}`.ps

	# Clean dir.
	rm -f ${a26DIR}/${EQ}*

    # Ctrl+C action.
    trap "rm -f ${a26DIR}/${EQ}* ${a26DIR}/tmpfile_$$ ${PLOTFILE} ${OUTDIR}/*_${RunNumber}; exit 1" SIGINT


    # D. Select gcp distance window.
    keys="<NETWK> <STNM> <Gcarc> <STLO> <STLA> <Az>"
    ${BASHCODEDIR}/Findfield.sh ${a01DIR}/${EQ}_FileList_Info "${keys}" | sort -u -k 1,2 \
    | awk -v D1=${PhaseDistMin} -v D2=${PhaseDistMax} '{if (D1<=$3 && $3<=D2) print $1,$2,$3,$4,$5,$6}' > ${EQ}_net_stn_gcarc_stlo_stla_az

	# D'. Select gcp distance window ( minimum distance required for S to bottom beneath XDepth.

	l=40
	r=120
	Flag=1
	while [ `echo "${l} + 0.001 < ${r}" | bc` -eq 1 ]
	do
		mid=`echo "${l} ${r}" | awk '{print $1+($2-$1)/2}'`
		taup_path -ph S,Sdiff -h ${EVDP} -deg ${mid} -mod ${Model_TT} -o stdout | awk 'NR>1 {print $2}' > tmpfile_$$
		MinR=`minmax -C tmpfile_$$ | awk '{print $1}'`
		[ `echo "${MinR} < 3480+${XDepth}" | bc` -eq 1 ] && r=${mid} || l=${mid}
	done
	awk -v D1=${l} '{if (D1<=$3) print $1,$2,$4,$5,$6}' ${EQ}_net_stn_gcarc_stlo_stla_az > ${EQ}_net_stn_stlo_stla_az

	if ! [ -s "${EQ}_net_stn_stlo_stla_az" ]
	then
		echo "        ~=>${EQ} has 0 S,Sdiff path beneath ${XDepth} km recorded in this data set..."
		continue
	fi

    # E. Call TauP to get In-N-Out points.
	XPierce=`echo ${XDepth} | awk '{print 2891-$1}'`
    echo "<NETWK> <STNM> <STLO> <STLA> <S_LO_IN> <S_LA_IN> <S_LO_OUT> <S_LA_OUT>" > ${EQ}_S_${XDepth}km.List
    while read netwk stnm STLO STLA AZ
    do
        taup_pierce -ph S,Sdiff -h ${EVDP} -sta ${STLA} ${STLO} -evt ${EVLA} ${EVLO} -mod ${Model_TT} -pierce ${XPierce} -nodiscon | awk 'NR>1 {print $5,$4}' > tmpfile_$$
		
		echo "${netwk} ${stnm} ${STLO} ${STLA} `head -n 1 tmpfile_$$` `tail -n 1 tmpfile_$$`" >> ${EQ}_S_${XDepth}km.List
    done < ${EQ}_net_stn_stlo_stla_az

	rm -f tmpfile_$$

    NSTA=`wc -l < ${EQ}_S_${XDepth}km.List`
    NSTA=$((NSTA-1))

	# F. make a great circle path file.
	keys="<STLO> <STLA>"
	${BASHCODEDIR}/Findfield.sh ${EQ}_S_${XDepth}km.List "${keys}" > ${EQ}_stlo_stla

	keys="<S_LO_IN> <S_LA_IN> <S_LO_OUT> <S_LA_OUT>"
	${BASHCODEDIR}/Findfield.sh ${EQ}_S_${XDepth}km.List "${keys}" \
	| awk '{printf ">\n%f %f\n%f %f\n",$1,$2,$3,$4}' > ${EQ}_path

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
0 1 20 0 0 CB Event: ${MM}/${DD}/${YYYY} ${HH}:${MIN}  S,Sdiff paths beneath ${XDepth} km.
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

		# now plot the paths
		psxy ${EQ}_path ${REG} ${PROJ} -m -O -W2p/yellow >> ${PLOTFILE}

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
0 1 Event: ${MM}/${DD}/${YYYY} ${HH}:${MIN}  S,Sdiff paths beneath ${XDepth} km.
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

		# now plot the paths.
		gmt psxy ${EQ}_path ${REG} ${PROJ} -O -W2p,yellow >> ${PLOTFILE}


    fi

done # End of EQ loop.

cd ${OUTDIR}

exit 0
