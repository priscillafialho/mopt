\name{objfc.norm2.custom}
\alias{objfc.norm2.custom}
\title{create an objective function which returns custom
output from a bivariate normal density}
\usage{
  objfc.norm2.custom(mu = c(0, 0), sigma = diag(2),
    ns = 50)
}
\arguments{
  \item{norm_mean}{2d vector with the true mean}

  \item{sample_size}{number of random draws to compute
  distance}
}
\description{
  create an objective function which returns custom output
  from a bivariate normal density
}
\examples{
myfunc <- objfc.norm2(c(0,0))
myfunc(list(m1=0,m2=0))
}

