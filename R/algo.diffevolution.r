#' differential evolution
#' @export
#' @family algos
algo.diffevo <- function(evals, chains, last, cfg, pdesc, priv) {

  ps=list()

  params_to_sample  = cfg$params_to_sample
  params_to_sample2 = paste('p',cfg$params_to_sample,sep='.')
  N                 = cfg$N
  revals = data.frame()

  # compute overall variance/covariance matrix

  # if chains is empty then we accept all
  if (is.null(priv$chain.states)) {
    chain.states = list()
    nzerotemp = pmin(N,cfg$n_untempered)
    chain.states$tempering = rep(1,N)
    priv = list(chain.states = chain.states)
  }
  if (nrow(chains)>0)  {
    chain.states     = priv$chain.states
  }    

  # for each chain, we need the last 2 values
  # and decides whether we accept or reject
  # th new one
  for (c.current in 1:N) {

    # Analyze latest evaluations (Accept/Reject)
    # ==========================================

    # for given current chain, find the latest value
    i.latest = max(subset(chains,chain==c.current)$i)
    # select latest row in the history
    val_old = tail(subset(chains, chain==c.current & i==i.latest),1)
    # select the evaluations
    val_new = subset(evals,chain==c.current)[1,]

    # if there 
    if (all(chains$chain!=c.current)) {
      val_new  = val_old
      next_val = val_new
      ACC = 0
      prob= 0
      status = -1
    # check that old value is NA, in which case we accept new one for sure
    } else if (!is.finite(val_old$value)) {
      next_val = val_new
      ACC  =1
      prob =1
      status = -2
    } else {

      # compute accept reject -- classic Metropolis Hasting
      prob = pmin(1, exp( chain.states$tempering[c.current] * (val_old$value - val_new$value)))
      if (is.na(prob)) prob = 0; 

      # decide on accept reject
      if (prob > runif(1)) {
        next_val = val_new
        ACC = 1
      } else {
        next_val = val_old
        ACC = 0
      }
      status = 1
    }

    cat(sprintf('[%.3d] value and ratio: %8.4f/%8.4f A=%d prob=%8.4f rate=%8.4f var=%8.4f status=%d secs=%8.4f node=%s mem=%s\n', c.current, val_old$value, val_new$value,  ACC, prob, chain.states$acc[c.current] ,chain.states$shock_var[c.current],status,val_new$time,as.character(val_new$d.node),as.character(val_new$d.mem)))
    
    # updating sampling variance
    chain.states$acc[c.current]       = 0.9*chain.states$acc[c.current] + 0.1*ACC
    # increase/decrease by 5%
    chain.states$shock_var[c.current] = chain.states$shock_var[c.current] * (1+ 0.05*( 2*(chain.states$acc[c.current]>0.234) -1))


    # append to the chain
    rownames(next_val) <- NULL
    revals = rbind(revals,next_val)

    # compute a set of new candidates
    # ===============================

    # select 2 from last population different from current
    ss = sample(setdiff( eval$chain, c.current  ), 2 ,replace =FALSE)

    # compute mutation






    # then we compute a guess for the chain  
    # pick some parameters to update 
    p.new = cfg$initial_value
    p.new$chain = c.current
    p.new[params_to_sample] = next_val[1,params_to_sample2]
    p.new = shockallp(p.new, chain.states$shock_var[c.current], VV, cfg)

    ps[[c.current]] = p.new
  }
 
  priv = list(chain.states = chain.states)
  return(list(ps = ps , priv=priv, evals=revals ))
}


