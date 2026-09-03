# Hmsc-HPC on CSC Roihu — setup and workflow

This folder fits an Hmsc model on a GPU with Hmsc-HPC. Three scripts:

- `HMSC_HPC_tutorial.Rproj` — the RStudio project file. Open first locally to set the correct working directory; alternatively, set working directory manually in R scripts using `setwd()`
- `S1_export_init.R` — build the model, write the init file (run locally)
- `run_fit_array_CSC.sh` — fit one chain per array task on the cluster (this file lives on CSC)
- `S2_import_posterior.R` — combine the chains into a fitted model (run locally)

## 1. Python side: Hmsc-HPC in a virtual environment

Run once on a Roihu GPU **login** node (Roihu online Dasboard: roihu.csc.fi → `Tools` → `Login node shell (Roihu-GPU)`) (replace `project_XXXXXXX` with your project).

```bash
module load python-tensorflow/2.21
python3 -m venv --system-site-packages /projappl/project_XXXXXXX/hmsc_tf_env
source /projappl/project_XXXXXXX/hmsc_tf_env/bin/activate
pip install git+https://github.com/hmsc-r/hmsc-hpc.git
```

If you can see a 'hmsc_tf_env' folder in projappl/project_XXXXXXX, chances are this has already 
been set up, so the above is not necessary. 

## 2. End-to-end workflow

0. Download the whole repository as ZIP, then unzip.
1. Double-click `HMSC_HPC_tutorial.Rproj` inside the unzipped folder. From there, run `S1_export_init.R` → creates `init/` and `models/` on your local computer
2. Copy this whole `init/` folder and the `run_fit_array_CSC.sh` script (edited to fit your specific analysis) to the scratch folder in CSC `/scratch/project_XXXXXXX/<your_folder>`, using the 
   online home directory (https://www.roihu.csc.fi)
3. Open a GPU login node shell in the online dashboard (`Tools` → `Login node shell (Roihu-GPU)`) 
   (WINDOWS USERS: If you worked on the `run_fit_array_CSC.sh` script using Windows, 
   run this first from the Roihu GPU login shell to prevent format errors:  
   `dos2unix /scratch/project_XXXXXXX/<your_folder>/run_fit_array_CSC.sh`)
4. Run `sbatch /scratch/project_XXXXXXX/<your_folder>/run_fit_array_CSC.sh` → fits one chain per array task → `fmTF/`
(optional: Check that GPU implementation worked: View log file in `logs`, confirm print output `Created device /job:localhost/replica:0/task:0/device:GPU:0 with 94915 MB memory:  -> device: 0, name: NVIDIA GH200 120GB`)
5. copy `fmTF/` back to your local computer using the online dashboard (https://www.roihu.csc.fi), 
   then run `S2_import_posterior.R` → creates fitted model in `models/`

The experiment settings (`samples`, `thin`, `nChains`, `project`) appear in all
three scripts and **must match**. The job array size must equal `nChains`
(`--array=0-3` for 4 chains).
