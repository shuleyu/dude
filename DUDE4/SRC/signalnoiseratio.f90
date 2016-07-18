program SNratio 
! written by Pei-ying Patty Lin

implicit none

include "sacf.h"

! Define the Maximum size of the data Array
INTEGER, PARAMETER         :: MAXnpts = 300000, MAXstation = 1000
INTEGER                    :: istation, nstation
INTEGER                    :: ierr, status_read, keep, ierrP, ierrS
INTEGER,ALLOCATABLE        :: npts(:), cutlen(:)
REAL(kind=4), ALLOCATABLE  :: beg(:), dt(:), cutbeg(:) 
REAL(kind=4), ALLOCATABLE  :: array(:,:), envarray(:,:)
REAl(kind=4)               :: cuty(MAXnpts)
REAL(kind=4), ALLOCATABLE  :: reftimeP(:), reftimeS(:)
REAL(kind=8)               :: timebeforeP, timewin_noise, timewin_signal, timewindow_factor
REAL(kind=8), ALLOCATABLE  :: timeSTART_noise(:), timeSTART_signalP(:), timeSTART_signalS(:)
REAL(kind=8), ALLOCATABLE  :: ratio_noiseP(:), ratio_noiseSV(:), ratio_noiseSH(:) 
REAL(kind=8), ALLOCATABLE  :: ratio_signalP(:), ratio_signalSV(:), ratio_signalSH(:)
CHARACTER*10, ALLOCATABLE  :: STA(:)
CHARACTER*80               :: filename_ZRTlist,Zfile(MAXstation), Rfile(MAXstation), Tfile(MAXstation)
CHARACTER*10               :: t_header,refphase 
CHARACTER                  :: yntaper*1, ynnormalize*1

   ! == Input valuables ============ 
   read(*,*) filename_ZRTlist

   ! == Define valuabes ============ 
   timebeforeP    = 60.0
   timewin_noise  = 120.0
   timewin_signal = 30.0

   
   ! --  
   status_read = 0
   istation = 1
   open(11, file = filename_ZRTlist )
   do while ( status_read .eq. 0 )
       read(11, *,iostat = status_read ) Zfile(istation), Rfile(istation), Tfile(istation)
       if ( status_read .eq. 0 ) istation = istation + 1
       if ( istation .gt. MAXstation)  stop 'station # >  MAXstation '
   end do
   nstation = istation - 1
   print *, nstation

   ! --

   ALLOCATE( array(MAXnpts,nstation), envarray(MAXnpts,nstation) , npts(nstation), beg(nstation), dt(nstation),&
             STA(nstation), STAT=keep)
   IF (keep /=0 ) STOP '<< ALLOCATE ERROR IN nstation >>'
   ALLOCATE( cutlen(nstation), cutbeg(nstation), STAT=keep)
   IF (keep /=0 ) STOP '<< ALLOCATE ERROR IN nstation >>'
   ALLOCATE( reftimeP(nstation), reftimeS(nstation),STAT=keep )
   IF (keep /=0 ) STOP '<< ALLOCATE ERROR IN nstation >>'
   ALLOCATE( timeSTART_noise(nstation), timeSTART_signalP(nstation), timeSTART_signalS(nstation), STAT=keep)
   IF (keep /=0 ) STOP '<< ALLOCATE ERROR IN nstation >>'
   ALLOCATE( ratio_noiseP(nstation), ratio_noiseSV(nstation), ratio_noiseSH(nstation), &
             ratio_signalP(nstation), ratio_signalSV(nstation), ratio_signalSH(nstation),STAT=keep)
   IF (keep /=0 ) STOP '<< ALLOCATE ERROR IN nstation >>'

   yntaper="n"
   ynnormalize="n" 
   do istation = 1, nstation 
       ! ================= Z (P) ===========================================================================================
       array(:, istation) = 0.0
       call rsac1(Zfile(istation), array(:,istation), npts(istation), beg(istation), dt(istation), MAXnpts, ierr) 
       call getkhv ('KSTNM',STA(istation),ierr)
       refphase = "P"
       include "phasesinclude.h"
       call getfhv(t_header,  reftimeP(istation), ierrP )
       refphase = "S"
       include "phasesinclude.h"
       call getfhv(t_header,  reftimeS(istation), ierrS ) 
