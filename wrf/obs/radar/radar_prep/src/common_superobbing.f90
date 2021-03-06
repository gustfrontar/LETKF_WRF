MODULE common_superobbing
!=======================================================================
!
! [PURPOSE:] Thinning of radar data
!
! [HISTORY:] This version produce a superobing of the observations but
! the data is stored in azimuth , range , elevation. Conversion to the 
! lat , lon , z is performed by the observation operator.
!
!=======================================================================
!$USE OMP_LIB
  USE common
  USE common_radar_tools
  USE common_smooth2d
  USE common_namelist

  IMPLICIT NONE
  PUBLIC

  REAL(r_size), ALLOCATABLE :: grid_ref(:,:,:)     , grid_vr(:,:,:)
  REAL(r_size), ALLOCATABLE :: grid_el_ref(:,:,:)  , grid_az_ref(:,:,:)  , grid_ra_ref(:,:,:) !Az, range, elev weighted by the observations.
  REAL(r_size), ALLOCATABLE :: grid_el_vr(:,:,:)   , grid_az_vr(:,:,:)   , grid_ra_vr(:,:,:)  !Az, range, elev weighted by the observations.
  REAL(r_size), ALLOCATABLE :: grid_lon_ref(:,:,:) , grid_lat_ref(:,:,:) , grid_z_ref(:,:,:)!Lat, Lon and Z weighted by the observations.
  REAL(r_size), ALLOCATABLE :: grid_lon_vr(:,:,:)  , grid_lat_vr(:,:,:)  , grid_z_vr(:,:,:) !Lat, Lon and Z weighted by the observations.
  REAL(r_size), ALLOCATABLE :: grid_w_vr(:,:,:)
  REAL(r_size), ALLOCATABLE :: grid_meanvr(:,:,:),grid_stdvr(:,:,:) !Non weighted radial velocity and its dispersion within each box.
  REAL(r_size)              :: tmpw
  REAL(r_size), ALLOCATABLE :: grid_error_ref(:,:,:) , grid_error_vr(:,:,:) 

  REAL(r_size), ALLOCATABLE     :: returnedpower(:,:,:)
  REAL(r_size) ,ALLOCATABLE     :: grid_count_ref(:,:,:),grid_count_vr(:,:,:)
  INTEGER nobs

  INTEGER                      :: NLON , NLAT , NLEV
  REAL(r_size) , ALLOCATABLE   :: lon(:,:) , lat(:,:) , z(:,:,:)
  REAL(r_size)                 :: DLON , DLAT

  REAL(r_size) :: max_obs_ref , min_obs_ref , max_obs_vr , min_obs_vr 
  
CONTAINS
!-----------------------------------------------------------------------
! Define grid
!-----------------------------------------------------------------------
SUBROUTINE define_grid ( CURRENT_RADAR )
 IMPLICIT NONE
 TYPE(radar) :: CURRENT_RADAR
 INTEGER     :: i,j,k

   !Translate DX into an appropiate DLON and DLAT.
   !Hopefully nobody will put a radar at the pole.

   DLON=rad2deg*DX/(COS(current_radar%lat0*deg2rad)*re)
   DLAT=rad2deg*DX/re

   !Compute possible value for NLON in order to cover the maximum radar range.
   MAXRANGE=min(MAXRANGE,current_radar%rrange(current_radar%nr)) 
   MAXRANGE=2.0*MAXRANGE
   NLON=CEILING( MAXRANGE / DX )
   NLAT=NLON

   NLEV=CEILING(MAXZ/DZ)

   !Force grid dimensions to be odd
   IF( MODULO( NLON , 2 )== 0)NLON=NLON+1
   IF( MODULO( NLAT , 2 )== 0)NLAT=NLAT+1

   ALLOCATE( lon(NLON,NLAT) , lat(NLON,NLAT) , z(NLON,NLAT,NLEV) )

   !DEFINE LAT AND LON
   DO i=1,NLON
     DO j=1,NLAT
       LON(i,j)=current_radar%lon0 + DLON*( -1.0-(NLON-1.0)/2.0 + i )
       LAT(i,j)=current_radar%lat0 + DLAT*( -1.0-(NLAT-1.0)/2.0 + j )
     ENDDO
   ENDDO

   !DEFINE Z
   DO k=1,NLEV
      Z(:,:,k)=DZ*(k-1)
   ENDDO

   WRITE(6,*)'DEFINE GRID DETAILED OUTPUT     '
   WRITE(6,*)'NLON ',NLON
   WRITE(6,*)'NLAT ',NLAT
   WRITE(6,*)'NLEV ',NLEV
   WRITE(6,*)'MAXRANGE ',MAXRANGE
   WRITE(6,*)'STARTING LON ',LON(1,1)
   WRITE(6,*)'STARTING LAT ',LAT(1,1)
   WRITE(6,*)'END      LON ',LON(NLON,NLAT)
   WRITE(6,*)'END      LAT ',LAT(NLON,NLAT)
   WRITE(6,*)'DLAT         ',DLAT
   WRITE(6,*)'DLON         ',DLON
   WRITE(6,*)'DX           ',DX
   WRITE(6,*)'DZ           ',DZ


