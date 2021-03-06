#This script generates pseudo-radar observations from WRF outputs.
ulimit -s unlimited

EXPERIMENT_NAME=SCALE_TO_RADAR_TEST

MODELDATAPATH="/home/paula.maldonado/scale_juan/argentina_anguil_2km_control/"
MODELTOPOPATH="/home/paula.maldonado/scale_juan/argentina_anguil_2km_control/const/topo"
RADARDATAPATH="/home/paula.maldonado/datosmate/RADAROBS/ANGUIL/20100111/120/dealiased_data/" 

TMPDIR="$HOME/TMP/SCALE_TO_RADAR/"
EXEC="$HOME/share/LETKF_WRF/wrf/obs/radar/scale_to_radar/scale_to_radar.exe"

export LD_LIBRARY_PATH=/usr/local/netcdf4.intel/lib/:$LD_LIBRARY_PATH

#DOMAIN="03"

source ../../../run/util.sh #Date functions.

INIDATE=20100111150000
ENDDATE=20100111150000

NAMELIST_SCALE2RADAR="$TMPDIR/s2r.namelist"

frec=300                           #Observation frequency in seconds.

add_obs_error=".FALSE."        
reflectivity_error="2.5d0"
radialwind_error="1.0d0"   
radarfile=""                
use_wt=".TRUE."                   #Include or not the effect of terminal velocity      
n_radar="1"                       #Number of radars                 
n_times="1"                       
model_split_output=".false."
method_ref_calc=2
input_type=1                      #1-restart files, 2-history files

#Grid parameters 
MPRJ_basepoint_lon="296.02D0"
MPRJ_basepoint_lat="-36.5D0"
MPRJ_type="LC"
MPRJ_LC_lat1="-37.D0"
MPRJ_LC_lat2="-36.D0"

mkdir  -p $RADARDATAPATH
mkdir  -p $TMPDIR

#------- CREATE NAMELIST PARAMETERS ------------------

echo "&general                               " >  $NAMELIST_SCALE2RADAR
echo "add_obs_error=$add_obs_error           " >> $NAMELIST_SCALE2RADAR
echo "reflectivity_error=$reflectivity_error " >> $NAMELIST_SCALE2RADAR
echo "radialwind_error=$radialwind_error     " >> $NAMELIST_SCALE2RADAR
echo "use_wt=$use_wt                         " >> $NAMELIST_SCALE2RADAR
echo "n_radar=$n_radar                       " >> $NAMELIST_SCALE2RADAR
echo "n_times=$n_times                       " >> $NAMELIST_SCALE2RADAR
echo "method_ref_calc=$method_ref_calc       " >> $NAMELIST_SCALE2RADAR
echo "input_type=$input_type                 " >> $NAMELIST_SCALE2RADAR
echo "/                                      " >> $NAMELIST_SCALE2RADAR

echo "&param_mapproj                         " >> $NAMELIST_SCALE2RADAR
echo "MPRJ_basepoint_lon=$MPRJ_basepoint_lon " >> $NAMELIST_SCALE2RADAR 
echo "MPRJ_basepoint_lat=$MPRJ_basepoint_lat " >> $NAMELIST_SCALE2RADAR
echo "MPRJ_type=$MPRJ_type                   " >> $NAMELIST_SCALE2RADAR
echo "MPRJ_LC_lat1=$MPRJ_LC_lat1             " >> $NAMELIST_SCALE2RADAR
echo "MPRJ_LC_lat2=$MPRJ_LC_lat2             " >> $NAMELIST_SCALE2RADAR
echo "/                                      " >> $NAMELIST_SCALE2RADAR

#---------END OF NAMELIST PARAMETERS

#Create folders and link files.

cdate=$INIDATE

itime=0001
irad=001

while [ $cdate -le  $ENDDATE ]
do

cd $TMPDIR

#Delete links from previous round
rm -fr $TMPDIR/topo* $TMPDIR/hist* $TMPDIR/radar*

ln -sf $MODELTOPOPATH/topo*.nc .

for ifile in $( ls $MODELDATAPATH/$cdate/fcst/mean/init* ) ; do

  myfile=$(basename $ifile)
  sufix=`echo $myfile | cut -c21-31`
  ln -sf $ifile ./model${itime}.${sufix}

done

#Search for the closest radar file. Loop over all availble radar files to get the closest
MINTDIST=999999
for ifile in $( ls $RADARDATAPATH/cfrad* ) ; do


  myfile=$(basename $ifile)
  #cfrad.20100111_062345.000_to_20100111_062721.999_ANG120_v39_SUR.nc_dealiased

  filedate1=`echo $myfile | cut -c7-14`
  filedate2=`echo $myfile | cut -c16-21`
  filedate=${filedate1}${filedate2}

  datedist=`date_diff $filedate $cdate`

  datedist=`abs_val $datedist`

  if [ $datedist -lt $MINTDIST ] ; then

   #We have a closer date.
   radarfile=$ifile
   MINTDIST=$datedist

  fi

done

echo "Radar file for $cdate is $radarfile"

ln -sf $EXEC ./scale_to_radar.exe 

ln -sf $radarfile ./radar${irad}_${itime}.nc

./scale_to_radar.exe

cdate=`date_edit2 $cdate $frec `

done






