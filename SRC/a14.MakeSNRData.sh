#!/bin/bash

# ====================================================================
# This script make SNR measurement.
#
# Ed Garnero/Pei-Ying(Patty) Lin/Shule Yu
# ====================================================================

echo ""
echo "--> `basename $0` is running. `date`"
mkdir -p ${a14DIR}
cd ${a14DIR}

# ==================================================
#              ! Work Begin !
# ==================================================


for EQ in `cat ${OUTDIR}/tmpfile_EQs_${RunNumber}`
do

	# Ctrl+C action.
	trap "rm -f ${a14DIR}/${EQ}* ${a14DIR}/tmpfile*$$ ${OUTDIR}/*_${RunNumber}; exit 1" SIGINT

	# Clean dir.
	rm -f ${a14DIR}/${EQ}*

	# A. Check the exist of list file.
	if ! [ -s "${a01DIR}/${EQ}_FileList" ]
	then
		echo "    ~=> ${EQ} doesn't have FileList ..."
		continue
	else
		echo "    ==> Making SNR measurements of ${EQ}..."
	fi


	# B. Tweak traveltime file.

	PhaseFile_P=`ls ${a05DIR}/${EQ}_*_P.gmt_Enveloped 2>/dev/null`
	PhaseFile_Pdiff=`ls ${a05DIR}/${EQ}_*_Pdiff.gmt_Enveloped 2>/dev/null`
	PhaseFile_S=`ls ${a05DIR}/${EQ}_*_S.gmt_Enveloped 2>/dev/null`
	PhaseFile_Sdiff=`ls ${a05DIR}/${EQ}_*_Sdiff.gmt_Enveloped 2>/dev/null`

	if ! [ -s "${PhaseFile_P}" ] || ! [ -s "${PhaseFile_Pdiff}" ] || ! [ -s "${PhaseFile_S}" ] || ! [ -s "${PhaseFile_Sdiff}" ]
	then
		echo "        ~=> ${EQ} can't find P/Pdiff/S/Sdiff first arrival file!"
		continue
	fi

	# a. for Pdiff, we need extend it to 180 degree.

	DISTMAX=`${MINMAX} -C ${PhaseFile_Pdiff} | awk '{print $2+0.01}'`

	rm -f tmpfile_$$
	for gcarc in `seq ${DISTMAX} 0.1 180`
	do
		echo "${gcarc}" >> tmpfile_$$
	done

	${EXECDIR}/LinearFit.out 0 3 0 << EOF
${PhaseFile_Pdiff}
tmpfile_$$
tmpfile_MoreDiff_$$
EOF
	cat ${PhaseFile_P} ${PhaseFile_Pdiff} tmpfile_MoreDiff_$$ > ${EQ}_P_TC.txt
	rm -f tmpfile_$$ tmpfile_MoreDiff_$$

	# b. for Sdiff, we need extend it to 180 degree.

	DISTMAX=`${MINMAX} -C ${PhaseFile_Sdiff} | awk '{print $2+0.01}'`

	rm -f tmpfile_$$
	for gcarc in `seq ${DISTMAX} 0.1 180`
	do
		echo "${gcarc}" >> tmpfile_$$
	done

	${EXECDIR}/LinearFit.out 0 3 0 << EOF
${PhaseFile_Sdiff}
tmpfile_$$
tmpfile_MoreDiff_$$
EOF
	cat ${PhaseFile_S} ${PhaseFile_Sdiff} tmpfile_MoreDiff_$$ > ${EQ}_S_TC.txt
	rm -f tmpfile_$$ tmpfile_MoreDiff_$$


	# C. Select stations which have the P arrival.

	PhaseDistMin=`${MINMAX} -C ${EQ}_P_TC.txt | awk '{print $1}'`
	PhaseDistMax=`${MINMAX} -C ${EQ}_P_TC.txt | awk '{print $2}'`

	keys="<FileName> <NETWK> <STNM> <Gcarc> <BeginTime> <EndTime>"
	${BASHCODEDIR}/Findfield.sh ${a01DIR}/${EQ}_FileList_Info "${keys}" \
	| awk -v D1=${PhaseDistMin} -v D2=${PhaseDistMax} '{if (D1<=$4 && $4<=D2) print $0}' \
	| sort -g -k 4,4 > ${EQ}_SelectedFiles


	# D. Get P arrivals of these stations.
	awk '{print $4}' ${EQ}_SelectedFiles > tmpfile_gcarc_$$

	${EXECDIR}/Interpolate.out 0 3 0 << EOF