END SUBROUTINE define_grid
!-----------------------------------------------------------------------
! Main superobbing routine
!-----------------------------------------------------------------------
SUBROUTINE radar_superobbing( CURRENT_RADAR )

TYPE(RADAR) :: CURRENT_RADAR 

INTEGER :: ia , ir , ie
REAL(r_size)  :: reali,realj,realk
INTEGER :: i , j , k  , nobs , iv
INTEGER :: ii,jj,kk,iobs,nv3d
REAL(r_sngl) :: wk(7)
INTEGER      :: maskh(NLON,NLAT),maskv(NLEV)
INTEGER      :: filter_size_x , filter_size_z 
REAL(r_size) :: tmpfield(NLON,NLAT,NLEV)
REAL(r_size) :: stderror , amp_factor , meanerror
REAL(r_size) :: maxrelativeerror , minrelativeerror
INTEGER      :: count1

REAL(r_size) :: obs_type_code

CHARACTER(256) :: filter_type

nobs=0
nv3d=current_radar%nv3d

IF ( SIMULATE_ERROR )THEN
!THIS IS AN OSSE, WE WILL ADD SOME KIND OF RANDOM NOISE TO THE THINNED OBS.
     filter_type = 'Lanczos'
     maskh       = 1
     maskv       = 1

    DO iv = 1,nv3d
      IF( iv == current_radar%iv3d_ref )THEN
       filter_size_x = NINT( ERROR_REF_SCLX / DX )
       filter_size_z = NINT( ERROR_REF_SCLZ / DZ )
      ENDIF
      IF( iv == current_radar%iv3d_vr )THEN
       filter_size_x = NINT( ERROR_VR_SCLX / DX )
       filter_size_z = NINT( ERROR_VR_SCLZ / DZ )
      ELSE
       CYCLE
      ENDIF

      !FOR REF ERRORS
      DO i=1,nlon
        DO j=1,nlat
          DO k=1,nlev
             CALL com_randn(1,tmpfield(i,j,k))
          ENDDO
        ENDDO
      ENDDO

      DO k=1,nlev
        DO j=1,nlat
         CALL com_randn2(nlon,tmpfield(:,j,k),0)
        ENDDO
         CALL filter_2d(tmpfield(:,:,k),tmpfield(:,:,k),maskh,filter_size_x,filter_type,nlon,nlat)
      ENDDO
      DO i =1,nlat
        DO j =1,nlon
          CALL filter_2d(tmpfield(i,j,:),tmpfield(i,j,:),maskv,filter_size_z,filter_type,nlev,1)
        ENDDO
      ENDDO


      IF ( iv == current_radar%iv3d_ref )THEN 
        !In this case we will assume spatially correlated random percentual errors in returned power.
        !In this case error_ref is the maximum relative error.
        ALLOCATE(grid_error_ref(NLON,NLAT,NLEV))
        maxrelativeerror=0.0d0
        minrelativeerror=0.0d0
         DO i=1,nlon
          DO j=1,nlat
           DO k=1,nlev
             IF( tmpfield(i,j,k) .GT. maxrelativeerror )maxrelativeerror=tmpfield(i,j,k)
             IF( tmpfield(i,j,k) .LT. minrelativeerror )minrelativeerror=tmpfield(i,j,k)
           ENDDO
          ENDDO
         ENDDO
         amp_factor= (2.0d0 * error_ref) / (maxrelativeerror-minrelativeerror) 
         !This is not the final error yet. This is just the error relative error.
         grid_error_ref = tmpfield * amp_factor
        
      ELSEIF ( iv == current_radar%iv3d_vr )THEN
        !In this case we will assume spatially correlated random Gaussian error in radial velocity.
        ALLOCATE(grid_error_vr(NLON,NLAT,NLEV))
        !Compute std.
        stderror=0.0d0
        DO i=1,nlon
         DO j=1,nlat
          DO k=1,nlev
           stderror=stderror+tmpfield(i,j,k)**2
          ENDDO
         ENDDO
        ENDDO
        stderror=stderror/REAL(NLON*NLAT*NLEV,r_size)
        stderror=SQRT(stderror)
        amp_factor = error_vr / stderror 
        grid_error_vr = tmpfield * amp_factor
      ENDIF

   ENDDO 


