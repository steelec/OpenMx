#
#   Copyright 2007-2018 The OpenMx Project
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
# 
#        http://www.apache.org/licenses/LICENSE-2.0
# 
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.


#------------------------------------------------------------------------------
# Author: Michael D. Hunter
# Date: 2016-01-30
# Filename: MxRobustSE.R
# Purpose: Write a function for robust standard errors
#------------------------------------------------------------------------------

##' imxRowGradients
##'
##' This is an internal function exported for those people who know
##' what they are doing.
##'
##' This function computes the gradient for each row of data.
##' The returned object is a matrix with the same number of rows as the data,
##' and the same number of columns as there are free parameters.
##'
##' @param model An OpenMx model object that has been run
##' @param robustSE Logical; are the row gradients being requested to calculate robust standard errors?
imxRowGradients <- function(model, robustSE=FALSE){
	if(is.null(model@output)){
		stop("The 'model' argument has no output.  Give me a model that has been run.")
	}
	#If 'model' contains submodels and uses the multigroup fitfunction, then we can be pretty sure what we're supposed to do to get
	#row gradients:
	if(length(model@submodels)){
		if(is(model@fitfunction,"MxFitFunctionMultigroup")){
			grads <- NULL
			paramLabels <- names(omxGetParameters(model))
			numParam <- length(paramLabels)
			contributingModelNames <- model@fitfunction$groups
			custom.compute <- mxComputeSequence(list(mxComputeNumericDeriv(checkGradient=FALSE, hessian=FALSE), mxComputeReportDeriv()))
			for(i in 1:length(model@submodels)){
				#Ignore submodels that don't contribute to the multigroup fitfunction:
				if(grep(pattern=model@submodels[[i]]$name,x=contributingModelNames)){
					currModel <- model@submodels[[i]]
					if(is.null(currModel@data)){
						if(robustSE){
							#This is a warning, not an error, because there are edge cases where the robust SEs could still be valid:
							warning(paste("submodel '",currModel@name,"' contributes to the multigroup fitfunction but contains no data; robust standard errors may be incorrect",sep=""))
						} 
						next
					}
					if(currModel@data$type!="raw"){
						if(robustSE){
							stop(paste("submodel '",currModel@name,"' contributes to the multigroup fitfunction but does not contain raw data, which is required for robust standard errors",sep=""))
						}
						next
					}
					if(robustSE && is(currModel@fitfunction, "MxFitFunctionWLS")){
						stop(paste("submodel '",currModel@name,"' contributes to the multigroup fitfunction but uses WLS fit; robust standard errors require ML fit",sep=""))	
					}
					if(length(currModel@submodels)){ #<--Possible TODO: handle this case with function recursion
						if(robustSE){
							warning(paste("submodel '",currModel@name,
														"' contains submodels of its own; support for submodels of submodels not implemented, so robust standard errors may be incorrect",sep=""))
						}
						else{
							warning(paste("submodel '",currModel@name,
														"' contains submodels of its own; support for submodels of submodels not implemented",sep=""))
						}
					}
					#By itself, a GREML model can't get robust SEs; you'd end up calculating the variance of the row derivatives for a sample of n=1 row.
					#But, if it's a submodel contributing to a multigroup fit (admittedly a corner case), then it's just another data row
					#(though I am not sure if the theory underlying the sandwich estimator still applies for restricted maximum likelihood):
					if(is(currModel@expectation, "MxExpectationGREML")){
						#There is assumed to be only one "row" with GREML expectation, even if the raw dataset isn't (yet) structured that way:
						currGrads <- matrix(0,nrow=1,ncol=numParam,dimnames=list(NULL,paramLabels))
						grun <- mxRun(mxModel(currModel, custom.compute))
						currGrads[1,names(grun$output$gradient)] <- grun$output$gradient
						grads <- rbind(grads,currGrads)
					}
					else{
						if(length(currModel@data$indexVector) == nrow(currModel@data$observed)){ #put data back in unsorted order
							currModel@data@observed <- currModel@data$observed[order(currModel@data$indexVector), ]
						}
						currData <- currModel@data$observed
						currGrads <- matrix(0,nrow=nrow(currData),ncol=numParam,dimnames=list(NULL,paramLabels))
						for(j in 1:nrow(currData)){
							grun <- mxRun(mxModel(currModel, custom.compute, mxData(currData[j,,drop=FALSE],"raw")), silent=as.logical((j-1)%%100))
							currGrads[j,names(grun$output$gradient)] <- grun$output$gradient
						}
						grads <- rbind(grads,currGrads)
					}
				}
			}
		}
		else{stop("to obtain gradients for data rows in submodels, please use an MxFitFunctionMultigroup in 'model'")}
	}
	else{ #i.e., if no submodels
		if(is.null(model@data)){
			stop("The 'model' argument must have data, or if multigroup, use an MxFitFunctionMultigroup")
		}
		if(model$data$type!='raw'){
			stop("The 'model' argument must have raw (not summary) data.")
		}
		nrows <- nrow(model$data$observed)
		if(length(model$data$indexVector) == nrows){ #put data back in unsorted order
			model@data@observed <- model$data$observed[order(model$data$indexVector), ]
		}
		data <- model@data@observed
		custom.compute <- mxComputeSequence(list(mxComputeNumericDeriv(checkGradient=FALSE, hessian=FALSE), mxComputeReportDeriv()))
		grads <- matrix(NA, nrows, length(coef(model)))
		gmodel <- model
		for(i in 1:nrows){
			gmodel <- mxModel(gmodel, custom.compute, mxData(data[i,,drop=FALSE], 'raw'))
			grun <- mxRun(gmodel, silent = as.logical((i-1)%%100), suppressWarnings = FALSE)
			grads[i,] <- grun$output$gradient #get gradient
		}
	}
	return(grads)
}


