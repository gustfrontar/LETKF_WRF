PROGRAM dec_airsret
!  USE common
!  USE common_obs_wrf

  IMPLICIT NONE
  INTEGER,PARAMETER :: r_size=kind(0.0d0)
  INTEGER,PARAMETER :: r_dble=kind(0.0d0)
  INTEGER,PARAMETER :: r_sngl=kind(0.0e0)

  REAL(r_size),PARAMETER :: pi=3.1415926535d0
  REAL(r_size),PARAMETER :: gg=9.81d0
  REAL(r_size),PARAMETER :: rd=287.0d0
  REAL(r_size),PARAMETER :: cp=1005.7d0
  REAL(r_size),PARAMETER :: re=6371.3d3
  REAL(r_size),PARAMETER :: r_omega=7.292d-5
  REAL(r_size),PARAMETER :: t0c=273.15d0
  REAL(r_size),PARAMETER :: undef=9.99d33

  INTEGER,PARAMETER :: nid_obs=7
  INTEGER,PARAMETER :: id_u_obs=2819
  INTEGER,PARAMETER :: id_v_obs=2820
  INTEGER,PARAMETER :: id_t_obs=3073
  INTEGER,PARAMETER :: id_q_obs=3330
  INTEGER,PARAMETER :: id_rh_obs=3331
  INTEGER,PARAMETER :: id_tv_obs=3079
  INTEGER,PARAMETER :: id_co_obs=5002
  INTEGER,PARAMETER :: id_totco_obs=5001
!
! surface observations codes > 9999
!
  INTEGER,PARAMETER :: id_ps_obs=14593
  INTEGER,PARAMETER :: id_rain_obs=19999
  INTEGER,PARAMETER :: id_tclon_obs=99991
  INTEGER,PARAMETER :: id_tclat_obs=99992
  INTEGER,PARAMETER :: id_tcmip_obs=99993


  LOGICAL,PARAMETER :: verbose = .FALSE.
  INTEGER,PARAMETER :: airstype = 21 ! observation type record for AIRS
  REAL(r_size),PARAMETER :: lon1 =  270.0d0 ! minimum longitude
  REAL(r_size),PARAMETER :: lon2 =  340.0d0 ! maximum longitude
  REAL(r_size),PARAMETER :: lat1 =  -70.0d0 ! minimum latitude
  REAL(r_size),PARAMETER :: lat2 =   20.0d0 ! maximum latitude

  ! use full data in the following domain.
  ! (use thinned data in other domain (iskip)).
  REAL(r_size),PARAMETER :: loni1 =  114.40d0 ! minimum longitude (inner)
  REAL(r_size),PARAMETER :: loni2 =  134.06d0 ! maximum longitude (inner)
  REAL(r_size),PARAMETER :: lati1 =  11.63d0 ! minimum latitude (inner)
  REAL(r_size),PARAMETER :: lati2 =  29.91d0 ! maximum latitude (inner)

  REAL(r_size),PARAMETER :: coef_error = 1.0d0  
  INTEGER,PARAMETER :: iskip = 3
  INTEGER,PARAMETER :: nunit=70
  INTEGER,PARAMETER :: nx=30
  INTEGER,PARAMETER :: ny=45
  INTEGER,PARAMETER :: nzt=28
  INTEGER,PARAMETER :: nzco=28
  INTEGER,PARAMETER :: nzq=14
  INTEGER :: statn
  INTEGER :: fid
  INTEGER :: nswath
  INTEGER :: nchar
  INTEGER :: swid
  INTEGER :: swopen,swinqswath,swattach,swrdattr,swrdfld,swdetach,swclose
  CHARACTER(256) :: swathname
  CHARACTER(100) :: filename
  REAL(r_dble) :: rlon(nx,ny)
  REAL(r_dble) :: rlat(nx,ny)
  REAL(r_dble) :: time(nx,ny),time1,time2
  REAL(r_sngl) :: levt(nzt)
  REAL(r_sngl) :: levq0(nzq+1)
  REAL(r_sngl) :: levq(nzq)
  REAL(r_sngl) :: t(nzt,nx,ny)
  REAL(r_sngl) :: te(nzt,nx,ny)
  INTEGER      :: tqc(nzt,nx,ny)
  REAL(r_sngl) :: q(nzq,nx,ny)
  REAL(r_sngl) :: qe(nzq,nx,ny)
  INTEGER      :: qqc(nzq,nx,ny)
