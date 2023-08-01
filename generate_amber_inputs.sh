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
#amber_restraints="restraintmask='(:$residue_start-$residue_end & !@H=)'"
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
Minimization input file in explicit solvent
 &cntrl
    ! Minimization options
    imin=1,        ! Turn on minimization
    maxcyc=5000,   ! Maximum number of minimization cycles
    ncyc=2500,     ! 100 steepest-descent steps, better for strained systems

    ! Potential energy function options
    cut=9.0,       ! nonbonded cutoff, in angstroms

    ! Control how often information is printed to the output file
    ntpr=100,      ! Print energies every 100 steps
    ntxo=2,        ! Write NetCDF format

    ! Restraint options
    ntr=1,         ! Positional restraints for proteins, sugars, ligands, and lipid head groups

    ! Set water atom/residue names for SETTLE recognition
    watnam='WAT',  ! Water residues are named WAT
    owtnm='O',     ! Water oxygens are named O
 /

 &wt
    type='END'
 /
Membrane posres
2.5
FIND
P31 * * PC
SEARCH
RES $residue_start $residue_end
END
END

EOF
echo "" >> 001.min/minimize.in

#cat <<EOF > 001.min/minimize2.in
# Minimization without Cartesian restraints
# &cntrl
# imin=1,
# maxcyc=10000,
# ncyc=5000,
# ntb=1,
# ntr=0,
# cut=12.0
#/
#END

#EOF
#echo "" >> 001.min/minimize2.in

# Heating scripts
cat <<EOF > 002.heat/heat-with-constraints.in
A NVT simulation for common production-level simulations
 &cntrl
    imin=0,        ! No minimization
    irest=0,       ! This is NOT a restart of an old MD simulation
    ntx=1,         ! So our inpcrd file has no velocities

    ! Temperature control
    ntt=3,         ! Langevin dynamics
    gamma_ln=1.0,  ! Friction coefficient (ps^-1)
    tempi=310,     ! Initial temp -- give it some small random velocities
    temp0=310,     ! Target temperature

    ! Potential energy control
    cut=9.0,       ! nonbonded cutoff, in angstroms

    ! MD settings
    nstlim=125000, ! 125K steps, 125 ps total
    dt=0.001,      ! time step (ps)

    ! SHAKE
    ntc=2,         ! Constrain bonds containing hydrogen
    ntf=2,         ! Do not calculate forces of bonds containing hydrogen

    ! Control how often information is printed
    ntpr=1000,     ! Print energies every 1000 steps
    ntwx=5000,     ! Print coordinates every 5000 steps to the trajectory
    ntwr=10000,    ! Print a restart file every 10K steps (can be less frequent)
!   ntwv=-1,       ! Uncomment to also print velocities to trajectory
!   ntwf=-1,       ! Uncomment to also print forces to trajectory
    ntxo=2,        ! Write NetCDF format
    ioutfm=1,      ! Write NetCDF format (always do this!)

    ! Wrap coordinates when printing them to the same unit cell
    iwrap=0,

    ! Restraint options
    ntr=1,         ! Positional restraints for proteins, sugars, ligands, and lipid head groups

    ! Set water atom/residue names for SETTLE recognition
    watnam='WAT',  ! Water residues are named WAT
    owtnm='O',     ! Water oxygens are named O
 /

 &wt
    type='END'
 /
Membrane posres
2.5
FIND
P31 * * PC
SEARCH
RES $residue_start $residue_end
END
END

EOF
echo "" >> 002.heat/heat-with-constraints.in

cat <<EOF > 002.heat/heat-with-constraints2.in
A NVT simulation for common production-level simulations
 &cntrl
    imin=0,        ! No minimization
    irest=1,       ! This IS a restart of an old MD simulation
    ntx=5,         ! So our inpcrd file has velocities

    ! Temperature control
    ntt=3,         ! Langevin dynamics
    gamma_ln=1.0,  ! Friction coefficient (ps^-1)
    temp0=310,     ! Target temperature

    ! Potential energy control
    cut=9.0,       ! nonbonded cutoff, in angstroms

    ! MD settings
    nstlim=125000, ! 125K steps, 125 ps total
    dt=0.001,      ! time step (ps)

    ! SHAKE
    ntc=2,         ! Constrain bonds containing hydrogen
    ntf=2,         ! Do not calculate forces of bonds containing hydrogen

    ! Control how often information is printed
    ntpr=1000,     ! Print energies every 1000 steps
    ntwx=5000,     ! Print coordinates every 5000 steps to the trajectory
    ntwr=10000,    ! Print a restart file every 10K steps (can be less frequent)
