# AR(p) Diagnostic ratio - UMCSI:VIX
#
# This script evaluates a grid of AR(p) models using a leakage-safe,
# expanding-window rolling forecast setup, and reports forecast accuracy metrics
# (MSE/RMSE/MAE) on the held-out test period for horizons h = 1 and h = 3.
#
# There are THREE nested "loops", implemented functionally (purrr) instead of
# for-loops: (1) model grid loop   : iterate over each p in p_grid (2) horizon
# loop      : iterate over each h in h_list (3) time/rolling loop : iterate over
# each timestamp k inside the test split
#
# Leakage safety rule: For a target observation at time t (the split row k), the
# forecast "origin" is set to t - h, so the model is fit only on data up through
# t - h (never t).

# Libraries
library(pipewelder)
library(tidyverse)
library(lubridate)
library(forecast)

# Set seed
set.seed(599)

# Retreive data from FRED
volatility_series <- get_fred("VIXCLS", "1990-01-02", "2025-12-31")
sentiment_series <- get_fred("UMCSENT", "1990-01-01", "2025-12-31")
