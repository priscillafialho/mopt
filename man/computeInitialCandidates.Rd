\name{computeInitialCandidates}
\alias{computeInitialCandidates}
\title{Compute Initial Parameter Candidates}
\usage{
  computeInitialCandidates(N, cf)
}
\arguments{
  \item{N}{number of chains}

  \item{cf}{an object of class mopt_config; a list}
}
\value{
  a list of length N, each containing a randomly perturbed
  version of starting vector p.
}
\description{
  for a given MOPT configuration, compute N starting
  values. A starting value is a disturbation of the
  supplied starting parameter vector p. This way we
  generate one starting value for each of N chains. The
  chains differ in that in each chain a different subset of
  parameters from the initial parameter vector is randomly
  disturbed.
}

