#!/bin/bash

# ====================================================================
# This script calculate P,SV,SH radiation pattern and plot out the
# beachball-like amplitude (Azimuth-TakeoffAngle-Amplitude)
#
# Ed Garnero/Pei-Ying(Patty) Lin/Shule Yu
# ====================================================================

echo ""
echo "--> `basename $0` is running. `date`"
mkdir -p ${a12DIR}
cd ${a12DIR}

# ==================================================
#              ! Work Begin !
# ==================================================


for EQ in `cat ${OUTDIR}/tmpfile_EQs_${RunNumber}`
do

	# Ctrl+C action.
	trap "rm -f ${a12DIR}/${EQ}* ${a12DIR}/tmpfile*$$ ${PLOTFILE} ${OUTDIR}/*_${RunNumber}; exit 1" SIGINT

	# A. Check the existance of list file.
	if ! [ -s "${a01DIR}/${EQ}_FileList" ]
	then
		echo "    ~=> ${EQ} doesn't have FileList ..."
		continue
	else
		echo "    ==> Making radiation pattern prediction of ${EQ}."
	fi

	# B. Pull information.
	keys="<EQ> <EVLA> <EVLO> <EVDP> <MAG>"
	${BASHCODEDIR}/Findfield.sh ${a01DIR}/EQInfo.txt "${keys}" | grep ${EQ} > ${EQ}_Info
	read EQ EVLA EVLO EVDP MAG < ${EQ}_Info


	# C. Grab CMT Info from website search result (connection required, http://www.globalcmt.org/CMTsearch.html).
	# Note: events before 2000 will cause problem in online search method because the event naming is different.

    CMTInfo=`${BASHCODEDIR}/GetCMT.sh ${EQ}`
    [ -z "${CMTInfo}" ] && CMTInfo=`${BASHCODEDIR}/GetCMT.sh ${EQ%?}`

	if [ -z "${CMTInfo}" ]
	then
		echo "        ~=> Can't find ${EQ} CMT information..."
		rm -f tmpfile_$$
		continue
	fi

	Strike=`echo "${CMTInfo}" | awk '{print $3}'`
	Dip=`echo "${CMTInfo}" | awk '{print $4}'`
	Rake=`echo "${CMTInfo}" | awk '{print $5}'`

	echo "<Strike1> <Dip1> <Rake1> <Strike2> <Dip2> <Rake2>" > ${EQ}_CMT.txt
	echo "${CMTInfo}" | awk '{print $3,$4,$5,$6,$7,$8}' >> ${EQ}_CMT.txt


	rm -f tmpfile_$$


	# D. For each phase, only select those stations receive this phase prdicted by PREM,
	# then get their takeoff angles for this phase. (Using TauP)

	while read Phase COMP
	do

		case "${COMP}" in

			P )
				COMP1=1
				;;
			SV )
				COMP1=2
				;;
			SH )
				COMP1=3
				;;
			* )
				echo "        !=> Wrong COMP input ! "
				exit 1
				;;
		esac

		# Check phase file.
		PhaseFile=`ls ${a05DIR}/${EQ}_*_${Phase}.gmt_Enveloped 2>/dev/null`
		if ! [ -s "${PhaseFile}" ]
		then
			echo "        ~=> RadPat: can't find First Arrival file for phase ${Phase} !"
			continue
		else
			PhaseDistMin=`minmax -C ${PhaseFile} | awk '{print $1}'`
			PhaseDistMax=`minmax -C ${PhaseFile} | awk '{print $2}'`
		fi


		# Select stations receive  this phase.
		keys="<NETWK> <STNM> <Gcarc> <Az>"
		${BASHCODEDIR}/Findfield.sh ${a01DIR}/${EQ}_FileList_Info "${keys}" | sort -u -k 1,2 \
		| awk -v D1=${PhaseDistMin} -v D2=${PhaseDistMax} '{if (D1<=$3 && $3<=D2) print $0}' \
		> ${EQ}_netwk_stnm_gcarc_az

		# Calculate ray paraemters of this phase for these stations.
		# (call TauP on grid spacing from DISTMIN to DISTMAX, then interpolate)
		# Note: only get the ray parameter of the first arrival.

		if ! [ -s "${EQ}_netwk_stnm_gcarc_az" ]
		then
			echo "        ~=> RadPat: no selected stations for phase ${Phase} !"
			echo "<NETWK> <STNM> <Gcarc> <Az> <RayP> <TakeOff> <RadPat>" > ${EQ}_${Phase}_${COMP}_RadPat.List
			continue
		fi


		awk '{print $3}' ${EQ}_netwk_stnm_gcarc_az > tmpfile_gcarc_$$
		DISTMIN=`minmax -C tmpfile_gcarc_$$ | awk '{print $1}'`
		DISTMAX=`minmax -C tmpfile_gcarc_$$ | awk '{print $2}'`
		awk '{print $4}' ${EQ}_netwk_stnm_gcarc_az > tmpfile_az_$$


		rm -f tmpfile_$$
		for gcarc in `seq ${DISTMIN} 0.1 ${DISTMAX}`
		do
			RayP=""
			RayP=`taup_time -mod ${Model_TT} -ph ${Phase} -h ${EVDP} -deg ${gcarc} --rayp | awk '{print $1}'`

			if [ -z "${RayP}" ]
			then
				echo "        !=> An error shouldn't occur happened: PREM ${Phase} @ ${gcarc} deg for ${EVDP} km doesn't exist! "
				exit 1
			fi

			echo "${gcarc} ${RayP}" >> tmpfile_$$
		done

		# make up for the final distance.
		if [ `echo "${DISTMAX}>${gcarc}"|bc` -eq 1 ]
		then
			RayP=""
			RayP=`taup_time -mod ${Model_TT} -ph ${Phase} -h ${EVDP} -deg ${DISTMAX} --rayp | awk '{print $1}'`

			if [ -z "${RayP}" ]
			then
				echo "        !=> An error shouldn't occur happened: PREM ${Phase} @ ${DISTMAX} deg for ${EVDP} km doesn't exist! "
				exit 1
			fi

			echo "${DISTMAX} ${RayP}" >> tmpfile_$$
		fi


		# Interpolate to calculate rayp for all gcarc.
		${EXECDIR}/Interpolate.out 0 3 0 << EOF
tmpfile_$$
tmpfile_gcarc_$$
tmpfile_rayp_$$
EOF

		paste tmpfile_az_$$ tmpfile_rayp_$$ > tmpfile_in_$$

		# Convert ray parameter to takeoff angle and radpat.
		${EXECDIR}/MakeRadPat.out 1 2 4 << EOF
${COMP1}
tmpfile_in_$$
tmpfile_rayp_takeoff_radpat_$$
${EVDP}
${Strike}
${Dip}
${Rake}
EOF

		# Prepare the final file.

		echo "<NETWK> <STNM> <Gcarc> <Az> <RayP> <TakeOff> <RadPat>" > ${EQ}_${Phase}_${COMP}_RadPat.List
		paste ${EQ}_netwk_stnm_gcarc_az tmpfile_rayp_takeoff_radpat_$$ >> ${EQ}_${Phase}_${COMP}_RadPat.List

		rm -f tmpfile*$$ ${EQ}_netwk_stnm_gcarc_az

	done < ${OUTDIR}/tmpfile_ChosenPhase_${RunNumber}

done # End of EQ loop.

cd ${OUTDIR}

exit 0
