#!/bin/bash

# =========================================
# This script makes DUDE-4.0 easier to use.
# (presumably. ... at least for me)
#
# Shule Yu
# Jan 12 2015
# =========================================

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
    echo "INFILE not found ..."
    exit 1
fi

#============================================
#            ! Parameters !
#============================================

# DIRs
WORKDIR=`grep "<WORKDIR>" ${CODEDIR}/INFILE | awk '{print $2}'`
mkdir -p ${WORKDIR}/LIST
mkdir -p ${WORKDIR}/INPUT
mkdir -p ${WORKDIR}/STDOUT
cp ${CODEDIR}/INFILE ${WORKDIR}/tmpfile_infile_$$
cp ${CODEDIR}/LIST.csh ${WORKDIR}/tmpfile_LIST_$$.csh
cp ${CODEDIR}/INFILE ${WORKDIR}/INPUT/INFILE_`date +%m%d_%H%M`
cp ${CODEDIR}/LIST.csh ${WORKDIR}/LIST/LIST_`date +%m%d_%H%M`
chmod -x ${WORKDIR}/LIST/*
cd ${WORKDIR}

# Deal with single parameters.
grep -n "<" ${WORKDIR}/tmpfile_infile_$$ \
| grep ">"                               \
| grep -v "BEGIN"                        \
| grep -v "END"                          \
| awk 'BEGIN {FS="<"} {print $2}'        \
| awk 'BEGIN {FS=">"} {print $1,$2}'     \
| awk '{print $1"=\""$2"\""}' > tmpfile_$$

source ${WORKDIR}/tmpfile_$$

# Deal with multiple parameters.
# They are between <XXX_BEGIN> and <XXX_END>
# The list is put into ${WORKDIR}/tmpfile_XXX_${RunNumber}
grep -n "<" ${WORKDIR}/tmpfile_infile_$$ \
| grep ">"                               \
| awk 'BEGIN {FS=":"} {print $2,$1}'     \
| awk 'BEGIN {FS="<"} {print $2}'        \
| awk 'BEGIN {FS=">"} {print $1,$2}'     \
| awk '{print $1,$2}'                    \
| grep "BEGIN"                           \
| sort -g -k 2,2 > tmpfile1_$$

grep -n "<" ${WORKDIR}/tmpfile_infile_$$ \
| grep ">"                               \
| awk 'BEGIN {FS=":"} {print $2,$1}'     \
| awk 'BEGIN {FS="<"} {print $2}'        \
| awk 'BEGIN {FS=">"} {print $1,$2}'     \
| awk '{print $1,$2}'                    \
| grep "END"                             \
| sort -g -k 2,2 > tmpfile2_$$

paste tmpfile1_$$ tmpfile2_$$ | awk '{print $1,$2,$4}' > tmpfile_parameters_$$

while read Name line1 line2
do
    Name=${Name%_*}
    awk -v N1=${line1} -v N2=${line2} '{ if ( $1!="" && N1<NR && NR<N2 ) print $0}' ${WORKDIR}/tmpfile_infile_$$ > ${WORKDIR}/tmpfile_${Name}_$$
done < tmpfile_parameters_$$

# EQs.
EQnames=`cat ${WORKDIR}/tmpfile_EQs_$$`

# Additional DIRs and files.
EXECDIR=${WORKDIR}/bin
DIRPLOT=${WORKDIR}/PLOTS
SACLIBs="${SACHOME}/lib/sacio.a ${SACHOME}/lib/libsac.a"
mkdir -p ${DIRPLOT}
mkdir -p ${EXECDIR}

#============================================
#            ! Test Dependencies !
#============================================
CommandList="sac psxy taup ps2pdf ${FCOMP} bc"
for Command in ${CommandList}
do
    command -v ${Command} >/dev/null 2>&1 || { echo >&2 "Command ${Command} is not found. Exiting ... "; exit 1; }
done

for LIB in ${SACLIBs}
do
    if ! [ -e ${LIB} ]
    then
        echo "SAC library path error. Exiting ..."
        exit 1
    fi
done
PATH=$PATH:./

#============================================
#            ! Compile !
#============================================
trap "rm -f ${EXECDIR}/*.o ${WORKDIR}/*_$$*; exit 1" SIGINT

INCLUDEDIR="-I${SACHOME}/include -I${CCODEDIR}"
LIBRARYDIR="-L. -L${CCODEDIR} -L${SACHOME}/lib"
LIBRARIES="-lt001 -lASU_tools -lsac -lsacio -lm"

# ASU_tools Functions.
cd ${CCODEDIR}
make
cd ${EXECDIR}

# Customized Functions.
for code in `ls ${SRCDIR}/*fun.c 2>/dev/null`
do
    name=`basename ${code}`
    name=${name%.fun.c}

    ${CCOMP} -c ${code}

    if [ $? -ne 0 ]
    then
        echo "${name} C function is not compiled ..."
        rm -f ${EXECDIR}/*.o ${WORKDIR}/*_$$*
        exit 1
    fi
done

for code in ${SRCDIR}/mrgrnk.f90
do
    name=`basename ${code}`
    name=${name%.f90}

    ${FCOMP} -c ${code}

    if [ $? -ne 0 ]
    then
        echo "${name} Fortran function is not compiled ..."
        rm -f ${EXECDIR}/*.o ${WORKDIR}/*_$$*
        exit 1
    fi
done

ar cr libt001.a *.o *.mod

# Executables.
for code in `ls ${SRCDIR}/*.c 2>/dev/null | grep -v fun.c`
do
    name=`basename ${code}`
    name=${name%.c}

    ${CCOMP} -o ${EXECDIR}/${name}.out ${code} ${INCLUDEDIR} ${LIBRARYDIR} ${LIBRARIES}

    if [ $? -ne 0 ]
    then
        echo "${name} C code is not compiled ..."
        rm -f ${EXECDIR}/*.o ${WORKDIR}/*_$$*
        exit 1
    fi
done

for code in `ls ${SRCDIR}/*.f ${SRCDIR}/*.f90 | grep -v mrgrnk.f90 2>/dev/null`
do
    name=`basename ${code}`
    name=${name%.*}

    ${FCOMP} -o ${EXECDIR}/${name}.out ${code} ${INCLUDEDIR} ${LIBRARYDIR} ${LIBRARIES}

    if [ $? -ne 0 ]
    then
        echo "${name} Fortran code is not compiled ..."
        rm -f ${EXECDIR}/*.o ${WORKDIR}/*_$$*
        exit 1
    fi
done

# Clean up.
rm -f ${EXECDIR}/*.o

# ==============================================
#           ! Work Begin !
# ==============================================

cd ${WORKDIR}
cat >> ${WORKDIR}/stdout << EOF

======================================
Run Date: `date`
EOF

# ==============================================
#           ! Work Begin !
# ==============================================

for EQ in ${EQnames}
do
    mkdir -p ${WORKDIR}/${EQ}

    echo "" >> ${WORKDIR}/stdout
    echo "==> Working on ${EQ} ..." >> ${WORKDIR}/stdout

    # Set up Ctrl + C actions.
	trap "rm -rf ${WORKDIR}/${EQ} ${WORKDIR}/*_$$*; exit 1" SIGINT

    # Find data.
    if ! [ -d ${DATADIR}/${EQ} ]
    then
        echo "    !=> Can't find DATA for ${EQ} ... " >> ${WORKDIR}/stdout
        continue
    fi

    # Grep CMT info.
    CMT=`grep ${EQ} ${CMTINFO} | head -n 1`
    if [ $? -ne 0 ]
    then
        CMT="0 90 0"
    else
        CMT=`echo ${CMT} | awk '{print $3,$4,$5}'`
    fi
    echo "    ==> CMT (strike, dip, rake): ${CMT}." >> ${WORKDIR}/stdout

    # Copy data.
	${SRCDIR}/a01.CopyData.sh
    echo "    ==> Data copied." >> ${WORKDIR}/stdout

    # Create the MASTER file for DUDE.
    ${SRCDIR}/a02.genMaster.sh >> ${WORKDIR}/stdout

    # Run DUDE.
    echo "    ==> Running DUDE..." >> ${WORKDIR}/stdout
    echo "" > .taup
    INPUT=" ${EQ} ${SRCDIR} ${WORKDIR} ${DIRPLOT} "
    nice -10 csh ${WORKDIR}/tmpfile_LIST_$$.csh > ${WORKDIR}/STDOUT/${EQ} 2>&1

    # Make PDF.
    cat `ls -rt ${DIRPLOT}/${EQ}.c*.ps` > ${DIRPLOT}/EQ_${EQ}.ps
    ps2pdf ${DIRPLOT}/EQ_${EQ}.ps ${DIRPLOT}/EQ_${EQ}.pdf
    echo "    ==> Just finished making the really big OUTPUT FILE : ${DIRPLOT}/EQ_${EQ}.pdf" >> ${WORKDIR}/stdout

    # Clean up.
    if [ ${CleanUp} -eq 1 ]
    then
        find ${WORKDIR}/${EQ} -iname "*sac" -exec rm '{}' \;
    fi

    echo "    ==> Done..." >> ${WORKDIR}/stdout
	rm -f tmpfile*

done # End of EQ loop.

cat >> ${WORKDIR}/stdout << EOF

End Date: `date`
======================================
EOF

# Clean up.
rm -f ${WORKDIR}/*_$$*

exit 0
