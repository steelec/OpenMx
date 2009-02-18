/***********************************************************
* 
*  omxObjective.cc
*
*  Created: Timothy R. Brick 	Date: 2008-11-13 12:33:06
*
*	Objective objects are a subclass of data matrix that evaluates
*   itself anew at each iteration, so that any changes to
*   free parameters can be incorporated into the update.
*
**********************************************************/

#include "omxMatrix.h"
#include "omxObjective.h"
#include "omxRObjective.h"
#include "omxRAMObjective.h"
#include "omxFIMLObjective.h"
#include "omxAlgebraObjective.h"\

/* Need a better way to deal with these. */
extern omxMatrix** algebraList;
extern omxMatrix** matrixList;

void omxFreeObjectiveArgs(omxObjective *oo) {
	/* Completely destroy the objective function tree */

	oo->destructFun(oo);
	oo->myMatrix = NULL;
	
}

void omxObjectiveCompute(omxObjective *oo) {
	if(OMX_DEBUG) { Rprintf("Objective compute: 0x%0x (needed: %s).\n", oo, (oo->myMatrix->isDirty?"Yes":"No"));}

	oo->objectiveFun(oo);

}

unsigned short omxObjectiveNeedsUpdate(omxObjective *oo)
{
	/* Should we let objective functions calculate this for themselves?  Might be complicated. */
	return 1;

}


void omxFillMatrixFromMxObjective(omxMatrix* om, SEXP rObj, SEXP dataList) {

	const char *objType;
	SEXP objectiveClass;
	omxObjective *obj = (omxObjective*) R_alloc(sizeof(omxObjective), 1);

	/* Register Objective and Matrix with each other */
	obj->myMatrix = om;
	omxResizeMatrix(om, 1, 1, FALSE);					// Objective matrices MUST be 1x1.
	om->objective = obj;
	
	/* Get Objective Type */
	PROTECT(objectiveClass = STRING_ELT(getAttrib(rObj, install("class")), 0));
	objType = CHAR(objectiveClass);
	obj->objType[250] = '\0';
	strncpy(obj->objType, objType, 249);
	
	/* Switch based on objective type. */  // Right now, this is hard-wired.  // TODO: Replace with hash function and table lookup.
	if(strncmp(objType, "MxRAMObjective", 21) == 0) { // Covariance-style optimization.
		obj->initFun = omxInitRAMObjective;
		obj->objectiveFun = omxCallRAMObjective;
		obj->destructFun = omxDestroyRAMObjective;
	} else if(strncmp(objType, "MxFIMLObjective", 15) == 0) {
		obj->initFun = omxInitFIMLObjective;
		obj->objectiveFun = omxCallFIMLObjective;
		obj->destructFun = omxDestroyFIMLObjective;
	} else if(strncmp(objType, "MxAlgebraObjective", 18) == 0) {
		obj->initFun = omxInitAlgebraObjective;
		obj->objectiveFun = omxCallAlgebraObjective;
		obj->destructFun = omxDestroyAlgebraObjective;
	} else if(strncmp(objType, "MxRObjective", 12) == 0) {
		obj->initFun = omxInitRObjective;
		obj->objectiveFun = omxCallRObjective;
		obj->destructFun = omxDestroyRObjective;
	} else {
		error("Objective function type %s not implemented on this kernel.", objType);
	}

	obj->initFun(obj, rObj, dataList);

	UNPROTECT(1);	/* objectiveClass */

}

void omxObjectivePrint(omxObjective* oo, char* d) {
	Rprintf("(Objective, type %s) ", oo->objType);
	omxMatrixPrint(oo->myMatrix, d);
}