ENDIF

   ALLOCATE(grid_ref(nlon,nlat,nlev),grid_vr(nlon,nlat,nlev))
   ALLOCATE(grid_count_ref(nlon,nlat,nlev),grid_count_vr(nlon,nlat,nlev))
   ALLOCATE(grid_az_ref(nlon,nlat,nlev),grid_el_ref(nlon,nlat,nlev),grid_ra_ref(nlon,nlat,nlev))
   ALLOCATE(grid_az_vr(nlon,nlat,nlev),grid_el_vr(nlon,nlat,nlev),grid_ra_vr(nlon,nlat,nlev))
   ALLOCATE(grid_lon_ref(nlon,nlat,nlev),grid_lat_ref(nlon,nlat,nlev),grid_z_ref(nlon,nlat,nlev))
   ALLOCATE(grid_lon_vr(nlon,nlat,nlev) ,grid_lat_vr(nlon,nlat,nlev) ,grid_z_vr(nlon,nlat,nlev))
   ALLOCATE(grid_w_vr(nlon,nlat,nlev))
   ALLOCATE(grid_meanvr(nlon,nlat,nlev),grid_stdvr(nlon,nlat,nlev))

    !We will work with reflectivity (not in dbz) if we have dbz as input then transform it
    IF( DBZ_TO_POWER )THEN
        WHERE( current_radar%radarv3d(:,:,:,current_radar%iv3d_ref) .NE. current_radar%missing )
        current_radar%radarv3d(:,:,:,current_radar%iv3d_ref)=10.0d0**( current_radar%radarv3d(:,:,:,current_radar%iv3d_ref)/10.0d0 )
        ENDWHERE
    ENDIF

    !Missing values not associated with clutter will be asigned a minimum reflectivity value. 
    WHERE ( current_radar%radarv3d(:,:,:,current_radar%iv3d_ref) .EQ. current_radar%missing ) current_radar%radarv3d(:,:,:,current_radar%iv3d_ref)=minz
    WHERE ( current_radar%radarv3d(:,:,:,current_radar%iv3d_ref) .LT. minz ) current_radar%radarv3d(:,:,:,current_radar%iv3d_ref)=minz

    IF ( USE_QCFLAG )THEN
    !If dealing with qced real data it will be a good idea to remove all values detected as non weather echoes in the qc algorithm.
    !This can also be useful to deal with simulated tophographyc shading in OSSES.
    WHERE ( current_radar%qcflag(:,:,:) .GE. 900.0d0 ) current_radar%radarv3d(:,:,:,current_radar%iv3d_ref)=current_radar%missing
    WHERE ( current_radar%qcflag(:,:,:) .GE. 900.0d0 ) current_radar%radarv3d(:,:,:,current_radar%iv3d_vr)=current_radar%missing
    ENDIF
    !We need reflectivity to average vr observations. Remove vr observations where the reflectivity is missing.
    WHERE ( current_radar%radarv3d(:,:,:,current_radar%iv3d_ref) .EQ. current_radar%missing ) current_radar%radarv3d(:,:,:,current_radar%iv3d_vr)=current_radar%missing

