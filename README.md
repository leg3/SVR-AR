# SVR-AR

Autoregressive forecasting model for the Sentiment–Volatility Ratio from the capstone project:

**Predictive Models for the Diagnostic Ratio of Consumer Sentiment and Volatility**

This repository contains the standalone AR forecasting workflow from the original capstone research code. The goal of this repository is to preserve, review, validate, and eventually clean up the AR implementation independently from the related ARIMA, MLP, and LSTM model repositories.

## Project Overview

The capstone project compared several forecasting approaches for a transformed ratio of consumer sentiment and market volatility.

The source series are:

* **UMCSI / UMCSENT**: University of Michigan Consumer Sentiment Index
* **VIXCLS**: CBOE Volatility Index from FRED

The modeled series is the log-transformed diagnostic ratio:

```r
log(SVR) = log(UMCSI) - log(mean monthly VIX)
```

This repository focuses only on the autoregressive model family.

The broader capstone compared:

* AR
* ARIMA
* MLP
* LSTM

Only the AR workflow is implemented here.

## Repository Purpose

This repository is currently in a preservation-first stage.

The immediate goal is to preserve the original AR research workflow in small, reviewable building blocks before making any major changes. The code has been added incrementally so that each logical section can be inspected, validated, committed, and reviewed independently.

Future changes may improve structure, documentation, validation, error handling, or reproducibility, but those changes should be separated from the preserved baseline.

## Current Workflow

The AR script performs the following steps:

1. Loads required R packages.
2. Retrieves VIX and UMCSI data from FRED.
3. Aggregates daily VIX observations to monthly mean values.
4. Applies log transformations to UMCSI and monthly mean VIX.
5. Constructs the log diagnostic ratio.
6. Creates a chronological modeling dataframe.
7. Splits the data into training and test partitions.
8. Defines forecast horizons and AR lag-order candidates.
9. Fits AR models as `ARIMA(p, 0, 0)` models using `forecast::Arima()`.
10. Uses an expanding-window rolling forecast design.
11. Calculates forecast accuracy metrics.
12. Exports the AR metrics table to CSV.

## Data Sources

The script retrieves data from FRED using `pipewelder::get_fred()`.

```r
volatility_series <- get_fred("VIXCLS", "1990-01-02", "2025-12-31")
sentiment_series <- get_fred("UMCSENT", "1990-01-01", "2025-12-31")
```

The requested data window is January 1990 through December 2025.

VIX data are retrieved as daily observations and then aggregated to monthly means. UMCSI is retrieved as a monthly sentiment series.

## Modeled Series

The script constructs the modeled series as follows:

```r
log_ratio_raw = log_value_sen - log_value_mnvol
```

Where:

* `log_value_sen` is the log of UMCSI.
* `log_value_mnvol` is the log of monthly mean VIX.
* `log_ratio_raw` is the modeled log diagnostic ratio.

The final modeling dataframe keeps:

```r
date
y
```

Where `y` is the log diagnostic ratio.

## Train/Test Split

The script uses a chronological train/test split.

```r
n_test <- 84
```

The final 84 monthly observations are held out as the test set.

Under the historical capstone baseline, this corresponds to:

| Partition | Observations |
| --------- | -----------: |
| Training  |          348 |
| Test      |           84 |
| Total     |          432 |

The split is time-ordered. No random sampling is used.

## AR Model Specification

Candidate AR models are fit using `forecast::Arima()`.

```r
forecast::Arima(ts_y, order = c(p, 0, 0), include.mean = TRUE)
```

This represents an AR model as:

```r
ARIMA(p, 0, 0)
```

The candidate lag orders are:

```r
p_grid <- c(1:6)
```

The forecast horizons are:

```r
h_list <- c(1, 3)
```

The preserved workflow therefore evaluates:

|  Horizon | Candidate Models                         |
| -------: | ---------------------------------------- |
|  1 month | AR(1), AR(2), AR(3), AR(4), AR(5), AR(6) |
| 3 months | AR(1), AR(2), AR(3), AR(4), AR(5), AR(6) |

The model is fit with a mean term included.

## Forecasting Design

The script uses a leakage-safe expanding-window rolling forecast setup.

For each target observation in the test period:

1. The target row is mapped to its global row index in the full modeling dataframe.
2. The forecast origin is set to:

```r
origin_global_idx <- target_global_idx - h
```

3. The AR model is fit only on observations available through the forecast origin.
4. The model forecasts `h` steps ahead.
5. The `h`-th forecast value is aligned with the target observation.

This means the model is repeatedly refit as the test period progresses.

The design is expanding-window because each successive forecast can use more historical observations, but never observations beyond the allowed forecast origin.

For horizon `h = 3`, the workflow generates a three-step-ahead forecast and evaluates the third forecasted value against the target observation.

## Evaluation Metrics

The script calculates three test-set accuracy metrics:

```r
mse  = mean(resid^2, na.rm = TRUE)
rmse = sqrt(mse)
mae  = mean(abs(resid), na.rm = TRUE)
```

The primary historical model-selection metric was MAE.

The results table includes:

| Column      | Description                         |
| ----------- | ----------------------------------- |
| `model_id`  | Model label, such as `AR1` or `AR5` |
| `p`         | AR lag order                        |
| `horizon`   | Forecast horizon                    |
| `test_mse`  | Test mean squared error             |
| `test_rmse` | Test root mean squared error        |
| `test_mae`  | Test mean absolute error            |

