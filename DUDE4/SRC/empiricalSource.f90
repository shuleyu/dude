PROGRAM EmpiricalSource 
! by Patty Lin, ASU

IMPLICIT NONE

INTEGER, parameter            :: MAXnpts = 300000, MAXsac = 3000, PLOTpoints = 1001
INTEGER                       :: iSAC, nSAC, ipts,  npts_stack0, npts_stack1, sacnpts
INTEGER, ALLOCATABLE          :: npts(:), cutlen(:), PLOTnpts(:)
INTEGER                       :: status_read,ierr, keep, ttest
REAL(kind=8)                  :: time_beg, time_end, time_win, time_beg_real
REAL(kind=4)                  :: cuty(MAXnpts), sacamp(MAXnpts),sacbeg, sacdt, tref, weightv, weighting(MAXsac), tempMAX 
REAL, ALLOCATABLE             :: y(:,:), beg(:), dt(:), cutbeg(:), shift_y(:,:)
REAL, ALLOCATABLE             :: T(:,:), reftime(:), newbeg(:), stack0(:), stack1(:), stdstack1(:) , CC(:), timeshift(:)
REAL, ALLOCATABLE             :: stationary(:), shifting(:)
CHARACTER*80                  :: filename_saclist, SACfile(MAXsac),sacname
CHARACTER                     :: yntaper*1, ynnormalize*1
CHARACTER*10                  :: refphase, t_header
CHARACTER, ALLOCATABLE        :: STA(:)*10

   ! == Input valuables ============
   READ(*,*) refphase
   READ(*,*) time_beg, time_end
   READ(*,*) filename_saclist
   ! == Define valuabes ============
   time_win= time_end- time_beg

   include "phasesinclude.h"

   ! -- Get the SACfile(ARRAY) for the sacfiles within the distance range --
   status_read = 0
   iSAC = 1
   open(11, file = filename_saclist )
   do while ( status_read .eq. 0 )
       read(11,*,iostat = status_read ) sacname, weightv
       call rsac1(sacname, sacamp, sacnpts, sacbeg, sacdt, MAXnpts, ierr)
       call getfhv(t_header,tref,ierr )
       if ( ierr == 0 ) then
           SACfile(iSAC) = sacname
           weighting(iSAC) = weightv
           if ( status_read .eq. 0 ) iSAC = iSAC + 1
           if ( iSAC .gt. MAXsac)  stop 'trace # >  MAXsac '
       end if
   end do
   nSAC = iSAC - 1






   ! -- Allocate arrays --
   ALLOCATE( y(MAXnpts, nSAC), shift_y(MAXnpts, nSAC), STAT=keep )
   IF (keep /=0 ) STOP '<< ALLOCATE ERROR IN y >>'
   ALLOCATE(npts(nSAC), beg(nSAC), dt(nSAC), cutlen(nSAC), cutbeg(nSAC), PLOTnpts(nSAC), STA(nSAC), STAT = keep )
   IF (keep /=0 ) STOP '<< ALLOCATE ERROR IN nSAC >>'
   ALLOCATE(T(10,nSAC),  reftime(nSAC), newbeg(nSAC), STAT = keep)
   IF (keep /=0 ) STOP '<< ALLOCATE ERROR IN nSAC >>'
   ALLOCATE(CC(nSAC), timeshift(nSAC),STAT = keep)
   IF (keep /=0 ) STOP '<< ALLOCATE ERROR IN nSAC >>'



  
   yntaper="n"
   ynnormalize="y" 
   do iSAC = 1, nSAC
       call rsac1(SACfile(iSAC), y(:,iSAC), npts(iSAC), beg(iSAC), dt(iSAC), MAXnpts, ierr)
       call getkhv('KSTNM',STA(iSAC),ierr)
       call getfhv(t_header,reftime(iSAC),ierr)
       time_beg_real = reftime(iSAC)+ time_beg
       call SUB_CUT_SACascii( y(:,iSAC), beg(iSAC), dt(iSAC) , time_beg_real, time_win, &
                                         yntaper, ynnormalize, cuty, cutlen(iSAC), cutbeg(iSAC) ) 
       newbeg(iSAC)= cutbeg(iSAC)-reftime(iSAC)
       shift_y(1: cutlen(iSAC), iSAC) = cuty(1:cutlen(iSAC))*weighting(iSAC) 
   end do




   npts_stack0 = MAXVAL(cutlen)
   ALLOCATE(stack0(npts_stack0))
   do ipts = 1,npts_stack0
       stack0(ipts)=SUM(shift_y(ipts,1:nSAC))
   end do

   open(12, file = "xy.stack0")
   write(12,'(''> '',a)')  "stack0"
   do ipts = 1,npts_stack0
      write(12,*) newbeg(1)+real(ipts-1)*dt(1), stack0(ipts)/MAXVAL(abs(stack0))
   end do


   ALLOCATE( stationary(npts_stack0), shifting(npts_stack0)) 

   stationary(1:npts_stack0)=stack0(1:npts_stack0)
   do iSAC = 1, nSAC
       if ( npts_stack0 .ne. cutlen(iSAC) ) STOP ' SOMETHING WITH LENGTH'
       shifting(1:cutlen(iSAC)) = shift_y(1:cutlen(iSAC), iSAC) 
       call Crosscorrelation(stationary, shifting, npts_stack0, dt(iSAC),CC(iSAC), timeshift(iSAC) )
   end do

   shift_y=0.0
   do iSAC = 1, nSAC
       time_beg_real = reftime(iSAC)+ time_beg - timeshift(iSAC)
       call SUB_CUT_SACascii( y(:,iSAC), beg(iSAC), dt(iSAC) , time_beg_real, time_win, &
                                         yntaper, ynnormalize, cuty, cutlen(iSAC), cutbeg(iSAC) )
       newbeg(iSAC)= cutbeg(iSAC)-reftime(iSAC) +timeshift(iSAC)
       shift_y(1: cutlen(iSAC), iSAC) = cuty(1:cutlen(iSAC))*weighting(iSAC)
   end do

 
   npts_stack1 = MAXVAL(cutlen)
   ALLOCATE(stack1(npts_stack1), stdstack1(npts_stack1))
   stack1=0.0
   stdstack1=0.0
   do ipts = 1,npts_stack1
       stack1(ipts)=SUM(shift_y(ipts,1:nSAC))
       stdstack1(ipts)= sqrt(SUM((shift_y(ipts,1:nSAC)-(stack1(ipts)/real(nSAC)))**2)/real(nSAC))
   end do
  
   tempMAX = MAXVAL(abs(stack1))
   do ipts = 1,npts_stack1
       stack1(ipts)=stack1(ipts)/tempMAX
   end do

   open(13, file = "xy.stack1")
   write(13,'(''> '',a)')  "stack1"
   do ipts = 1,npts_stack1
      write(13,*) newbeg(1)+real(ipts-1)*dt(1), stack1(ipts)
   end do
  
   open(14,file = "xy.stdpolygon")
   do ipts = 1,npts_stack1
      write(14,*) newbeg(1)+real(ipts-1)*dt(1), stack1(ipts)+ stdstack1(ipts)
   end do
   do ipts = npts_stack1,1 , -1
      write(14,*) newbeg(1)+real(ipts-1)*dt(1), stack1(ipts)-stdstack1(ipts)
   end do

   open(15, file = "ccdt")
   do iSAC = 1, nSAC
      write(15,'(2F10.5, 1x, a)') CC(iSAC), timeshift(iSAC), STA(iSAC) 
   end do
   close(11)
   close(12)
   close(13)
   close(14)     
   close(15)

   DEALLOCATE( y, shift_y,  npts, beg, dt, cutlen, cutbeg, PLOTnpts, T,  &
              reftime, newbeg, CC, timeshift, STA)
   DEALLOCATE( stack1, stdstack1, stationary, shifting)