!Loop over radar variables.


grid_ref=0.0d0
grid_vr =0.0d0
grid_count_ref=0.0d0
grid_count_vr=0.0d0

grid_az_ref=0.0d0
grid_el_ref=0.0d0
grid_ra_ref=0.0d0
grid_az_vr =0.0d0
grid_el_vr =0.0d0
grid_ra_vr =0.0d0
grid_w_vr  =0.0d0
grid_lon_ref=0.0d0
grid_lat_ref=0.0d0
grid_z_ref  =0.0d0
grid_lon_vr =0.0d0
grid_lat_vr =0.0d0
grid_z_vr   =0.0d0

grid_meanvr=0.0d0
grid_stdvr=0.0d0

!AVERAGE DATA AND INCLUDE OBSERVATIONA ERROR.
    !We will compute the i,j,k for each radar grid point and box average the data.


!TODO COMPUTE MAXIMUM AND MINIMUM OF REF AND VR BEFORE PROCEEDING 
    min_obs_ref=999.0d0
    max_obs_ref=-999.0d0
    min_obs_vr=999.0d0
    max_obs_vr=-999.0d0




    DO ia=1,current_radar%na
     DO ir=1,current_radar%nr
      DO ie=1,current_radar%ne


        !Get i,j,k very simple approahc since we are assuming a regular lat/lon/z grid.
        CALL lll2ijk(current_radar%lon(ia,ir,ie),current_radar%lat(ia,ir,ie),current_radar%z(ia,ir,ie),reali,realj,realk)

        !Skip data outside the model domain.
        IF( reali < 1 .OR. reali > nlon .OR. realj < 1 .OR. realj > nlat .OR. realk < 1 .OR. realk > nlev )CYCLE

         i=ANINT(reali)
         j=ANINT(realj)
         k=ANINT(realk)

         IF ( current_radar%radarv3d(ia,ir,ie,current_radar%iv3d_ref) .NE. current_radar%missing )THEN !PROCESS REFLECITIVITY

            IF(current_radar%radarv3d(ia,ir,ie,current_radar%iv3d_ref) > max_obs_ref)THEN
              max_obs_ref=current_radar%radarv3d(ia,ir,ie,current_radar%iv3d_ref)
            ENDIF
            IF(current_radar%radarv3d(ia,ir,ie,current_radar%iv3d_ref) < min_obs_ref)THEN
              min_obs_ref=current_radar%radarv3d(ia,ir,ie,current_radar%iv3d_ref)
            ENDIF



            IF( ( USE_ATTENUATION .and. current_radar%attenuation(ia,ir,ie) > attenuation_threshold ) .or.  &
                ( .not. USE_ATTENUATION ) )THEN
              !Estimate attenuation
              grid_ref(i,j,k)=grid_ref(i,j,k)+current_radar%radarv3d(ia,ir,ie,current_radar%iv3d_ref)
              grid_count_ref(i,j,k)=grid_count_ref(i,j,k)+1.0d0


              grid_az_ref(i,j,k)=grid_az_ref(i,j,k)+current_radar%azimuth(ia)
              grid_el_ref(i,j,k)=grid_el_ref(i,j,k)+current_radar%elevation(ie)
              grid_ra_ref(i,j,k)=grid_ra_ref(i,j,k)+current_radar%rrange(ir)

              grid_lon_ref(i,j,k)=grid_lon_ref(i,j,k)+current_radar%lon(ia,ir,ie)
              grid_lat_ref(i,j,k)=grid_lat_ref(i,j,k)+current_radar%lat(ia,ir,ie)
              grid_z_ref(i,j,k)  =grid_z_ref(i,j,k)  +current_radar%z(ia,ir,ie)
            !ELSE
            !  WRITE(*,*)"[Warning]: Attenuated pixel at ",i,j,k,current_radar%attenuation(ia,ir,ie) 
            ENDIF

          ENDIF

          !CONSIDER THE RADIAL VELOCITY
          IF( current_radar%radarv3d(ia,ir,ie,current_radar%iv3d_vr) .NE. current_radar%missing )THEN !PROCESS WIND
             IF( current_radar%radarv3d(ia,ir,ie,current_radar%iv3d_ref) .NE. current_radar%missing )THEN
                tmpw=current_radar%radarv3d(ia,ir,ie,current_radar%iv3d_ref)
             ELSE
                tmpw=minz
             ENDIF

            IF(current_radar%radarv3d(ia,ir,ie,current_radar%iv3d_vr) > max_obs_vr)THEN
              max_obs_vr=current_radar%radarv3d(ia,ir,ie,current_radar%iv3d_vr)
            ENDIF
            IF(current_radar%radarv3d(ia,ir,ie,current_radar%iv3d_vr) < min_obs_vr)THEN
              min_obs_vr=current_radar%radarv3d(ia,ir,ie,current_radar%iv3d_vr)
            ENDIF


            !Wind will be averaged using an average weighted by returned power.
            !(this should reduce noise). 
            
            grid_vr(i,j,k)=grid_vr(i,j,k)+current_radar%radarv3d(ia,ir,ie,current_radar%iv3d_vr)*tmpw
            grid_az_vr(i,j,k)=grid_az_vr(i,j,k)+current_radar%azimuth(ia)*tmpw
            grid_el_vr(i,j,k)=grid_el_vr(i,j,k)+current_radar%elevation(ie)*tmpw
            grid_ra_vr(i,j,k)=grid_ra_vr(i,j,k)+current_radar%rrange(ir)*tmpw

            grid_lon_vr(i,j,k)=grid_lon_vr(i,j,k)+current_radar%lon(ia,ir,ie)*tmpw
            grid_lat_vr(i,j,k)=grid_lat_vr(i,j,k)+current_radar%lat(ia,ir,ie)*tmpw
            grid_z_vr(i,j,k)  =grid_z_vr(i,j,k)  +current_radar%z(ia,ir,ie)*tmpw

            grid_w_vr(i,j,k)=grid_w_vr(i,j,k)+tmpw
    
            grid_count_vr(i,j,k)=grid_count_vr(i,j,k)+1.0d0

            grid_meanvr(i,j,k)=grid_meanvr(i,j,k)+current_radar%radarv3d(ia,ir,ie,current_radar%iv3d_vr)
            grid_stdvr(i,j,k) =grid_stdvr(i,j,k) +current_radar%radarv3d(ia,ir,ie,current_radar%iv3d_vr) ** 2

            !if( i==30 .and. j==96 .and. k==9)then
            !write(*,*)current_radar%radarv3d(ia,ir,ie,current_radar%iv3d_vr),tmpw
            !endif


     
          ENDIF 

      ENDDO
     ENDDO
    ENDDO


    !Average data and write observation file (FOR LETKF)
    DO ii=1,nlon
     DO jj=1,nlat
      DO kk=1,nlev
 
           IF( grid_count_ref(ii,jj,kk) > 0.0d0 )THEN  !Process reflectivity
              grid_ref(ii,jj,kk) = grid_ref(ii,jj,kk) / grid_count_ref(ii,jj,kk)

              IF(  SIMULATE_ERROR .AND. grid_ref(ii,jj,kk) .GT. minz )THEN
                  grid_error_ref(ii,jj,kk)=grid_error_ref(ii,jj,kk) * grid_ref(ii,jj,kk)
                  grid_ref(ii,jj,kk) = grid_ref(ii,jj,kk) + grid_error_ref(ii,jj,kk)
                  IF( grid_ref(ii,jj,kk) .LT. minz )THEN
                    grid_ref(ii,jj,kk) = minz
                  ENDIF  
              ENDIF

              grid_az_ref(ii,jj,kk)=grid_az_ref(ii,jj,kk) / grid_count_ref(ii,jj,kk)
              grid_el_ref(ii,jj,kk)=grid_el_ref(ii,jj,kk) / grid_count_ref(ii,jj,kk)
              grid_ra_ref(ii,jj,kk)=grid_ra_ref(ii,jj,kk) / grid_count_ref(ii,jj,kk)

              grid_lon_ref(ii,jj,kk)=grid_lon_ref(ii,jj,kk) / grid_count_ref(ii,jj,kk)
              grid_lat_ref(ii,jj,kk)=grid_lat_ref(ii,jj,kk) / grid_count_ref(ii,jj,kk)
              grid_z_ref(ii,jj,kk)  =grid_z_ref(ii,jj,kk)   / grid_count_ref(ii,jj,kk)


           ENDIF

           IF( grid_count_vr(ii,jj,kk) > 0.0d0 )THEN
 
              grid_vr(ii,jj,kk) = grid_vr(ii,jj,kk) / grid_w_vr(ii,jj,kk)

 
              !if( grid_vr(ii,jj,kk) < -90 )write(*,*)grid_vr(ii,jj,kk),grid_w_vr(ii,jj,kk),grid_count_vr(ii,jj,kk),ii,jj,kk

              IF(  SIMULATE_ERROR )THEN
                 grid_vr(ii,jj,kk)=grid_vr(ii,jj,kk)+grid_error_vr(ii,jj,kk)
              ENDIF

              grid_az_vr(ii,jj,kk)=grid_az_vr(ii,jj,kk) / ( grid_w_vr(ii,jj,kk) )
              grid_el_vr(ii,jj,kk)=grid_el_vr(ii,jj,kk) / ( grid_w_vr(ii,jj,kk) )
              grid_ra_vr(ii,jj,kk)=grid_ra_vr(ii,jj,kk) / ( grid_w_vr(ii,jj,kk) )

              grid_lon_vr(ii,jj,kk)=grid_lon_vr(ii,jj,kk) / ( grid_w_vr(ii,jj,kk))
              grid_lat_vr(ii,jj,kk)=grid_lat_vr(ii,jj,kk) / ( grid_w_vr(ii,jj,kk))
              grid_z_vr(ii,jj,kk)  =grid_z_vr(ii,jj,kk)   / ( grid_w_vr(ii,jj,kk))

              grid_meanvr(ii,jj,kk)=grid_meanvr(ii,jj,kk) / ( grid_count_vr(ii,jj,kk) )
              grid_stdvr(ii,jj,kk) =grid_stdvr(ii,jj,kk)  / (grid_count_vr(ii,jj,kk) )
              IF( grid_count_vr(ii,jj,kk) >= 1.0d0) THEN
               grid_stdvr(ii,jj,kk) = SQRT(grid_stdvr(ii,jj,kk) - (grid_meanvr(ii,jj,kk)**2) )
              ELSE
               grid_stdvr(ii,jj,kk) = 0.0d0
              ENDIF
              !If variability within a box is big then we may have:
              ! -small scale strong phenomena (tornado!)
              ! -noise in the data.
              ! In any case averaging the data is not a god idea so this data
              ! can be rejected a priori.
              IF( use_vr_std )THEN
                IF( grid_stdvr(ii,jj,kk) > vr_std_threshold )grid_count_vr(ii,jj,kk)=0.0 !Reject the observation.
              ENDIF
           ENDIF

      ENDDO
     ENDDO
    ENDDO


    WRITE(*,*)"Input reflectivity obs. range = ",10*log10(min_obs_ref)," to ",10*log10(max_obs_ref)
    WRITE(*,*)"Input radial vel. obs. range = ",min_obs_vr," to ",max_obs_vr



    !COMPUTE REFLECTIIVITY ERROR VARIANCE in DBZ
    IF( SIMULATE_ERROR )THEN
    stderror=0.0d0
    meanerror=0.0d0
    count1=0
    DO ii=1,nlon
     DO jj=1,nlat
      DO kk=1,nlev
       IF( grid_count_ref(ii,jj,kk) .GT. 0.0d0 )THEN
         !Compute error in dbz.
         stderror = stderror + ( 10.0d0*log10( grid_ref(ii,jj,kk) ) - 10.0d0*log10( grid_ref(ii,jj,kk) - grid_error_ref(ii,jj,kk) ) )**2
         meanerror= meanerror + 10.0d0*log10( grid_ref(ii,jj,kk) ) - 10.0d0*log10( grid_ref(ii,jj,kk) - grid_error_ref(ii,jj,kk) )
         count1=count1+1
       ENDIF 
      ENDDO
     ENDDO
    ENDDO
    meanerror = meanerror / count1 
    error_ref = SQRT(stderror / count1 - meanerror**2 )
    ENDIF

   !WRITE THE DATA
   !WRITE FILE HEADER.
  IF( endian == 'b')THEN
   OPEN(UNIT=99,FILE='radarobs.dat',STATUS='unknown',FORM='unformatted',CONVERT='big_endian')
  ELSEIF( endian == 'l' )THEN
   OPEN(UNIT=99,FILE='radarobs.dat',STATUS='unknown',FORM='unformatted',CONVERT='little_endian')
  ENDIF
   !Introduce a small header with the radar possition and two values that might be useful.
   write(99)REAL(current_radar%lon0,r_sngl)
   write(99)REAL(current_radar%lat0,r_sngl)
   write(99)REAL(current_radar%z0,r_sngl)

    nobs=0

    min_obs_ref=999.0d0
    max_obs_ref=-999.0d0
    min_obs_vr=999.0d0
    max_obs_vr=-999.0d0
    DO ii=1,nlon
     DO jj=1,nlat
      DO kk=1,nlev

       !correspond to the location where the stronger echoes are located.
       IF( grid_count_ref(ii,jj,kk) .GT. 0.0d0 .OR. grid_count_vr(ii,jj,kk) .GT. 0.0d0)THEN

        IF( latlon_coord )THEN  !Lat-lon output
           wk(2)=REAL(grid_lon_ref(ii,jj,kk),r_sngl)
           wk(3)=REAL(grid_lat_ref(ii,jj,kk),r_sngl)
           wk(4)=REAL(grid_z_ref(ii,jj,kk),r_sngl)
        ELSE                    !Az, range , elev output
           wk(2)=REAL(grid_az_ref(ii,jj,kk),r_sngl)
           wk(3)=REAL(grid_el_ref(ii,jj,kk),r_sngl)
           wk(4)=REAL(grid_ra_ref(ii,jj,kk),r_sngl)
        ENDIF
       ENDIF

       IF( grid_count_ref(ii,jj,kk) .GT. 0.0d0 )THEN
           wk(1)=REAL(id_ref_obs,r_sngl)
           wk(6)=REAL(error_ref,r_sngl)
           wk(5)=REAL(grid_ref(ii,jj,kk),r_sngl)
           wk(7)=REAL(current_radar%lambda,r_sngl)
           WRITE(99)wk
           nobs = nobs + 1
           if( grid_ref(ii,jj,kk) > max_obs_ref)max_obs_ref=grid_ref(ii,jj,kk)
           if( grid_ref(ii,jj,kk) < min_obs_ref)min_obs_ref=grid_ref(ii,jj,kk)
           !WRITE(*,*)wk
       ENDIF
       IF( grid_count_vr(ii,jj,kk) .GT. 0.0d0 )THEN
           wk(1)=REAL(id_vr_obs,r_sngl)
           wk(6)=REAL(error_vr,r_sngl)
           wk(5)=REAL(grid_vr(ii,jj,kk),r_sngl)
           wk(7)=REAL(current_radar%lambda,r_sngl)
           WRITE(99)wk
           nobs=nobs +1
           if( grid_vr(ii,jj,kk) > max_obs_vr)max_obs_vr=grid_vr(ii,jj,kk)
           if( grid_vr(ii,jj,kk) < min_obs_vr)min_obs_vr=grid_vr(ii,jj,kk)

           !WRITE(*,*)wk
       ENDIF
      ENDDO
     ENDDO
    ENDDO

    WRITE(*,*)"Reflectivity obs. range = ",10*log10(min_obs_ref)," to ",10*log10(max_obs_ref)
    WRITE(*,*)"Radial vel. obs. range = ",min_obs_vr," to ",max_obs_vr




