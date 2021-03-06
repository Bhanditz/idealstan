#' Data and Identification for \code{id_estimate}
#' 
#' \code{idealdata} objects contain the relevant legislator/bill (person/item) matrix of data along with slots containing information
#' about the kind of identification used in the estimation.
#' 
#' @seealso \code{\link{id_make}} to create an \code{idealdata} object suitable for estimation with \code{id_estimate}.
#' @export
setClass('idealdata',
         slots=list(score_matrix='data.frame',
                    person_data='data.frame',
                    group_vals='ANY',
                    group_varying='logical',
                    person_vals='ANY',
                    item_data='data.frame',
                    person_cov='array',
                    item_cov='matrix',
                    item_cov_miss='matrix',
                    group_cov='array',
                    time='ANY',
                    exog_data='vector',
                    time_vals='vector',
                    vote_labels='ANY',
                    vote_count='integer',
                    miss_val='ANY',
                    restrict_count='numeric',
                    restrict_data='list',
                    stanmodel='stanmodel',
                    param_fix='numeric',
                    constraint_type='numeric',
                    restrict_vals='ANY',
                    subset_group='character',
                    subset_person='character',
                    to_sample='numeric',
                    unrestricted='matrix',
                    restrict_num_high='numeric',
                    restrict_num_low='numeric',
                    restrict_ind_high='ANY',
                    restrict_ind_low='ANY',
                    vote_int='numeric',
                    simul_data='list',
                    simulation='logical',
                    diff='numeric',
                    diff_high='numeric',
                    restrict_var='logical',
                    restrict_var_high='numeric',
                    restrict_mean_val='numeric',
                    restrict_mean_ind='numeric',
                    restrict_mean='logical',
                    person_start='numeric'))


#' Results of \code{\link{id_estimate}} function
#' 
#' The \code{idealstan} objects store the results of estimations carried out by the \code{\link{id_estimate}} function. 
#' These objects include the full results of Bayesian sampling performed by the \code{\link[rstan]{stan}} function in the \pkg{rstan}
#' package.
#' @export
setClass('idealstan',
         slots=list(score_data='idealdata',
                    to_fix='list',
                    model_type='numeric',
                    use_ar='logical',
                    model_code='character',
                    test_model_code='character',
                    stan_samples='stanfit',
                    use_vb='logical',
                    use_groups='logical',
                    simulation='logical'))

setGeneric('subset_ideal',signature='object',
           function(object,...) standardGeneric('subset_ideal'))

setMethod('subset_ideal',signature(object='idealdata'),
          function(object,use_subset=FALSE,sample_it=FALSE,subset_group=NULL,subset_person=NULL,sample_size=20) {
            
            
            # Functions for subsetting data and sampling
            
            x <- object@score_matrix
            parliament <- object@person_data
            
            if(use_subset==TRUE & !is.null(subset_group)) {
              if(!all(subset_group %in% parliament$group)) stop('The specified parliament bloc/party must be in the list of blocs/parties in the legislature data.')
              x <- x[parliament$group %in% subset_group,]
              
              object@subset_group <- subset_group
            } 
            if(use_subset==TRUE & !is.null(subset_person)) {
              if(!all(subset_person %in% parliament$person.names[parliament$group%in% subset_group])) {
                stop('The legislators to subset must be members of the subsetted bloc as well.')
              }
              x <- x[parliament$person.names %in% subset_person,]
              object@subset_person <- subset_person
            }
            
            if(sample_it==TRUE) {
              object@to_sample <- sample(1:nrow(x),sample_size)
              x <- x[object@to_sample,]
            }
            object@score_matrix <- x
            
            return(object)
          })

setGeneric('clean_bills',signature='object',
           function(object,...) standardGeneric('clean_bills'))

setMethod('clean_bills',signature(object='idealdata'),
          function(object) {
            x <- object@score_matrix
            
            if(grepl('absence_inflate|ordinal',x@model_type)) {
              select_cols <- apply(x,2, {
                if(length(table(x))<(vote_count-1)) {
                  FALSE
                } else {
                  TRUE
                }
              })
              x <- x[,select_cols]
            } else {
              select_cols <- apply(x,2, {
                if(length(table(x))<(vote_count)) {
                  FALSE
                } else {
                  TRUE
                }
              })
              x <- x[,select_cols]
            }
            object@score_matrix <- x
            return(object)
          })

