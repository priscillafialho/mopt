\name{evaluateParameters}
\alias{evaluateParameters}
\title{Evaluate objective function at N candidate parameter vectors}
\usage{
  evaluateParameters(ps, cf, balance = FALSE)
}
\arguments{
  \item{ps}{list of length N. each component is another
  list representing a particular value of the parameter
  vector.}

  \item{cf}{an object of class mopt_config}
}
\value{
  a data.frame
}
\description{
  Evaluates the objective function at N different value of
  the parameter vector. Depending on the configuration
  given in cf, evaluation is serial, parallel using
  multicore, or using MPI on a cluster.
}

