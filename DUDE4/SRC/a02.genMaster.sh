#!/bin/bash

# ==================================================
# This script generate eventStation.${EQ} file from
# sac files. ( for all ${DATA}/${EQ}/*Z.sac files )
#
# Shule Yu
# Oct 18 2015
# ==================================================

echo "    ==> Making eventStation file for ${EQ}."

rm -f ${WORKDIR}/${EQ}/eventStation.${EQ}

echo "1.STNM   2.NETWK   3. GCARC   4.\"DEGREE\"   5.AZ   6.\"deg\"   7.BAZ   8.\"deg\"   9.STLA   10.STLO   11.EVLA   12.EVLO   13.Depth   14.\"km\"   15.\"Mw\"   16.Mag.   17.\"Multiple\"   18.\"Centers\"   19.EQname        ( sorted according to ${SORT} )" > ${WORKDIR}/${EQ}/eventStation.${EQ}

saclst KSTNM KNETWK GCARC AZ BAZ STLA STLO EVLA EVLO EVDP MAG f `ls ${WORKDIR}/${EQ}/*Z.sac` \
    |awk -v E=${EQ} '{print $2,$3,$4" DEGREE "$5" deg "$6" deg "$7,$8,$9,$10,$11/1000" km Mw "$12" Multiple Centers "E}' | sort -u $1 | sort -g -k ${SORT} >> ${WORKDIR}/${EQ}/eventStation.${EQ}

exit 0