Results are sorted by:

```r
arrange(horizon, test_mae)
```

## Historical Capstone Baseline

The capstone reported the following historical AR results.

### One-Month Horizon

| Model |    Test RMSE |     Test MAE |
| ----- | -----------: | -----------: |
| AR(1) | 0.2215495905 | 0.1624811652 |
| AR(2) | 0.2209759606 | 0.1641702885 |
| AR(3) | 0.2200958536 | 0.1612321149 |
| AR(4) | 0.2197891154 | 0.1603621363 |
| AR(5) | 0.2186439587 | 0.1596278215 |
| AR(6) | 0.2191517384 | 0.1605112827 |

The reported best one-month AR model was:

```text
AR(5), test MAE approximately 0.15963
```

### Three-Month Horizon

| Model |    Test RMSE |     Test MAE |
| ----- | -----------: | -----------: |
| AR(1) | 0.3540760006 | 0.2454582785 |
| AR(2) | 0.3543001846 | 0.2469333908 |
| AR(3) | 0.3513650968 | 0.2419530462 |
| AR(4) | 0.3483161280 | 0.2373494115 |
| AR(5) | 0.3455230040 | 0.2338481481 |
| AR(6) | 0.3467826632 | 0.2356262466 |

The reported best three-month AR model was:

```text
AR(5), test MAE approximately 0.23385
```

These values are historical reference results. The repository should not force the current workflow to reproduce these numbers if package behavior, source data, or code behavior differs. Any discrepancy should be documented rather than hidden.

## Dependencies

The preserved AR workflow uses the following R packages:

```r
library(pipewelder)
library(tidyverse)
library(lubridate)
library(forecast)
```

Package roles:

| Package      | Purpose                                             |
| ------------ | --------------------------------------------------- |
| `pipewelder` | Retrieves FRED source data                          |
| `tidyverse`  | Data manipulation, joining, summarizing, CSV export |
| `lubridate`  | Date handling and monthly VIX aggregation           |
| `forecast`   | AR model fitting and forecasting                    |

## Running the Script

From an R session or RStudio project rooted at this repository, run the main AR script.

Example:

```r
source("SVR_AR.R")
```

If the script has a different filename, replace `SVR_AR.R` with the actual script name.

The script retrieves data, builds the transformed series, performs rolling AR evaluation, writes the metrics CSV, and prints the final metrics table.

## Output

The preserved script writes:

```text
AR Metrics FINAL.csv
```

This file contains the test metrics for every AR lag-order and forecast-horizon combination.

Generated output files should be reviewed before committing. In general, generated artifacts should not be committed unless the repository intentionally decides to preserve a specific output as part of the documented baseline.

## Validation Checklist

Useful validation checks include:

```r
nrow(df_all)
nrow(train_df)
nrow(test_df)

range(df_all$date)
range(train_df$date)
range(test_df$date)

h_list
p_grid

metrics_arp_nn
```

Expected structural checks:

```r
stopifnot(nrow(test_df) == 84)
stopifnot(nrow(train_df) + nrow(test_df) == nrow(df_all))
stopifnot(max(train_df$date) < min(test_df$date))
stopifnot(identical(h_list, c(1, 3)))
stopifnot(identical(p_grid, 1:6))
stopifnot(nrow(metrics_arp_nn) == length(p_grid) * length(h_list))
```

The final metrics table should contain:

```r
model_id
p
horizon
test_mse
test_rmse
test_mae
```

## Preservation Notes

This repository intentionally preserves several details from the recovered AR script, including:

* The use of `pipewelder::get_fred()`.
* The requested source-data window ending in December 2025.
* Monthly mean aggregation of daily VIX values.
* The log-ratio construction.
* The 84-observation test period.
* Candidate AR lag orders from 1 through 6.
* Forecast horizons of 1 and 3 months.
* `forecast::Arima()` with `order = c(p, 0, 0)`.
* `include.mean = TRUE`.
* The expanding-window rolling forecast setup.
* The output object name `metrics_arp_nn`.
* The output filename `AR Metrics FINAL.csv`.

Some names may be improved in later cleanup, but preservation of original behavior takes priority during the baseline phase.

## Known Review Items

The following items should be reviewed before treating the repository as fully cleaned or production-ready:

* Confirm the exact behavior and return structure of `pipewelder::get_fred()`.
* Confirm whether FRED data revisions affect reproducibility.
* Confirm whether current output exactly matches the historical capstone metrics.
* Document any differences between the capstone paper and executed code.
* Add explicit warning/error handling for failed AR fits if needed.
* Decide whether generated CSV outputs belong in source control.
* Consider renaming objects such as `metrics_arp_nn` after the preservation phase.
* Consider adding dependency documentation or environment capture.
* Consider separating preserved research code from cleaned reusable code.

## Relationship to Other SVR Repositories

This repository is part of a broader effort to preserve and document the capstone forecasting models as separate standalone repositories.

Related model families include:

* SVR-ARIMA
* SVR-MLP
* SVR-LSTM

Those models are intentionally handled in separate repositories. This repository should remain focused on the AR implementation unless a future architectural decision explicitly changes that separation.

## License

See the repository license file for licensing details.