!  REAL(r_sngl) :: co(nzq,nx,ny)
!  REAL(r_sngl) :: coe(nzq,nx,ny)
!  INTEGER      :: coqc(nzq,nx,ny)
  REAL(r_sngl) :: psurf(nx,ny)
  REAL(r_sngl) :: pbest(nx,ny)
  REAL(r_sngl) :: pgood(nx,ny)
  INTEGER(2) :: qq(nx,ny)
  INTEGER :: i,j,k
  REAL(r_sngl) :: wk(7)
  INTEGER :: iy,im,id,ih,imin
  INTEGER :: iy1,im1,id1,ih1,imin1
  INTEGER :: iy2,im2,id2,ih2,imin2
  REAL(r_sngl) :: sec4
  REAL(r_size) :: sec
  LOGICAL :: ex
  CHARACTER(14) :: outfile='yyyymmddhh.dat'
!                           123456789012345
  INTEGER      :: NQ(nzq) , NT(nzt) !, NCO(nzco)
  REAL(r_size) :: tile_lat_mean , tile_lon_mean
!=======================================================================
! READING HDF
!=======================================================================
  NQ=0
  NT=0
!  NCO=0
  tile_lat_mean=0.0d0
  tile_lon_mean=0.0d0
  !
  ! open
  !
  CALL GETARG( 1, filename )
  !READ(5,'(A)') filename
  PRINT *,filename
  !PRINT *,filename
  fid = swopen(filename,1)
  IF(fid == -1) THEN
    PRINT *,'IO ERROR: opening file ',filename
    STOP
  END IF
  nswath = swinqswath(filename,swathname,nchar)
  IF(nswath /= 1) THEN
    PRINT *,'FILE ERROR: bad nswath ',nswath
    STOP
  END IF
  IF(swathname /= 'L2_Standard_atmospheric&surface_product') THEN
    PRINT *,'FILE ERROR: bad swath name ',swathname
    STOP
  END IF
  swid = swattach(fid, swathname)
  IF(swid == -1) THEN
    PRINT *,'FILE ERROR: failed to attach to swath ',swathname
    STOP
  END IF
  !
  ! read
  !
!  statn = swrdattr(swid,'start_year',iy)
!  statn = swrdattr(swid,'start_month',im)
!  statn = swrdattr(swid,'start_day',id)
!  statn = swrdattr(swid,'start_hour',ih)
!  statn = swrdattr(swid,'start_minute',imin)
!  statn = swrdattr(swid,'start_sec',sec4)
!  sec = sec4
  statn = swrdattr(swid,'start_Time',time1)
  statn = swrdattr(swid,'end_Time',time2)
  statn = swrdfld(swid,'Longitude',(/0,0/),(/1,1/),(/nx,ny/),rlon)
  statn = swrdfld(swid,'Latitude',(/0,0/),(/1,1/),(/nx,ny/),rlat)
  statn = swrdfld(swid,'Time',(/0,0/),(/1,1/),(/nx,ny/),time)
  statn = swrdfld(swid,'pressStd',0,1,nzt,levt)
  statn = swrdfld(swid,'pressH2O',0,1,nzq+1,levq0)
  DO k=1,nzq
    levq(k) = exp(0.5d0 * (log(levq0(k)) + log(levq0(k+1))))