${EQ}_P_TC.txt
tmpfile_gcarc_$$
tmpfile_$$
EOF

	paste ${EQ}_SelectedFiles tmpfile_$$ > ${EQ}_SelectedFiles_PArrival
	rm -f tmpfile_$$ tmpfile_gcarc_$$


	# E. Select stations which have the S arrival.

	PhaseDistMin=`${MINMAX} -C ${EQ}_S_TC.txt | awk '{print $1}'`
	PhaseDistMax=`${MINMAX} -C ${EQ}_S_TC.txt | awk '{print $2}'`

	awk -v D1=${PhaseDistMin} -v D2=${PhaseDistMax} '{if (D1<=$4 && $4<=D2) print $0}' ${EQ}_SelectedFiles_PArrival > ${EQ}_SelectedFiles_PArrival_SArrival

	# F. Get S arrivals of these stations.

	awk '{print $4}' ${EQ}_SelectedFiles_PArrival_SArrival > tmpfile_gcarc_$$

	${EXECDIR}/Interpolate.out 0 3 0 << EOF
${EQ}_S_TC.txt
tmpfile_gcarc_$$
tmpfile_$$
EOF

	paste ${EQ}_SelectedFiles_PArrival_SArrival tmpfile_$$ > tmpfile1_$$
	mv tmpfile1_$$ ${EQ}_SelectedFiles_PArrival_SArrival
	rm -f tmpfile_$$ tmpfile_gcarc_$$


	# G. For S and P selected files,
	# select BeginTime < Tp - 3min && EndTime > Tp + 30sec for P,
	# select BeginTime < Tp - 3min && EndTime > Ts + 30sec for S,

	awk '{if ($5<$7-180 && $6>$7+30) print $0}' ${EQ}_SelectedFiles_PArrival > tmpfile_$$
	mv tmpfile_$$ ${EQ}_SelectedFiles_PArrival

	awk '{if ($5<$7-180 && $6>$8+30) print $0}' ${EQ}_SelectedFiles_PArrival_SArrival > tmpfile_$$
	mv tmpfile_$$ ${EQ}_SelectedFiles_PArrival_SArrival


	# H. Enter SNR measurement loop.
	for COMP in R T Z
	do

		# a. check we still have valid stations.
		case "${COMP}" in
			Z )
				if ! [ -s "${EQ}_SelectedFiles_PArrival" ]
				then
					echo "        ~=> No selected files for ${COMP} component SNR measurements..."
					continue
				else
					awk '{print $1}' ${EQ}_SelectedFiles_PArrival > ${EQ}_Files.txt
				fi
				;;

			R | T )
				if ! [ -s "${EQ}_SelectedFiles_PArrival" ]
				then
					echo "        ~=> No selected files for ${COMP} component SNR measurements..."
					continue
				else
					awk '{print $1}' ${EQ}_SelectedFiles_PArrival_SArrival > ${EQ}_Files.txt
				fi
				;;

			* )
				echo "        !=> Not possible! How could you enter here >_<..."
				exit 1
				;;
		esac



		# b. Choose file already exists for this component.
		#    (get the filenames exists both in ${EQ}_SelectedFiles_* and ${a01DIR}/${EQ}_FileList_${COMP})
		${BASHCODEDIR}/Findrow.sh ${a01DIR}/${EQ}_FileList_${COMP} ${EQ}_Files.txt > ${EQ}_List1
		saclst kstnm knetwk gcarc f `cat ${EQ}_List1` > tmpfile_$$

		sort -g -k 4,4 tmpfile_$$ > ${EQ}_List1
		rm -f tmpfile_$$

		# c. Choose files needed to be rotated for getting this component.
		if [ ${COMP} = "T" ] || [ ${COMP} = "R" ]
		then
			${BASHCODEDIR}/Findrow.sh ${a01DIR}/${EQ}_FileList_E ${EQ}_Files.txt > tmpfile1_$$
			${BASHCODEDIR}/Findrow.sh ${a01DIR}/${EQ}_FileList_N ${EQ}_Files.txt > tmpfile2_$$

			# If for some stations, either E or N didn't pass the time window selection
			# throw away these stations.

			saclst kstnm knetwk f `cat tmpfile1_$$` | awk '{print $2"_"$3}' | sort  > tmpfile1_net_st_$$
			saclst kstnm knetwk f `cat tmpfile2_$$` | awk '{print $2"_"$3}' | sort  > tmpfile2_net_st_$$
			comm -1 -2 tmpfile1_net_st_$$ tmpfile2_net_st_$$ > tmpfile_keep_net_st_$$

			saclst kstnm knetwk f `cat tmpfile1_$$` | awk '{print $2"_"$3,$1}' > tmpfile1_net_st_file_$$
			saclst kstnm knetwk f `cat tmpfile2_$$` | awk '{print $2"_"$3,$1}' > tmpfile2_net_st_file_$$

			${BASHCODEDIR}/Findrow.sh tmpfile1_net_st_file_$$ tmpfile_keep_net_st_$$ | awk '{print $2}' > tmpfile1_$$
			${BASHCODEDIR}/Findrow.sh tmpfile2_net_st_file_$$ tmpfile_keep_net_st_$$ | awk '{print $2}' > tmpfile2_$$


			# Deal with rotation npts problem. (List2 has more info than List1)

			saclst npts f `cat tmpfile1_$$` > tmpfile3_$$
			saclst kstnm knetwk npts gcarc f `cat tmpfile2_$$` > tmpfile4_$$
			paste tmpfile3_$$ tmpfile4_$$ | sort -g -k 7,7 > ${EQ}_List2

			rm -f tmpfile1_$$ tmpfile2_$$ tmpfile3_$$ tmpfile4_$$ tmpfile1_net_st_$$ tmpfile2_net_st_$$ tmpfile1_net_st_file_$$ tmpfile2_net_st_file_$$

			[ ${COMP} = "R" ] && ReadIn="junk.R" || ReadIn="junk.T"

		fi



		# d.get (by interpolate) the cut time t1 ( Tp - 180 sec )
		awk '{print $4}' ${EQ}_List1 > ${EQ}_gcarc_$$

		${EXECDIR}/Interpolate.out 0 3 0 << EOF
