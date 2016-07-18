#!/bin/bash

#=========================================================
# This script
#
# Shule Yu
# Jun 23 2014
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
    echo "INFILE not found ..."
    exit 1
fi

#============================================
#            ! Parameters !
#============================================

# DIRs.
WORKDIR=`grep "<WORKDIR>" ${CODEDIR}/INFILE | awk '{print $2}'`
mkdir -p ${WORKDIR}/LIST
mkdir -p ${WORKDIR}/INPUT
cp ${CODEDIR}/INFILE ${WORKDIR}/tmpfile_INFILE_$$
cp ${CODEDIR}/INFILE ${WORKDIR}/INPUT/INFILE_`date +%m%d_%H%M`
cp ${CODEDIR}/LIST.sh ${WORKDIR}/tmpfile_LIST_$$
cp ${CODEDIR}/LIST.sh ${WORKDIR}/LIST/LIST_`date +%m%d_%H%M`
chmod -x ${WORKDIR}/LIST/*
cd ${WORKDIR}

# Deal with single parameters.
grep -n "<" ${WORKDIR}/tmpfile_INFILE_$$     \
| grep ">" | grep -v "BEGIN" | grep -v "END" \
| awk 'BEGIN {FS="<"} {print $2}'            \
| awk 'BEGIN {FS=">"} {print $1,$2}' > tmpfile_$$
awk '{print $1}' tmpfile_$$ > tmpfile1_$$
awk '{$1="";print "\""$0"\""}' tmpfile_$$ > tmpfile2_$$
sed 's/\"[[:blank:]]/\"/' tmpfile2_$$ > tmpfile3_$$
paste -d= tmpfile1_$$ tmpfile3_$$ > tmpfile_$$
source ${WORKDIR}/tmpfile_$$

# Deal with multiple parameters.
# They are between <XXX_BEGIN> and <XXX_END>
# The list is put into ${WORKDIR}/tmpfile_XXX_${RunNumber}
grep -n "<" ${WORKDIR}/tmpfile_INFILE_$$ \
| grep ">" | grep "_BEGIN"               \
| awk 'BEGIN {FS=":<"} {print $2,$1}'    \
| awk 'BEGIN {FS="[> ]"} {print $1,$NF}' \
| sed 's/_BEGIN//g'                      \
| sort -g -k 2,2 > tmpfile1_$$

grep -n "<" ${WORKDIR}/tmpfile_INFILE_$$ \
| grep ">" | grep "_END"                 \
| awk 'BEGIN {FS=":<"} {print $2,$1}'    \
| awk 'BEGIN {FS="[> ]"} {print $1,$NF}' \
| sed 's/_END//g'                        \
| sort -g -k 2,2 > tmpfile2_$$

paste tmpfile1_$$ tmpfile2_$$ | awk '{print $1,$2,$4}' > tmpfile_parameters_$$

while read Name line1 line2
do
    Name=${Name%_*}
    awk -v N1=${line1} -v N2=${line2} '{ if ( $1!="" && N1<NR && NR<N2 ) print $0}' ${WORKDIR}/tmpfile_INFILE_$$ \
	| sed 's/^[[:blank:]]*//g' > ${WORKDIR}/tmpfile_${Name}_$$
done < tmpfile_parameters_$$

# Additional DIRs.
EXECDIR=${WORKDIR}/bin
PLOTDIR=${WORKDIR}/PLOTS
FileListDIR=${WORKDIR}/FileList
mkdir -p ${EXECDIR}
mkdir -p ${PLOTDIR}
mkdir -p ${FileListDIR}

#============================================
#            ! Test Dependencies !
#============================================
CommandList="sac saclst gmt"
for Command in ${CommandList}
do
    command -v ${Command} >/dev/null 2>&1 || { echo >&2 "Command ${Command} is not found. Exiting ... "; exit 1; }
done

#============================================
#            ! Compile !
#============================================
trap "rm -f ${EXECDIR}/*.o ${WORKDIR}/*_$$; exit 1" SIGINT

INCLUDEDIR="-I${CPPCODEDIR} -I${CCODEDIR} -I${SACDIR}/include -I${GMTHDIR}"
LIBRARYDIR="-L${CPPCODEDIR} -L${CCODEDIR} -L${SACDIR}/lib -L${GMTLIBDIR} -L."
LIBRARIES="-lASU_tools -lgmt -lsac -lsacio -lm"
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${GMTLIBDIR}

# ASU_tools Functions.
cd ${CCODEDIR}
make
cd ${EXECDIR}

# Customized Functions.
for code in `ls ${SRCDIR}/*fun.c 2>/dev/null`
do
    name=`basename ${code}`
    name=${name%.fun.c}

    ${CCOMP} -Wall -c ${code} ${INCLUDEDIR}

    if [ $? -ne 0 ]
    then
        echo "${name} C function is not compiled ..."
        rm -f ${EXECDIR}/*.o ${WORKDIR}/*_$$
        exit 1
    fi
done

# Executables (c).
for code in `ls ${SRCDIR}/*.c 2>/dev/null | grep -v fun.c`
do
    name=`basename ${code}`
    name=${name%.c}

    ${CCOMP} -Wall -o ${EXECDIR}/${name}.out ${code} ${INCLUDEDIR} ${LIBRARYDIR} ${LIBRARIES}

    if [ $? -ne 0 ]
    then
        echo "${name} C code is not compiled ..."
        rm -f ${EXECDIR}/*.o ${WORKDIR}/*_$$
        exit 1
    fi
done

# Executables (c++).
for code in `ls ${SRCDIR}/*.cpp 2>/dev/null | grep -v fun.cpp`
do
    name=`basename ${code}`
    name=${name%.cpp}

    ${CPPCOMP} ${CPPFLAG} -o ${EXECDIR}/${name}.out ${code} ${INCLUDEDIR} ${LIBRARYDIR} ${LIBRARIES}

    if [ $? -ne 0 ]
    then
        echo "${name} C++ code is not compiled ..."
        rm -f ${EXECDIR}/*.o ${WORKDIR}/*_$$
        exit 1
    fi
done

# Executables (fortran).
for code in `ls ${SRCDIR}/*.f 2>/dev/null`
do
    name=`basename ${code}`
    name=${name%.f}

    ${FCOMP} -o ${EXECDIR}/${name}.out ${code} ${INCLUDEDIR} ${LIBRARYDIR} ${LIBRARIES}

    if [ $? -ne 0 ]
    then
        echo "${name} Fortran code is not compiled ..."
        rm -f ${EXECDIR}/*.o ${WORKDIR}/*_$$
        exit 1
    fi
done

# Clean up.
rm -f ${EXECDIR}/*fun.o

# ==============================================
#           ! Work Begin !
# ==============================================

cd ${WORKDIR}
cat >> ${WORKDIR}/stdout << EOF

======================================
Run Date: `date`
EOF

bash ${WORKDIR}/tmpfile_LIST_$$ >> ${WORKDIR}/stdout 2>&1

cat >> ${WORKDIR}/stdout << EOF

End Date: `date`
======================================
EOF

# Clean up.
rm -f ${WORKDIR}/*_$$

exit 0
