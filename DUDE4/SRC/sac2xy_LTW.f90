PROGRAM sac2xy_LTW 
! written by Pei-ying (Patty) Lin, at ASU, Aug 2009

IMPLICIT NONE
INTEGER, parameter            :: MAXnpts = 3000000, MAXsac = 3000, PLOTpoints = 2000 
INTEGER                       :: iSAC, nSAC, sacnpts, skip_points,ipts
INTEGER, ALLOCATABLE          :: npts(:), cutlen(:), PLOTnpts(:) 
INTEGER                       :: status_read,ierr, keep
REAL(kind=8)                  :: time_beg, time_end, time_win, dist_beg, dist_end, amp_scale, amp_multiply
REAL                          :: sacamp(MAXnpts), cuty(MAXnpts),gcarc(MAXsac),y(MAXnpts), intp_y(MAXnpts), intp_time(MAXnpts)
REAL                          :: sacbeg, sacdt,sacgcarc
REAL, ALLOCATABLE             :: beg(:), dt(:), cutbeg(:)
CHARACTER*80                  :: filename_saclist, sacname, SACfile(MAXsac)
CHARACTER                     :: yntaper*1, ynnormalize*1


   ! == Input valuables ============
   READ(*,*) time_beg, time_end
   READ(*,*) dist_beg, dist_end
   READ(*,*) amp_scale
   READ(*,*) filename_saclist

   ! == Define valuabes ============
   amp_multiply = (dist_end-dist_beg)/40.0*amp_scale
   time_win= time_end- time_beg

   
   
   ! -- Get the SACfile(ARRAY) for the sacfiles within the distance range --
   status_read = 0
   iSAC = 1
   open(11, file = filename_saclist )
   do while ( status_read .eq. 0 )
       read(11,*,iostat = status_read ) sacname
       call rsac1(sacname, sacamp, sacnpts, sacbeg, sacdt, MAXnpts, ierr)
       call getfhv('gcarc', sacgcarc, ierr )
       if ( sacgcarc >= dist_beg .and. sacgcarc <= dist_end ) then
           SACfile(iSAC) = sacname
           gcarc(iSAC) = sacgcarc
           if ( status_read .eq. 0 ) iSAC = iSAC + 1
           if ( iSAC .gt. MAXsac)  stop 'trace # >  MAXsac '
       end if
   end do
   nSAC = iSAC - 1

   !print *, "Number of SAC files :", nSAC, "in this distance range(degree)", dist_beg, dist_end
 
   ! -- Allocate arrays --
   ALLOCATE(npts(nSAC), beg(nSAC), dt(nSAC), cutlen(nSAC), cutbeg(nSAC), PLOTnpts(nSAC), STAT = keep )
   IF (keep /=0 ) STOP '<< ALLOCATE ERROR IN nSAC >>'
   




   open(12, file = "xy.seismograms")
  

   yntaper="n"
   ynnormalize="y" 
   do iSAC = 1, nSAC
       print *,nSAC
       y= 0.0
       call rsac1(SACfile(iSAC), y, npts(iSAC), beg(iSAC), dt(iSAC), MAXnpts, ierr)
       !write(12,'(''> '',2(f8.3))')  gcarc(iSAC), dt(iSAC)
       !do ipts = 1,npts(iSAC)
       !   write(12,*) beg(iSAC)+real(ipts-1)*dt(iSAC), y(ipts)*amp_multiply+gcarc(iSAC)
       !end do   
       ! --------------------------------
       call SUB_CUT_SACascii( y, beg(iSAC), dt(iSAC) , time_beg, time_win, &
                                         yntaper, ynnormalize, cuty, cutlen(iSAC), cutbeg(iSAC) ) 
          skip_points = anint((cutlen(iSAC)*dt(iSAC) / real(PLOTpoints) ) / dt(iSAC))  
          if ( skip_points <= 2 ) then 
               PLOTnpts(iSAC) = cutlen(iSAC)
               skip_points = 1
          else 
               PLOTnpts(iSAC) = PLOTpoints 
          end if
       write(12,'(''> '',2(f8.3))')  gcarc(iSAC), dt(iSAC)  
       intp_y = 0.0
       intp_time = 0.0
       do ipts = 1, PLOTnpts(iSAC)
          intp_y(ipts)=cuty(1+(ipts-1)*skip_points)
          intp_time(ipts)=cutbeg(iSAC)+real((ipts-1)*skip_points)*dt(iSAC)
          if ( intp_time(ipts) .ge. beg(iSAC) .and. &
               intp_time(ipts) .lt. beg(iSAC)+real(npts(iSAC))*dt(iSAC) ) then
               write(12,*) intp_time(ipts), intp_y(ipts)*amp_multiply+gcarc(iSAC)
          end if
       end do
   end do




STOP
END














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
INTEGER, PARAMETER   :: MAXnpts = 1500000, k=8

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
