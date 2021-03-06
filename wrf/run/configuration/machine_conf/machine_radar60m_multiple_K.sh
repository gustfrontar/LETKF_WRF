#MACHINE CONFIGURATION
GROUP=""
SYSTEM="0"  # 0 - K computer , 1 - qsub cluster
PROC_PER_NODE=8     #Number of procs per node.
PROC_PER_MEMBER=8   #Number  of procs per ensemble members (torque)
NODES_PER_MEMBER=2  #Number of nodes per ensemble member.
PPSSERVER=pps1      #Hostname of pps server (for perturbation generation and post processing)
MAX_RUNNING=8       #Maximum number of simultaneous processes running in PPS servers.
ELAPSE="00:10:00"   #MAXIMUM ELAPSE TIME (MODIFY ACCORDING TO THE SIZE OF THE DOMAIN AND THE RESOLUTION)
MAX_BACKGROUND_JOBS=128

TOTAL_NODES_FORECAST=120
TOTAL_NODES_LETKF=120

#These options control job split (in case of big jobs)
#Job split is performed authomaticaly if the number of ensemble members is
#larger than MAX_MEMBER_PER_JOB.
MAX_MEMBER_PER_JOB=60      #Number of members included on each job.
MAX_SUBMITT_JOB=1          #Maximum number of jobs that can be submitted to the queue.

