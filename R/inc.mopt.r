require(plyr)
require(MSBVAR)

# setting up the config
# should be given 
# list of model parameters including, 
#   * priority, 
#   * moment a priori connection
#   * transform (optional)
#   * bounds (optional)
# list of computational parameters
#   * tolerance
#   * iteration limit

#' create the configuration for the MCMC 
#' chain. 
#' @export
mopt_config <- function(p) {
	stopifnot(is.list(p))
 cf = list()

 cf$mode           = 'mpi'
 cf$iter           = 10
 cf$i              = 0
 cf$use_last_run   = TRUE
 cf$file_chain     = 'evaluations.dat'
 cf$file_lastparam = 'param_submit.dat'
 cf$file_errorparam= 'param_error.dat'
 cf$wd             = '~/git/bankruptcy/R'
 cf$source_on_nodes = 'example-bgp-mpi-slaves.r'
 cf$logdir         = 'sims/sim2/workers'	# log directory relative to cf$wd
 cf$params_to_sample = c()	#This is a vector of names: c('delta', 'b')
 cf$objfunc          = MOPT_OBJ_FUNC
 cf$modelinfo      = c()
                                
 cf$run            = 0
 cf$shock_var      = 0.1
 cf$moments_to_use = c()
 cf$moments.data   = c()
 cf$moments.sd     = c()
 cf$np_shock       = 1
 cf$save_freq      = 25
 cf$initial_value  = p
 cf$params_all     = names(p) #c('sep','c','b','s0','s1','firmMass','beta','delta','sigma','f_rho','f_mx','f_my','f_a')
 cf$N              = 3 # default in case of serial
 cf$mcfactor       = 1L # multicore factor on MPI cluster: if you have N chains which require (intermediate, private) multicore computation
                        # you set this to the number of cores required by each chain.
                        # for example, each chain requires 2 cores to compute the objective function: cf$mcfactor = 2
                        # if you reserved N MPI cores, this will start off only N / cf$mcfactor

 param.descript = data.frame()
 for (n in names(p)) {
   param.descript = rbind(param.descript,data.frame(param=n, lb=NA , ub=NA))
 }
 rownames(param.descript) <- names(p)
 cf$pdesc = param.descript

 class(cf) <- 'mopt_config'

 return(cf)
}

#' defining sampling support for parameter
#' @export
samplep <- function(pp,lb,ub) {
  res = list()
  class(res) <- 'mopt_smaplep'
  res$pp = pp
  res$lb = lb
  res$ub = ub
  return(res)
}

#' add data moments to the configuration
#' @export 
datamoments <- function(names,values,sds) {
  res = list()
  rr = data.frame(moment=names,value = values, sd = sds)
  class(res) <- 'mopt_dmoms'
  res$dd = rr
  return(res)
}

#' @export
"+.mopt_config" <- function(cf,argb) {

 if (class(argb)=='mopt_smaplep') {
    cf$pdesc[argb$pp,'lb'] = argb$lb
    cf$pdesc[argb$pp,'ub'] = argb$ub
    cf$pdesc$param = paste(cf$pdesc$param)
 }

 if (class(argb)=='mopt_dmoms') {
    cf$data.moments = argb$dd
 }

 return(cf)
}

# mopt_obj_wrapper <- function(p,objfunc=NA) {
#   m = try( {
# 
# get result
#     r = objfunc(p)  
# 
#     if (!is.list(r)) {
#       r = list(value=r)
#     }
# 
# check that there is a status 
# and that values is not NA
#     if (!('status' %in% names(r))) { 
#       r$status=1
#     }
# 
#     if (is.nan(r$value) | is.na(r$value)) {
#       r$status=-1
#       stop("objective function produced NA")
#     }
#     return(r)
# 
#   },silent=TRUE) 
#   return(m) 
# returns NA if there is any sort of crash
# later it would be good to get the error message
#  }

mopt_obj_wrapper <- function(p,objfunc=NA) {
	m = tryCatch( {

		#         get result
		r = objfunc(p)  

		if (!is.list(r)) {
			r = list(value=r)
		}

		#         check that there is a status 
		#         and that values is not NA
		if (!('status' %in% names(r))) { 
			r$status=1
		}

		if (is.nan(r$value) | is.na(r$value)) {
			r$status=-1
		}

		r
	},error = function(e) {
		list(status=-1,error=e$message)
	} ) 
	return(m) 
	#     returns NA if there is any sort of crash
	#     later it would be good to get the error message
}

