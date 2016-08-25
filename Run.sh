#!/bin/bash

#=========================================================
# This script Run the project.
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
a08DIR=${OUTDIR}/a08.BigProfileDistinctSum
a09DIR=${OUTDIR}/a09.ZoomProfile
a10DIR=${OUTDIR}/a10.ZoomProfileComb
a11DIR=${OUTDIR}/a11.ZoomProfileDistinctSum
mkdir -p ${EXECDIR}
mkdir -p ${PLOTDIR}

#======================================================
#            ! Test Software Dependencies !
#======================================================

CommandList="${FCOMP} ${CCOMP} ${CPPCOMP} sac saclst taup_time"

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

#===================================================================
#            ! Compile ASU_tools, ASU_tools_cpp library !
#===================================================================

# Set up Ctrl + C action.
trap "cd ${CCODEDIR}; make clean; cd ${CPPCODEDIR}; make clean; rm -f ${OUTDIR}/*_$$; exit 1" SIGINT

# Compile ASU_tools Library.
cd ${CCODEDIR}
make
cd ${CPPCODEDIR}
make

#==================================================
#            ! Compile C,C++,Fortran codes !
#==================================================

# Set up Ctrl + C action.
trap "rm -f ${EXECDIR}/*.o ${OUTDIR}/*_$$; exit 1" SIGINT

# Set Header/Library dirs, Libray names.
INCLUDEDIR="-I${CPPCODEDIR} -I${CCODEDIR} -I${SACDIR}/include"
LIBRARYDIR="-L${CPPCODEDIR} -L${CCODEDIR} -L${SACDIR}/lib -L."
LIBRARIES="-lASU_tools -lsac -lsacio -lm"

cd ${EXECDIR}

# Customized Functions (C).
for code in `ls ${SRCDIR}/*fun.c 2>/dev/null`
do
    name=`basename ${code}`
    name=${name%.fun.c}

    ${CCOMP} ${CFLAG} -c ${code} ${INCLUDEDIR}

    if [ $? -ne 0 ]
    then
        echo "${name} C function is not compiled ..."
        rm -f ${EXECDIR}/*.o ${OUTDIR}/*_$$
        exit 1
    fi
done

# Customized Functions (C++).
for code in `ls ${SRCDIR}/*fun.cpp 2>/dev/null`
do
    name=`basename ${code}`
    name=${name%.fun.cpp}

    ${CPPCOMP} ${CPPFLAG} -c ${code} ${INCLUDEDIR}

    if [ $? -ne 0 ]
    then
        echo "${name} C++ function is not compiled ..."
        rm -f ${EXECDIR}/*.o ${OUTDIR}/*_$$
        exit 1
    fi
done

# Executables (C).
for code in `ls ${SRCDIR}/*.c 2>/dev/null | grep -v fun.c`
do
    name=`basename ${code}`
    name=${name%.c}

    ${CCOMP} ${CFLAG} -o ${EXECDIR}/${name}.out ${code} ${INCLUDEDIR} ${LIBRARYDIR} ${LIBRARIES}

    if [ $? -ne 0 ]
    then
        echo "${name} C code is not compiled ..."
        rm -f ${EXECDIR}/*.o ${OUTDIR}/*_$$
        exit 1
    fi
done

# Executables (C++).
for code in `ls ${SRCDIR}/*.cpp 2>/dev/null | grep -v fun.cpp`
do
    name=`basename ${code}`
    name=${name%.cpp}

    ${CPPCOMP} ${CPPFLAG} -o ${EXECDIR}/${name}.out ${code} ${INCLUDEDIR} ${LIBRARYDIR} ${LIBRARIES}

    if [ $? -ne 0 ]
    then
        echo "${name} C++ code is not compiled ..."
        rm -f ${EXECDIR}/*.o ${OUTDIR}/*_$$
        exit 1
    fi
done

# Executables (fortran).
for code in `ls ${SRCDIR}/*.f90 2>/dev/null`
do
    name=`basename ${code}`
    name=${name%.f}

    ${FCOMP} -o ${EXECDIR}/${name}.out ${code} ${INCLUDEDIR} ${LIBRARYDIR} ${LIBRARIES}

    if [ $? -ne 0 ]
    then
        echo "${name} Fortran code is not compiled ..."
        rm -f ${EXECDIR}/*.o ${OUTDIR}/*_$$
        exit 1
    fi
done

# Clean up.
rm -f ${EXECDIR}/*fun.o

# ==============================================
#           ! Work Begin !
# ==============================================

cd ${OUTDIR}
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
rm -f ${OUTDIR}/*_$$

exit 0