setGeneric('sample_model',signature='object',
           function(object,...) standardGeneric('sample_model'))

setMethod('sample_model',signature(object='idealdata'),
          function(object,nchains=4,niters=2000,warmup=floor(niters/2),ncores=NULL,
                   to_use=to_use,this_data=this_data,use_vb=FALSE,...) {

            
            init_vals <- lapply(1:nchains,.init_stan,
                                num_legis=this_data$num_legis,
                                restrict_sd=this_data$restrict_sd,
                                person_sd=this_data$legis_sd,
                                diff_high=this_data$diff_high,
                                T=this_data$T,
                                restrict_var=this_data$restrict_var,
                                restrict_var_high=this_data$restrict_var_high,
                                time_sd=this_data$time_sd,
                                use_ar=this_data$use_ar,
                                person_start=object@person_start,
                                actual=TRUE)

            if(is.null(ncores)) {
              ncores <- 1
            }
            if(use_vb==FALSE) {
              out_model <- sampling(object@stanmodel,data=this_data,chains=nchains,iter=niters,cores=ncores,
                                    warmup=warmup,
                                    init=init_vals,
                                    ...)
            } else {
              out_model <- vb(object@stanmodel,data=this_data,
                              ...)
            }
            outobj <- new('idealstan',
                          score_data=object,
                          model_code=object@stanmodel@model_code,
                          stan_samples=out_model,
                          use_vb=use_vb)
            
            return(outobj)
          })

setGeneric('id_model',
           signature='object',
           function(object,...) standardGeneric('id_model'))

setMethod('id_model',signature(object='idealdata'),
          function(object,fixtype='vb',model_type=NULL,this_data=NULL,nfix=10,
                   prior_fit=NULL,
                   restrict_ind_high=NULL,
                   restrict_ind_low=NULL,
                   ncores=NULL,
                   use_groups=NULL) {

            x <- object@score_matrix
            
            run_id <- switch(fixtype,vb_full=.vb_fix,vb_partial=.vb_fix,constrained=.constrain_fix,
                             constrain=.constrain_fix,
                             prior_fit=.prior_fit)

            object <- run_id(object=object,this_data=this_data,nfix=nfix,
                   restrict_ind_high=restrict_ind_high,
                   restrict_ind_low=restrict_ind_low,
                   ncores=ncores,
                   model_type=model_type,
                   use_groups=use_groups,
                   fixtype=fixtype,
                   prior_fit=prior_fit)
            

            return(object)
          })

