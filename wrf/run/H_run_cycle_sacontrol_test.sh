#!/bin/bash
#=======================================================================
#   To run the WRF-LETKF 
#   This scripts prepares all the data needed to run the letkf cycle 
#   then submmits the job to the K computer.
#   Based on the script developed by Shigenori Otsuka
#   Diferences from V3:
#   -Boundary perturbations, met em are perturbed and real is run in 
#    K computer nodes.
#   -Letkf incorporates relaxation to prior inflation and eigen exa
#    matrix computations.
#   -LETKF uses NETCDF IO.
#=======================================================================
#set -x
#-----------------------------------------------------------------------
# Modify below according to your environment
#-----------------------------------------------------------------------
#Get root dir
CDIR=`pwd`

#CONFIGURATION
DOMAINCONF=SA_60KM                  #Define a domain
CONFIGURATION=control40msa_test     #Define a experiment configuration
MCONFIGURATION=machine_60ksa_H_test #Define a machine configuration (number of nodes, etc)
LETKFNAMELIST=control               #Define a letkf namelist template

RESTART=1
RESTARTDATE=20100924120000
RESTARTITER=10


MYHOST=`hostname`
PID=$$
MYSCRIPT=${0##*/}

if [ -e $CDIR/configuration/analysis_conf/${CONFIGURATION}.sh ];then
source $CDIR/configuration/analysis_conf/${CONFIGURATION}.sh
else
echo "CAN'T FIND CONFIGURATION FILE $CDIR/configuration/analysis_conf/${CONFIGURATION}.sh"
exit
fi

if [ -e $CDIR/configuration/machine_conf/${MCONFIGURATION}.sh ];then
source $CDIR/configuration/machine_conf/${MCONFIGURATION}.sh
else
echo "CAN'T FIND MACHINE CONFIGURATION FILE $CDIR/configuration/machine_conf/${MCONFIGURATION}.sh"
exit
fi


source $UTIL

echo '>>>'
echo ">>> INITIALIZING WORK DIRECTORY AND OUTPUT DIRECTORY"
echo '>>>'

safe_init_outputdir $OUTPUTDIR

set_my_log

echo $my_log

#Start of the section that will be output to my log.
{
safe_init_tmpdir $TMPDIR


save_configuration $CDIR/$MYSCRIPT

echo ">>>> I'm RUNNING IN $MYHOST and my PID is $PID" 
echo ">>>> My config file is $CONFIGURATION         " 
echo ">>>> My domain is $DOMAINCONF                 " 
echo ">>>> My machine is $MCONFIGURATION            " 
echo ">>>> I' am $CDIR/$MYSCRIPT                    "
echo ">>>> My LETKFNAMELIST is $LETKFNAMELIST       " 

echo '>>>'                                           
echo ">>> COPYING DATA TO WORK DIRECTORY "          
echo '>>>'                                         

copy_data   


##################################################
# START CYCLE IN TIME
##################################################

echo ">>>"                                                         
echo ">>> STARTING WRF-LETKF CYCLE FROM $IDATE TO $EDATE"         
echo ">>>"                                                          
 
if [ $RESTART -eq 0 ] ; then
CDATE=$IDATE
ITER=1
else
CDATE=$RESTARTDATE
ITER=$RESTARTITER
fi


while test $CDATE -le $EDATE
do

echo '>>>'                                                           
echo ">>> BEGIN COMPUTATION OF $CDATE  ITERATION: $ITER"             
echo '>>>'                                                           

set_cycle_dates   

echo " >>"                                                           
echo " >> GENERATING PERTURBATIONS"                                  
echo " >>"                                                           

#PERTURB MET_EM FILES USING RANDOM BALANCED OR RANDOM SMOOTHED PERTURBATIONS (run in PPS)
run_script=$TMPDIR/SCRIPTS/perturb_met_em.sh                         
perturb_met_em $run_script                                           

echo " >>"                                                           
echo " >> ENSEMBLE FORECASTS AND LETKF"
echo " >>"

#CREATE OUTPUT DIRECTORIES FOR THE CURRENT CYCLE (YYYYMMDDHHNNSS)
RESULTDIRG=$OUTPUTDIR/gues/$ADATE/
RESULTDIRA=$OUTPUTDIR/anal/$ADATE/

mkdir -p $RESULTDIRG
mkdir -p $RESULTDIRA

echo " >>"
echo " >> WAITING FOR ENSEMBLE RUN"
echo " >>"

run_ensemble_forecast

echo " >>"
echo " >> WAITING FOR ENSEMBLE RUN"
echo " >>"

get_observations

echo " >>"
echo " >> WAITING FOR LETKF"
echo " >>"

run_letkf

echo " >>"
echo " >> DOING POST PROCESSING"
echo " >>"

arw_postproc 

echo " >>"
echo " >> CHECKING CYCLE"
echo " >>"

check_postproc


CDATE=$ADATE
ITER=`expr $ITER + 1`
RESTART=0    #TURN RESTART FLAG TO 0 IN CASE IT WAS GREATHER THAN 0.

done	### MAIN LOOP ###

echo "NORMAL END"


} > $my_log 2>&1