mopt_obj_wrapper_custom <- function(p,objfunc=NA) {
	m = tryCatch( {

		#         get result
		r = objfunc(p)  

		if (!is.list(r)) {
			stop('MOPT_OBJ_FUNC must return a list')
		}

		if (!('output' %in% names(r))){
			stop('MOPT_OBJ_FUNC must return a list with an element named: output')
		}
		r
	},error = function(e) {
		list(status=-1,error=e$message)
	} ) 
	return(m) 
}


#' prepares mopt to run with either MPI or openMP or just serial
#' @export
prepare.mopt_config <- function(cf) {
  if (cf$mode=='mpi') {
    cat('[mode=mpi] USING MPI !!!!! \n')

    # creating the cluster
	# size of the cluster is determined by MPIRUN, i.e. in the SGE submit script. not here.
    require(snow)  
    cl <- makeCluster(type='MPI')
	cf$cl <- cl	# add cluster to the config as well

	# we are hard coding the name of the cluster here
	# as long as we always use the same name, that's fine.
	  # worker roll call
	  num.worker <- length(clusterEvalQ(cl,Sys.info()))
      dir.create(file.path(cf$wd,cf$logdir),showWarnings=FALSE)
	  cat("Master: I've got",num.worker,"workers\n")
	  cat("Master: doing rollcall on cluster now\n")
	  cat("Here is the boss talking. Worker roll call on",date(),"\n",file=file.path(cf$wd,cf$logdir,"rollcall.txt"),append=FALSE)
    # setting up the slaves
    eval(parse(text = paste("clusterEvalQ(cl,setwd('",cf$wd,"'))",sep='',collapse=''))) 
    eval(parse(text = paste("clusterEvalQ(cl,source('",cf$source_on_nodes,"'))",sep='',collapse=''))) 
    clusterCall(cl, rollcall, file.path(cf$wd,cf$logdir))

    # adding the normal lapply
    cf$mylapply = function(a,b) { return(parLapply(cl,a,b))}

    # adding the load balanced lapply
    cf$mylbapply = function(a,b) { return(clusterApplyLB(cl,a,b))}

	stopifnot(is.integer(cf$mcfactor))
	cf$N = floor(length(cl) / cf$mcfactor)
	# TODO
	# N is the number of chains. This need not be necessarily the number of cores/nodes available.
	# for example suppose computation of the objective function requires
	# 2 cores: so then we'll have N chains which requires a cluster with 2*N cores
  } else if (cf$mode=='multicore') {
    cat('[mode=mulicore] YEAH !!!!! \n')    
    require(parallel)
    
    if(Sys.info()[['sysname']]=='Windows') {
      cl <- makeCluster(spec=detectCores(),type='MPI')
      
      # worker roll call
      dir.create(file.path(cf$wd,"workers"),showWarnings=FALSE)
      cat("Master: I've got",num.worker,"workers\n")
      cat("Master: doing rollcall on cluster now\n")
      cat("Here is the boss talking. Worker roll call on",date(),"\n",file=file.path(cf$wd,"workers","rollcall.txt"),append=FALSE)
      # setting up the slaves
      eval(parse(text = paste("clusterEvalQ(cl,setwd('",cf$wd,"'))",sep='',collapse=''))) 
      eval(parse(text = paste("clusterEvalQ(cl,source('",cf$source_on_nodes,"'))",sep='',collapse=''))) 
      clusterCall(cl, rollcall, file.path(cf$wd,"workers"))
      
      
      # adding the normal lapply
      cf$mylapply = function(a,b) { return(parLapply(cl,a,b))}
      
      # adding the load balanced lapply
      cf$mylbapply = function(a,b) { return(clusterApplyLB(cl,a,b))}
      
      cf$N = length(cl)
    } else{
      cf$mylapply  = mclapply;
      cf$mylbapply = mclapply;
      cf$N=detectCores()      
    }
  } else {
    cf$mode = 'serial'
    cat('[mode=serial] NOT USING MPI !!!!! \n')    
    cf$mylapply  = lapply;
    cf$mylbapply = lapply;
  }
  return(cf)
}

