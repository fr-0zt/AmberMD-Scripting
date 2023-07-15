#!/bin/bash

###########################################################
# run_md_simulations.sh
# Author: Senal Liyanage
# Affiliation: Mississippi State University
# Contact: sdd313@msstate.edu
# Date: June 4, 2023
# Description: Bash script for running MD simulations
###########################################################

# Usage message
usage() {
    echo
    echo "USAGE: run_md_simulations.sh [SYSTEM NAME] [CPU] [0/1] [GPU INDEX] [MD Start] [MD Stop] [TRAJECTORY NUMBER]"
    echo
    echo "For preproduction run, set the third argument to 0."
    echo "For production run, set the third argument to 1."
    echo
    exit
}

# Check the number of arguments
if [ $# -lt 3 ]; then
    usage
else
    echo "Running MD Simulations..."
fi

# Set variables based on the arguments
system_name=$1
cpu_cores=$2
simulation_type=$3
gpu_index=$4
md_start=$5
md_stop=$6
trajectory_number=$7

# Function for preproduction run
preproduction_run() {
    # Minimize the system's energy with constraints decreasing over time.
    mpirun -np $cpu_cores pmemd.MPI -O -p $system_name.parm7 -c $system_name.rst7 -i 001.min/minimize.in -o 001.min/min.log -inf 001.min/$system_name-min.info -x 001.min/$system_name-min.nc -r 001.min/$system_name-min.rst -ref $system_name.rst7
    mpirun -np $cpu_cores pmemd.MPI -O -p $system_name.parm7 -c 001.min/$system_name-min.rst -i 001.min/minimize2.in -o 001.min/min2.log -inf 001.min/$system_name-min2.info -x 001.min/$system_name-min2.nc -r 001.min/$system_name-min2.rst -ref 001.min/$system_name-min.rst

    # Heat the system to 310K with constraints.
    mpirun -np $cpu_cores pmemd.MPI -O -p $system_name.parm7 -c 001.min/$system_name-min2.rst -i 002.heat/heat-with-constraints.in -o 002.heat/$system_name-heat.log -inf 002.heat/$system_name-heat.info -x 002.heat/$system_name-heat.nc -r 002.heat/$system_name-heat.rst -ref 001.min/$system_name-min2.rst
    mpirun -np $cpu_cores pmemd.MPI -O -p $system_name.parm7 -c 002.heat/$system_name-heat.rst -i 002.heat/heat-with-constraints2.in -o 002.heat/$system_name-heat2.log -inf 002.heat/$system_name-heat2.info -x 002.heat/$system_name-heat2.nc -r 002.heat/$system_name-heat2.rst -ref 001.min/$system_name-heat.rst
}

# Function for production run
production_run() {
    # Check if necessary arguments are available
    if [ -z "$gpu_index" ] || [ -z "$md_start" ] || [ -z "$md_stop" ] || [ -z "$trajectory_number" ]; then
        echo "Please specify the GPU index, the starting MD run, the ending MD run, and the trajectory number."
        exit
    fi

    # Select a CUDA device and run NPT MD simulations until the target simulation length is reached (nmax+1).
    export CUDA_VISIBLE_DEVICES=$gpu_index

    cd Traj${trajectory_number}/003.equil || { echo "Could not change to directory Traj${trajectory_number}/003.equil"; exit 1; }


    # Equilibrate the system with constraints.
    mpirun -np $cpu_cores pmemd.MPI -O -p ../../$system_name.parm7 -c ../../002.heat/$system_name-heat2.rst -i equil.in -o $system_name-equil.log -inf $system_name-equil.info -x $system_name-equil.nc -r $system_name-equil.rst

    cd ../004.prod

    # Production
    if [ $md_start == "0" ]; then
        $AMBERHOME/bin/pmemd.cuda -O -p ../../$system_name.parm7 -c ../003.equil/$system_name-equil.rst -i production.in -o $system_name-md0.log -inf $system_name-md0.info -x $system_name-md0.nc -r $system_name-md0.rst
        nrun=1
    else
        nrun=$md_start
    fi

    prev=$(expr $nrun - 1)
    nmax=$md_stop

    while [ $nrun -le $nmax ]; do
        $AMBERHOME/bin/pmemd.cuda -O -p ../../$system_name.parm7 -c $system_name-md$prev.rst -i production.in -o $system_name-md$nrun.log -inf $system_name-md$nrun.info -x $system_name-md$nrun.nc -r $system_name-md$nrun.rst
        prev=$nrun
        nrun=$(expr $nrun + 1)
    done
}

# Main script execution
if [ $simulation_type == "0" ]; then
    preproduction_run
elif [ $simulation_type == "1" ]; then
    production_run
else
    echo "Invalid argument for simulation type. Exiting simulation."
    usage
fi