!   ntwv=-1,       ! Uncomment to also print velocities to trajectory
!   ntwf=-1,       ! Uncomment to also print forces to trajectory
    ntxo=2,        ! Write NetCDF format
    ioutfm=1,      ! Write NetCDF format (always do this!)

    ! Wrap coordinates when printing them to the same unit cell
    iwrap=0,

    ! Restraint options
    ntr=1,         ! Positional restraints for proteins, sugars, ligands, and lipid head groups

    ! Set water atom/residue names for SETTLE recognition
    watnam='WAT',  ! Water residues are named WAT
    owtnm='O',     ! Water oxygens are named O
 /

 &wt
    type='END'
 /
Membrane posres
2.5
FIND
P31 * * PC
SEARCH
RES $residue_start $residue_end
END
END

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
    cat <<EOF > Traj${traj}/003.equil/equil.1.in
A NPT simulation for common production-level simulations
 &cntrl
	imin=0,        ! No minimization
	irest=1,       ! This IS a restart of an old MD simulation
	ntx=5,         ! So our inpcrd file has velocities

	! Temperature control
	ntt=3,         ! Langevin dynamics
	gamma_ln=1.0,  ! Friction coefficient (ps^-1)
	temp0=310,     ! Target temperature

	! Potential energy control
	cut=9.0,       ! nonbonded cutoff, in angstroms

	! MD settings
	nstlim=125000, ! 125K steps, 125 ps total
	dt=0.001,      ! time step (ps)

	! SHAKE
	ntc=2,         ! Constrain bonds containing hydrogen
	ntf=2,         ! Do not calculate forces of bonds containing hydrogen

	! Control how often information is printed
	ntpr=1000,     ! Print energies every 1000 steps
	ntwx=5000,     ! Print coordinates every 5000 steps to the trajectory
	ntwr=10000,    ! Print a restart file every 10K steps (can be less frequent)
!   ntwv=-1,       ! Uncomment to also print velocities to trajectory
!   ntwf=-1,       ! Uncomment to also print forces to trajectory
	ntxo=2,        ! Write NetCDF format
	ioutfm=1,      ! Write NetCDF format (always do this!)

	! Wrap coordinates when printing them to the same unit cell
	iwrap=0,

	! Constant pressure control.
	barostat=1,    ! Berendsen barostat... change to 2 for MC
	ntp=3,         ! 1=isotropic, 2=anisotropic, 3=semi-isotropic w/ surften
	pres0=1.0,     ! Target external pressure, in bar
	taup=1.0,

	! Constant surface tension (needed for semi-isotropic scaling). Uncomment
	! for this feature. csurften must be nonzero if ntp=3 above
	csurften=3,    ! Interfaces in 1=yz plane, 2=xz plane, 3=xy plane
	gamma_ten=0.0, ! Surface tension (dyne/cm). 0 gives pure semi-iso scaling
	ninterface=2,  ! Number of interfaces (2 for bilayer)

	! Restraint options
	ntr=1,         ! Positional restraints for proteins, sugars, ligands, and lipid head groups

	! Set water atom/residue names for SETTLE recognition
	watnam='WAT',  ! Water residues are named WAT
	owtnm='O',     ! Water oxygens are named O
 /

 &wt
	type='END'
 /
Membrane posres
1.0
FIND
P31 * * PC
SEARCH
RES $residue_start $residue_end
END
END

EOF
	
    echo "" >> Traj${traj}/003.equil/equil.1.in
	
	cat <<EOF > Traj${traj}/003.equil/equil.2.in
A NPT simulation for common production-level simulations
 &cntrl
	imin=0,        ! No minimization
	irest=1,       ! This IS a restart of an old MD simulation
	ntx=5,         ! So our inpcrd file has velocities

	! Temperature control
	ntt=3,         ! Langevin dynamics
	gamma_ln=1.0,  ! Friction coefficient (ps^-1)
	temp0=310,     ! Target temperature

	! Potential energy control
	cut=9.0,       ! nonbonded cutoff, in angstroms

	! MD settings
	nstlim=250000, ! 250K steps, 500 ps total
	dt=0.002,      ! time step (ps)

	! SHAKE
	ntc=2,         ! Constrain bonds containing hydrogen
	ntf=2,         ! Do not calculate forces of bonds containing hydrogen

	! Control how often information is printed
	ntpr=1000,     ! Print energies every 1000 steps
	ntwx=5000,     ! Print coordinates every 5000 steps to the trajectory
	ntwr=10000,    ! Print a restart file every 10K steps (can be less frequent)
