#!/bin/bash
#SBATCH --job-name=ts_satfire_gen
#SBATCH --mail-type=ALL
#SBATCH --mail-user=s320062@studenti.polito.it
#SBATCH --nodes=1
#SBATCH --output=ts_satfire_datagen_%j.log
#SBATCH --ntasks=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=24
#SBATCH --mem=128G
#SBATCH --time=0-12:00:00
#SBATCH --partition=cpu_sapphire

set -euo pipefail

module purge
module load miniconda3/3.13.25
eval "$(conda shell.bash hook)"

mkdir -p $SCRATCH/TS-SatFire
rsync -av $HOME/github/TS-SatFire/ $SCRATCH/TS-SatFire/
cd $SCRATCH/TS-SatFire

conda activate $SCRATCH/conda-envs/ts-satfire

mkdir -p $SCRATCH/TS-SatFire/dataset/dataset_train
mkdir -p $SCRATCH/TS-SatFire/dataset/dataset_val
mkdir -p $SCRATCH/TS-SatFire/dataset/dataset_test

# the important part
python dataset_gen_pred.py -mode train -ts 3 -it 1
#python dataset_gen_pred.py -mode val -ts 3 -it 1
#python dataset_gen_pred.py -mode test -ts 3 -it 1

rsync -av $SCRATCH/TS-SatFire/dataset/ $HOME/github/TS-SatFire/dataset/

# to run:
# sbatch <name of this file>
# scontrol show job <the id of the job, given by previous command>