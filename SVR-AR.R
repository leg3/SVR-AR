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

# Time-ordered partitions (monthly obs)
n_test <- 84   # ~7 years

# Create modeling dataframe (monthly, ordered, no missing y)
df_all <- log_diagnostic_ratio_series %>%
  select(date, y = log_ratio_raw) %>%
  arrange(date) %>%
  filter(!is.na(y))

# Total number of observations
n <- nrow(df_all)

# Sanity check: need enough observations to have train + test
stopifnot(n_test < n)

# Define start index of the test block in df_all
# This is a "global" index relative to df_all.
i_test_start <- n - n_test + 1

# Subset df_all into training and test sets
train_df <- df_all[1:(i_test_start - 1), ]
test_df  <- df_all[i_test_start:n, ]

# Rolling forecast
# Horizons
h_list <- c(1, 3)

# Define the AR order grid to evaluate
p_grid <- c(1:6)

# Define global start index for the test split inside df_all
# Needed because rolling code maps split row k -> global df_all row index:
# target_global_idx = split_start_idx + (k - 1)
test_start_idx <- i_test_start