${EQ}_P_TC.txt
${EQ}_gcarc_$$
${EQ}_CutT1_$$
EOF

		awk '{$4=""; print $0}' ${EQ}_List1 > tmpfile_$$
		paste tmpfile_$$ ${EQ}_CutT1_$$ | awk '{print $1,$2,$3,$4-180}' > ${EQ}_List1
		rm -f tmpfile_$$


		# e.get (by interpolate) the cut time t2 ( Tp/Ts + 30 sec )
		if [ "${COMP}" = Z ]
		then
			cp ${EQ}_List1 tmpfile_$$
			paste tmpfile_$$ ${EQ}_CutT1_$$ | awk '{print $1,$2,$3,$4,$5+30}' > ${EQ}_List1
			rm -f tmpfile_$$
		else

			${EXECDIR}/Interpolate.out 0 3 0 << EOF
${EQ}_S_TC.txt
${EQ}_gcarc_$$
${EQ}_CutT2_$$
EOF

			cp ${EQ}_List1 tmpfile_$$
			paste tmpfile_$$ ${EQ}_CutT2_$$ | awk '{print $1,$2,$3,$4,$5+30}' > ${EQ}_List1
			rm -f tmpfile_$$
		fi


		# d,e*.get (by interpolate) the cut window for List2.
		if [ -s "${EQ}_List2" ]
		then
			awk '{print $7}' ${EQ}_List2 > ${EQ}_gcarc_$$

			${EXECDIR}/Interpolate.out 0 3 0 << EOF