!   ntwv=-1,       ! Uncomment to also print velocities to trajectory
!   ntwf=-1,       ! Uncomment to also print forces to trajectory
	ntxo=2,        ! Write NetCDF format
	ioutfm=1,      ! Write NetCDF format (always do this!)

	! Wrap coordinates when printing them to the same unit cell
	iwrap=0,

	! Constant pressure control.
	barostat=1,    ! Berendsen barostat... change to 2 for MC
	ntp=3,         ! 1=isotropic, 2=anisotropic, 3=semi-isotropic w/ surften
	pres0=1.0,     ! Target external pressure, in bar
	taup=1.0,

	! Constant surface tension (needed for semi-isotropic scaling). Uncomment
	! for this feature. csurften must be nonzero if ntp=3 above
	csurften=3,    ! Interfaces in 1=yz plane, 2=xz plane, 3=xy plane
	gamma_ten=0.0, ! Surface tension (dyne/cm). 0 gives pure semi-iso scaling
	ninterface=2,  ! Number of interfaces (2 for bilayer)

	! Restraint options
	ntr=1,         ! Positional restraints for proteins, sugars, ligands, and lipid head groups

	! Set water atom/residue names for SETTLE recognition
	watnam='WAT',  ! Water residues are named WAT
	owtnm='O',     ! Water oxygens are named O
 /

 &wt
	type='END'
 /
Membrane posres
0.5
FIND
P31 * * PC
SEARCH
RES $residue_start $residue_end
END
END

EOF
	
    echo "" >> Traj${traj}/003.equil/equil.2.in
	
	cat <<EOF > Traj${traj}/003.equil/equil.3.in
A NPT simulation for common production-level simulations
 &cntrl
	imin=0,        ! No minimization
	irest=1,       ! This IS a restart of an old MD simulation
	ntx=5,         ! So our inpcrd file has velocities

	! Temperature control
	ntt=3,         ! Langevin dynamics
	gamma_ln=1.0,  ! Friction coefficient (ps^-1)
	temp0=310,     ! Target temperature

	! Potential energy control
	cut=9.0,       ! nonbonded cutoff, in angstroms

	! MD settings
	nstlim=250000, ! 250K steps, 500 ps total
	dt=0.002,      ! time step (ps)

	! SHAKE
	ntc=2,         ! Constrain bonds containing hydrogen
	ntf=2,         ! Do not calculate forces of bonds containing hydrogen

	! Control how often information is printed
	ntpr=1000,     ! Print energies every 1000 steps
	ntwx=5000,     ! Print coordinates every 5000 steps to the trajectory
	ntwr=10000,    ! Print a restart file every 10K steps (can be less frequent)
!   ntwv=-1,       ! Uncomment to also print velocities to trajectory
!   ntwf=-1,       ! Uncomment to also print forces to trajectory
	ntxo=2,        ! Write NetCDF format
	ioutfm=1,      ! Write NetCDF format (always do this!)

	! Wrap coordinates when printing them to the same unit cell
	iwrap=0,

	! Constant pressure control.
	barostat=1,    ! Berendsen barostat... change to 2 for MC
	ntp=3,         ! 1=isotropic, 2=anisotropic, 3=semi-isotropic w/ surften
	pres0=1.0,     ! Target external pressure, in bar
	taup=1.0,

	! Constant surface tension (needed for semi-isotropic scaling). Uncomment
	! for this feature. csurften must be nonzero if ntp=3 above
	csurften=3,    ! Interfaces in 1=yz plane, 2=xz plane, 3=xy plane
	gamma_ten=0.0, ! Surface tension (dyne/cm). 0 gives pure semi-iso scaling
	ninterface=2,  ! Number of interfaces (2 for bilayer)

	! Restraint options
	ntr=1,         ! Positional restraints for proteins, sugars, ligands, and lipid head groups

	! Set water atom/residue names for SETTLE recognition
	watnam='WAT',  ! Water residues are named WAT
	owtnm='O',     ! Water oxygens are named O
 /

 &wt
	type='END'
 /
Membrane posres
0.1
FIND
P31 * * PC
SEARCH
RES $residue_start $residue_end
END
END

EOF
	
    echo "" >> Traj${traj}/003.equil/equil.3.in
	
	cat <<EOF > Traj${traj}/003.equil/equil.4.in
