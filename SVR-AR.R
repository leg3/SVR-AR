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

# Monthly mean of VIX (convert daily VIX to monthly average)
mean_volatility_series <- volatility_series %>%
  mutate(month = floor_date(date, "month")) %>%
  group_by(month) %>%
  summarize(mean_value = mean(value, na.rm = TRUE), .groups = "drop") %>%
  rename(date = month)

# Log transform the series
log_sentiment_series <- sentiment_series %>%
  mutate(log_value_sen = log(value))

# Log transform the volatility series (monthly mean VIX)
log_mean_volatility_series <- mean_volatility_series %>%
  mutate(log_value_mnvol = log(mean_value))

# Join and compute transformed ratio
log_diagnostic_ratio_series <- log_sentiment_series %>%
  inner_join(log_mean_volatility_series, by = "date") %>%
  select(-value, -mean_value) %>%
  mutate(log_ratio_raw = (log_value_sen - log_value_mnvol))
