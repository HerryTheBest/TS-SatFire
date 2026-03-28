#!/bin/bash
#SBATCH --job-name=ts_satfire
#SBATCH --mail-type=ALL
#SBATCH --mail-user=s320062@studenti.polito.it
#SBATCH --gres=gpu:1
#SBATCH --nodes=1
#SBATCH --output=ts_satfire_%j.log
#SBATCH --ntasks=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=32G
#SBATCH --time=0-12:00:00
#SBATCH --partition=gpu_a100


module purge
module load miniconda3/3.13.25
cp $HOME/github/TS-SatFire/* $SCRATCH/TS-SatFire
cd $SCRATCH/TS-SatFire
conda create --name ts-satfire --file environment.yml
conda init
source $SCRATCH/.conda/envs/ts-satfire
conda activate ts-satfire
python $SCRATCH/TS-SatFire/datagen_gen_pred.py -mode train -ts 3 -it 1
rsync $SCRATCH/TS-SatFire/* $HOME/github/TS-SatFire/
