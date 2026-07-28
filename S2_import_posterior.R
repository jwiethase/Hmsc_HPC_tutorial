# Re-attach Hmsc-HPC posterior samples to the model =====
# Run after all chains have finished on the cluster and you have copied the
# fmTF/ folder back. Combines the per-chain posterior files into a normal
# fitted Hmsc object you can use with the usual Hmsc post-processing functions.

## Packages =====
required_version <- "3.4-1"
if (!requireNamespace("Hmsc", quietly = TRUE) || packageVersion("Hmsc") < required_version) {
  if (!requireNamespace("pak", quietly = TRUE)) install.packages("pak")
  pak::pak("hmsc-r/HMSC")
}
library(Hmsc)
library(ggplot2)

## Settings: MUST match S1_export_init.R and the job script =====
project <- "Hmsc_HPC_tutorial"
samples <- 250
thin <- 10
nChains <- 4
transient <- samples * thin / 2

dirs <- list(models = "models", post = "fmTF")
stem <- sprintf("%s_%dchains_%dsamples_%dthin", project, nChains, samples, thin)

## Load the unfitted model and the posterior chains =====
m <- readRDS(file.path(dirs$models, paste0(project, "_unfitted.rds")))

# Hmsc-HPC writes one file per chain. Each file is a list with $list (the chains
# it contains) and $time; a single-chain file therefore lives in $list[[1]].
chainList <- vector("list", nChains)
for (chain in 0:(nChains - 1)) {  # Python numbers chains from 0
  post_path <- file.path(dirs$post, sprintf("%s_%dchain_post.rds", stem, chain))
  chainList[[chain + 1]] <- readRDS(post_path)$list[[1]]
}

## Combine into a fitted Hmsc object =====
# nSamples/thin/transient must match the fitting run so the object behaves
# correctly in downstream functions.
fm <- importPosteriorFromHPC(m, chainList, nSamples = samples, thin = thin,
                             transient = transient)
saveRDS(fm, file.path(dirs$models, paste0(stem, "_fitted.rds")))

## Quick convergence check =====
# Gelman-Rubin diagnostic (PSRF) on the environmental responses (Beta);
# values close to 1 indicate the chains have converged.

mpost <- convertToCodaObject(fm, alpha = !is.null(fm$rL) && any(sapply(fm$rL, function(x) !is.null(x$s))))

## Convergence: Beta PSRF & ESS =====
psrf <- coda::gelman.diag(mpost$Beta, multivariate = FALSE)$psrf[, 1]
ess <- coda::effectiveSize(mpost$Beta)
df <- rbind(data.frame(metric = "PSRF", value = psrf),
            data.frame(metric = "ESS", value = ess))
df$metric <- factor(df$metric, c("PSRF", "ESS"))

ggplot(df, aes(metric, value)) +
  geom_violin(fill = "grey85") +
  geom_jitter(width = 0.08, size = 0.4, alpha = 0.2) +
  geom_hline(data = data.frame(metric = factor("PSRF", c("PSRF", "ESS")), y = 1.1),
             aes(yintercept = y), linetype = 2, colour = "red") +
  facet_wrap(~metric, scales = "free") +
  labs(x = NULL, y = NULL) +
  theme_bw()

plotVariancePartitioning(fm, computeVariancePartitioning(fm))


# ===========================================================================
# SCALING UP (optional): loop over the same combinations as S2HPCa
# ===========================================================================
# model_types    <- c("default", "tight_prior")
# response_types <- c("setA", "setB")
# thins          <- c(10, 100)
#
# for (mt in model_types) {
#   for (rt in response_types) {
#     m <- readRDS(file.path(dirs$models, sprintf("%s_%s_%s_unfitted.rds", project, mt, rt)))
#     for (th in thins) {
#       transient <- samples * th / 2
#       stem <- sprintf("%s_%s_%s_%dchains_%dsamples_%dthin", project, mt, rt, nChains, samples, th)
#       chainList <- vector("list", nChains)
#       for (chain in 0:(nChains - 1)) {
#         post_path <- file.path(dirs$post, sprintf("%s_%dchain_post.rds", stem, chain))
#         chainList[[chain + 1]] <- readRDS(post_path)$list[[1]]
#       }
#       fm <- importPosteriorFromHPC(m, chainList, nSamples = samples, thin = th, transient = transient)
#       saveRDS(fm, file.path(dirs$models, paste0(stem, "_fitted.rds")))
#     }
#   }
# }