!WRITE GRIDDED DATA (FOR DEBUG)
!Write gridded file (for debug but also might be usefull for model verification)
IF(DEBUG_OUTPUT)THEN
   IF( endian == 'b')THEN
     OPEN(UNIT=101,FILE='super.grd',STATUS='unknown',FORM='unformatted',CONVERT='big_endian')
   ELSEIF( endian == 'l' )THEN
     OPEN(UNIT=101,FILE='super.grd',STATUS='unknown',FORM='unformatted',CONVERT='little_endian')
   ENDIF
   DO kk=1,nlev
      WRITE(101)REAL(grid_ref(:,:,kk),r_sngl)
   ENDDO
   DO kk=1,nlev
      WRITE(101)REAL(grid_vr(:,:,kk),r_sngl)
   ENDDO
   DO kk=1,nlev
      WRITE(101)REAL(grid_count_ref(:,:,kk),r_sngl)
   ENDDO
 IF( latlon_coord )THEN
   DO kk=1,nlev
      WRITE(101)REAL(grid_lon_ref(:,:,kk),r_sngl)
   ENDDO
   DO kk=1,nlev
      WRITE(101)REAL(grid_lat_ref(:,:,kk),r_sngl)
   ENDDO
   DO kk=1,nlev
      WRITE(101)REAL(grid_z_ref(:,:,kk),r_sngl)
   ENDDO
   DO kk=1,nlev
      WRITE(101)REAL(grid_lon_vr(:,:,kk),r_sngl)
   ENDDO
   DO kk=1,nlev
      WRITE(101)REAL(grid_lat_vr(:,:,kk),r_sngl)
   ENDDO
   DO kk=1,nlev
      WRITE(101)REAL(grid_z_vr(:,:,kk),r_sngl)
   ENDDO

 ELSE
   DO kk=1,nlev
      WRITE(101)REAL(grid_az_ref(:,:,kk),r_sngl)
   ENDDO
   DO kk=1,nlev
      WRITE(101)REAL(grid_ra_ref(:,:,kk),r_sngl)
   ENDDO
   DO kk=1,nlev
      WRITE(101)REAL(grid_el_ref(:,:,kk),r_sngl)
   ENDDO
   DO kk=1,nlev
      WRITE(101)REAL(grid_az_vr(:,:,kk),r_sngl)
   ENDDO
   DO kk=1,nlev
      WRITE(101)REAL(grid_ra_vr(:,:,kk),r_sngl)
   ENDDO
   DO kk=1,nlev
      WRITE(101)REAL(grid_el_vr(:,:,kk),r_sngl)
   ENDDO

 ENDIF
   CLOSE(101)

 IF( SIMULATE_ERROR )THEN
  IF( endian == 'b' )THEN
   OPEN(UNIT=101,FILE='error.grd',STATUS='unknown',FORM='unformatted',CONVERT='big_endian')
  ELSEIF( endian == 'l' )THEN
   OPEN(UNIT=101,FILE='error.grd',STATUS='unknown',FORM='unformatted',CONVERT='little_endian')
  ENDIF

   DO kk=1,nlev
      WRITE(101)REAL(grid_error_ref(:,:,kk),r_sngl)
   ENDDO
   DO kk=1,nlev
      WRITE(101)REAL(grid_error_vr(:,:,kk),r_sngl)
   ENDDO
   CLOSE(101)

 ENDIF