!    levq(k) = 0.5d0 * ((levq0(k)) + (levq0(k+1)))
  END DO
  statn = swrdfld(swid,'TAirStd',(/0,0,0/),(/1,1,1/),(/nzt,nx,ny/),t)
  statn = swrdfld(swid,'TAirStdErr',(/0,0,0/),(/1,1,1/),(/nzt,nx,ny/),te)
  statn = swrdfld(swid,'TAirStd_QC',(/0,0,0/),(/1,1,1/),(/nzt,nx,ny/),tqc)
  statn = swrdfld(swid,'PSurfStd',(/0,0/),(/1,1/),(/nx,ny/),psurf)
  statn = swrdfld(swid,'PBest',(/0,0/),(/1,1/),(/nx,ny/),pbest)
  statn = swrdfld(swid,'PGood',(/0,0/),(/1,1/),(/nx,ny/),pgood)
  statn = swrdfld(swid,'H2OMMRStd',(/0,0,0/),(/1,1,1/),(/nzq,nx,ny/),q)
  q = q*0.001d0 ! g/kg -> kg/kg
  statn = swrdfld(swid,'H2OMMRStdErr',(/0,0,0/),(/1,1,1/),(/nzq,nx,ny/),qe)
  qe = qe*0.001d0 ! g/kg -> kg/kg
  !statn = swrdfld(swid,'Qual_H2O',(/0,0/),(/1,1/),(/nx,ny/),qq)
  statn = swrdfld(swid,'H20MMRStd_QC',(/0,0,0/),(/1,1,1/),(/nzt,nx,ny/),qqc)
  ! read CO related variables.
!  statn = swrdfld(swid,'COVMRLevStd',(/0,0,0/),(/1,1,1/),(/nzt,nx,ny/),co)
!  statn = swrdfld(swid,'COVMRLevStdErr',(/0,0,0/),(/1,1,1/),(/nzt,nx,ny/),coe)
!  statn = swrdfld(swid,'COVMRLevStd_QC',(/0,0,0/),(/1,1,1/),(/nzt,nx,ny/),coqc)
  !
  ! close
  !
  statn = swdetach(swid)
  statn = swclose(fid)
