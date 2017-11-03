#!/bin/bash

export AzMin=0
export AzMax=360

# cat > x << EOF
# <PhaseESW_BEGIN>
# S    T    0    40    100    ${AzMin}    ${AzMax}    0.01    0.2    AllSt
# <PhaseESW_END>
# 
# <AP_BEGIN>
# S    T    0    40    100    ${AzMin}    ${AzMax}    0.01    0.2    AllSt    -100    100    SH    Portrait
# <AP_END>
# 
# <APC_BEGIN>
# 0.5    S    T    0    40    100    ${AzMin}    ${AzMax}    0.01    0.2    AllSt    -100    100    SH    Portrait
# <APC_END>
# 
# <APDS_BEGIN>
# 1    1    S    T    0    40    100    ${AzMin}    ${AzMax}    0.01    0.2    AllSt     Own    1    -100    100    SH    Portrait
# <APDS_END>
# EOF
# awk 'NR>15 {print $0}' INFILE >> x
# mv x INFILE
# 
# ./Run.sh

# for file in `ls /NAS/shule/PROJ/t001.DoubleBump/PLOTS/20??????????.pdf`
# do
# 	Name=`basename ${file}`
# 	mv ${file} ${file%/*}/${AzMin}_${AzMax}_${Name}
# done

for AzMin in `seq 0 10 10`
do
	AzMax=$((AzMin+10))

	cat > x << EOF
<PhaseESW_BEGIN>
S    T    0    40    100    ${AzMin}    ${AzMax}    0.01    0.2    AllSt
<PhaseESW_END>

<AP_BEGIN>
S    T    0    40    100    ${AzMin}    ${AzMax}    0.01    0.2    AllSt    -100    100    SH    Portrait
<AP_END>

<APC_BEGIN>
0.5    S    T    0    40    100    ${AzMin}    ${AzMax}    0.01    0.2    AllSt    -100    100    SH    Portrait
<APC_END>

<APDS_BEGIN>
1    1    S    T    0    40    100    ${AzMin}    ${AzMax}    0.01    0.2    AllSt     Own    1    -100    100    SH    Portrait
<APDS_END>
EOF
	awk 'NR>15 {print $0}' INFILE >> x
	mv x INFILE

	./Run.sh

	for file in `ls /NAS/shule/PROJ/t001.DoubleBump/PLOTS/20??????????.pdf`
	do
		Name=`basename ${file}`
		mv ${file} ${file%/*}/${AzMin}_${AzMax}_${Name}
	done

done

exit 0
