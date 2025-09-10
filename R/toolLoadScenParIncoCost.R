#' When running with REMIND, starting from the second run of
#' iterativeEdgeTransport() scenario specific inputData can be reloaded from
#' saved files
#' @author Alex K. Hagen
#' @param edgeTransportFolder folder where the RDS files from last iterativeEdgeTransport() run are stored
#' @returns list with different input data sets
#' @import data.table
#' @export

toolLoadScenParIncoCost <- function(SSPs, transportPolS) {
  # Transport policy scenario inconvenience cost factors
  # 
  scenParIncoCost <- fread(system.file("extdata/scenParIncoCost.csv",
                                       package = "edgeTransport", mustWork = TRUE), header = TRUE)
  scenParIncoCost[, "startYearCat" := fcase( SSPscen == SSPs[1] & transportPolScen == transportPolS[1], "origin", SSPscen == SSPs[2] & transportPolScen == transportPolS[2], "final")]
  scenParIncoCost <- scenParIncoCost[!is.na(startYearCat)][, c("transportPolScen", "SSPscen") := NULL]

  return(scenParIncoCost)
  
}