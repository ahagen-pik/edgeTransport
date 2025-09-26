#' When running with REMIND, starting from the second run of
#' iterativeEdgeTransport() scenario specific inputData can be reloaded from
#' saved files
#' @author Alex K. Hagen
#' @param edgeTransportFolder folder where the RDS files from last iterativeEdgeTransport() run are stored
#' @returns list with different input data sets
#' @import data.table
#' @export

toolReLoadInputs <- function(edgeTransportFolder) {
  # bind variables locally to prevent NSE notes in R CMD CHECK
  period <- univocalName <- test <- . <- NULL

  ### load inputs  ------------------------------------------------------------

  # general model parameters
  genModelPar <- list(
    lambdasDiscreteChoice = lambdasDiscreteChoice,
    annuityCalc = annuityCalc
  )

  # these are the scenario specific files which are read in from the EDGE-T folder from the previous run
  inputFiles <- c("scenSpecPrefTrends",
                  "scenSpecLoadFactor",
                  "scenSpecEnIntensity",
                  "CAPEXandNonFuelOPEX",
                  "upfrontCAPEXtrackedFleet",
                  "initialIncoCosts",
                  "annualMileage",
                  "timeValueCosts"
                  )

  RDSinputs <- toolLoadRDSinputs(edgeTransportFolder, inputFiles)

  # Time resolution
  dtTimeRes <- unique(RDSinputs$scenSpecEnIntensity[, c("univocalName", "period")])
  highRes <- unique(dtTimeRes$period)
  lowResUnivocalNames <- copy(dtTimeRes)
  lowResUnivocalNames <- lowResUnivocalNames[, .(test = all(highRes %in% period)), by = univocalName]
  lowResUnivocalNames <- lowResUnivocalNames[test == FALSE, univocalName]
  lowTimeRes <- unique(dtTimeRes[univocalName %in% lowResUnivocalNames]$period)


  # # input data, this is just a list for the overview, it can be deleted
  # inputData <- list(
  #   scenSpecPrefTrends,
  #   scenSpecLoadFactor,
  #   scenSpecEnIntensity,
  #   CAPEXandNonFuelOPEX,
  #   upfrontCAPEXtrackedFleet,
  #   initialIncoCosts,
  #   annualMileage,
  #   timeValueCosts,
  #   histESdemand   # source for that is missing
  # )

  input <- list(
    genModelPar = genModelPar,
    RDSinputs = RDSinputs
  )

  return(input)
}