!       call getfhv ('T0', reftimeP(istation), ierrP)  
!       call getfhv ('T2', reftimeS(istation), ierrS)

       ! --- Noise ratio   ------ 
       if ( ierrP == 0 ) then
           timeSTART_noise(istation) = reftimeP(istation) - ( timebeforeP + timewin_noise ) 
       
           envarray(:, istation) = 0.0
           call SUB_CUT_SACascii( array(:,istation), beg(istation), dt(istation) , timeSTART_noise(istation), timewin_noise, &
                                         yntaper, ynnormalize, cuty, cutlen(istation), cutbeg(istation) )
           call envelope( cutlen(istation), cuty, envarray(:,istation))
           ratio_noiseP(istation) = SUM(envarray(1:cutlen(istation),istation)) 
       ! --- signal ratio  ------
           timeSTART_signalP(istation) = reftimeP(istation) - ( timewin_signal / 2.0  )
       
           envarray(:, istation) = 0.0
           call SUB_CUT_SACascii( array(:,istation), beg(istation), dt(istation) , timeSTART_signalP(istation), timewin_signal, &
                                         yntaper, ynnormalize, cuty, cutlen(istation), cutbeg(istation) )
           call envelope( cutlen(istation), cuty, envarray(:,istation))
           ratio_signalP(istation)= SUM(envarray(1:cutlen(istation),istation))
        else 
           ratio_noiseP(istation)  = 0.0
           ratio_signalP(istation) = 0.0

        end if
          
       ! ================= R (SV) ===========================================================================================

       if ( ierrS == 0 ) then 
           timeSTART_signalS(istation) = reftimeS(istation) - ( timewin_signal / 2.0  )
           array(:, istation) = 0.0 
           call rsac1(Rfile(istation), array(:,istation), npts(istation), beg(istation), dt(istation), MAXnpts, ierr)
       
       ! -- Noise ratio --------------------------------
           envarray(:, istation) = 0.0
           call SUB_CUT_SACascii( array(:,istation), beg(istation), dt(istation) , timeSTART_noise(istation), timewin_noise, &
                                         yntaper, ynnormalize, cuty, cutlen(istation), cutbeg(istation) )
           call envelope( cutlen(istation), cuty, envarray(:,istation))
           ratio_noiseSV(istation) = SUM(envarray(1:cutlen(istation),istation))
       
       ! -- Signal ratio -------------------------------
            envarray(:, istation) = 0.0
            call SUB_CUT_SACascii( array(:,istation), beg(istation), dt(istation) , timeSTART_signalS(istation), timewin_signal, &
                                         yntaper, ynnormalize, cuty, cutlen(istation), cutbeg(istation) )
            call envelope( cutlen(istation), cuty, envarray(:,istation))
            ratio_signalSV(istation)= SUM(envarray(1:cutlen(istation),istation))
        else
           ratio_noiseSV(istation)  = 0.0
           ratio_signalSV(istation) = 0.0
        end if


       ! ================= T (SH) ===========================================================================================

       if ( ierrS == 0 ) then 
       ! -- T -- SH
           array(:, istation) = 0.0
           call rsac1(Tfile(istation), array(:,istation), npts(istation), beg(istation), dt(istation), MAXnpts, ierr)
  
       ! -- Noise ratio --------------------------------
           envarray(:, istation) = 0.0
           call SUB_CUT_SACascii( array(:,istation), beg(istation), dt(istation) , timeSTART_noise(istation), timewin_noise, &
                                         yntaper, ynnormalize, cuty, cutlen(istation), cutbeg(istation) )
           call envelope( cutlen(istation), cuty, envarray(:,istation))
           ratio_noiseSH(istation) = SUM(envarray(1:cutlen(istation),istation))


       ! -- Signal ratio -------------------------------
           envarray(:, istation) = 0.0
           call SUB_CUT_SACascii( array(:,istation), beg(istation), dt(istation) , timeSTART_signalS(istation), timewin_signal, &
                                         yntaper, ynnormalize, cuty, cutlen(istation), cutbeg(istation) )
           call envelope( cutlen(istation), cuty, envarray(:,istation))
           ratio_signalSH(istation)= SUM(envarray(1:cutlen(istation),istation))
       ! =====================================================================================================================
       else
           ratio_noiseSH(istation)  = 0.0
           ratio_signalSH(istation) = 0.0
       end if
end do

timewindow_factor = timewin_noise/timewin_signal
open(12, file = "SNratio.info")
do istation = 1, nstation
   write(12,'(6F20.10, 2x,a)') ratio_noiseP(istation), ratio_signalP(istation)*timewindow_factor, &
                               ratio_noiseSV(istation), ratio_signalSV(istation)*timewindow_factor, &
                               ratio_noiseSH(istation), ratio_signalSH(istation)*timewindow_factor, &
                               STA(istation)
end do 



close(11)
close(12)

DEALLOCATE( array, envarray, npts, beg, dt, STA, cutlen, cutbeg, reftimeP, reftimeS, timeSTART_noise,timeSTART_signalP, &
            timeSTART_signalS, ratio_noiseP, ratio_noiseSV, ratio_noiseSH, ratio_signalP, ratio_signalSV, ratio_signalSH )
STOP
END

Subroutine SUB_CUT_SACascii(yarray, beg, delta, cutt1, twin, yntaper, ynnormalize, cuty ,cutnpts, cutbeg)

! ####################################################################################
! # NOTICE!!! Taper     here : Taper for cut window of data
! # NOTICE!!! Normalize here : Normalize for cut window of data 
! # 2009.0414 written by pylin.patty 
! #
! # New version you can do the same job as sac commamd "cuterr fillz!" 
! # if you need taper for your cut window which across b or e,
! # please taper the origianl seismogram first.
! # 2009.0427 updated by pylin.patty
! #  
! ####################################################################################
implicit none


