#!/bin/csh

${SRCDIR}/c01.list_prep                 ${INPUT}
# ${SRCDIR}/c05.profile_big               ${INPUT} -1 180 0 4500
# ${SRCDIR}/c07.profile_big_distinc_sum   ${INPUT} 40 100 0 1000 1.0 1.0
# ${SRCDIR}/c08.profile_zoom              ${INPUT} 40 100 -50 200 P Z
${SRCDIR}/c09.profile_zoom_distinc_sum  ${INPUT} 40 85 -50 200 ScS T 0.5 0.5
# ${SRCDIR}/c16.empirical_src_stack       ${INPUT} P Z 40 100 -20 30 0
# ${SRCDIR}/c16.empirical_src_stack       ${INPUT} PcP Z 40 100 -20 30 0
# ${SRCDIR}/c12.radiation_pat             ${INPUT}  ${CMT}
# ${SRCDIR}/c13.radpat_piercings          ${INPUT}  ${CMT}
# ${SRCDIR}/c14.radpat_pierce_1           ${INPUT}  ${CMT}  PcP P
# ${SRCDIR}/c18.profile_zoom_distinc_sum_weights ${INPUT} 40 100  -50 500 P Z 0.2 0.2
# ${SRCDIR}/c18.profile_zoom_distinc_sum_weights ${INPUT} 40 100  -50 5000 PcP Z 0.2 0.2

exit 0

# ==========================================================
#               ! Documentary !
# ==========================================================

# Make lists of stations, etc. | Something Must Do.
${SRCDIR}/c01.list_prep                 ${INPUT}

# Master map of great circle paths.
${SRCDIR}/c02.map_master                ${INPUT}

# Map of some major cities and paths and info.
${SRCDIR}/c03.map_citydist              ${INPUT}

# Histogram plots.
${SRCDIR}/c04.histograms                ${INPUT}

# Big profile | dist minmax, time minmax | if dist minmax = -1, generate dist minmax automatically.
${SRCDIR}/c05.profile_big               ${INPUT} -1 180 0 4500

# Big profile_comb | dist minmax, time minmax, distance gap | plot traces while disatance interval >= dist_gap | if dist minmax = -1, generate dist minmax automatically.
${SRCDIR}/c06.profile_big_comb          ${INPUT}  0 180 0 4500  0.8
${SRCDIR}/c32.profile_big_comb_NetWork  ${INPUT}  0 180 0 4500  0.2 TA

# profile_big_stack | dist minmax, time minmax, distwin, distinc | if dist minmax = -1, generate dist minmax automatically.
${SRCDIR}/c07.profile_big_distinc_sum    ${INPUT} 0 180 0 4500 1.0 1.0
${SRCDIR}/c30.profile_big_distinc_sum_NewWork    ${INPUT} 0 180 0 4500 0.25 0.25 TA

# zoom | dist minmax, time minmax, phase, comp
${SRCDIR}/c08.profile_zoom              ${INPUT} 10 90 -50 1000  P Z
${SRCDIR}/c08.profile_zoom              ${INPUT} 10 90 -50 1000  S T
${SRCDIR}/c08.profile_zoom              ${INPUT} 10 90 -50 1000  S R

# zoom | dist minmax, time minmax, phase, comp
${SRCDIR}/c08T.profile_zoom              ${INPUT} 35 90 -50 1000  P Z
${SRCDIR}/c08T.profile_zoom              ${INPUT} 35 90 -50 1000  S T
${SRCDIR}/c08T.profile_zoom              ${INPUT} 35 90 -50 1000  S R

# zoom_diststack | dist minmax, time minmax, phase, comp, distwin, distinc
${SRCDIR}/c09.profile_zoom_distinc_sum  ${INPUT} 10 90 -50 1500 P Z 0.5 0.5
${SRCDIR}/c09.profile_zoom_distinc_sum  ${INPUT} 10 90 -50 1500 S T 0.5 0.5
${SRCDIR}/c09.profile_zoom_distinc_sum  ${INPUT} 10 90 -50 1500 S R 0.5 0.5
${SRCDIR}/c31.profile_zoom_distinc_sum_NewWork  ${INPUT} 10 90 -50 1500 P Z 0.2 0.2 TA
${SRCDIR}/c31.profile_zoom_distinc_sum_NewWork  ${INPUT} 10 90 -50 1500 S R 0.2 0.2 TA
${SRCDIR}/c31.profile_zoom_distinc_sum_NewWork  ${INPUT} 10 90 -50 1500 S T 0.2 0.2 TA

# TA station map
${SRCDIR}/c10.map_TA_dists              ${INPUT}

