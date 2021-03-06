####################################################################################
## Purpose:
##
## Notes:
####################################################################################
library(tidyverse)
library(raster)
library(tidygraph)
library(ggraph)
source("Space_the_Final_Miptier/R/themes.R")
set.seed(48)
#......................
# read data
#......................
ibD <- readRDS("data/derived_data/bigbarcode_genetic_data/mipanalyzer.DRCibD.long.mtdt.rds")
mtdt <- readRDS("data/derived_data/sample_metadata.rds")
#..............................................................
# Idenity samples with IBD that are greater than half the
# genome (i.e. at or above meiotic siblings)
# These represent likely recent transmission events
#..............................................................
ibD.meiotic <- ibD %>%
  dplyr::filter(malecotf >= 0.5)
ibdmeioticsmpls <- as.character(ibD.meiotic$smpl1)
ibdmeioticsmpls <- c(ibdmeioticsmpls, as.character(ibD.meiotic$smpl2))

#..............................................................
# Coordinate for meiotic pair edges
# need to jitter very slightly to account for within cluster
# edges -- otherwise lines edges can't be drawn
#..............................................................
# coord pts
coords.pts <- mtdt %>%
  dplyr::select(c("name", "hv001", "longnum", "latnum")) %>%
  dplyr::filter(name %in% ibdmeioticsmpls)
# add spatial jitter
coords.pts$long_jitter <- coords.pts$longnum + runif(n = nrow(coords.pts), min = -1e-3, max = 1e-3)
coords.pts$lat_jitter <- coords.pts$latnum + runif(n = nrow(coords.pts), min = -1e-3, max = 1e-3)
coords.pts <- coords.pts %>%
  dplyr::select(c("name", "hv001", "long_jitter", "lat_jitter"))
# long connections
colnames(coords.pts)[1] <- "smpl1"
ibD.meiotic <- dplyr::left_join(ibD.meiotic, coords.pts, by = "smpl1")
colnames(coords.pts)[1] <- "smpl2"
ibD.meiotic <- dplyr::left_join(ibD.meiotic, coords.pts, by = "smpl2")
colnames(coords.pts)[1] <- "name"

# write this out for later use
saveRDS(ibD.meiotic, file = "data/derived_data/bigbarcode_genetic_data/meiotic_sibs_mipanalyzer.DRCibD.long.mtdt.rds")
saveRDS(coords.pts, file = "data/derived_data/meiotic_sibs_coordpts.rds")



#..............................................................
# Permutation Testing
#..............................................................
# Wrapper for Meiotic Siblings
meiotic_sib_wrapper <- function(name, nsmpls, IBDdistrib, IBDwi, covardistrib){
  #' @param nsmpls numeric; number of samples to simulate as pairs for IBD
  #' @param IBDdistrib numeric vector; distribution of IBD in population
  #' @param covardistrib numeric vector; distribution of covariate in population

  IBDpermutator <- function(nsmpls, IBDdistrib, IBDwi, covardistrib){

    distmat <- matrix(NA, nrow = nsmpls, ncol = nsmpls)
    smpl.pairs <- sum(lower.tri(distmat, diag = F))
    # ibd
    smpl.pair.IBD <- sample(IBDdistrib, size = smpl.pairs, prob = IBDwi/sum(IBDwi), replace = T)
    # covar
    smpl.pair.covar <- tibble::tibble(
      covar.x = sample(covardistrib, size = smpl.pairs, replace = T),
      covar.y = sample(covardistrib, size = smpl.pairs, replace = T)
    )

    # convert to dist object
    distmat[lower.tri(distmat, diag = F)] <- smpl.pair.IBD
    # long out
    smpl.pair.IBD <- as.dist(distmat) %>%
      broom::tidy(.) %>%
      dplyr::bind_cols(., smpl.pair.covar) %>%
      magrittr::set_colnames(c("smpl1", "smpl2", "simibd", "covar.x", "covar.y"))
    return(smpl.pair.IBD)
  } # end nested function

  #..............................................................
  # Tidy up for meiotic siblings
  #..............................................................

  # given that you are at or above meiotic, this is what your
  # covar distribution should look like
  smpl.pair.IBD <- IBDpermutator(nsmpls, IBDdistrib, IBDwi, covardistrib)
  if (max(smpl.pair.IBD$simibd) >= 0.5) {
    smpl.pair.IBD.meiotic <- smpl.pair.IBD %>%
      dplyr::filter(simibd >= 0.5) %>%
      dplyr::mutate(covardiff = (covar.x - covar.y)^2) # make magnitude same always

    return(smpl.pair.IBD.meiotic$covardiff)

  } else {
    return(NA)
  }

} # end function


#..............................................................
# Bring in covariates for NULLs
#..............................................................
clstcovar <- readRDS("data/derived_data/covar_rasterstack_samplinglocations_raw.RDS")
prevdistrib <- clstcovar$prev
citydistrib <- clstcovar$urban
# find distribution of samples that are from same cluster
# subtraction here will be turned into a binary downstream (i.e. 0 means same cluster)
unique_clst_vs_same_distrib <- mtdt$hv001

#..............................................................
# Save some memory for IBD distribut
#..............................................................
IBDdistrib <- sort( unique(ibD$malecotf) )
IBDwi <- table(ibD$malecotf)
if(!all(names(IBDwi) == IBDdistrib)){
  stop("Issue with IBD distrib uniqueness")
}


#..............................................................
# Run Simulations
#..............................................................
simdf <- tibble::tibble(
  name = c("prev", "urban", "clstwthn"),
  nsmpls = nrow(mtdt),
  IBDdistrib = list(IBDdistrib),
  IBDwi = list(IBDwi),
  covardistrib = list(prevdistrib, citydistrib, unique_clst_vs_same_distrib)
)
iters <- 1e4
simdf <- lapply(1:iters, function(x) return(simdf)) %>%
  dplyr::bind_rows() %>%
  dplyr::arrange(name)

simdf$results <- furrr::future_pmap(simdf, meiotic_sib_wrapper)
# out
dir.create("results/meiotic_perms/", recursive = T)
saveRDS(simdf, file = "results/meiotic_perms/meiotic_permutation_simulations.RDS")
