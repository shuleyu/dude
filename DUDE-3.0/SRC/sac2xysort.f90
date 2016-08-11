PROGRAM sac2xysort 
use m_mrgrnk

IMPLICIT NONE
INTEGER, parameter            :: MAXnpts = 200000, MAXsac = 1500, PLOTpoints = 3001
INTEGER                       :: iSAC, nSAC, sacnpts, skip_points,ipts, iorder
INTEGER, ALLOCATABLE          :: npts(:), cutlen(:), PLOTnpts(:), iordergcarc(:) 
INTEGER                       :: status_read,ierr, keep
REAL(kind=8)                  :: time_beg, time_end, time_win, dist_beg, dist_end, amp_scale, amp_multiply
REAL(kind=8)                  :: reduce, tempendtime
REAL                          :: sacamp(MAXnpts), cuty(MAXnpts),gcarc(MAXsac),  sacbeg, sacdt,sacgcarc, gcarcB,dist_gap
REAL, ALLOCATABLE             :: y(:,:), beg(:), dt(:), cutbeg(:), intp_y(:,:), intp_time(:,:), ordergcarc(:), reftime(:)
REAL(kind=8), ALLOCATABLE     :: realtime_start(:)
CHARACTER*80                  :: filename_saclist, sacname, SACfile(MAXsac)
CHARACTER*80, ALLOCATABLE     :: orderSACfile(:)
CHARACTER                     :: yntaper*1, ynnormalize*1


   ! == Input valuables ============
   READ(*,*) time_beg, time_end
   READ(*,*) dist_beg, dist_end
   READ(*,*) amp_scale
   READ(*,*) dist_gap
   READ(*,*) filename_saclist
   ! == Define valuabes ============
   reduce = 0.0
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
   print *, nSAC

   ALLOCATE( iordergcarc(nSAC), orderSACfile(nSAC), ordergcarc(nSAC), STAT=keep )
   IF (keep /=0 ) STOP '<< ALLOCATE ERROR IN ordeSACfile >>'

   call  mrgrnk(gcarc(1:nSAC),iordergcarc(1:nSAC))
   do iSAC = 1, nSAC
      iorder = iordergcarc(iSAC)
      orderSACfile(iSAC) = SACfile(iorder)
   enddo


   ! -- Allocate arrays --
   ALLOCATE( y(MAXnpts, nSAC), intp_y(MAXnpts, nSAC), intp_time(MAXnpts, nSAC),STAT=keep )
   IF (keep /=0 ) STOP '<< ALLOCATE ERROR IN y >>'
   ALLOCATE(npts(nSAC), beg(nSAC), dt(nSAC), cutlen(nSAC), cutbeg(nSAC), PLOTnpts(nSAC), STAT = keep )
   IF (keep /=0 ) STOP '<< ALLOCATE ERROR IN nSAC 1 >>'
   ALLOCATE(realtime_start(nSAC),  reftime(nSAC), STAT = keep)
   IF (keep /=0 ) STOP '<< ALLOCATE ERROR IN nSAC 2>>'




   
  
   yntaper="n"
   ynnormalize="y" 
   !ynnormalize="n" 



   do iSAC = 1, nSAC
       call rsac1(orderSACfile(iSAC), y(:,iSAC), npts(iSAC), beg(iSAC), dt(iSAC), MAXnpts, ierr)
       call getfhv('gcarc', ordergcarc(iSAC),ierr)
       realtime_start(iSAC) = time_beg+reduce*ordergcarc(iSAC)
       call SUB_CUT_SACascii( y(:,iSAC), beg(iSAC), dt(iSAC), realtime_start(iSAC), time_win, &
                                         yntaper, ynnormalize, cuty, cutlen(iSAC), cutbeg(iSAC) ) 

       skip_points = anint((cutlen(iSAC)*dt(iSAC) / real(PLOTpoints) ) / dt(iSAC))  
       tempendtime = cutbeg(iSAC)+real((PLOTpoints-1)*skip_points)*dt(iSAC)-reduce*ordergcarc(iSAC) 
       PLOTnpts(iSAC) = PLOTpoints
       if ( tempendtime < time_end ) then
           PLOTnpts(iSAC) = PLOTpoints + anint((time_end-tempendtime)/(real(skip_points)*dt(iSAC)))
       else
           PLOTnpts(iSAC) = PLOTpoints
       end if


       if ( cutlen(iSAC) <= PLOTpoints )  PLOTnpts(iSAC) = cutlen(iSAC)
  

      do ipts = 1, PLOTnpts(iSAC)
          intp_y(ipts,iSAC)=cuty(1+(ipts-1)*skip_points)
          intp_time(ipts,iSAC)=cutbeg(iSAC)+real((ipts-1)*skip_points)*dt(iSAC)-reduce*ordergcarc(iSAC)
       end do
   end do


   open(12, file = "xy.seismograms")
   write(12,'(''> '',(f12.6))')  ordergcarc(1) 
   do ipts=1,PLOTnpts(1)
       if ( intp_time(ipts,1) .ge. beg(1) .and. &
                intp_time(ipts,1) .lt. beg(1)+real(npts(1)*dt(1) ) ) then
           write(12,*) intp_time(ipts,1), ordergcarc(1)-intp_y(ipts,1)*amp_multiply, ipts
       end if
   end do
   gcarcB = ordergcarc(1)
   do iSAC = 2, nSAC
       if (  (ordergcarc(iSAC) - gcarcB ) >= dist_gap ) then 
           write(12,'(''> '',(f12.6))')  ordergcarc(iSAC)
           do ipts=1,PLOTnpts(iSAC)
               if ( intp_time(ipts,iSAC) .ge. beg(iSAC) .and. &
                   intp_time(ipts,iSAC) .lt. beg(iSAC)+real(npts(iSAC))*dt(iSAC) ) then
                   write(12,*) intp_time(ipts,iSAC), ordergcarc(iSAC)-intp_y(ipts,iSAC)*amp_multiply, ipts
               end if
           end do
           gcarcB = ordergcarc(iSAC)  
       end if
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
INTEGER, PARAMETER   :: MAXnpts = 200000, k=8

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
   cutbeg = 0.0
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

