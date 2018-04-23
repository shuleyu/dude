#!/bin/bash

# ====================================================================
# This script combine all *ps file and make a PDF file.
#
# Ed Garnero/Pei-Ying(Patty) Lin/Shule Yu
# ====================================================================

echo ""
echo "--> `basename $0` is running. `date`"
cd ${PLOTDIR}

# ==================================================
#              ! Work Begin !
# ==================================================

# Ctrl+C action.
trap "rm -f ${PLOTDIR}/tmpfile*$$ ${EQ}.pdf a*.pdf ${OUTDIR}/*_${RunNumber}; exit 1" SIGINT

# Clean PDF(s)
# rm -f *pdf

# Work Begin.

if [ ${ByWhich} = "EQ" ]
then

	for EQ in `cat ${OUTDIR}/tmpfile_EQs_${RunNumber}`
	do


		# get all plots for this EQ
		ls -rt ${EQ}.a* > tmpfile_names_$$ 2>/dev/null

		if ! [ -s tmpfile_names_$$ ]
		then
			continue
		fi

		# sort according to ascending task number.
		rm -f tmpfile_unsorted_names_$$
		while read psfile
		do
			Num=${psfile#*.a}
			Num=${Num%%.*}
			echo ${Num} ${psfile} >> tmpfile_unsorted_names_$$
		done  < tmpfile_names_$$

		sort -s -g -k 1,1 tmpfile_unsorted_names_$$ > tmpfile_names_$$

		# cat all ps files into one big ps file.
		rm -f tmpfile_$$
		while read num file
		do
			cat ${file} >> tmpfile_$$
		done < tmpfile_names_$$

		# ps2pdf.
		if [ -s tmpfile_$$ ]
		then
			echo "    ==> Combining plot(s) from ${EQ}."
			ps2pdf tmpfile_$$ ${EQ}.pdf
		fi

        tomini ${EQ}.pdf

	done # End of EQ loop.

else


	for task in `seq 1 30`
	do
		Task=`printf "%.2d" ${task}`

		# get all plots for each task.
		ls -rt *a${Task}* > tmpfile_names_$$ 2>/dev/null

		if ! [ -s tmpfile_names_$$ ]
		then
			continue
		fi

		# sort according to ascending EQ number.
		rm -f tmpfile_unsorted_names_$$
		while read psfile
		do
			EQ=${psfile#.*}
			echo ${EQ} ${psfile} >> tmpfile_unsorted_names_$$
		done  < tmpfile_names_$$

		sort -s -g -k 1,1 tmpfile_unsorted_names_$$ > tmpfile_names_$$

		# cat all ps files into one big ps file.
		rm -f tmpfile_$$
		while read eq file
		do
			cat ${file} >> tmpfile_$$
		done < tmpfile_names_$$


		# ps2pdf.
		if [ -s tmpfile_$$ ]
		then
			echo "    ==> Combining plot(s) from a${Task}..."
			ps2pdf tmpfile_$$ a${Task}.pdf
		fi

        tomini a${Task}.pdf

	done # End of Task loop.

fi

rm -f tmpfile*$$

cd ${OUTDIR}

exit 0
