**Molecular Dynamics Simulations with AMBER**

In this repository, you'll find two shell scripts designed to perform Molecular Dynamics (MD) simulations using the AMBER suite of programs. 

The first script, generate_amber_inputs.sh, creates the required input files for AMBER simulations. It enables the generation of multiple trajectories with ligand constraints specified by a range of residues. 

The second script, run_md_simulations.sh, executes preproduction or production MD simulations on a specified system using the AMBER suite of programs. 

To use these scripts, follow these steps: 

1. Generate the necessary input files by running generate_amber_inputs.sh with the desired parameters: 

_./generate_amber_inputs.sh [RESIDUE_START] [RESIDUE_END] [NUMBER_OF_TRAJECTORIES]_

2. Run the MD simulations by executing run_md_simulations.sh with the appropriate arguments: 

_./run_md_simulations.sh [SYSTEM NAME] [CPU] [0/1] [GPU INDEX] [MD Start] [MD Stop]_

For more detailed instructions on how to use these scripts, please refer to the comments in each script.