${EQ}_P_TC.txt
${EQ}_gcarc_$$
${EQ}_CutT1_$$
EOF

			${EXECDIR}/Interpolate.out 0 3 0 << EOF
${EQ}_S_TC.txt
${EQ}_gcarc_$$
${EQ}_CutT2_$$
EOF
			awk '{$7=""; print $0}' ${EQ}_List2 > tmpfile_$$
			paste tmpfile_$$ ${EQ}_CutT1_$$ ${EQ}_CutT2_$$ | awk '{$7-=180;$8+=30; print $0}' > ${EQ}_List2
			rm -f tmpfile_$$

		fi



		# f. Process data (to sac format) in ${EQ}_List1.
		rm -f ${EQ}_SACMacro1.m
		while read filename stnm netwk T1 T2
		do

			cat >> ${EQ}_SACMacro1.m << EOF
cut off
r ${filename}
rmean
rtr
dif
taper
hp co 0.01 n 2 p 2
w junk.sac
cut O ${T1} ${T2}
r junk.sac
envelope
w junk.sac
cut b 0 120
r junk.sac
int
w ${EQ}.${netwk}.${stnm}.Noise.sac
cut e -60 0
r junk.sac
int
w ${EQ}.${netwk}.${stnm}.Signal.sac
EOF
		done < ${EQ}_List1

		sac >/dev/null 2>&1  << EOF
m ${EQ}_SACMacro1.m
q
EOF
		rm -f junk.sac


		# f*. Process data (to sac format) in ${EQ}_List2, for COMP="R" or "T".
		if [ ${COMP} = "T" ] || [ ${COMP} = "R" ]
		then

			rm -f ${EQ}_SACMacro2.m
			while read Efile ENpts Nfile stnm netwk NNpts T1 T2
			do
				if [ ${ENpts} -ge ${NNpts} ]
				then
					SACCut="cut b n ${NNpts}"
				else
					SACCut="cut b n ${ENpts}"
				fi

				cat >> ${EQ}_SACMacro2.m << EOF
${SACCut}
r ${Nfile} ${Efile}
rotate to GCP
w junk.R junk.T
r ${ReadIn}
rmean
rtr
dif
taper
hp co 0.01 n 2 p 2
w junk.sac
cut O ${T1} ${T2}
r junk.sac
envelope
w junk.sac
cut b 0 120
r junk.sac
int
w ${EQ}.${netwk}.${stnm}.Noise.sac
cut e -60 0
r junk.sac
int
w ${EQ}.${netwk}.${stnm}.Signal.sac
EOF
			done < ${EQ}_List2

			if [ -s "${EQ}_SACMacro2.m" ]
			then

				sac >/dev/null 2>&1 << EOF
