#!/bin/bash

###########################################################
# generate_amber_inputs.sh
# Author: Senal Liyanage
# Affiliation: Mississippi State University
# Contact: sdd313@msstate.edu
# Date: June 4, 2023
# Description: Bash script for generating AMBER inputs for multiple trajectories
###########################################################

# Cleanup function
cleanup() {
    local num_traj=$1
    echo "Cleaning up old directories and files..."
    rm -rf 001.min 002.heat
    for ((traj=1; traj<=num_traj; traj++)); do
        rm -rf "Traj${traj}"
    done
    echo "Cleanup done."
}

# Check if the first argument is "cleanup"
if [ "$1" == "cleanup" ]; then
    if [ $# -ne 2 ]; then
        echo "Error: Cleanup requires the number of trajectories as the second argument."
        echo "USAGE: $0 cleanup [NUMBER_OF_TRAJECTORIES]"
        exit 1
    fi
    cleanup $2
    exit 0
fi

# Usage message
usage() {
    echo "USAGE: $0 [RESIDUE_START] [RESIDUE_END] [NUMBER_OF_TRAJECTORIES]"
    echo "Generates AMBER scripts for the specified number of trajectories, with ligand constraints for the given range of residues."
}

# Check the number of arguments
if [ $# -ne 3 ]; then
    echo "Error: Incorrect number of arguments."
    usage
    exit 1
fi

# Check if arguments are numbers
re='^[0-9]+$'
if ! [[ $1 =~ $re ]] || ! [[ $2 =~ $re ]] || ! [[ $3 =~ $re ]]; then
    echo "Error: All arguments must be positive integers."
    usage
    exit 1
fi

# Set variables based on the arguments
residue_start=$1
residue_end=$2
number_of_trajectories=$3
amber_restraints="restraintmask='(:$residue_start-$residue_end & !@H=)'"
echo "Writing scripts for $number_of_trajectories trajectories with ligand constraints for residues $residue_start to $residue_end."

# Create directories for minimization and heating
directories=("001.min" "002.heat")
for dir in "${directories[@]}"; do
    if [ -d "$dir" ]; then
        echo "Error: Directory \'$dir\' already exists."
        exit 1
    fi
    mkdir -p "$dir"
done

# Minimization scripts
cat <<EOF > 001.min/minimize.in
# Minimization with Cartesian restraints
 &cntrl
 imin=1,
 maxcyc=10000,
 ncyc=5000,
 ntb=1,
 cut=12.0,
 ntr=1,
 $amber_restraints,
 restraint_wt=500
/
END

EOF
echo "" >> 001.min/minimize.in

cat <<EOF > 001.min/minimize2.in
# Minimization without Cartesian restraints
 &cntrl
 imin=1,
 maxcyc=10000,
 ncyc=5000,
 ntb=1,
 ntr=0,
 cut=12.0
/
END

EOF
echo "" >> 001.min/minimize2.in

# Heating scripts
cat <<EOF > 002.heat/heat-with-constraints.in
# Lipid 144 heating 100K for 5ps
 &cntrl
  imin=0,
  ntx=1,
  ntc=2,
  ntf=2,
  tol=0.0000001,
  nstlim=2500,
  ntt=3,
  gamma_ln=1.0,
  ntr=1,
  ig=-1,
  ntpr=100,
  ntwr=10000,
  ntwx=100,
  dt=0.002,
  nmropt=1,
  ntb=1,
  ntp=0,
  cut=10.0,
  ioutfm=1,
  ntxo=2,
  iwrap=1,
  restraint_wt=10.0,
  $amber_restraints
 /
 &wt type='TEMP0', istep1=0, istep2=2500,
                   value1=0.0, value2=100.0 /
 &wt type='END' /

EOF
echo "" >> 002.heat/heat-with-constraints.in

cat <<EOF > 002.heat/heat-with-constraints2.in
# Lipid 144 heating 310K for 195 ps
 &cntrl
  imin=0,
  ntx=5,
  irest=1,
  ntc=2,
  ntf=2,
  tol=0.0000001,
  nstlim=97500,
  ntt=3,
  gamma_ln=1.0,
  ntr=1,
  ig=-1,
  ntpr=100,
  ntwr=10000,
  ntwx=100,
  dt=0.002,
  nmropt=1,
  ntb=2,
  ntp=2,
  taup=2.0,
  cut=10.0,
  ioutfm=1,
  ntxo=2,
  iwrap=1,
  restraint_wt=10.0,
  $amber_restraints
 /
 &wt type='TEMP0', istep1=0, istep2=97500,
                   value1=100.0, value2=310.0 /
 &wt type='END' /

EOF
echo "" >> 002.heat/heat-with-constraints2.in

# Create trajectory directories and the corresponding input files
for ((traj=1; traj<=number_of_trajectories; traj++)); do
    directories=("Traj${traj}/003.equil" "Traj${traj}/004.prod")
    for dir in "${directories[@]}"; do
        if [ -d "$dir" ]; then
            echo "Error: Directory \'$dir\' already exists."
            exit 1
        fi
        mkdir -p "$dir"
    done

    # Equilibration script
    cat <<EOF > Traj${traj}/003.equil/equil.in
    # Equilibration 1ns at 310K
     &cntrl
       imin=0, ntx=5, irest=1, 
       ntc=2, ntf=2, tol=0.0000001,
       nstlim=500000, ntt=3, gamma_ln=1.0,
       temp0=310.0,
       ntpr=5000, ntwr=250000, ntwx=25000,
       dt=0.002, ig=-1, iwrap=1,
       ntb=2, cut=10.0, ioutfm=1, ntxo=2,
       ntp=2,
     /
     /
     &ewald
      skinnb=3.0,
     /

EOF
	
    echo "" >> Traj${traj}/003.equil/equil.in

    # Production script
    cat <<EOF > Traj${traj}/004.prod/production.in
    # Production 10 ns NPT at 310K
     &cntrl
       imin=0, ntx=5, irest=1,
       ntc=2, ntf=2, tol=0.0000001,
       nstlim=5000000, ntt=3, gamma_ln=2.0,
       temp0=310.0,
       ntpr=5000, ntwr=2500000, ntwx=5000,
       dt=0.002, ig=-1, iwrap=1,
       ntb=2, cut=10.0, ioutfm=1, ntxo=2,
       ntp=2, barostat=2,
     /

EOF
	
    echo "" >> Traj${traj}/004.prod/production.in
done
