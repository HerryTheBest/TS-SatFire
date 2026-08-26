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
#SBATCH --time=0-12:00:00
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
#python run_spatial_temp_model_pred.py -m swinunetr3d -mode pred -b 8 -r 1 -lr 0.001 -nh 3 -ed 36 -nc 43 -ts 3 -it 1 -test_after_train
#python run_spatial_temp_model_pred.py -m swinunetr3d -mode pred -b 8 -r 1 -lr 0.001 -nh 3 -ed 36 -nc 43 -ts 3 -it 1 -resume model_swinunetr3d_mode_pred_num_heads_3_hidden_size_36_batchsize_8_checkpoint_epoch_80_nc_43_ts_3.pth
python run_spatial_temp_model_pred.py -m swinunetr3d -mode pred -b 8 -r 1 -lr 0.001 -nh 3 -ed 36 -nc 43 -ts 3 -it 1 -test

rsync -av $SCRATCH/TS-SatFire/saved_models/ $HOME/github/TS-SatFire/saved_models/

# to run:
# sbatch <name of this file>
# scontrol show job <the id of the job, given by previous command>