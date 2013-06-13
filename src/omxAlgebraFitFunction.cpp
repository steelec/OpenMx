/*
 *  Copyright 2007-2013 The OpenMx Project
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *       http://www.apache.org/licenses/LICENSE-2.0
 *
 *   Unless required by applicable law or agreed to in writing, software
 *   distributed under the License is distributed on an "AS IS" BASIS,
 *   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 */

#include "omxAlgebraFunctions.h"

#ifndef _OMX_ALGEBRA_FITFUNCTION_
#define _OMX_ALGEBRA_FITFUNCTION_ TRUE

typedef struct {

	omxMatrix *algebra;

} omxAlgebraFitFunction;

void omxDestroyAlgebraFitFunction(omxFitFunction *off) {

}

static void omxCallAlgebraFitFunction(omxFitFunction *off, int want, double *gradient) {	// TODO: Figure out how to give access to other per-iteration structures.
	if(OMX_DEBUG_ALGEBRA) {Rprintf("Beginning Algebra Fit Function Computation.\n");}
	omxMatrix* algebra = ((omxAlgebraFitFunction*)(off->argStruct))->algebra;

	omxRecompute(algebra);
	
	// This should really be checked elsewhere. TODO
	if(algebra->rows != 1 || algebra->cols != 1) {
		error("MxAlgebraFitFunction's fit function algebra does not evaluate to a 1x1 matrix.");
	}
	
	off->matrix->data[0] = algebra->data[0];
	
	if(OMX_DEBUG) {Rprintf("Algebra Fit Function value is %f.\n", off->matrix->data[0]);}
}

omxRListElement* omxSetFinalReturnsAlgebraFitFunction(omxFitFunction *off, int *numReturns) {
	*numReturns = 1;
	omxRListElement* retVal = (omxRListElement*) R_alloc(1, sizeof(omxRListElement));

	retVal[0].numValues = 1;
	retVal[0].values = (double*) R_alloc(1, sizeof(double));
	strncpy(retVal[0].label, "Minus2LogLikelihood", 20);
	retVal[0].values[0] = omxMatrixElement(off->matrix, 0, 0);

	return retVal;
}

void omxInitAlgebraFitFunction(omxFitFunction* off, SEXP rObj) {
	
	if(OMX_DEBUG && off->matrix->currentState->parentState == NULL) {
		Rprintf("Initializing Algebra fitFunction function.\n");
	}
	
	SEXP newptr;
	
	omxAlgebraFitFunction *newObj = (omxAlgebraFitFunction*) R_alloc(1, sizeof(omxAlgebraFitFunction));
	PROTECT(newptr = GET_SLOT(rObj, install("algebra")));
	newObj->algebra = omxMatrixLookupFromState1(newptr, off->matrix->currentState);
	if(OMX_DEBUG && off->matrix->currentState->parentState == NULL) {
		Rprintf("Algebra Fit Function Bound to Algebra %d\n", newObj->algebra);
	}
	
	off->computeFun = omxCallAlgebraFitFunction;
	off->setFinalReturns = omxSetFinalReturnsAlgebraFitFunction;
	off->destructFun = omxDestroyAlgebraFitFunction;
	off->repopulateFun = handleFreeVarList;

	
	off->argStruct = (void*) newObj;
}


#endif /* _OMX_ALGEBRA_FITFUNCTION_ */
