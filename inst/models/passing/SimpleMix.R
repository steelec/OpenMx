library(OpenMx)

set.seed(1)

start_prob <- c(.2,.3,.4)

state <- sample.int(3, 1, prob=start_prob)
trail <- c(state)
for (rep in 1:200) {
	state <- sample.int(3, 1, prob=start_prob)
	trail <- c(trail, state)
}

noise <- .2
trailN <- sapply(trail, function(v) rnorm(1, mean=v, sd=sqrt(noise)))

classes <- list()

for (cl in 1:3) {
	classes[[cl]] <- mxModel(paste0("class", cl), type="RAM",
			       manifestVars=c("ob"),
			       mxPath("one", "ob", value=cl, free=FALSE),
			       mxPath("ob", arrows=2, value=noise, free=FALSE),
			       mxFitFunctionML(vector=TRUE))
}

mix1 <- mxModel(
	"mix1", classes,
	mxData(data.frame(ob=trailN), "raw"),
	mxMatrix(values=1, nrow=1, ncol=3, free=c(FALSE,TRUE,TRUE), name="weights"),
	mxExpectationMixture(paste0("class",1:3), scale="softmax"),
	mxFitFunctionML(),
	mxComputeSequence(list(
		mxComputeGradientDescent(),
		mxComputeReportExpectation())))

mix1Fit <- mxRun(mix1)

omxCheckCloseEnough(mix1Fit$expectation$output$weights,
                    start_prob/sum(start_prob), .03)

# ------------------

mix3 <- mxModel(
	"mix3", classes,
	mxData(data.frame(ob=trailN, row=1:length(trailN)), "raw"),
	mxMatrix(values=runif(3*length(trailN)),
		 nrow=length(trailN), ncol=3, free=TRUE, name="rowWeight"),
	mxAlgebra(rowWeight[data.row,], name="weights"),
	mxExpectationMixture(paste0("class",1:3), scale="softmax"),
	mxFitFunctionML(),
	mxComputeSequence(list(
		mxComputeGradientDescent(),
		mxComputeReportExpectation())))

mix3$rowWeight$free[,1] <- FALSE

mix3Fit <- mxRun(mix3)

omxCheckCloseEnough(sum(apply(mix3Fit$rowWeight$values, 1, function(x) {
  which(x == max(x))
}) != trail) / length(trail), 0, .17)

# ------------------

mix2 <- mxModel(
  "mix2", classes,
  mxData(data.frame(ob=trailN), "raw"),
  mxMatrix(values=1, nrow=1, ncol=3, free=c(FALSE,TRUE,TRUE), name="initial"),
  mxExpectationHiddenMarkov(paste0("class",1:3), scale="softmax"),
  mxFitFunctionML(),
  mxComputeSequence(list(
    mxComputeGradientDescent(),
    mxComputeReportExpectation())))

mix2Fit <- mxRun(mix2)
omxCheckCloseEnough(mix2Fit$output$fit, mix1Fit$output$fit, 1e-6)
