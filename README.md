# MilkBot-API
The MilkBot lactation model is a nonlinear lactation model describing daily milk production 
as a function of time(days) since calving (DIM). It is parameterized so that fitted parameter
values are can be interpreted as observable features of the lactation as a whole.  
<img src="https://github.com/jehrlich/MilkBot-API/blob/master/assets/equation.svg" width="450">

- **_scale_**, the overall level of milk production
- **_ramp_**, governs the rate of the rise in early lactation
- **_decay_** is the rate of exponential decline, most apparent in late lactation
- **_offset_** is a small (usually insignificant) correction for time between calving and the theoretical start of lactation

An open-access paper in **_PeerJ_** provides a good introduction to the model. 
[Quantifying inter-group variability in lactation curve shape and magnitude with the MilkBot® lactation model](https://peerj.com/articles/54/)

Because it is a nonlinear model, fitting is not straightforward. We have developed and 
[validated](https://www.sciencedirect.com/science/article/pii/S0022030212003815) a Bayesian 
fitting engine that estimates fitted parameter values from a set of expected values (the priors) 
and any number of data points.

This API describes the API for a planned public service for access to that fitting process.

## current status
This API is under development and open for comment and suggestions. When some consensus
has been achieved on a workable API, the fitting engine will be ported to this API.