A NPT simulation for common production-level simulations
 &cntrl
	imin=0,        ! No minimization
	irest=1,       ! This IS a restart of an old MD simulation
	ntx=5,         ! So our inpcrd file has velocities

	! Temperature control
	ntt=3,         ! Langevin dynamics
	gamma_ln=1.0,  ! Friction coefficient (ps^-1)
	temp0=310,     ! Target temperature

	! Potential energy control
	cut=9.0,       ! nonbonded cutoff, in angstroms

	! MD settings
	nstlim=250000, ! 250K steps, 500 ps total
	dt=0.002,      ! time step (ps)

	! SHAKE
	ntc=2,         ! Constrain bonds containing hydrogen
	ntf=2,         ! Do not calculate forces of bonds containing hydrogen

	! Control how often information is printed
	ntpr=1000,     ! Print energies every 1000 steps
	ntwx=5000,     ! Print coordinates every 5000 steps to the trajectory
	ntwr=10000,    ! Print a restart file every 10K steps (can be less frequent)
!   ntwv=-1,       ! Uncomment to also print velocities to trajectory
!   ntwf=-1,       ! Uncomment to also print forces to trajectory
	ntxo=2,        ! Write NetCDF format
	ioutfm=1,      ! Write NetCDF format (always do this!)

	! Wrap coordinates when printing them to the same unit cell
	iwrap=0,

	! Constant pressure control.
	barostat=1,    ! Berendsen barostat... change to 2 for MC
	ntp=3,         ! 1=isotropic, 2=anisotropic, 3=semi-isotropic w/ surften
	pres0=1.0,     ! Target external pressure, in bar
	taup=1.0,

	! Constant surface tension (needed for semi-isotropic scaling). Uncomment
	! for this feature. csurften must be nonzero if ntp=3 above
	csurften=3,    ! Interfaces in 1=yz plane, 2=xz plane, 3=xy plane
	gamma_ten=0.0, ! Surface tension (dyne/cm). 0 gives pure semi-iso scaling
	ninterface=2,  ! Number of interfaces (2 for bilayer)

	! Set water atom/residue names for SETTLE recognition
	watnam='WAT',  ! Water residues are named WAT
	owtnm='O',     ! Water oxygens are named O
 /

EOF
	
    echo "" >> Traj${traj}/003.equil/equil.4.in

    # Production script
    cat <<EOF > Traj${traj}/004.prod/production.in
A NPT simulation for common production-level simulations
 &cntrl
	imin=0,        ! No minimization
	irest=1,       ! This IS a restart of an old MD simulation
	ntx=5,         ! So our inpcrd file has velocities

	! Temperature control
	ntt=3,         ! Langevin dynamics
	gamma_ln=1.0,  ! Friction coefficient (ps^-1)
	temp0=310,     ! Target temperature

	! Potential energy control
	cut=9.0,       ! nonbonded cutoff, in Angstroms

	! MD settings
	nstlim=5000000,! 10 ns total
	dt=0.002,      ! time step (ps)

	! SHAKE
	ntc=2,         ! Constrain bonds containing hydrogen
	ntf=2,         ! Do not calculate forces of bonds containing hydrogen

	! Control how often information is printed
	ntpr=20000,    ! Print energies every 10000 steps
	ntwx=10000,    ! Print coordinates every 50000 steps to the trajectory
	ntwr=2500000,  ! Print a restart file every 2500K steps (can be less frequent)
!   ntwv=-1,       ! Uncomment to also print velocities to trajectory
!   ntwf=-1,       ! Uncomment to also print forces to trajectory
	ntxo=2,        ! Write NetCDF format
	ioutfm=1,      ! Write NetCDF format (always do this!)

	! Wrap coordinates when printing them to the same unit cell
	iwrap=1,

	! Constant pressure control.
	barostat=1,    ! Berendsen barostat... change to 2 for MC
	ntp=3,         ! 1=isotropic, 2=anisotropic, 3=semi-isotropic w/ surften
	pres0=1.0,     ! Target external pressure, in bar
	taup=1.0,

	! Constant surface tension (needed for semi-isotropic scaling). Uncomment
	! for this feature. csurften must be nonzero if ntp=3 above
	csurften=3,    ! Interfaces in 1=yz plane, 2=xz plane, 3=xy plane
	gamma_ten=0.0, ! Surface tension (dyne/cm). 0 gives pure semi-iso scaling
	ninterface=2,  ! Number of interfaces (2 for bilayer)

	! Set water atom/residue names for SETTLE recognition
	watnam='WAT',  ! Water residues are named WAT
	owtnm='O',     ! Water oxygens are named O
 /
EOF
	
    echo "" >> Traj${traj}/004.prod/production.in
done