# big TA profile | time minmax
${SRCDIR}/c11.profile_big_TA            ${INPUT} 0 4500

# Focal mech & rad pats
${SRCDIR}/c12.radiation_pat             ${INPUT}  ${CMT}

# rad pats + piercing points
${SRCDIR}/c13.radpat_piercings          ${INPUT}  ${CMT}

# calc and save SNR ratios
${SRCDIR}/c17.measure_SNR               ${INPUT}

# empirical source maker |  phase, comp, dist minmax, esf time window, flag_SNratio | flag_SNratio:  0 = off / 1 = on ( after running c17.measure_SNR )
${SRCDIR}/c16.empirical_src_stack       ${INPUT} P Z 10 90 -20 30 0
${SRCDIR}/c16.empirical_src_stack       ${INPUT} S T 30 90 -20 40 0
${SRCDIR}/c16.empirical_src_stack       ${INPUT} S R 30 80 -20 40 0
${SRCDIR}/c16.empirical_src_stack       ${INPUT} P Z 10 90 -20 30 1
${SRCDIR}/c16.empirical_src_stack       ${INPUT} S T 30 90 -20 40 1
${SRCDIR}/c16.empirical_src_stack       ${INPUT} S R 30 80 -20 40 1

# zoom_diststack | time/dist minmax, phase/comp, distwin, distinc | ( vaild after running c12.radiation_pat and c13.radpat_piercings, therefore c18 is only vaild for those 12 phase-comp pairs )
${SRCDIR}/c18.profile_zoom_distinc_sum_weights ${INPUT} 137 153  -20 80 PKIKP Z 0.2 0.2
${SRCDIR}/c18.profile_zoom_distinc_sum_weights ${INPUT} 137 153  -20 80 PKIKP Z 0.2 0.2
${SRCDIR}/c18.profile_zoom_distinc_sum_weights ${INPUT} 24 90  -100 7000 ScS T 0.2 0.2
${SRCDIR}/c18.profile_zoom_distinc_sum_weights ${INPUT} 60 90  -100 6500 S T 1 1
${SRCDIR}/c18.profile_zoom_distinc_sum_weights ${INPUT} 76 77  -100 6500 S T 0.005 0.005
${SRCDIR}/c18.profile_zoom_distinc_sum_weights ${INPUT} 12 45 -50 1000 P Z 0.5 0.25
${SRCDIR}/c18.profile_zoom_distinc_sum_weights ${INPUT} 12 45 -50 1000 S R 0.5 0.25
${SRCDIR}/c18.profile_zoom_distinc_sum_weights ${INPUT} 12 45 -50 1000 S T 0.5 0.25

# Map of ScS bounce points on tomography.
${SRCDIR}/c50.map_scs_bounce            ${INPUT}

# Map of SS surface reflection pts on tomography.
${SRCDIR}/c51.map_ss_bounce             ${INPUT}

# Map of S paths below a specific depth.
${SRCDIR}/c52.map_sdiffpath             ${INPUT}

# Map of SKS paths and In / Out CMB locations.
${SRCDIR}/c53.map_SKS_pathInOutCMB      ${INPUT}

# Map of PKIKP path and In / Out CMB locations.
${SRCDIR}/c54.map_PKIKP_pathInOutICB    ${INPUT}

# Map of PKP paths below a specific depth.
${SRCDIR}/c53.map_PKP                   ${INPUT}

# ray path cross_section for 1 phase | phase, comp.
${SRCDIR}/c95.raypath_crosssection      ${INPUT} ScS 70

# radpat+piercings for 1 phase | phase, comp ( of rad_pat)
${SRCDIR}/c14.radpat_pierce_1           ${INPUT}  ${CMT}  PP P
${SRCDIR}/c14.radpat_pierce_1           ${INPUT}  ${CMT}  PKP P
${SRCDIR}/c14.radpat_pierce_1           ${INPUT}  ${CMT}  SKS SV
${SRCDIR}/c14.radpat_pierce_1           ${INPUT}  ${CMT}  ScSScSScSScSScS SH

# traveltime zoomed for selected component | dist minmax, time minmax, comp (R/T/Z/ALL), Cshell_num (c99)
${SRCDIR}/c99.TraveltimeCurve           ${INPUT}  0 180 -100 12500 T c99
# traveltime zoomed for 1 phase | dist minmax, time minmax, phase, comp (R/T/Z/ALL), Cshell_num (c98)
${SRCDIR}/c98.TraveltimeCurve_zoom      ${INPUT}  0 180 -100 12500 S T c98