m ${EQ}_SACMacro2.m
q
EOF
				rm -f junk.sac junk.R junk.T

			fi

		fi


		# f. Process data (from sac to SNR)
		saclst knetwk kstnm depmax f `ls ${EQ}*Signal.sac` | awk '{if ($4!=0) print $2,$3}' > ${EQ}_NETWK_STNM.txt

		rm -f tmpfile_$$ tmpfile1_$$
		while read NETWK STNM
		do
			saclst knetwk kstnm depmax kcmpnm depmin f ${EQ}.${NETWK}.${STNM}.Noise.sac >> tmpfile_$$
			saclst depmax kcmpnm depmin f ${EQ}.${NETWK}.${STNM}.Signal.sac >> tmpfile1_$$
		done < ${EQ}_NETWK_STNM.txt

		paste tmpfile_$$ tmpfile1_$$ | awk '{print $2,$3,($8-$10)/60/($4-$6)*120}' > ${COMP}_netwk_stnm_snr.txt
		rm -f tmpfile_$$ tmpfile1_$$

	done # Done component loop.

	# I. Merge measurements on 3 component into 1 file.
	OUTFILE=${a14DIR}/${EQ}_SNR.List
	echo "<NETWK> <STNM> <SNR_R> <SNR_T> <SNR_Z>" > ${OUTFILE}

	# a. stations which have all 3 SNR measurements.
	touch R_netwk_stnm_snr.txt T_netwk_stnm_snr.txt Z_netwk_stnm_snr.txt
	awk '{print $1"_"$2}' R_netwk_stnm_snr.txt | sort > R_netwk_stnm.txt
	awk '{print $1"_"$2}' T_netwk_stnm_snr.txt | sort > T_netwk_stnm.txt
	awk '{print $1"_"$2}' Z_netwk_stnm_snr.txt | sort > Z_netwk_stnm.txt
	comm -1 -2 R_netwk_stnm.txt T_netwk_stnm.txt > tmpfile_$$
	comm -1 -2 Z_netwk_stnm.txt tmpfile_$$ > tmpfile_keep_net_st_$$

	awk '{print $1"_"$2,$3}' R_netwk_stnm_snr.txt | sort > tmpfileR_$$
	awk '{print $1"_"$2,$3}' T_netwk_stnm_snr.txt | sort > tmpfileT_$$
	awk '{print $1"_"$2,$3}' Z_netwk_stnm_snr.txt | sort > tmpfileZ_$$

	${BASHCODEDIR}/Findrow.sh tmpfileR_$$ tmpfile_keep_net_st_$$ | awk '{print $2}' > tmpfile1_$$
	${BASHCODEDIR}/Findrow.sh tmpfileT_$$ tmpfile_keep_net_st_$$ | awk '{print $2}' > tmpfile2_$$
	${BASHCODEDIR}/Findrow.sh tmpfileZ_$$ tmpfile_keep_net_st_$$ | awk '{print $2}' > tmpfile3_$$
	paste tmpfile_keep_net_st_$$ tmpfile1_$$ tmpfile2_$$ tmpfile3_$$ \
	| awk 'BEGIN {FS="_"} {print $1,$2}' >> ${OUTFILE}

	# b. stations which only have some measurements.

	rm -f tmpfile_$$
	comm -2 -3 R_netwk_stnm.txt tmpfile_keep_net_st_$$ > tmpfile_$$
	comm -2 -3 T_netwk_stnm.txt tmpfile_keep_net_st_$$ >> tmpfile_$$
	comm -2 -3 Z_netwk_stnm.txt tmpfile_keep_net_st_$$ >> tmpfile_$$
	sort tmpfile_$$ | uniq > tmpfile1_$$

	while read label
	do
		echo ${label} > tmpfile_$$

		RSNR=""
		TSNR=""
		ZSNR=""

		RSNR=`${BASHCODEDIR}/Findrow.sh tmpfileR_$$ tmpfile_$$ | awk '{print $2}'`
		TSNR=`${BASHCODEDIR}/Findrow.sh tmpfileT_$$ tmpfile_$$ | awk '{print $2}'`
		ZSNR=`${BASHCODEDIR}/Findrow.sh tmpfileZ_$$ tmpfile_$$ | awk '{print $2}'`

		[ -z "${RSNR}" ] && RSNR="nan"
		[ -z "${TSNR}" ] && TSNR="nan"
		[ -z "${ZSNR}" ] && ZSNR="nan"

		echo "${label} ${RSNR} ${TSNR} ${ZSNR}" | awk 'BEGIN {FS="_"} {print $1,$2}' >> ${OUTFILE}

	done < tmpfile1_$$

	rm -f tmpfile*$$
	

done # End of EQ loop.

cd ${OUTDIR}

exit 0