##' imxRobustSE
##'
##' This is an internal function exported for those people who know
##' what they are doing.
##'
##' This function computes robust standard errors via a sandwich estimator.
##' The "bread" of the sandwich is the numerically computed inverse Hessian
##' of the likelihood function.  This is what is typically used for standard
##' errors throughout OpenMx.  The "meat" of the sandwich is the covariance
##' matrix of the numerically computed row derivatives of the likelihood function
##' (i.e. row gradients).
##' 
##' When \code{details=FALSE}, only the standard errors are returned.  When \code{details=TRUE},
##' a list with named elements \code{SE} and \code{cov} is returned.  The \code{SE} element is the vector of standard errors that is also returned when \code{details=FALSE}.  The \code{cov} element is the full covariance matrix of the parameter estimates.  The square root of the diagonal of \code{cov} gives the standard errors.
##' 
##' This function may not work correctly if 'model' is a multigroup model.  This function also does not correctly handle multilevel data.
##'
##' @param model An OpenMx model object that has been run
##' @param details logical. whether to return the full parameter covariance matrix
imxRobustSE <- function(model, details=FALSE){
	if(is(model@expectation, "MxExpectationGREML")){
		stop("robust standard errors cannot be calculated for a single-group model that uses GREML expectation")
	}
	if(is(model@fitfunction, "MxFitFunctionWLS")){
		stop("imxRobustSE() requires a maximum-likelihood fit, but 'model' uses a WLS fitfunction")
	}
	if(!is(model@fitfunction, "MxFitFunctionML") && !is(model@fitfunction, "MxFitFunctionMultigroup")){
		warning(paste("imxRobustSE() requires a maximum-likelihood fit, but 'model' uses ",class(model@fitfunction),"; robust standard errors will only be correct if the fitfunction units are -2lnL",sep=""))
	}
	grads <- imxRowGradients(model, robustSE=TRUE)/-2
	hess <- model@output$hessian/2
	ret <- OpenMx::"%&%"(solve(hess), nrow(grads)*var(grads))
	if(details){
		return(list(SE=sqrt(diag(ret)), cov=ret))
	} else {
		return(sqrt(diag(ret)))
	}
}

#robse <- imxRobustSE(thresholdModelrun)
#cbind(robse, prevSE)

