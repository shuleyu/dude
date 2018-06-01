#!/bin/bash

#=========================================================
# This script Run DUDE.
#
# Shule Yu
#=========================================================

# Export variables to all sub scripts.
set -a
CODEDIR=${PWD}
SRCDIR=${CODEDIR}/SRC
RunNumber=$$

#============================================
#            ! Test Files !
#============================================
if ! [ -e ${CODEDIR}/INFILE ]
then
    echo "INFILE not found ! Exiting..."
    exit 1
fi

#==================================================
#          ! Get parameters from INFILE !
#==================================================

# Set up OUTDIR.
OUTDIR=`grep "<OUTDIR>" ${CODEDIR}/INFILE | awk '{print $2}'`
DateTag=`date +%m%d_%H%M`
mkdir -p ${OUTDIR}/LIST
mkdir -p ${OUTDIR}/INPUT
cp ${CODEDIR}/INFILE ${OUTDIR}/tmpfile_INFILE_$$
cp ${CODEDIR}/LIST.sh ${OUTDIR}/tmpfile_LIST_$$
cp ${CODEDIR}/INFILE ${OUTDIR}/INPUT/INFILE_${DateTag}
cp ${CODEDIR}/LIST.sh ${OUTDIR}/LIST/LIST_${DateTag}
chmod -x ${OUTDIR}/LIST/LIST_${DateTag}
cd ${OUTDIR}

# Set up Ctrl + C action.
trap "rm -f ${OUTDIR}/*_$$; exit 1" SIGINT

# Read in single line parameters.
# Commands below read these parameters as variables. Can be used by "$" sign.
grep -n "<" ${OUTDIR}/tmpfile_INFILE_$$      \
| grep ">" | grep -v "BEGIN" | grep -v "END" \
| awk 'BEGIN {FS="<"} {print $2}'            \
| awk 'BEGIN {FS=">"} {print $1,$2}' > tmpfile_$$
awk '{print $1}' tmpfile_$$ > tmpfile1_$$
awk '{$1="";print "\""$0"\""}' tmpfile_$$ > tmpfile2_$$
sed 's/\"[[:blank:]]/\"/' tmpfile2_$$ > tmpfile3_$$
paste -d= tmpfile1_$$ tmpfile3_$$ > tmpfile_$$
source ${OUTDIR}/tmpfile_$$

# Read in multiple line parameters.
# These parameters are between name tag <XXX_BEGIN> and <XXX_END> in INFILE.
# Commands followed put these parameters in file ${OUTDIR}/tmpfile_XXX_$$ for
# future use.
grep -n "<" ${OUTDIR}/tmpfile_INFILE_$$  \
| grep ">" | grep "_BEGIN"               \
| awk 'BEGIN {FS=":<"} {print $2,$1}'    \
| awk 'BEGIN {FS="[> ]"} {print $1,$NF}' \
| sed 's/_BEGIN//g'                      \
| sort -g -k 2,2 > tmpfile1_$$

grep -n "<" ${OUTDIR}/tmpfile_INFILE_$$  \
| grep ">" | grep "_END"                 \
| awk 'BEGIN {FS=":<"} {print $2,$1}'    \
| awk 'BEGIN {FS="[> ]"} {print $1,$NF}' \
| sed 's/_END//g'                        \
| sort -g -k 2,2 > tmpfile2_$$

paste tmpfile1_$$ tmpfile2_$$ | awk '{print $1,$2,$4}' > tmpfile_parameters_$$

while read Name line1 line2
do
    Name=${Name%_*}
    awk -v N1=${line1} -v N2=${line2} '{ if ( $1!="" && N1<NR && NR<N2 ) print $0}' ${OUTDIR}/tmpfile_INFILE_$$ \
	| sed 's/^[[:blank:]]*//g' > ${OUTDIR}/tmpfile_${Name}_$$
done < tmpfile_parameters_$$

