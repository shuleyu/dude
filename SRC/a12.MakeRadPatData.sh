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


	YYYY=`echo ${EQ} | cut -c1-4 `
	MM=`  echo ${EQ} | cut -c5-6 `
	DD=`  echo ${EQ} | cut -c7-8 `
	HH=`  echo ${EQ} | cut -c9-10 `
	MIN=` echo ${EQ} | cut -c11-12 `

	# C. Grab CMT Info from either from given CMT file or from website search result (connection required).
	# Note: events before 2000 will cause problem in online search method because the event naming is different.

	CMTInfo=""
	if [ -s "${CMTFILE}" ]
	then
		CMTInfo=`grep ${EQ} ${CMTFILE} | head -n 1`
	fi

	if [ -z "${CMTInfo}" ]
	then
		SearchURL="http://www.globalcmt.org/cgi-bin/globalcmt-cgi-bin/CMT4/form?itype=ymd&yr=${YYYY}&mo=${MM}&day=${MM}&otype=ymd&oyr=${YYYY}&omo=${MM}&oday=${DD}&jyr=1976&jday=1&ojyr=1976&ojday=1&nday=1&lmw=0&umw=10&lms=0&ums=10&lmb=0&umb=10&llat=-90&ulat=90&llon=-180&ulon=180&lhd=0&uhd=1000&lts=-9999&uts=9999&lpe1=0&upe1=90&lpe2=0&upe2=90&list=2"
		curl ${SearchURL} > tmpfile_$$ 2>/dev/null
		CMTInfo=`grep ${EQ} tmpfile_$$ | head -n 1`
	fi

	if [ -z "${CMTInfo}" ]
	then
		echo "        ~=> Can't find ${EQ} CMT information..."
		rm -f tmpfile_$$
		continue
	fi

	Strike=`echo "${CMTInfo}" | awk '{print $3}'`
	Dip=`echo "${CMTInfo}" | awk '{print $4}'`
	Rake=`echo "${CMTInfo}" | awk '{print $5}'`

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
		${BASHCODEDIR}/Findfield.sh ${a01DIR}/${EQ}_FileList_Info "${keys}" | uniq \
		| awk -v D1=${PhaseDistMin} -v D2=${PhaseDistMax} '{if (D1<=$3 && $3<=D2) print $0}' \
		> ${EQ}_netwk_stnm_gcarc_az


		# Calculate ray paraemters of this phase for these stations.
		# (call TauP on grid spacing from DISTMIN to DISTMAX, then interpolate)
		# Note: only get the ray parameter of the first arrival.

		if ! [ -s "${EQ}_netwk_stnm_gcarc_az" ]
		then
			echo "        ~=> RadPat: no valid stations for phase ${Phase} !"
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
		if [ `echo "${DISTMAX}>gcarc"|bc` -eq 1 ]
		then
			RayP=""
			RayP=`taup_time -mod ${Model_TT} -ph ${Phase} -h ${EVDP} -deg ${gcarc} --rayp | awk '{print $1}'`

			if [ -z "${RayP}" ]
			then
				echo "        !=> An error shouldn't occur happened: PREM ${Phase} @ ${gcarc} deg for ${EVDP} km doesn't exist! "
				exit 1
			fi

			echo "${gcarc} ${RayP}" >> tmpfile_$$
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

		echo "<NETWK> <STNM> <Gcarc> <Az> <RayP> <TakeOff> <RadPat>" > ${EQ}_${Phase}_${COMP}_RadPat.txt
		paste ${EQ}_netwk_stnm_gcarc_az tmpfile_rayp_takeoff_radpat_$$ >> ${EQ}_${Phase}_${COMP}_RadPat.txt

		rm -f tmpfile*$$ ${EQ}_netwk_stnm_gcarc_az

	done < ${OUTDIR}/tmpfile_ChosenPhase_${RunNumber}

done # End of EQ loop.

cd ${OUTDIR}

exit 0
