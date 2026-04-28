#!/bin/bash
#SBATCH --job-name=ts_satfire_env_setup
#SBATCH --mail-type=ALL
#SBATCH --mail-user=s320062@studenti.polito.it
#SBATCH --nodes=1
#SBATCH --output=ts_satfire_%j.log
#SBATCH --ntasks=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=24
#SBATCH --mem=128G
#SBATCH --time=0-6:00:00
#SBATCH --partition=cpu_sapphire

set -euo pipefail

module purge
module load miniconda3/3.13.25
eval "$(conda shell.bash hook)"

# radical purge
if [ ! -d "$SCRATCH/conda-envs/ts-satfire" ]; then
    echo "Removing conda env..."
    conda env remove --prefix $SCRATCH/conda-envs/ts-satfire -y
fi

echo "Deleting Conda-envs folder..."
rm -r $SCRATCH/conda-envs

echo "Deleting TS-SatFire folder..."
rm -r $SCRATCH/TS-SatFire
# ---

# to run:
# sbatch <name of this file>
# scontrol show job <the id of the job, given by previous command>