#Release v0.5.1
* Fixed bugs in plotting functions related to plotting two groups.
* Fixed bug in AR(1) model with restricted time variance.
* Updated dependencies to rstan 2.18.2.
* Added error-catching in covariate creation.

#Release v0.5.0
* New models for Poisson, ordinal-graded response, Normal and Log-normal outcomes.
* Time-varying ideal point processes: random-walks and auto-regressive priors.
* Time-varying plot functions for ideal points.
* Hierarchical covariates for ideal points and item/bill discrimination.
* Switched from matrix data input to long data frames.

#Release v0.2.9.1
* Fixed bugs in `id_extract` and `id_make` functions.

#Release v0.2.9
* Fixed a bug in the ideal point plot function, and also in the `auto_id` option in `id_estimate`.

# Release v0.2.2
* First release on CRAN.
* Fixed documentation issues from v0.2.1
* All vignettes now building properly.