#' Energy Demand Generator (EDGE)- Transport Model
#'
#' The Edge Transport Model includes the transport specific input data preparation,
#' a choice model to determine transport mode and technology shares, a demand regression
#' and a fleet tracking for cars, busses and trucks
#'
#' @param SSPscen SSP or SDP scenario
#' @param transportPolScen EDGE-T transport policy scenario
#' @param isICEban optional enabling of ICE ban
#' @param demScen Demand scenario, used to apply reduction factors on total demands from the regression
#' @param gdxPath Path to a GDX file to load price signals from a REMIND run
#' @param outputFolder Path to folder for storing output data
#' @param isStored Optional saving of intermediate RDS files
#' @param isTransportReported Optional transport reporting in MIF format
#' @param isTransportExtendedReported Optional extension of transport reporting providing more detailed variables
#' @param isREMINDinputReported Optional reporting of REMIND input data
#' @param isAnalyticsReported Optional reporting of analytics data (e.g. variables over iterations)
#' @returns Transport input data for REMIND
#' @author Johanna Hoppe, Jarusch Müßel, Alois Dirnaichner, Marianna Rottoli
#' @import data.table
#' @importFrom reporttransport reportEdgeTransport storeData
#' @importFrom madrat getConfig
#' @export

toolEdgeTransportSA <- function(SSPscen,
                                transportPolScen,
                                isICEban = FALSE,
                                demScen = "default",
                                gdxPath = NULL,
                                outputFolder = NULL,
                                isStored = TRUE,
                                isTransportReported = TRUE,
                                isTransportExtendedReported = FALSE,
                                isREMINDinputReported = FALSE,
                                isAnalyticsReported = FALSE){

  # bind variables locally to prevent NSE notes in R CMD CHECK
  variable <- version <- NULL

  #To trigger the madrat caching even if changes are only applied to the csv files, we include here the version number of edget
  version <- "2.23.3"

  # set GDP cutoff to differentiate between regions
  GDPcutoff <- 30800 # [constant 2017 US$MER]
  # Year when scenario differentiation sets in
  policyStartYear <- 2021
  # last time step of historical data
  baseYear <- 2010
  # share of electricity in Hybrid electric vehicles
  hybridElecShare <- 0.4

  ########################################################
  ## Load input data
  ########################################################
  if (is.null(outputFolder) & isStored) stop("Please provide an outputfolder to store your results")

  inputs <- toolLoadInputs(SSPscen, transportPolScen, demScen, gdxPath, hybridElecShare)
  if (is.null(gdxPath)) {gdxPath <- file.path(getConfig("sourcefolder"),
                                              "REMINDinputForTransportStandalone", "v1.2", "fulldata.gdx")}
  if (!file.exists(gdxPath)) stop("Please provide valid path to REMIND fulldata.gdx as input for fuel costs")

  helpers <- inputs$helpers
  genModelPar <- inputs$genModelPar
  scenModelPar <- inputs$scenModelPar
  inputDataRaw <- inputs$inputDataRaw

  # If no demand scenario specific factors are applied, the demScen equals the SSPscen
  if (is.null(scenModelPar$scenParDemFactors)) demScen <- SSPscen

  ########################################################
  ## Prepare input data and apply scenario specific changes
  ########################################################

  scenSpecInputData <- toolPrepareScenInputData(genModelPar,
                                                scenModelPar,
                                                inputDataRaw,
                                                policyStartYear,
                                                GDPcutoff,
                                                helpers,
                                                isICEban)

  ########################################################
  ## Calibrate historical preferences
  ########################################################
  histPrefs <- toolCalibrateHistPrefs(scenSpecInputData$combinedCAPEXandOPEX,
                                      inputDataRaw$histESdemand,
                                      inputDataRaw$timeValueCosts,
                                      genModelPar$lambdasDiscreteChoice,
                                      helpers)
  ##########################
  # The following lines are supposed to be deleted:
  # overwrite historical preferences for trucks in MEA
  pathMEA <- paste0("extdata/SWsToBeDeleted/historicalPreferencesMix2.RDS")
  paste(pathMEA)
  paste(system.file(pathMEA, package = "edgeTransport", mustWork = TRUE))
  pathIND_CHA_USA <- "extdata/SWsToBeDeleted/value2010.csv"
  overwriteIND_CHA_USA <- fread(system.file(pathIND_CHA_USA, package = "edgeTransport", mustWork = TRUE),
            header = TRUE,
            na.strings = "NA",
            colClasses = list(character = "technology"))

  overwriteMEA <- readRDS(system.file(pathMEA, package = "edgeTransport", mustWork = TRUE))
  histPrefs$historicalPreferences[region == "MEA" & grepl("Truck", vehicleType)] <- overwriteMEA[region == "MEA" & grepl("Truck", vehicleType)]
  histPrefs$historicalPreferences[region %in% unique(overwriteIND_CHA_USA$region) & grepl("Truck", vehicleType) & technology == "" & period %in% unique(overwriteIND_CHA_USA$period) ] <- overwriteIND_CHA_USA[region %in% unique(overwriteIND_CHA_USA$region) & grepl("Truck", vehicleType)]

  # end of temporary solution
  ##########################
  scenSpecPrefTrends <- rbind(histPrefs$historicalPreferences,
                              scenSpecInputData$scenSpecPrefTrends)
  scenSpecPrefTrends <- toolApplyMixedTimeRes(scenSpecPrefTrends,
                                              helpers)
  if (isICEban) scenSpecPrefTrends <- toolApplyICEbanOnPreferences(scenSpecPrefTrends, helpers)
  scenSpecPrefTrends <- toolNormalizePreferences(scenSpecPrefTrends)

  #-------------------------------------------------------
  inputData <- list(
    scenSpecPrefTrends = scenSpecPrefTrends,
    scenSpecLoadFactor = scenSpecInputData$scenSpecLoadFactor,
    scenSpecEnIntensity = scenSpecInputData$scenSpecEnIntensity,
    combinedCAPEXandOPEX = scenSpecInputData$combinedCAPEXandOPEX,
    upfrontCAPEXtrackedFleet = scenSpecInputData$upfrontCAPEXtrackedFleet,
    initialIncoCosts = scenSpecInputData$initialIncoCosts,
    annualMileage = inputDataRaw$annualMileage,
    timeValueCosts = inputDataRaw$timeValueCosts,
    histESdemand = inputDataRaw$histESdemand,
    GDPMER = inputDataRaw$GDPMER,
    GDPpcMER = inputDataRaw$GDPpcMER,
    GDPpcPPP = inputDataRaw$GDPpcPPP,
    population = inputDataRaw$population
  )

  print("Input data preparation finished")
  ########################################################
  ## Prepare data for
  ## endogenous costs update
  ########################################################

  vehicleDepreciationFactors <- toolCalculateVehicleDepreciationFactors(genModelPar$annuityCalc,
                                                                        helpers)
  dataEndogenousCosts <- toolPrepareDataEndogenousCosts(inputData,
                                                        genModelPar$lambdasDiscreteChoice,
                                                        helpers)

  #################################################
  ## Demand regression module
  #################################################
  ## demand in million km
  sectorESdemand <- toolDemandRegression(inputData$histESdemand,
                                         inputData$GDPpcPPP,
                                         inputData$population,
                                         genModelPar$genParDemRegression,
                                         scenModelPar$scenParDemRegression,
                                         scenModelPar$scenParRegionalDemRegression,
                                         scenModelPar$scenParDemFactors,
                                         baseYear,
                                         policyStartYear,
                                         helpers)

  #------------------------------------------------------
  # Start of iterative section
  #------------------------------------------------------

  fleetVehiclesPerTech <- NULL
  iterations <- 3

  if (isAnalyticsReported) {
    endogenousCostsIterations <- list()
    fleetVehNumbersIterations <- list()
    costsDiscreteChoiceIterations <- list()
  }

  for (i in seq(1, iterations, 1)) {

    #################################################
    ## Cost module
    #################################################
    # provide endogenous updates to cost components -----------
    # number of vehicles changes in the vehicle stock module and serves
    # as new input for endogenous cost update
    endogenousCosts <- toolUpdateEndogenousCosts(dataEndogenousCosts,
                                                 vehicleDepreciationFactors,
                                                 scenModelPar$scenParIncoCost,
                                                 policyStartYear,
                                                 inputData$timeValueCosts,
                                                 inputData$scenSpecPrefTrends,
                                                 genModelPar$lambdasDiscreteChoice,
                                                 helpers,
                                                 isICEban,
                                                 fleetVehiclesPerTech)

    if (isAnalyticsReported) {
      endogenousCostsIterations[[i]] <- lapply(copy(endogenousCosts),
                                               function(x){ x[, variable := paste0(variable, "|Iteration ", i)]})
    }

    print("Endogenous updates to cost components finished")
    #################################################
    ## Discrete choice module
    #################################################
    # calculate vehicle sales shares and mode shares for all levels of the decisionTree
    vehSalesAndModeShares <- toolDiscreteChoice(inputData,
                                                genModelPar,
                                                endogenousCosts$updatedEndogenousCosts,
                                                helpers)
    if (isAnalyticsReported) {
      costsDiscreteChoiceIterations[[i]] <- lapply(copy(vehSalesAndModeShares$costsDiscreteChoice),
                                               function(x){ x[, variable := paste0(variable, "|Iteration ", i)]})
    }

    ESdemandFVsalesLevel <- toolCalculateFVdemand(sectorESdemand,
                                                  vehSalesAndModeShares$shares,
                                                  helpers,
                                                  inputData$histESdemand,
                                                  baseYear)
    print("Calculation of vehicle sales and mode shares finished")
    #################################################
    ## Vehicle stock module
    #################################################
    # Calculate vehicle stock for cars, trucks and busses -------
    fleetSizeAndComposition <- toolCalculateFleetComposition(ESdemandFVsalesLevel,
                                                             vehicleDepreciationFactors,
                                                             vehSalesAndModeShares$shares,
                                                             inputData$annualMileage,
                                                             inputData$scenSpecLoadFactor,
                                                             helpers)

    if (isAnalyticsReported) {
      fleetVehNumbersIterations[[i]] <- copy(fleetSizeAndComposition$fleetVehNumbers)
      fleetVehNumbersIterations[[i]][, variable := paste0(variable, "|Iteration ", i)]
    }
    fleetVehiclesPerTech <- fleetSizeAndComposition$fleetVehiclesPerTech

    print("Calculation of vehicle stock finished")
  }
  #------------------------------------------------------
  # End of iterative section
  #------------------------------------------------------

  #################################################
  ## Reporting
  #################################################
  # Rename transportPolScen if ICE ban is activated
  if (isICEban & (transportPolScen %in% c("Mix1", "Mix2", "Mix3", "Mix4"))) transportPolScen <- paste0(transportPolScen, "ICEban")

  print(paste("Run", SSPscen, transportPolScen, "demand scenario", demScen, "finished"))

  # Save data
  outputFolder <- file.path(outputFolder, paste0(format(Sys.time(), "%Y-%m-%d_%H.%M.%S"),
                                                 "-", SSPscen, "-", transportPolScen, "-", demScen))

  outputRaw <- list(
    SSPscen = SSPscen,
    transportPolScen = transportPolScen,
    demScen = demScen,
    gdxPath = gdxPath,
    hybridElecShare = hybridElecShare,
    histPrefs = histPrefs,
    fleetSizeAndComposition = fleetSizeAndComposition,
    endogenousCosts = endogenousCosts,
    vehSalesAndModeShares = vehSalesAndModeShares$shares,
    sectorESdemand = sectorESdemand,
    ESdemandFVsalesLevel = ESdemandFVsalesLevel,
    helpers = helpers
  )
  # not all data from inputdataRaw and inputdata is needed for the reporting
  add <- append(inputDataRaw,
                inputData[!names(inputData) %in% c("histESdemand", "GDPMER","GDPpcMER", "GDPpcPPP", "population")])
  outputRaw <- append(outputRaw, add)

  if (isAnalyticsReported) outputRaw <- append(outputRaw, list(endogenousCostsIterations = endogenousCostsIterations,
                                                               costsDiscreteChoiceIterations = costsDiscreteChoiceIterations,
                                                               fleetVehNumbersIterations = fleetVehNumbersIterations))

  if (isStored) storeData(outputFolder = outputFolder, varsList = outputRaw)

  output <- reportEdgeTransport(outputFolder,
                                outputRaw,
                                isTransportReported,
                                isTransportExtendedReported,
                                isAnalyticsReported,
                                isREMINDinputReported,
                                isStored)

return(output)
}
