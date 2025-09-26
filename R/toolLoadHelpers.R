#' Loads all helpers needed for EDGET
#'
#' @returns helpers a list of different helpers
#' @export


toolLoadHelpers <- function() {
  # load edgeTransport package data   #
  # in the standalone version this data is loaded via toolLoadPackageData()
  # but here we only need a small subset of data which we load directly

  # Decision tree discrete choice model
  decisionTree <- toolLoadDecisionTree("regionCode21")
  # Exponents discrete choice model
  lambdasDiscreteChoice <- fread(system.file("extdata/genParLambdasDiscreteChoiceModel.csv",
                                             package = "edgeTransport", mustWork = TRUE), header = TRUE)

  annuityCalc <- fread(system.file("extdata/genParAnnuityCalc.csv",
                                   package = "edgeTransport", mustWork = TRUE), header = TRUE)
  # Interest Rate and vehicle service life for annuity calculation
  # NOTE: right now there is only "default". If we add scenario specific annuity parameters,
  # we need to shift annuityCalc to the scenPar's and adjust read-in here

  ## helpers
  mitigationTechMap <- fread(system.file("extdata", "helpersMitigationTechmap.csv",
                                         package = "edgeTransport"))
  regionmappingISOto21to12 <- fread(system.file("extdata", "helpersRegionmappingISOto21to12.csv",
                                                package = "edgeTransport"))
  reportingNames <- fread(system.file("extdata", "helpersReportingNames.csv",
                                      package = "edgeTransport"), skip = 1)
  reportingAggregation <- fread(system.file("extdata", "helpersReportingAggregation.csv",
                                            package = "edgeTransport"), skip = 1)
  mapEdgeToREMIND <- fread(system.file("extdata/helpersMappingEdgeTtoREMINDcategories.csv",
                                       package = "edgeTransport", mustWork = TRUE))

  ##############
  # categories for filtering data
  categories <- c("trn_pass_road_LDV_4W", "trn_pass_road_LDV_2W", "trn_freight_road", "trn_pass", "trn_freight")
  filterEntries <- getFilterEntriesUnivocalName(categories, decisionTree)
  filterEntries[["trackedFleet"]] <- c(filterEntries[["trn_pass_road_LDV_4W"]], filterEntries[["trn_freight_road"]],
                                       getFilterEntriesUnivocalName("Bus", decisionTree)[["Bus"]])

  # collect helpers
  helpers <- list(
    decisionTree = decisionTree,
    regionmappingISOto21to12 = regionmappingISOto21to12,
    mitigationTechMap = mitigationTechMap,
    mapEdgeToREMIND = mapEdgeToREMIND,
    filterEntries = filterEntries,
    dtTimeRes = dtTimeRes,
    lowTimeRes = lowTimeRes,
    reportingNames = reportingNames,
    reportingAggregation = reportingAggregation
  )

}