#' Posterior Summaries for fitted \code{idealstan} object
#' 
#' This function produces quantiles and standard deviations for the posterior samples of \code{idealstan} objects.
#' 
#' @param object An \code{idealstan} object fitted by \code{\link{id_estimate}}
#' @param pars Either \code{'ideal_pts'} for person ideal points, 
#' \code{'items'} for items/bills difficulty and discrimination parameters,
#' and \code{'all'} for all parameters in the model, including incidental parameters.
#' @param high_limit A number between 0 and 1 reflecting the upper limit of the 
#' uncertainty interval (defaults to 0.95).
#' @param low_limit A number between 0 and 1 reflecting the lower limit of the 
#' uncertainty interval (defaults to 0.05).
#' @param aggregate Whether to return summaries of the posterior values or the 
#' full posterior samples. Defaults to \code{TRUE}.
#' @return A \code{\link[dplyr]{tibble}} data frame with parameters as rows and descriptive statistics as columns
#' 
#' @export
setMethod('summary',signature(object='idealstan'),
          function(object,pars='ideal_pts',
                   high_limit=0.95,
                   low_limit=0.05,
                   aggregate=TRUE) {
            
            options(tibble.print_max=1000,
                    tibble.print_min=100)
            

            if(pars=='ideal_pts') {
              ideal_pts <- .prepare_legis_data(object,
                                               high_limit=high_limit,
                                               low_limit=low_limit,
                                               aggregate=aggregate)
              if(is.null(ideal_pts$time_id)) {
                ideal_pts$time_id=1
              }
              if(aggregate) {
                ideal_pts <- select(ideal_pts,
                                    Person=person_id,
                                    Group=group_id,
                                    Time_Point=time_id,
                                    `Low Posterior Interval`=low_pt,
                                    `Posterior Median`=median_pt,
                                    `High Posterior Interval`=high_pt,
                                    `Parameter Name`=legis)
              } else {
                # add in iteration numbers
                ideal_pts <- group_by(ideal_pts,person_id) %>% 
                  mutate(Iteration=1:n())
                ideal_pts <- select(ideal_pts,
                                    Person=person_id,
                                    Group=group_id,
                                    Time_Point=time_id,
                                    Ideal_Points=ideal_pts,
                                    Iteration,
                                    `Parameter Name`=legis)
              }
              return(ideal_pts)
            }
            
            if(pars=='items') {

              # a bit trickier with item points
              item_plot <- levels(object@score_data@score_matrix$item_id)
              if(object@model_type %in% c(1,2) || (object@model_type>6 && object@model_type<13)) {
                # binary models and continuous
                item_points <- lapply(item_plot,.item_plot_binary,object=object,
                                      low_limit=low_limit,
                                      high_limit=high_limit,
                                      all=T,
                                      aggregate=aggregate) %>% bind_rows()
              } else if(object@model_type %in% c(3,4)) {
                # rating scale
                item_points <- lapply(item_plot,.item_plot_ord_rs,object=object,
                                      low_limit=low_limit,
                                      high_limit=high_limit,
                                      all=T,
                                      aggregate=aggregate) %>% bind_rows()
              } else if(object@model_type %in% c(5,6)) {
                # grm
                item_points <- lapply(item_plot,.item_plot_ord_grm,object=object,
                                      low_limit=low_limit,
                                      high_limit=high_limit,
                                      all=T,
                                      aggregate=aggregate) %>% bind_rows()
              } else if(object@model_type %in% c(13,14)) {
                # latent space
                item_points <- lapply(item_plot,.item_plot_ls,object=object,
                                      low_limit=low_limit,
                                      high_limit=high_limit,
                                      all=T,
                                      aggregate=aggregate) %>% bind_rows()
              }
              return(item_points)
            }

            
            if(pars=='all') {
              if(!is.null(pars)) {
                sumobj <- rstan::summary(object@stan_samples,pars=pars)
                this_summary <- sumobj[[1]] %>% as_data_frame
              } else {
                sumobj <- rstan::summary(object@stan_samples)
                this_summary <- sumobj[[1]] %>% as_data_frame
              }
              
              this_summary <- mutate(this_summary,
                                     parameters=row.names(sumobj[[1]]),
                                     par_type=stringr::str_extract(parameters,'[A-Za-z_]+')) %>% 
                rename(posterior_mean=`mean`,
                       posterior_sd=`sd`,
                       posterior_median=`50%`,
                       Prob.025=`2.5%`,
                       Prob.25=`25%`,
                       Prob.75=`75%`,
                       Prob.975=`97.5%`) %>% 
                select(parameters,par_type,posterior_mean,posterior_median,posterior_sd,Prob.025,
                       Prob.25,Prob.75,Prob.975)
              return(this_summary)
            }
            
            if(pars %in% c('person_cov','discrim_reg_cov','discrim_infl_cov')) {

              param_name <- switch(pars,person_cov='legis_x',
                                   discrim_reg_cov='sigma_reg_x',
                                   discrim_infl_cov='sigma_abs_x')
              
              to_sum <- as.array(object@stan_samples,
                                  pars=param_name)
              
              # reset names of parameters
              new_names <- switch(pars,person_cov=attributes(object@score_data@person_cov)$dimnames$colnames,
                                  discrim_reg=attributes(object@score_data@item_cov)$dimnames$colnames,
                                  discrim_abs=attributes(object@score_data@item_cov_miss)$dimnames$colnames)
              
              attributes(to_sum)$dimnames$parameters <- new_names
              
              if(!aggregate) {
                return(to_sum)
              } else {
                out_d <- data_frame(Covariate=new_names,
                                    `Posterior Median`=apply(to_sum,3,median),
                                    `Posterior High Interval`=apply(to_sum,3,quantile,high_limit),
                                    `Posterior Low Interval`=apply(to_sum,3,quantile,low_limit),
                                    Parameter=param_name)
                return(out_d)
              }
              
            }
            
})

