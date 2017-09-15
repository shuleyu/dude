#!/bin/csh

# ===== envirment setting =================
set DIRSRC = /NAS/patty/DUDE/DUDE-1.3/SRC
source $DIRSRC/c0.ENV_setting


# =======================================
$FCOMP $DIRSRC/sac2xy.f90 $SACLIBs -o SAC2XY
$FCOMP $DIRSRC/sac2xy_LTW.f90 $SACLIBs -o SAC2XY
$FCOMP -c $DIRSRC/mrgrnk.f90
$FCOMP $DIRSRC/sac2xysort.f90 -o sac2xysort  $SACLIBs mrgrnk.o
$FCOMP  $DIRSRC/sac2xystack.f90 $SACLIBs -o SAC2XYstack
$FCOMP -I$DIRSRC $DIRSRC/sac2xyzoom.f90 $SACLIBs -o SAC2XYZOOM
$FCOMP  -I$DIRSRC $DIRSRC/sac2xyzoomstack.f90 $SACLIBs -o SAC2XYZOOMSTACK
$FCOMP $DIRSRC/sac2xy.f90 $SACLIBs -o SAC2XY
$FCOMP $DIRSRC/radiation.f90 -o RADI
$FCOMP $DIRSRC/radiation_th,az.f -o RADTHAZ
$FCOMP -I$DIRSRC $DIRSRC/empiricalSource.f90 -o EmpiricalSource $SACLIBs 
$FCOMP -I$SACHOME/include -o SNratio $DIRSRC/signalnoiseratio.f90 $SACLIBs 
$FCOMP -I$DIRSRC $DIRSRC/sac2xyzoomstack_withweights.f90 $SACLIBs -o SAC2XYZOOMSTACK_withweights 
$FCOMP $DIRSRC/taupTC_text.f90 -o taupTC_text
#$FCOMP $DIRSRC/random_num.f90 -o random_num
#EOF
