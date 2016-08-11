PROGRAM sac2xyTRIPstack 
use m_mrgrnk

IMPLICIT NONE
INTEGER, parameter            :: MAXnpts = 200000, MAXsac = 5000, PLOTpoints = 3001
INTEGER                       :: iSAC, nSAC, sacnpts, skip_points,ipts, iorder, npts_twin_around_reference, idstack 
INTEGER                       :: pts_position_range_around_reference1, pts_position_range_around_reference2
INTEGER, ALLOCATABLE          :: npts(:), cutlen(:), PLOTnpts(:), iordergcarc(:), ntrace_stack(:) 
INTEGER                       :: status_read,ierr, keep, nshift_dstack, ndstack
REAL(kind=8)                  :: time_beg, time_end, time_win, dist_beg, dist_end, amp_scale, amp_multiply, mean_SNratio
REAL(kind=8)                  :: reduce,tempMAX, tempendtime, twin_around_reference
REAL(kind=8)                  :: timebeforeP, timewin_noise, timewin_signal,distbin_win, dist_shift, timeSTART
REAL(kind=8)                  :: dwwin_stack_beg, dwwin_stack_end, dwwin_stacK_mid, weight_val
REAL                          :: reftime_flag
REAL                          :: sacamp(MAXnpts), cuty(MAXnpts),gcarc(MAXsac), weighting(MAXsac), sacbeg, sacdt,sacgcarc, gcarcB
REAL, ALLOCATABLE             :: y(:,:), beg(:), dt(:), cutbeg(:), intp_y(:,:), intp_time(:,:), ordergcarc(:), MAXamp(:), reftime(:)
REAL, ALLOCATABLE             :: envarray(:,:), stack_amp_normalizeMAXtrace(:,:)
REAL(kind=8), ALLOCATABLE     :: realtime_start(:), noiseP(:), signal(:), SNratio(:), orderweighting(:)
CHARACTER*80                  :: filename_saclist, sacname, SACfile(MAXsac)
CHARACTER*80, ALLOCATABLE     :: orderSACfile(:)
CHARACTER                     :: yntaper*1, ynnormalize*1, WAVE*1


   ! == Input valuables ============
   READ(*,*) time_beg, time_end
   READ(*,*) dist_beg, dist_end
   READ(*,*) amp_scale
   READ(*,*) reduce
   READ(*,*) filename_saclist
   READ(*,*) WAVE
   READ(*,*) distbin_win, dist_shift

   ! == Define valuabes ============
   amp_multiply = (dist_end-dist_beg)/40.0*amp_scale
   time_win= time_end- time_beg

   nshift_dstack = anint(distbin_win/2.0/dist_shift)
   ndstack = anint((dist_end-dist_beg)/dist_shift)
   ALLOCATE(ntrace_stack(ndstack), stack_amp_normalizeMAXtrace(MAXnpts,ndstack))


   timebeforeP    = 180.0 !in sec
   timewin_noise  = 60.0
   timewin_signal = 20.0
   twin_around_reference = 30 !in sec

 
   
   ! -- Get the SACfile(ARRAY) for the sacfiles within the distance range --
   status_read = 0
   iSAC = 1
   
   open(11, file = filename_saclist )
   do while ( status_read .eq. 0 )
       read(11,*,iostat = status_read ) sacname, weight_val
       call rsac1(sacname, sacamp, sacnpts, sacbeg, sacdt, MAXnpts, ierr)
       call getfhv('gcarc', sacgcarc, ierr )
       if ( WAVE .eq. "P") call getfhv('T0', reftime_flag, ierr)
       if ( WAVE .eq. "S") call getfhv('T2', reftime_flag, ierr)
   
       if ( sacgcarc >= dist_beg .and. sacgcarc <= dist_end .and. reftime_flag >= 0.0 ) then
           
           SACfile(iSAC) = sacname
           gcarc(iSAC) = sacgcarc
           weighting(iSAC) = weight_val
           if ( status_read .eq. 0 ) iSAC = iSAC + 1
           if ( iSAC .gt. MAXsac)  stop 'trace # >  MAXsac '
       end if
   end do
   nSAC = iSAC - 1

   ALLOCATE( iordergcarc(nSAC), orderSACfile(nSAC), ordergcarc(nSAC),orderweighting(nSAC), STAT=keep )
   IF (keep /=0 ) STOP '<< ALLOCATE ERROR IN ordeSACfile >>'

   call  mrgrnk(gcarc(1:nSAC),iordergcarc(1:nSAC))
   do iSAC = 1, nSAC
      iorder = iordergcarc(iSAC)
      orderSACfile(iSAC) = SACfile(iorder)
      orderweighting(iSAC) = weighting(iorder)
   enddo


   print *, "Number of SAC files :", nSAC, "in this distance range(degree)", dist_beg, dist_end

   ! -- Allocate arrays --
   ALLOCATE( y(MAXnpts, nSAC), intp_y(MAXnpts, nSAC), intp_time(MAXnpts, nSAC),STAT=keep )
   IF (keep /=0 ) STOP '<< ALLOCATE ERROR IN y >>'
   ALLOCATE(npts(nSAC), beg(nSAC), dt(nSAC), cutlen(nSAC), cutbeg(nSAC), PLOTnpts(nSAC), STAT = keep )
   IF (keep /=0 ) STOP '<< ALLOCATE ERROR IN nSAC >>'
   ALLOCATE(realtime_start(nSAC), MAXamp(nSAC), reftime(nSAC), STAT = keep)
   IF (keep /=0 ) STOP '<< ALLOCATE ERROR IN nSAC >>'

   ALLOCATE( envarray(MAXnpts,nSAC), noiseP(nSAC), signal(nSAC), SNratio(nSAC), STAT = keep)
   IF (keep /=0 ) STOP '<< ALLOCATE ERROR IN nSAC >>'
 



   
  
   yntaper="n"
   ynnormalize="y" 
   !ynnormalize="n" 


   open(14, file = "xy.seismograms.win")


   do iSAC = 1, nSAC
       call rsac1(orderSACfile(iSAC), y(:,iSAC), npts(iSAC), beg(iSAC), dt(iSAC), MAXnpts, ierr)
       call getfhv('gcarc', ordergcarc(iSAC),ierr)
       if ( WAVE .eq. "P") call getfhv('T0', reftime(iSAC), ierr)
       if ( WAVE .eq. "S") call getfhv('T2', reftime(iSAC), ierr)
       ! -- normal
       realtime_start(iSAC) = time_beg+reduce*ordergcarc(iSAC)



       timeSTART = reftime(iSAC) -  timebeforeP
       envarray(:, iSAC) = 0.0
       call SUB_CUT_SACascii( y(:,iSAC), beg(iSAC), dt(iSAC) , timeSTART, timewin_noise, &
                                                      "n", "n", cuty, cutlen(iSAC), cutbeg(iSAC) )
       call envelope( cutlen(iSAC), cuty, envarray(:,iSAC))
       noiseP(iSAC) = SUM(envarray(1:cutlen(iSAC),iSAC))

        
       timeSTART = reftime(iSAC) -  (timewin_signal / 2.0 )
       envarray(:, iSAC) = 0.0
       call SUB_CUT_SACascii( y(:,iSAC), beg(iSAC), dt(iSAC) , timeSTART, timewin_signal, &
                                                      "n", "n", cuty, cutlen(iSAC), cutbeg(iSAC) )
       call envelope( cutlen(iSAC), cuty, envarray(:,iSAC))
       signal(iSAC) = SUM(envarray(1:cutlen(iSAC),iSAC))
 
  
       if (  noiseP(iSAC) .ne. 0.0 ) then
           SNratio(iSAC) =  signal(iSAC)*3.0 / noiseP(iSAC)
       else 
           SNratio(iSAC) = 0.0
       end if

       call SUB_CUT_SACascii( y(:,iSAC), beg(iSAC), dt(iSAC), realtime_start(iSAC), time_win, &
                                         yntaper, ynnormalize, cuty, cutlen(iSAC), cutbeg(iSAC) ) 
       ! --shorter along reftime
       !time_win =75 
       !realtime_start(iSAC) = reftime(iSAC) - 25
       !call SUB_CUT_SACascii( y(:,iSAC), beg(iSAC), dt(iSAC), realtime_start(iSAC), time_win, &
       !                                  yntaper, ynnormalize, cuty, cutlen(iSAC), cutbeg(iSAC) ) 


       npts_twin_around_reference = anint(twin_around_reference / dt(iSAC)) 
       pts_position_range_around_reference1 = anint(abs(reftime(iSAC)-cutbeg(iSAC) )/ dt(iSAC)) - (npts_twin_around_reference / 2)
       pts_position_range_around_reference2 = pts_position_range_around_reference1 + npts_twin_around_reference
       MAXamp(iSAC) = maxval(abs(cuty(pts_position_range_around_reference1:pts_position_range_around_reference2)))
       write(14,*)  ordergcarc(iSAC), cutbeg(iSAC) + pts_position_range_around_reference1*dt(iSAC)-reduce*ordergcarc(iSAC)
       write(14,*)  ordergcarc(iSAC), cutbeg(iSAC) + pts_position_range_around_reference2*dt(iSAC)-reduce*ordergcarc(iSAC)
       write(14,'(''> '')')
       skip_points = anint((cutlen(iSAC)*dt(iSAC) / real(PLOTpoints) ) / dt(iSAC))  
       tempendtime = cutbeg(iSAC)+real((PLOTpoints-1)*skip_points)*dt(iSAC)-reduce*ordergcarc(iSAC) 
       PLOTnpts(iSAC) = PLOTpoints
       if ( tempendtime < time_end ) then
           PLOTnpts(iSAC) = PLOTpoints + anint((time_end-tempendtime)/(real(skip_points)*dt(iSAC)))
       else
           PLOTnpts(iSAC) = PLOTpoints
       end if
       if ( cutlen(iSAC) <= PLOTpoints )  then
             PLOTnpts(iSAC) = cutlen(iSAC)
             skip_points = 1
       end if
 
       do ipts = 1, PLOTnpts(iSAC)
          intp_y(ipts,iSAC)=cuty(1+(ipts-1)*skip_points)*orderweighting(iSAC)
          intp_time(ipts,iSAC)=cutbeg(iSAC)+real((ipts-1)*skip_points)*dt(iSAC)-reduce*ordergcarc(iSAC)
       end do
   end do
   
   tempMAX = MAXval(intp_y)
   mean_SNratio=sum(SNratio)/ real(nSAC)
   ! =================================================================================
   ! -- output all sac2xyz --- 
   !open(13, file = "xy.seismograms.qeqeqe")
   !do iSAC = 1, nSAC
   !    write(13,'(''> '',3(f12.6))')  ordergcarc(iSAC), noiseP(iSAC), dt(iSAC)
   !    if ( noiseP(iSAC) .ne. 0.0  ) then
   !        do ipts=1,PLOTnpts(iSAC)
   !            !write(13,*) intp_time(ipts,iSAC), ordergcarc(iSAC)-intp_y(ipts,iSAC)/MAXamp(iSAC)*SNratio(iSAC)/mean_SNratio &
   !            write(13,*) intp_time(ipts,iSAC), ordergcarc(iSAC)-intp_y(ipts,iSAC)/MAXamp(iSAC)*SNratio(iSAC)/mean_SNratio &
   !                        *amp_multiply, ipts
   !        end do
   !    end if
   !end do
   ! ==================================================================================
   ntrace_stack = 0
   stack_amp_normalizeMAXtrace=0
   do iSAC = 1, nSAC
       do idstack = 1, ndstack
           dwwin_stack_beg = dist_beg+(idstack-nshift_dstack)*dist_shift
           dwwin_stack_end = dist_beg+(idstack-nshift_dstack)*dist_shift+distbin_win
           if ( ordergcarc(iSAC) >= dwwin_stack_beg .and. ordergcarc(iSAC) < dwwin_stack_end .and. MAXamp(iSAC) .ne. 0.0) then
               ntrace_stack(idstack)=ntrace_stack(idstack)+1
               do ipts=1,PLOTnpts(iSAC)
                   stack_amp_normalizeMAXtrace(ipts,idstack)= stack_amp_normalizeMAXtrace(ipts,idstack) &
                             + (intp_y(ipts,iSAC)/MAXamp(iSAC))
                             !+ (intp_y(ipts,iSAC)/MAXamp(iSAC)*SNratio(iSAC)/mean_SNratio)
               end do
           end if
       end do
   end do



   open(12, file = "xy.seismograms")
   do idstack = 1, ndstack
       dwwin_stack_beg = dist_beg+(idstack-nshift_dstack)*dist_shift
       dwwin_stack_end = dist_beg+(idstack-nshift_dstack)*dist_shift+distbin_win
       dwwin_stacK_mid = (dwwin_stack_beg+dwwin_stack_end)/2.0
       write(12,'(''> '',f8.3, I10)')  dwwin_stacK_mid, ntrace_stack(idstack)
       do ipts = 1, PLOTnpts(1)
            if ( ntrace_stack(idstack) .ne. 0 ) then
               stack_amp_normalizeMAXtrace(ipts,idstack)= &
                      stack_amp_normalizeMAXtrace(ipts,idstack)/ntrace_stack(idstack)
               write(12,*) intp_time(ipts,1), dwwin_stacK_mid- stack_amp_normalizeMAXtrace(ipts,idstack)*amp_multiply
            end if
       end do
   end do

   close(12)
   close(14) 


   ! ==================================================================================
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
REAL(kind=4)         :: beg, delta,cutbeg, xdummy
INTEGER              :: cutnpts, istart, tmpnpts
CHARACTER*1          :: yntaper, ynnormalize
!     Define variables used in the filtering routine
REAL(kind=k)         :: cutt1, twin
REAL(kind=k)         :: MAX_cuty

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
return
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