#' Generic Function for Plotting \code{idealstan} objects
#' 
#' This generic function will run all the plotting functions associated with fitted \code{idealstan} objects.
#' 
#' @param object An \code{idealstan} object
#' @param ... Other options passed onto the underlying plot function
#' 
#' @export
setGeneric('id_plot',
           signature='object',
           function(object,...) standardGeneric('id_plot'))

#' Plot Results of \code{\link{id_estimate}}
#' 
#' This function allows you to access the full range of plotting options for fitted \code{idealstan} models.
#' 
#' \code{id_plot} is a wrapper function that can access the various plotting functions available in the \code{idealstan} package. 
#'    Currently, the options are limited to a plot of legislator/person ideal points with bills/item midpoints as an optional overlay.
#'    Additional plots will be available in future versions of \code{idealstan}.
#' @param object A fitted \code{idealstan} object
#' @param plot_type Specify the plot as a character string. Currently 'persons' for legislator/person ideal point plot and 
#'    'histogram' for a histogram of model estimates for given parameters.
#' @param ... Additional arguments passed on to the underlying functions. See individual function documentation for details.
#' @return A \code{\link[ggplot2]{ggplot}} object
#' @seealso \code{\link{id_plot_legis}} for a legislator/person ideal point plot, 
#' \code{\link{id_plot_all_hist}} for a standard histogram plot,
#' \code{\link{id_plot_compare}} for an ideal point plot of two different models of the same data,
#' \code{\link{id_plot_rhats}} for a histogram of \code{Rhat} values,
#' \code{\link{id_plot_sims}} for plotting true versus estimated values,
#' \code{\link{id_estimate}} for how to estimate an \code{idealstan} object.
#' @export
setMethod(id_plot, signature(object='idealstan'),
          function(object,plot_type='persons',...) {
            if(plot_type=='persons') {
              id_plot_legis(object,...)
            } else if(plot_type=='histogram') {
              id_plot_all_hist(object,...)
            }
            
          })

#' Generic Method for Extracting Posterior Samples
#' 
#' This generic will extract the full \code{\link[rstan]{stan}}} posterior samples from \code{idealstan} objects.
#' 
#' See the corresponding method definition for more information about what you can acccess with this generic.
#' 
#' @description This is a generic function.
#' 
#' @param object A fitted \code{idealstan} object
#' @param ... Other arguments passed on to underlying functions
#' @export
setGeneric('id_extract',signature='object',
           function(object,...) standardGeneric('id_extract'))


#' Extract \code{\link[rstan]{stan}} joint posterior distribution from \code{idealstan} object
#' 
#' This convenience function allows you to extract the underlying \code{\link[rstan]{rstan}} posterior estimates for the full parameters
#'   estimates of the \code{idealstan} model object. See \code{\link[rstan]{extract}} for the underlying function and more options.
#'   
#' You can use this function to access a matrix or array of the full posterior estimates of each of the parameters in an 
#'  \code{idealstan} object. There are available options to pick certain parameters of the model, such as the person (legislator)
#'  ideal points or item (bill) discrimination scores. Alternatively, you can leave the \code{extract_type} option blank and 
#'  receive a list of all of the available parameters. Please note that the list of parameters do not have particularly
#'  informative names. 
#'  
#'  All parameters are returned in the order in which they were input into the \code{\link{id_make}} function.
#'  
#' @param object A fitted \code{idealstan} object (see \code{\link{id_estimate}})
#' @param extract_type Can be one of \code{'persons'} for person/legislator ideal points,
#' \code{'reg_discrim'} for non-inflated item (bill) discrimination scores,
#' \code{'reg_diff'} for non-inflated item (bill) difficulty scores,
#' \code{'miss_discrim'} for inflated item (bill) discrimination scores,
#' and \code{'miss_diff'} for inflated item (bill) difficulty scores.
#' @param ... Any additional arguments passed on to the \code{\link[rstan]{extract}} function.
#' 
#' @export
setMethod(id_extract,signature(object='idealstan'),
          function(object,extract_type='persons',...) {
              
            .extract_samples(obj=object,extract_type=extract_type)
            
          })
