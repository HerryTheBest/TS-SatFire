#!/bin/bash
#SBATCH --job-name=ts_satfire_download_wind
#SBATCH --mail-type=ALL
#SBATCH --mail-user=s320062@studenti.polito.it
#SBATCH --nodes=1
#SBATCH --output=ts_satfire_dWind_%j.log
#SBATCH --ntasks=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=24
#SBATCH --mem=128G
#SBATCH --time=0-1:00:00
#SBATCH --partition=cpu_sapphire

module purge
module load miniconda3/3.13.25
eval "$(conda shell.bash hook)"

#mkdir $SCRATCH_FLASH/TS-SatFire/hrrr_wind
rsync -av --exclude '*.log' $HOME/github/TS-SatFire/ $SCRATCH_FLASH/TS-SatFire/ 

cd $SCRATCH_FLASH/TS-SatFire/

#pip install netcdf4

python download_hrrr_wind.py --test --years 2017 --output $SCRATCH_FLASH/TS-SatFire/hrrr_wind

rsync -av --exclude '*.png' $SCRATCH_FLASH/TS-SatFire/ $HOME/github/TS-SatFire/ 
