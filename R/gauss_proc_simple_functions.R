library(tidyverse)
library(sf)
library(PrevMap)

#----------------------------------------------------------------------------------------------------
# Guassian Surface Plot
#----------------------------------------------------------------------------------------------------
logit <- function(x, tol=1e-4){
  return( log(((x+tol)/(1-x+tol))) )
}


fit_pred_spMLE <- function(outcome, covar,
                           long_var = "longnum", lat_var = "latnum",
                           data,
                           grid.pred,
                           kappa = 0.5,
                           start.cov.pars = c(1,1),
                           scale.predictions = "prevalence",
                           pred.reps = 1e2, SE = T){


  #..................
  # run model
  #..................
  eq <- as.formula(paste0(outcome, "~", covar))
  coords <- as.formula(paste0("~", long_var, "+", lat_var))
  ret.fit <- PrevMap::linear.model.MLE(formula=eq, coords=coords,
                                       data=data, start.cov.pars=start.cov.pars,
                                       kappa=kappa)

  ret.pred <- PrevMap::spatial.pred.linear.MLE(ret.fit,
                                               grid.pred = grid.pred,
                                               scale.predictions=scale.predictions,
                                               n.sim.prev=pred.reps, standard.errors=SE)

  return(list(
    fit = ret.fit,
    pred = ret.pred
  ))

}




prevmaprasterplotter <- function(prevrasters, smoothfct = 5, alpha = 0.8){

  # need this for bounding box
  DRC <- sf::as_Spatial(osmdata::getbb("Democratic Republic of the Congo",
                                       featuretype = "country",
                                       format_out = 'sf_polygon'))

  # make raster
  ret.rstr <- raster::rasterFromXYZ(cbind(prevrasters$grid.pred[,1],
                                          prevrasters$grid.pred[,2],
                                          prevrasters$prevalence$predictions),
                                    crs="+proj=longlat +datum=WGS84")

  # mask raster
  ret.rstr <- raster::mask(x = ret.rstr, mask = DRC)

  ret.smrstr.m.plot <- ggplot() +
    ggspatial::layer_spatial(data = ret.rstr, aes(fill = stat(band1)),
                             alpha = alpha)
  return(ret.smrstr.m.plot)
}
