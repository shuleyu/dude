#!/bin/bash

# ====================================================================
# This script make ScS bouncing points (using TauP), then plot the
# bouncing points on a map.
#
# Ed Garnero/Pei-Ying(Patty) Lin/Shule Yu
# ====================================================================

echo ""
echo "--> `basename $0` is running. `date`"
mkdir -p ${a22DIR}
cd ${a22DIR}

# ==================================================
#              ! Work Begin !
# ==================================================

# Set TauP precision.
echo "taup.distance.precision=3" > .taup
echo "taup.time.precision=3" >> .taup


for EQ in `cat ${OUTDIR}/tmpfile_EQs_${RunNumber}`
do

	# Ctrl+C action.
	trap "rm -f ${a22DIR}/${EQ}* ${OUTDIR}/*_${RunNumber}; exit 1" SIGINT


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

	# C. Check phase file.

    if ! [ -s "`ls ${a05DIR}/${EQ}_*_ScS.gmt_Enveloped` 2>/dev/null" ]
    then
        echo "        ~=> Plot ${Num}: can't find Firsta Arrival file !"
        continue
    else
        PhaseFile=`ls ${a05DIR}/${EQ}_*_ScS.gmt_Enveloped`
        PhaseDistMin=`minmax -C ${PhaseFile} | awk '{print $1}'`
        PhaseDistMax=`minmax -C ${PhaseFile} | awk '{print $2}'`
    fi


    PLOTFILE=${PLOTDIR}/${EQ}.`basename ${0%.sh}`.ps

    # Clean dir.
    rm -f ${a22DIR}/${EQ}*

    # Ctrl+C action.
    trap "rm -f ${a22DIR}/${EQ}* ${PLOTFILE} ${OUTDIR}/*_${RunNumber}; exit 1" SIGINT


    # D. Select gcp distance window.
    keys="<NETWK> <STNM> <Gcarc> <STLO> <STLA>"
    ${BASHCODEDIR}/Findfield.sh ${a01DIR}/${EQ}_FileList_Info "${keys}" | sort | uniq \
    | awk -v D1=${PhaseDistMin} -v D2=${PhaseDistMax} '{if (D1<=$3 && $3<=D2) print $1,$2,$4,$5}' > ${EQ}_net_stn_stlo_stla


    # E. Call TauP to get bouncing point lon/lat.
    echo "<NETWK> <STNM> <STLO> <STLA> <ScS_HitLO> <ScS_HitLA>" > ${EQ}_ScSHit.List
    while read netwk stnm STLO STLA
    do
        taup_path -ph ScS -h ${EVDP} -sta ${STLA} ${STLO} -evt ${EVLA} ${EVLO} -mod ${Model_TT} -o stdout | awk -v stlo=${STLO} -v stla=${STLA} -v net=${netwk} -v stn=${stnm} '{if ($2==3480 && $3!="") print net,stn,stlo,stla,$4,$3}' >> ${EQ}_ScSHit.List
    done < ${EQ}_net_stn_stlo_stla

    NSTA=`wc -l ${EQ}_ScSHit.List`
    NSTA=$((NSTA-1))

    echo "Done."
    sleep 10000

    # F. plot. (GMT-4)
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
		REG="-R0/360/-90/90"
		PROJ="-JR${EVLO}/7.0i"
        CPT="-C${SRCDIR}/ritsema.cpt"

        # plot title and tag.
        pstext -JX11i/1i -R-100/100/-1/1 -N -X0i -Y7i -K > ${PLOTFILE} << EOF
0 1 20 0 0 CB Event: ${MM}/${DD}/${YYYY} ${HH}:${MIN}
0 0.5 15  0 0 CB ${EQ} LAT=${EVLA} LON=${EVLO} Z=${EVDP} Mb=${MAG} NSTA=${NSTA}/${NSTA_All}
EOF
        pstext -J -R -N -Wored -G0 -Y-0.3i -O -K >> ${PLOTFILE} << EOF
0 0.5 10 0 0 CB SCRIPT: `basename ${0}` `date "+CREATION DATE: %m/%d/%y  %H:%M:%S"`
EOF
        # plot S20RTS @ 2891 km.
        xyz2grd ${SRCDIR}/ritsema.2880 -G2880.grd -I2 ${REG} -:
        grdimage 2880.grd ${CPT} ${REG} ${PROJ} -E40 -K -O -X-1i -Y-4.5i >> ${PLOTFILE}

        # add a color scale to the right for the tomography map
        psscale ${CPT} -D3.5i/-0.2i/3.0i/0.13ih -B2/:"@~\144@~Vs (%)": -O -K -N300 >> ${PLOTFILE}

		# plot the coast lines
		pscoast ${REG} ${PROJ} -Ba0g45/a0g45wsne -Dl -A40000 -W2 -O -K >> ${PLOTFILE}

        # then plot the great circle path file
        psxy xy.gcpaths $REG $PROJ -: $MGMT -K -O -W1.0/250/0/200t5_15:0 >> $OUTFILE

# now plot the EQ and stations
psxy xy.eq       $REG $PROJ -: -Sa0.12i -K -O -W1/0/0/0 -G0 >> $OUTFILE
psxy xy.stations $REG $PROJ -: -St0.03i -K -O -W1/0/0/0 -G0 >> $OUTFILE

# now plot the ScS bounce points:
psxy xy.scs_bounce $REG $PROJ -: -Sx+0.15i -K -O -W3/yellow  >> $OUTFILE


    fi

    # F*. plot. (GMT-5)
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

done # End of EQ loop.

cd ${OUTDIR}

exit 0