!=======================================================================
! QC -> OUTPUT LETKF OBS FORMAT
!=======================================================================
  wk(7) = REAL(airstype) ! TYPE CODE for AIRS retrieval
  CALL com_tai2utc(time1,iy1,im1,id1,ih1,imin1,sec)
  IF(imin1 > 30) CALL com_tai2utc(time1+1800.d0,iy1,im1,id1,ih1,imin1,sec)
  WRITE(outfile(1:10),'(I4.4,3I2.2)') iy1,im1,id1,ih1
  OPEN(nunit+ih1,FILE=outfile,FORM='unformatted',ACCESS='sequential')
  CALL com_tai2utc(time2,iy2,im2,id2,ih2,imin2,sec)
  IF(imin2 > 30) CALL com_tai2utc(time2+1800.d0,iy2,im2,id2,ih2,imin2,sec)
  IF(ih2 /= ih1) THEN
    WRITE(outfile(1:10),'(I4.4,3I2.2)') iy2,im2,id2,ih2
    OPEN(nunit+ih2,FILE=outfile,FORM='unformatted',ACCESS='sequential')
  END IF
  DO j=1,ny
    DO i=1,nx
      tile_lat_mean=tile_lat_mean + rlat(i,j)
      tile_lon_mean=tile_lon_mean + rlon(i,j)
      IF(rlon(i,j) < 0) rlon(i,j) = rlon(i,j) + 360.0d0
      !WRITE(*,*)i,j,rlon(i,j),rlat(i,j)
      IF(rlon(i,j) < lon1) CYCLE
      IF(rlon(i,j) > lon2) CYCLE
      IF(rlat(i,j) < lat1) CYCLE
      IF(rlat(i,j) > lat2) CYCLE
     
      !IF(rlon(i,j) < loni1 .or. rlon(i,j) > loni2 .or. rlat(i,j) < lati1 .or. rlat(i,j) > lati2) THEN
        IF(mod(i,iskip) /= 1) CYCLE
        IF(mod(j,iskip) /= 1) CYCLE
      !END IF  
      
            
      CALL com_tai2utc(time(i,j),iy,im,id,ih,imin,sec)
      IF(imin > 30) CALL com_tai2utc(time(i,j)+1800.d0,iy,im,id,ih,imin,sec)
      wk(2) = rlon(i,j)
      wk(3) = rlat(i,j)

      !
      ! T
      !
      wk(1) = id_t_obs
      DO k=1,nzt
        !IF(levt(k) > psurf(i,j)) CYCLE !below surface
        IF( tqc(k,i,j) /= 0 ) CYCLE !QC
        wk(4) = levt(k)
        wk(5) = t(k,i,j)
        wk(6) = te(k,i,j) * sqrt(coef_error)
        WRITE(nunit+ih) wk
        IF(verbose) WRITE(6,'(F5.0,7F8.2)') wk(1:6),pbest(i,j),pgood(i,j)
        NT(k)=NT(k)+1
      END DO
      !
      ! Q
      !
      wk(1) = id_q_obs
      DO k=1,nzq
        !IF(levq0(k) > psurf(i,j)) CYCLE !below surface
        IF(qqc(k,i,j) /= 0 ) CYCLE !QC
        wk(4) = levq(k)
        wk(5) = q(k,i,j)
        wk(6) = qe(k,i,j) * sqrt(coef_error)
        WRITE(nunit+ih) wk
        IF(verbose) WRITE(6,'(F5.0,3F8.2,2ES11.2,2F8.2,I2)') wk(1:6),levq0(k),pbest(i,j),qqc(k,i,j)
        NQ(k)=NQ(k)+1
      END DO
      !
      !  CO
      !
      !wk(1) = id_co_obs
      !DO k=1,nzq
      !  IF(levt(k) > psurf(i,j)) CYCLE !below surface
      !  IF(coqc(k,i,j) /= 0 ) CYCLE !QC
      !  wk(4) = levt(k)
      !  wk(5) = co(k,i,j)
      !  wk(6) = coe(k,i,j) * sqrt(coef_error)
      !  WRITE(nunit+ih) wk
      !  IF(verbose) WRITE(6,'(F5.0,3F8.2,2ES11.2,2F8.2,I2)')wk(1:6),levq0(k),pbest(i,j),qqc(k,i,j)
      !  NCO(k)=NCO(k)+1
      !END DO
    END DO
  END DO

  tile_lat_mean=tile_lat_mean/(nx*ny)
  tile_lon_mean=tile_lon_mean/(nx*ny)

  CLOSE(nunit+ih1)
  IF(ih2 /= ih1) CLOSE(nunit+ih2)

  WRITE(*,*)"=================== SUMARY =========================="
  WRITE(*,*)"  P    ,  NT  " !, NCO "
  DO k=1,nzt
     WRITE(*,*)levt(k),"  ",NT(k) !,"  ",NCO(k)
  ENDDO
  WRITE(*,*)"====================================================="

  WRITE(*,*)"=================== SUMARY =========================="
  WRITE(*,*)"  P    ,  NQ "
  DO k=1,nzq
     WRITE(*,*)levt(k),"  ",NQ(k)
  ENDDO
  WRITE(*,*)"====================================================="

  WRITE(*,*)" LAT MEAN ",tile_lat_mean," LON MEAN ",tile_lon_mean

  STOP
END PROGRAM dec_airsret