!     Define the Maximum size of the data Array
INTEGER, PARAMETER   :: MAXnpts = 300000, k=8

!     Define the Data Array of size MAX
REAL(kind=4)         :: yarray(MAXnpts), yitm(MAXnpts),cuty(MAXnpts)

!     Declare Variables used in the rsac1() subroutine
REAL(kind=4)         :: beg, delta,cutbeg
INTEGER              :: cutnpts, istart
CHARACTER*1          :: yntaper, ynnormalize
!     Define variables used in the filtering routine
REAL(kind=k)         :: cutt1, twin
REAL(kind=k)         :: MAX_cuty

   cutnpts = anint(twin / delta)+1
   if ( cutnpts .gt. MAXnpts ) STOP '<<ERROR in setting dimension for cutnpts! >>'
   cuty= 0.0
   yitm= 0.0
   if ( (cutt1- beg) >= -0.000001 ) then
       istart =  anint((cutt1-beg)/delta)+1
       yitm(1:cutnpts)=yarray(istart:istart+cutnpts)
       if ( yntaper == "y" ) then
           call sub_taper_ascii(yitm,cutnpts,1,cutnpts,cutnpts,10,10)
       end if
       cuty(1:cutnpts)=yitm(1:cutnpts)
       cutbeg=real(istart-1)*delta+beg
   else if ( (beg- cutt1) >= -0.000001 ) then
       istart =  anint((beg-cutt1)/delta)
       yitm(1:istart) = 0.0
       yitm(istart+1:cutnpts)=yarray(1:cutnpts-istart)
       if ( yntaper == "y" ) then
           call sub_taper_ascii(yitm,cutnpts,1,cutnpts,cutnpts,10,10)
       end if
       cuty(1:cutnpts)=yitm(1:cutnpts)
       cutbeg=beg-real(istart)*delta
   end if

   if ( ynnormalize == "y" ) then
       MAX_cuty= maxval(abs(cuty))
       cuty=cuty/MAX_cuty
   end if

END subroutine SUB_CUT_SACascii

SUBROUTINE sub_taper_ascii(y,npts,j1,j2,jpts,nlperc,nrperc)
!
!  Apply  hanning taper to data window
!
!      WIKI Window function 
!          HANN window w(n) = 0.5*(1-cos(2*pi*n/(N-1)))
!                      w0(n) = 0.5*(1+cos(2*pi*n/(N-1))) 
!           COSINE window w(n) = cos(pi*n/(N-1)-pi/2) = sin(pi*n/(N-1))
!      Formula in SAC
!          DATA(J)=DATA(J)*(F0-F1*COS(OMEGA*(J-1))
!              TYPE     OMEGA     F0    F1
!              HANNING  PI/N      0.50  0.50
!              HAMMING  PI/N      0.54  0.46
!              COSINE   PI/(2*N)  1.00  1.00
! ---------------------------------------------------------------------        
!       y       =       data array
!       npts    =       total length of array to be filtered or transformed
!       j1,j2   =       first and last points of actual data
!       jpts    =       number of data points (j2-j1+1)
!       nlperc,nrperc = left and right taper widths percentage
!       nl,nr   =       left and right taper widths
!-------------------------------------------------------------------------
!Version:
!  the results of the hanning and hamming are exactly the same 
!                                                  as those of the SAC.
!  the results of the cosine are a little bit different. 
!  pylin.patty 09.0406 
!-------------------------------------------------------------------------
   real y(1)
   pi=3.141592654
  ! zero beginning of array
   if(j1.gt.1) then
       do i=1,j1-1
           y(i)=0.0
       end do
   endif
  ! zero end of array
   do  i=j2+1,npts
      y(i)=0.0
   end do

  ! calculate how many point to do taper
   nl = int(nlperc*npts/100)
   nr = int(nrperc*npts/100)
  ! taper left side
   do i=j1,j1+nl-1
       arg = pi * float(i + 1 - j1 - nl ) / float(nl) !for hanning and hamming
       !y(i) = y(i) * (1 + cos(arg)) / 2.
       y(i)=y(i)*(0.5+0.5*cos(arg))   !-- hanning 
       !y(i)=y(i)*(0.54+0.46*cos(arg)) !-- hamming
       !arg = pi * float(i + 1 - j1 - nl ) / float(2*nl) !for cosine
       !y(i)=y(i)*(1.0+1.0*cos(arg))   !-- for cosine 
   end do
  
  ! taper right side
   do i=j2-nr+1,j2
       arg = pi * float(i - (j2 + 1 -nr) ) / float(nr) !for hanning and hamming
       !y(i) = y(i) * (1 + cos(arg)) / 2.
       y(i)=y(i)*(0.5+0.5*cos(arg))   !-- hanning
       !y(i)=y(i)*(0.54+0.46*cos(arg)) !-- hamming
       !arg = pi * float(i - (j2 + 1 -nr) ) / float(2*nr) !for cosine
       !y(i)=y(i)*(1.0+1.0*cos(arg))   !-- for cosine
   end do

return
END 