ENDIF


WRITE(*,*)'A TOTAL NUMBER OF ', nobs , ' HAS BEEN WRITTEN TO THE OBSERVATION FILE'

    !TODO: OBSERVATION ERROR CAN BE DEFINED AS AN INCREASING FUNCTION OF RANGE.
    !TO TAKE INTO ACCOUNT ATTENUATION AS WELL AS BEAM BROADENING.

RETURN
END SUBROUTINE radar_superobbing
!-----------------------------------------------------------------------
! Horizontal coordinate conversion
!-----------------------------------------------------------------------
SUBROUTINE lll2ijk(rlon,rlat,rlev,ri,rj,rk)
  IMPLICIT NONE
  REAL(r_size),INTENT(IN) :: rlon
  REAL(r_size),INTENT(IN) :: rlat
  REAL(r_size),INTENT(IN) :: rlev
  REAL(r_size),INTENT(OUT) :: ri
  REAL(r_size),INTENT(OUT) :: rj
  REAL(r_size),INTENT(OUT) :: rk

    ri=(rlon-LON(1,1))/DLON + 1.0d0
    rj=(rlat-LAT(1,1))/DLAT + 1.0d0    
    rk=(rlev-Z(1,1,1))/DZ   + 1.0d0
  

  RETURN
END SUBROUTINE lll2ijk



END MODULE common_superobbing
