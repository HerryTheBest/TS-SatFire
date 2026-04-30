#!/bin/bash
#SBATCH --job-name=ts_satfire_test
#SBATCH --mail-type=ALL
#SBATCH --mail-user=s320062@studenti.polito.it
#SBATCH --nodes=1
#SBATCH --output=ts_satfire_%j.log
#SBATCH --ntasks=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=24
#SBATCH --mem=128G
#SBATCH --time=0-1:00:00
#SBATCH --partition=cpu_sapphire

module purge
module load miniconda3/3.13.25
eval "$(conda shell.bash hook)"

$SCRATCH/conda-envs/ts-satfire/bin/python - <<'EOF'
import numpy as np

for dataset_path, filename in [
    ('/mnt/beegfs-compat/lsturaro/TS-SatFire/dataset/dataset_train', 'pred_train_img_seqtoseq_alll_3i_1.npy'),
    ('/mnt/beegfs-compat/lsturaro/TS-SatFire/dataset/dataset_val',   'pred_val_img_seqtoseq_alll_3i_1.npy'),
]:
    path = f"{dataset_path}/{filename}"
    print(f"Loading {filename}...")
    data = np.load(path)
    print(f"NaNs before: {np.isnan(data).sum()}")
    data = np.nan_to_num(data, nan=0.0, posinf=0.0, neginf=0.0)
    print(f"NaNs after:  {np.isnan(data).sum()}")
    np.save(path, data)
    print(f"Saved.\n")
EOF