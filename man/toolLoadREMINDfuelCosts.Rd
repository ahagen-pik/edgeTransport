% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/toolLoadREMINDfuelCosts.R
\name{toolLoadREMINDfuelCosts}
\alias{toolLoadREMINDfuelCosts}
\title{Load fuel prices from a REMIND fulldata.gdx in [US$/MJ] and map them on to
the edgeTransport decision tree. The output is provided in the same spatial resolution
as the transferred gdx file and the temporal resolution is set according to the param yrs.}
\usage{
toolLoadREMINDfuelCosts(
  gdxPath,
  hybridElecShare,
  helpers,
  transportFolder = ".",
  iterationNumber = NULL
)
}
\arguments{
\item{gdxPath}{path to REMIND fulldata.gdx}

\item{hybridElecShare}{Share of electricity in Hybrid electric vehicles}

\item{helpers}{list with helpers}

\item{transportFolder}{folder to search for fuel prices from previous iterations for averaging}

\item{iterationNumber}{iteration number to store fuel costs for later iterations}
}
\value{
fuel costs on technology level
}
\description{
Load fuel prices from a REMIND fulldata.gdx in [US$/MJ] and map them on to
the edgeTransport decision tree. The output is provided in the same spatial resolution
as the transferred gdx file and the temporal resolution is set according to the param yrs.
}