#' Generic Method to Use \code{shinystan} with \code{idealstan}
#' 
#' A generic function for launching \code{\link[shinystan]{launch_shinystan}}.
#' 
#' @param object A fitted \code{idealstan} object.
#' @param ... Other arguments passed on to underlying function 
#' @export
setGeneric('launch_shinystan',signature='object',
           function(object,...) standardGeneric('launch_shinystan')) 

#' Function to Launch Shinystan with an \code{idealstan} Object
#' 
#' This wrapper will pull the \code{rstan} samples out of a fitted \code{idealstan} model and then launch
#' \code{\link[shinystan]{launch_shinystan}}. This function is useful for examining convergence statistics of the 
#' underlying MCMC sampling.
#' 
#' @seealso \code{\link[shinystan]{shinystan}}
#' @param object A fitted \code{idealstan} object
#' @param pars A character vector of parameters to select from the underlying \code{rstan} model object
#' @param ... Other parameters passed on to \code{\link[shinystan]{shinystan}}
#' @importFrom shinystan as.shinystan launch_shinystan
#' @export
setMethod(launch_shinystan,signature(object='idealstan'),
          function(object,pars=c('L_free',
                                 'sigma_reg_free',
                                 'sigma_abs_free',
                                 'restrict_high',
                                 'restrict_low',
                                 'restrict_ord',
                                 'steps_votes',
                                 'steps_votes_grm'),...) {
            to_shiny <- as.shinystan(object@stan_samples)
            launch_shinystan(to_shiny,...)
          })

#' Plot the MCMC posterior draws by chain
#' 
#' This function allows you to produce trace plots for assessing the quality
#' and convergence of MCMC chains. 
#' 
#' To use this function, you must pass a fitted \code{idealstan} object
#' along with the name of a parameter in the model. To determine these
#' parameter names, use the \code{summary} function or obtain the data
#' from a plot by passing the \code{return_data=TRUE} option to 
#' \code{id_plog_legis} or \code{id_plot_legis_dyn} to find the 
#' name of the parameter in the Stan model.
#' 
#' This function is a simple wrapper around \code{\link[rstan]{stan_trace}}. 
#' Please refer to that function's documentation for further options.
#' 
#' @param object A fitted \code{idealstan} model
#' @param ... Other options passed on to \code{\link[rstan]{stan_trace}}
#' @export
setGeneric('stan_trace',
           signature='object',
           function(object,...) standardGeneric('stan_trace'))

#' Plot the MCMC posterior draws by chain
#' 
#' This function allows you to produce trace plots for assessing the quality
#' and convergence of MCMC chains. 
#' 
#' To use this function, you must pass a fitted \code{idealstan} object
#' along with the name of a parameter in the model. To determine these
#' parameter names, use the \code{summary} function or obtain the data
#' from a plot by passing the \code{return_data=TRUE} option to 
#' \code{id_plog_legis} or \code{id_plot_legis_dyn} to find the 
#' name of the parameter in the Stan model.
#' 
#' This function is a simple wrapper around \code{\link[rstan]{stan_trace}}. 
#' Please refer to that function's documentation for further options.
#' 
#' @param object A fitted \code{idealstan} model
#' @param par The character string  name of a parameter in the model 
#' @param ... Other options passed on to \code{\link[rstan]{stan_trace}}
#' @export
setMethod('stan_trace',signature(object='idealstan'),
          function(object,par='L_full[1]') {
            
        rstan::stan_trace(object@stan_samples,pars = par)
          })

