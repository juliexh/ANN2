// [[Rcpp::depends(RcppArmadillo)]]
#include <RcppArmadillo.h>
#include "loss.h"
using namespace Rcpp;
using namespace arma;

// ---------------------------------------------------------------------------//
// Base loss class
// ---------------------------------------------------------------------------//

double loss::eval(mat y, mat y_fit) { return 0; }
mat loss::grad(mat y, mat y_fit) { return 0; }

// ---------------------------------------------------------------------------//
// Loss classes
// ---------------------------------------------------------------------------//

class logLoss : public loss
{
public:
  logLoss () {}
  
  double eval(mat y, mat y_fit) 
  {
    mat l = -log( y_fit.elem(find(y == 1)) );
    l = clamp(l, std::numeric_limits<double>::min(), 
              std::numeric_limits<double>::max());
    return accu(l) / y.n_rows;
  }
  
  mat grad(mat y, mat y_fit) 
  { 
    return y_fit-y;
  }
};

class squaredLoss : public loss 
{
public:
  squaredLoss () {}
  
  double eval(mat y, mat y_fit) 
  {
    mat l = pow(y_fit - y, 2);
    return accu( l ) / y.n_rows;
  }
  
  mat grad(mat y, mat y_fit) 
  { 
    return 2 * (y_fit - y);
  }
};

class absoluteLoss : public loss
{
public:
  absoluteLoss () {}
  
  double eval(mat y, mat y_fit) 
  {
    mat l = abs(y_fit - y);
    return accu( l ) / y.n_rows;
  }
  
  mat grad(mat y, mat y_fit) 
  { 
    return sign( y_fit - y );
  }
};

class huberLoss : public loss
{
private:
  double dHuber;
public:
  huberLoss(List loss_param_) 
    : dHuber(loss_param_["dHuber"]) {}
  
  double eval(mat y, mat y_fit) 
  {
    mat E   = abs(y_fit - y);
    mat l   = dHuber * (E - dHuber/2);
    uvec iE = find(E <= dHuber);
    l(iE)   = pow(E(iE), 2)/2;
    return accu( l ) / y.n_rows;
  }
  
  mat grad(mat y, mat y_fit) 
  { 
    mat E   = y_fit - y;
    mat dl  = dHuber * sign(E);
    uvec iE = find(abs(E) <= dHuber);
    dl(iE)  = E(iE);
    return dl;
  }
};

class pseudoHuberLoss : public loss
{
private:
  double dHuber;
public:
  pseudoHuberLoss(List loss_param_) 
    : dHuber(loss_param_["dHuber"]) {}
  
  double eval(mat y, mat y_fit) 
  {
    mat l = sqrt(1 + pow( (y_fit - y) / dHuber, 2)) - 1;
    return accu( l ) / y.n_rows;
  }
  
  mat grad(mat y, mat y_fit) 
  { 
    mat E = y_fit - y;
    return E % ( 1 / sqrt(1 + pow(E/dHuber, 2)) );
  }
};

// ---------------------------------------------------------------------------//
// Methods for loss factory 
// ---------------------------------------------------------------------------//

// Constructor
lossFactory::lossFactory (List loss_param_) : loss_param(loss_param_) 
{
  // Set optimization type
  type = as<std::string>(loss_param["type"]);
}

// Method for creating optimizers
loss *lossFactory::createLoss () 
{
  if      (type == "log")         return new logLoss();
  else if (type == "squared")     return new squaredLoss();
  else if (type == "absolute")    return new absoluteLoss();
  else if (type == "huber")       return new huberLoss(loss_param);
  else if (type == "pseudoHuber") return new pseudoHuberLoss(loss_param);
  else                            return NULL;
}

