#' Calculate annuity for different vehicle types
#'
#' @author Johanna Hoppe
#' @param annuityCalc input data for interest rate and service Life from edgeTransport
#' @param helpers list with helpers
#' @import data.table


toolCalculateAnnuity <- function(annuityCalc, helpers) {
  # bind variables locally to prevent NSE notes in R CMD CHECK
  FVvehvar <- serviceLife <- interestRate <- NULL

  annuity <- merge(helpers$mitigationTechMap[, c("FVvehvar", "univocalName")], annuityCalc, by = "FVvehvar", all.y = TRUE)[, FVvehvar := NULL]
  # Calculate annuity factor to annualize CAPEX
  annuity[, annuity := ((1 + interestRate)^serviceLife  * interestRate) / ((1 + interestRate)^serviceLife - 1)][, c("interestRate", "serviceLife") := NULL]

  return(annuity)
}
