#!/bin/bash
#SBATCH --job-name=ts_satfire_temp_pred
#SBATCH --mail-type=ALL
#SBATCH --mail-user=s320062@studenti.polito.it
#SBATCH --gres=gpu:1
#SBATCH --nodes=1
#SBATCH --output=ts_satfire_stPred_%j.log
#SBATCH --ntasks=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=24
#SBATCH --mem=128G
#SBATCH --time=0-06:00:00
#SBATCH --partition=gpu_a40

set -euo pipefail

module purge
module load miniconda3/3.13.25
eval "$(conda shell.bash hook)"

mkdir -p $SCRATCH/TS-SatFire
rsync -av $HOME/github/TS-SatFire/ $SCRATCH/TS-SatFire/
cd $SCRATCH/TS-SatFire

conda activate $SCRATCH/conda-envs/ts-satfire
export WANDB_MODE=disabled
python run_spatial_temp_model_pred.py -m swinunetr3d -mode pred -b 8 -r 1 -lr 0.001 -nh 3 -ed 36 -nc 43 -ts 3 -it 1

#$SCRATCH/conda-envs/ts-satfire/bin/python -c "import torchvision; print('torchvision OK:', torchvision.__version__)"
#$SCRATCH/conda-envs/ts-satfire/bin/python run_spatial_temp_model_pred.py -m SwinUNETR -mode pred -b 8 -r 1 -lr 0.001 -nh 3 -ed 24 -nc 8 -ts 3 -it 1 -test


# to run:
# sbatch <name of this file>
# scontrol show job <the id of the job, given by previous command>