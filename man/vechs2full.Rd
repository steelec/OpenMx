%
%   Copyright 2007-2018 The OpenMx Project
%
%   Licensed under the Apache License, Version 2.0 (the "License");
%   you may not use this file except in compliance with the License.
%   You may obtain a copy of the License at
% 
%        http://www.apache.org/licenses/LICENSE-2.0
% 
%   Unless required by applicable law or agreed to in writing, software
%   distributed under the License is distributed on an "AS IS" BASIS,
%   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%   See the License for the specific language governing permissions and
%   limitations under the License.

\name{vechs2full}
\alias{vechs2full}

\title{Inverse Strict Half-vectorization}

\description{
   This function returns the symmetric matrix constructed from a strict half-vectorization.
}

\usage{
vechs2full(x)
}

\arguments{
   \item{x}{an input single column or single row matrix.}
}

\details{
   The strict half-vectorization of an input matrix consists of the elements in the lower triangle of the matrix, excluding the elements along the diagonal of the matrix, as a column vector.  The column vector is created by traversing the matrix in column-major order.  The inverse strict half-vectorization takes a vector and reconstructs a symmetric matrix such that \code{vechs2full(vechs(x))} is equal to \code{x} with zero along the diagonal if \code{x} is symmetric.

   Note that very few vectors have the correct number of elements to construct a symmetric matrix.  For example, vectors with 1, 3, 6, 10, and 15 elements can be used to make a symmetric matrix, but none of the other numbers between 1 and 15 can.  An error is thrown if the number of elements in \code{x} cannot be used to make a symmetric matrix.
}

\seealso{
\code{\link{vech2full}}, \code{\link{vech}}, \code{\link{vechs}}, \code{\link{rvectorize}}, \code{\link{cvectorize}}
}

\examples{

vechs2full(1:10)

matrix(1:16, 4, 4)
vechs(matrix(1:16, 4, 4))
vechs2full(vechs(matrix(1:16, 4, 4)))



}
