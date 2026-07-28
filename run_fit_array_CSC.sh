#!/bin/bash
# Fit one MCMC chain per array task with Hmsc-HPC on CSC Roihu =====
# Submit from inside the tutorial folder:  sbatch run_fit_array_CSC.sh
# One-time environment setup is described in SETUP.md.

#SBATCH --job-name=hmsc_fit
#SBATCH --account=project_XXXXXXX                                                  # <-- EDIT: your CSC project number
#SBATCH --partition=gpumedium                                                          
#SBATCH --gres=gpu:gh200:1                                                         # 1 GPU (a Hopper H100) per task
#SBATCH --cpus-per-task=72                                                         # the 72 ARM cores tied to one GH200
#SBATCH --time=06:00:00                                            
#SBATCH --array=0-3                                                                # one task per chain: 0 .. (nChains - 1)
#SBATCH --output=/scratch/project_XXXXXXX/Hmsc_HPC_tutorial/logs/fit_%A_%a.out     # <-- EDIT: your CSC project number & folder name

# --- Environment -------------------------------------------------------------
module purge
module load python-tensorflow/2.21 
source /projappl/project_XXXXXXX/hmsc_tf_env/bin/activate                          # <-- EDIT: Path to an existing Python environment

# --- Experiment settings: MUST match S1_export_init.R --------------------
project="Hmsc_HPC_tutorial"                                                        # <-- EDIT: The project name from S1_export_init.R
samples=250                                                                        # <-- EDIT: The samples set in S1_export_init.R
thin=10                                                                            # <-- EDIT: The thin set in S1_export_init.R
nChains=4                                                                          # <-- EDIT: The number of chains set in S1_export_init.R
transient=$(( samples * thin / 2 ))                            

# --- Paths (relative to the submission folder) -------------------------------
directory="/scratch/project_XXXXXXX/Hmsc_HPC_tutorial"                             # <-- EDIT: your CSC project number & folder name
mkdir -p "${directory}/fmTF" "${directory}/logs"
INIT_DIR="$directory/init"
POST_DIR="$directory/fmTF"

chain=$SLURM_ARRAY_TASK_ID
stem="${project}_${nChains}chains_${samples}samples_${thin}thin"
init_file="$INIT_DIR/${stem}_init.rds"
post_file="$POST_DIR/${stem}_${chain}chain_post.rds"

# --- Fit (skip if this chain is already done) --------------------------------
if [ -f "$post_file" ]; then
  echo "Already done, skipping: $post_file"
  exit 0
fi

echo "Fitting chain $chain of $nChains ($samples samples, thin $thin) ..."
srun python3 -m hmsc.run_gibbs_sampler \
  --input  "$init_file" \
  --output "$post_file" \
  --samples "$samples" --transient "$transient" --thin "$thin" \
  --chain "$chain" --verbose 100


# ===========================================================================
# SCALING UP (optional): array over thins x model_types x response_types x chains
# ===========================================================================
# Set --array=0-(N-1) with N = nThins * nModelTypes * nResponseTypes * nChains,
# then decode the flat task id into the four indices (same naming as S2HPCa):
#
# thins=(10 100)
# model_types=(default tight_prior)
# response_types=(setA setB)
# nChains=4
#
# combo=$(( SLURM_ARRAY_TASK_ID / nChains ))
# chain=$(( SLURM_ARRAY_TASK_ID % nChains ))
# thin_idx=$(( combo / (${#model_types[@]} * ${#response_types[@]}) ))
# mt_idx=$(( (combo / ${#response_types[@]}) % ${#model_types[@]} ))
# rt_idx=$(( combo % ${#response_types[@]} ))
# thin=${thins[$thin_idx]}
# model_type=${model_types[$mt_idx]}
# response_type=${response_types[$rt_idx]}
# transient=$(( samples * thin / 2 ))
# stem="${project}_${model_type}_${response_type}_${nChains}chains_${samples}samples_${thin}thin"
# init_file="$INIT_DIR/${stem}_init.rds"
# post_file="$POST_DIR/${stem}_${chain}chain_post.rds"
# srun python3 -m hmsc.run_gibbs_sampler --input "$init_file" --output "$post_file" \
#   --samples "$samples" --transient "$transient" --thin "$thin" --chain "$chain" --verbose 100
