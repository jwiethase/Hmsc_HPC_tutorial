# Build an Hmsc model and export it for Hmsc-HPC =====
# Run this on your laptop or a CSC login node (no GPU needed). It writes an
# "init" file that the GPU Gibbs sampler reads on the cluster, plus a copy of
# the unfitted model that script S2 needs later.

## Packages =====
# Hmsc >= 3.4-1 is required: it writes the init object as a native .rds that
# Hmsc-HPC reads directly. pak is the modern replacement for install_github().
required_version <- "3.4-1"
if (!requireNamespace("Hmsc", quietly = TRUE) || packageVersion("Hmsc") < required_version) {
  if (!requireNamespace("pak", quietly = TRUE)) install.packages("pak")
  pak::pak("hmsc-r/HMSC")
}
library(Hmsc)
set.seed(1)  # reproducible starting values

## Folders =====
project <- "Hmsc_HPC_tutorial"
dirs <- list(init = "init", models = "models")
for (d in dirs) dir.create(d, recursive = TRUE, showWarnings = FALSE)

## Example data and model =====
data(TD, package = "Hmsc")
Y <- TD$Y                      
XData <- TD$X                  
studyDesign <- TD$studyDesign  
rL <- HmscRandomLevel(units = studyDesign$sample)

m <- Hmsc(Y = Y, XData = XData, XFormula = ~ x1 + x2,
          studyDesign = studyDesign, ranLevels = list(sample = rL),
          distr = "probit")

# Save the unfitted model so S2 can re-attach the fitted posterior from the HPC to it
saveRDS(m, file.path(dirs$models, paste0(project, "_unfitted.rds")))

## MCMC settings (kept small for the tutorial; MUST match the job script so it can find the files) =====
samples <- 250    # posterior samples kept per chain
thin <- 10        # keep 1 of every `thin` iterations
nChains <- 4      # number of chains -> array size in the job script
transient <- samples * thin / 2   # burn-in iterations (discarded)

## Export the init file =====
# engine = "HPC" prepares the model and per-chain starting values and returns
# them (it does not sample). 
init_obj <- sampleMcmc(m, samples = samples, thin = thin, transient = transient,
                       nChains = nChains, verbose = 1, engine = "HPC")

stem <- sprintf("%s_%dchains_%dsamples_%dthin", project, nChains, samples, thin)
init_path <- file.path(dirs$init, paste0(stem, "_init.rds"))
saveRDS(init_obj, init_path)

# ===========================================================================
# SCALING UP (optional): one init file per combination of settings
# ===========================================================================
# Often you want several models at once: different priors, different predictor
# sets, different response matrices, and/or different thinning. Build one model
# per (model_type, response_type) and one init file per (model_type,
# response_type, thin). The job script then fits every (combination x chain) as
# one array task. Replace build_model() with your own model-construction code.
#
# model_types    <- c("default", "tight_prior")  # e.g. different priors/formulas
# response_types <- c("setA", "setB")             # e.g. different Y matrices
# thins          <- c(10, 100)
# nChains <- 4; samples <- 250
#
# for (mt in model_types) {
#   for (rt in response_types) {
#     m <- build_model(mt, rt)  # <- returns an Hmsc model for this combination
#     saveRDS(m, file.path(dirs$models, sprintf("%s_%s_%s_unfitted.rds", project, mt, rt)))
#     for (th in thins) {
#       transient <- samples * th / 2
#       init_obj <- sampleMcmc(m, samples = samples, thin = th, transient = transient,
#                              nChains = nChains, verbose = 1, engine = "HPC")
#       stem <- sprintf("%s_%s_%s_%dchains_%dsamples_%dthin", project, mt, rt, nChains, samples, th)
#       saveRDS(init_obj, file.path(dirs$init, paste0(stem, "_init.rds")))
#     }
#   }
# }