STOP
END


SUBROUTINE Crosscorrelation(stationary, shifting, npts, delta, CC, timeshift) 
IMPLICIT NONE
INTEGER, parameter            :: MAXnpts = 300000
INTEGER                       :: npts, ipts, delay, maxdelay
INTEGER(KIND=4), DIMENSION(1) :: iptr
REAL(KIND=4), ALLOCATABLE     :: correl(:), sumshift(:), denom(:)
REAL(kind=4)                  :: stationary(MAXnpts), shifting(MAXnpts)
REAL(kind=4)                  :: sumstatsq, avg1, avg2, timeshift, delta, CC 
       
       avg1 = SUM(stationary(1:npts))/real(npts)
       avg2 = SUM(shifting(1:npts))/real(npts)

       ! sum over stationay array
       sumstatsq = 0.0
       DO ipts =1,npts
          sumstatsq = sumstatsq + (stationary(ipts) - avg1)**2
       END DO
       ! calculate denominator        

       ALLOCATE(sumshift(-(npts-1):(npts-1)))
       ALLOCATE(denom(-(npts-1):(npts-1)))

       sumshift=0.0
       denom=0.0
       DO delay=-(npts-1),(npts-1)
           DO ipts=1,npts 
               IF ( (ipts-delay) > 0 .and. (ipts-delay) <= npts ) THEN
                   sumshift(delay) = sumshift(delay) + (shifting(ipts-delay) - avg2)**2
               END IF
           END DO
           denom(delay) = sqrt(sumstatsq)*sqrt(sumshift(delay))
       END DO
       ! correlation over delays
       ALLOCATE(correl(-(npts-1):(npts-1)))
       correl = 0.0
       DO delay=-(npts-1),(npts-1)
           DO ipts=1,npts 
               IF ( (ipts-delay) > 0 .and. (ipts-delay) <= npts ) THEN
                   correl(delay) = correl(delay) + (stationary(ipts) - avg1)*(shifting(ipts-delay) - avg2)
               END IF
           END DO
           correl(delay) = correl(delay)/denom(delay)
       END DO
       ! determine max delay
       iptr = MAXLOC(correl)
       ipts=1
       DO delay=-(npts-1),(npts-1)
           IF (ipts == iptr(1)) THEN
               maxdelay = delay
           END IF 
           ipts = ipts+1
       END DO
       CC = MAXVAL(correl)  
       timeshift = float(maxdelay)*delta
       !write(*,*) "Maximum Correlation Coefficient: ", CC
       !write(*,*) "Best Time shift:  ", timeshift, " (sec)"

       DEALLOCATE(sumshift, denom, correl )
return
end










subroutine SUB_CUT_SACascii(yarray, beg, delta, cutt1, twin, yntaper, ynnormalize, cuty ,cutnpts, cutbeg)

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
REAL(kind=4)         :: MAX_cuty

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
       if (  (MAX_cuty - 0.0) <= 0.0000000001 ) then
             cuty=0.0
       else 
             cuty=cuty/MAX_cuty
       end if
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
