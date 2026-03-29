#!/bin/bash
#SBATCH --job-name=ts_satfire
#SBATCH --mail-type=ALL
#SBATCH --mail-user=s320062@studenti.polito.it
#SBATCH --nodes=1
#SBATCH --output=ts_satfire_%j.log
#SBATCH --ntasks=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=24
#SBATCH --mem=64G
#SBATCH --time=0-12:00:00
#SBATCH --partition=cpu_sapphire


module purge
module load miniconda3/3.13.25

# Initialize conda for this shell session
eval "$(conda shell.bash hook)"

# Create the working directory on scratch and copy files
mkdir -p $SCRATCH/TS-SatFire
cp -r $HOME/github/TS-SatFire/* $SCRATCH/TS-SatFire/
cd $SCRATCH/TS-SatFire

# Create the conda env only if it doesn't already exist
# Use --prefix to place it on scratch, avoiding the 30-day cleanup hitting your home
if [ ! -d "$SCRATCH/conda-envs/ts-satfire" ]; then
    conda env create --prefix $SCRATCH/conda-envs/ts-satfire --file environment.yml
fi

conda activate $SCRATCH/conda-envs/ts-satfire

python $SCRATCH/TS-SatFire/datagen_gen_pred.py -mode train -ts 3 -it 1

rsync -av $SCRATCH/TS-SatFire/* $HOME/github/TS-SatFire/