#=======================================
#       ! Additional DIRs !
#=======================================
EXECDIR=${OUTDIR}/bin
PLOTDIR=${OUTDIR}/PLOTS
a01DIR=${OUTDIR}/a01.ListPrep
a02DIR=${OUTDIR}/a02.MasterMap
a03DIR=${OUTDIR}/a03.CityMap
a04DIR=${OUTDIR}/a04.Histogram
a05DIR=${OUTDIR}/a05.MakeTravelTimeData
a06DIR=${OUTDIR}/a06.BigProfile
a07DIR=${OUTDIR}/a07.BigProfileComb
a08DIR=${OUTDIR}/a08.BigProfileIncSum
a09DIR=${OUTDIR}/a09.ZoomProfile
a10DIR=${OUTDIR}/a10.ZoomProfileComb
a11DIR=${OUTDIR}/a11.ZoomProfileIncSum
a12DIR=${OUTDIR}/a12.MakeRadPatData
a13DIR=${OUTDIR}/a13.PlotRadPat
a14DIR=${OUTDIR}/a14.MakeSNRData
a15DIR=${OUTDIR}/a15.EmpiricalSourceWavelets
a16DIR=${OUTDIR}/a16.AlignedProfile
a17DIR=${OUTDIR}/a17.AlignedProfileComb
a18DIR=${OUTDIR}/a18.AlignedProfileIncSum
a19DIR=${OUTDIR}/a19.MapTA
a20DIR=${OUTDIR}/a20.MapAK
a21DIR=${OUTDIR}/a21.MapScSBounce
a22DIR=${OUTDIR}/a22.MapSSReflect
a23DIR=${OUTDIR}/a23.MapSdiffPath
a24DIR=${OUTDIR}/a24.MapSKSInOutCMB
a25DIR=${OUTDIR}/a25.MapPKIKPInOutCMB
a26DIR=${OUTDIR}/a26.MapSBeneathXkm
mkdir -p ${EXECDIR}
mkdir -p ${PLOTDIR}

if [ ${NewPlots} -eq 1 ]
then
	for EQ in `cat ${OUTDIR}/tmpfile_EQs_${RunNumber}`
	do
		rm -f ${PLOTDIR}/${EQ}*
	done
fi

#======================================================
#            ! Test Software Dependencies !
#======================================================

CommandList="${CPPCOMP} sac saclst taup_time tac"

case "${GMTVERSION}" in
	4 )
		CommandList="${CommandList} psxy"
		;;
	5 )
		CommandList="${CommandList} gmt"
		;;
	* )
		echo "Wrong GMT version ! Exiting ..."
		rm -f  ${OUTDIR}/*_$$
		exit 1
	;;
esac

for Command in ${CommandList}
do
    command -v ${Command} >/dev/null 2>&1
	if [ $? -ne 0 ]
	then
		echo "Command ${Command} is not found! Exiting ..."
		rm -f  ${OUTDIR}/*_$$
		exit 1
	fi
done


#==================================================
#            ! Compile C,C++,Fortran codes !
#==================================================

# Set up Ctrl + C action.
trap "rm -f ${EXECDIR}/*.o ${OUTDIR}/*_$$; exit 1" SIGINT

# Set Header/Library dirs, Libray names.
INCLUDEDIR="-I${CPPCODEDIR} -I${CCODEDIR} -I${SACDIR}/include"
LIBRARYDIR="-L${CCODEDIR} -L${SACDIR}/lib -L."
LIBRARIES="-lASU_tools -lsac -lsacio -lm"

# Compile ASU_tools Library.
cd ${CCODEDIR}
make

cd ${SRCDIR}
make OUTDIR=${EXECDIR} CDIR=${CCODEDIR} CPPDIR=${CPPCODEDIR} SACDIR=${SACDIR}

echo "Compile finished...running..."

# ==============================================
#           ! Work Begin !
# ==============================================

cat >> ${OUTDIR}/stdout << EOF

======================================
Run Date: `date`
EOF

bash ${OUTDIR}/tmpfile_LIST_$$ >> ${OUTDIR}/stdout 2>&1

cat >> ${OUTDIR}/stdout << EOF

End Date: `date`
======================================
EOF

# Clean up.
for EQ in `cat ${OUTDIR}/tmpfile_EQs_${RunNumber}`
do
	find ${OUTDIR}/ -iname "${EQ}*PlotFile*" -exec rm -f '{}' \;

	if [ ${CleanSAC} -eq 1 ]
	then
		find ${OUTDIR}/ -iname "${EQ}*sac" -exec rm -f '{}' \;
	fi
done

echo "Finished."

rm -f ${OUTDIR}/*_$$

exit 0