!-----------------------------------------------------------------------
! UTC to TAI93
!-----------------------------------------------------------------------
SUBROUTINE com_utc2tai(iy,im,id,ih,imin,sec,tai93)
  IMPLICIT NONE
  INTEGER,INTENT(IN) :: iy,im,id,ih,imin
  INTEGER,PARAMETER :: r_size=kind(0.0d0)
  INTEGER,PARAMETER :: r_dble=kind(0.0d0)
  INTEGER,PARAMETER :: r_sngl=kind(0.0e0)
  REAL(r_size),INTENT(IN) :: sec
  REAL(r_size),INTENT(OUT) :: tai93
  REAL(r_size),PARAMETER :: mins = 60.0d0
  REAL(r_size),PARAMETER :: hour = 60.0d0*mins
  REAL(r_size),PARAMETER :: day = 24.0d0*hour
  REAL(r_size),PARAMETER :: year = 365.0d0*day
  INTEGER,PARAMETER :: mdays(12) = (/31,28,31,30,31,30,31,31,30,31,30,31/)
  INTEGER :: days,i

  tai93 = REAL(iy-1993,r_size)*year + FLOOR(REAL(iy-1993)/4.0,r_size)*day
  days = id -1
  DO i=1,12
    IF(im > i) days = days + mdays(i)
  END DO
  IF(MOD(iy,4) == 0 .AND. im > 2) days = days + 1 !leap year
  tai93 = tai93 + REAL(days,r_size)*day + REAL(ih,r_size)*hour &
              & + REAL(imin,r_size)*mins + sec
  IF(iy > 1993 .OR. (iy==1993 .AND. im > 6)) tai93 = tai93 + 1.0d0 !leap second
  IF(iy > 1994 .OR. (iy==1994 .AND. im > 6)) tai93 = tai93 + 1.0d0 !leap second
  IF(iy > 1995) tai93 = tai93 + 1.0d0 !leap second
  IF(iy > 1997 .OR. (iy==1997 .AND. im > 6)) tai93 = tai93 + 1.0d0 !leap second
  IF(iy > 1998) tai93 = tai93 + 1.0d0 !leap second
  IF(iy > 2005) tai93 = tai93 + 1.0d0 !leap second
  IF(iy > 2008) tai93 = tai93 + 1.0d0 !leap second

  RETURN
END SUBROUTINE com_utc2tai
!-----------------------------------------------------------------------
! TAI93 to UTC
!-----------------------------------------------------------------------
SUBROUTINE com_tai2utc(tai93,iy,im,id,ih,imin,sec)
  IMPLICIT NONE
  INTEGER,PARAMETER :: r_size=kind(0.0d0)
  INTEGER,PARAMETER :: r_dble=kind(0.0d0)
  INTEGER,PARAMETER :: r_sngl=kind(0.0e0)
  INTEGER,PARAMETER :: n=7 ! number of leap seconds after Jan. 1, 1993
  INTEGER,PARAMETER :: leapsec(n) = (/  15638399,  47174400,  94608001,&
                                  &    141868802, 189302403, 410227204,&
                                  &    504921605/)
  REAL(r_size),INTENT(IN) :: tai93
  INTEGER,INTENT(OUT) :: iy,im,id,ih,imin
  REAL(r_size),INTENT(OUT) :: sec
  REAL(r_size),PARAMETER :: mins = 60.0d0
  REAL(r_size),PARAMETER :: hour = 60.0d0*mins
  REAL(r_size),PARAMETER :: day = 24.0d0*hour
  REAL(r_size),PARAMETER :: year = 365.0d0*day
  INTEGER,PARAMETER :: mdays(12) = (/31,28,31,30,31,30,31,31,30,31,30,31/)
  REAL(r_size) :: wk,tai
  INTEGER :: days,i,leap

  tai = tai93
  sec = 0.0d0
  DO i=1,n
    IF(FLOOR(tai93) == leapsec(i)+1) sec = 60.0d0 + tai93-FLOOR(tai93,r_size)
    IF(FLOOR(tai93) > leapsec(i)) tai = tai -1.0d0
  END DO
  iy = 1993 + FLOOR(tai /year)
  wk = tai - REAL(iy-1993,r_size)*year - FLOOR(REAL(iy-1993)/4.0,r_size)*day
  IF(wk < 0.0d0) THEN
    iy = iy -1
    wk = tai - REAL(iy-1993,r_size)*year - FLOOR(REAL(iy-1993)/4.0,r_size)*day
  END IF
  days = FLOOR(wk/day)
  wk = wk - REAL(days,r_size)*day
  im = 1
  DO i=1,12
    leap = 0
    IF(im == 2 .AND. MOD(iy,4)==0) leap=1
    IF(im == i .AND. days >= mdays(i)+leap) THEN
      im = im + 1
      days = days - mdays(i)-leap
    END IF
  END DO
  id = days +1

  ih = FLOOR(wk/hour)
  wk = wk - REAL(ih,r_size)*hour
  imin = FLOOR(wk/mins)
  IF(sec < 60.0d0) sec = wk - REAL(imin,r_size)*mins

  RETURN
END SUBROUTINE com_tai2utc