#' cluster rollcall
#' 
#' cluster reporting function. makes every worker state their name and 
#' writes into a log file
#' @export
#' @param dir path to the log directory
rollcall <- function(dir){
  my.name <- Sys.info()["nodename"]
  cat("I am",my.name,"and I'm ready to go.\n",file=file.path(dir,"rollcall.txt"),append=TRUE)
}



#' this is the main function, it will run the
#' optimizer in parallel if called with MPI=TRUE
#' it will search for the minimum
#' @export
runMOpt <- function(cf,autoload=TRUE) {

  # reading configuration
  # =====================
  pdesc = cf$pdesc
  p     = cf$initial_value
  priv = list()

  # setting up the cluster if MPI
  # =============================
  last_time = as.numeric(proc.time()[3])

  # saving all evaluations with param values
  # start from best last value
  if (file.exists(cf$file_chain) & autoload ) {
    load(cf$file_chain)

    #load saved mcf 
    load('cf.dat')	  
    cf <- c(cf,mmcf[setdiff(names(mmcf), names(cf))])
    cf$shock_var = mmcf$shock_var
    cf$run = max(param_data$run) +1

  } else {
    param_data = data.frame()
    cf$run = 0

    # what is the meaning of these paramters?
    # I find theta, breaks, nu, and kk are used algo.wl.r, acc is used to update sample var.
    cf$theta  = seq(1,l=50)
    cf$breaks = seq(-2,0,l=50) 
    cf$acc    = 0.5
    cf$nu     = seq(0,l=50)
    cf$kk     = 2
    cf$i      = 1
  }

  cat('Number of Chains: ',cf$N,'\n')

  # we want to keep a matrix for the chain
  # it should be a data.frame in long format
  # with a chain and iteration indicator
  # each row will also have the all parameters and the 
  # objective value
  # we are going to carry 2 arrays
  #   -- param_data: will store all evaluations
  #   -- chain_data: will store the chain results

  #  ========================   MCMC loop =======================

  # get initial candidates
  cat('Computing intial candidates\n')
  ps = computeInitialCandidates(cf$N,cf)
  param_data = evaluateParameters(ps,cf)

  cat('Starting main MCMC loop\n')  
  for (i in cf$i:cf$iter) {

    cf$i=i
    #                 step 1, evaluate candidates 
    # --------------------------------------------------------
    eval_start = as.numeric(proc.time()[3])
    rd = evaluateParameters(ps,cf)
    eval_time  = as.numeric(proc.time()[3]) - eval_start
    if ( (i %% cf$save_freq)==1 & i>10 ) {
      save(cf,priv,param_data,file=cf$file_chain)      
      #save mcf in case of restart
      mmcf=cf
      save(mmcf,file='cf.dat')
    }

    #            step 2, updating chain and computing guesses
    # ----------------------------------------------------------------
    algo_start = as.numeric(proc.time()[3])
    rr   = mcf$algo(rd,param_data, 0, mcf, mcf$pdesc, priv)
    algo_time  = as.numeric(proc.time()[3]) - algo_start
    priv = rr$priv
    ps   = rr$ps

    # append the accepted/rejected draws
    param_data = rbind(param_data,rr$evals)
    run_time = as.numeric(proc.time()[3]) - last_time

    # small reporting
    # ----------------
    cat(sprintf('[%d/%d][total: %f][last: %f ( e:%4.2f + a:%4.2f )][m: %f] best value %f \n',
                  i , cf$iter , 
                  as.numeric(proc.time()[3]),  
                  run_time,  
                  eval_time/run_time,
                  algo_time/run_time, 
                  sum(gc()[,"(Mb)"]), 
                  min(param_data$value,na.rm=TRUE))) 
    last_time = as.numeric(proc.time()[3])
    for (pp in paste('p',cf$params_to_sample,sep='.')) {
      cat(' range for ',pp,' ',range(param_data[,pp]),'\n')
    }
  }

  #saving the data set
  save(cf,priv,param_data,file=cf$file_chain)      

  # stopping the cluster using R snow command
  #if (cf$USE_MPI) {
  #  stopCluster(cl)
  #}

  return(param_data)
}






