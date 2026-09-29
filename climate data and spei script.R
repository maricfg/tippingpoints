# =============================================================================
# Climate data and SPEI calculation and
# =============================================================================

library(raster)
library(reshape2)
library(dplyr)
library(SPEI)
library(zoo)

# ---- Folders ------------------------------------------------------------------
nc_dir   <- file.path("data", "NC Files")  # ERA5-Land NetCDF files: <country>/<country>_<year>.nc
csv_dir  <- file.path("data", "processed")    # converted and cleaned CSV files: <country>/
spei_dir <- file.path("data", "processed")    # community files for SPEI: <country>/SPEI-by community/

# ---- Countries and years --------------------------------------------------------
countries <- c("Ghana", "Kenya", "Mali", "Ethiopia")
years     <- 2002:2023

# Countries where up to two rainy seasons per year are identified
# (Dunning et al., 2016). All others use a single season (Liebmann and Marengo, 2001).
two_season_countries <- c("Kenya", "Ethiopia")

# ---- SPEI -------------------------------------------------------------------------
n_communities <- list(Ghana = 30, Kenya = 30, Mali = 30, Ethiopia = 30)
spei_scales   <- c(1, 12)   # months
ref_years     <- 2002:2011        # reference period

# =============================================================================
# Convert nc to csv
# =============================================================================
for (country in countries) {
  dir.create(file.path(csv_dir, country), recursive = TRUE, showWarnings = FALSE)
  
  for (year in years) {
    ncfile <- file.path(nc_dir, country, paste(country, "_", year, ".nc", sep = ""))
    
    t2m <- brick(ncfile, var = "t2m") # 2m temperature
    tp  <- brick(ncfile, var = "tp")  # Total precipitation
    
    # Convert to dataframes
    t2m.tab <- as.data.frame(t2m, xy = TRUE)
    tp.tab  <- as.data.frame(tp, xy = TRUE)
    
    # Switch rows/columns and export as csv
    t2m.tab.2 <- reshape2::melt(t2m.tab, id = c("x", "y"))
    t2m.out <- file.path(csv_dir, country, paste(country, "_", year, "_t2m.csv", sep = ""))
    write.csv(t2m.tab.2, t2m.out)
    
    tp.tab.2 <- reshape2::melt(tp.tab, id = c("x", "y"))
    tp.out <- file.path(csv_dir, country, paste(country, "_", year, "_tp.csv", sep = ""))
    write.csv(tp.tab.2, tp.out)
    
    message("Converted: ", country, " ", year)
  }
}

# =============================================================================
# Clean temperature
# =============================================================================
clean_t2m <- function(csv.in, csv.out) {
  
  # Read the t2m file
  t2m <- read.csv(csv.in, row.names = 1)
  
  # Remove the "X" character that appears in the beginning of all dates
  t2m$date <- substr(t2m$variable, 2, 20)
  
  # Split the date variable by the "." character
  t2m <- t2m %>%
    data.frame(do.call("rbind", strsplit(as.character(t2m$date), ".", fixed = TRUE)))
  
  # Rename the date variable
  t2m <- t2m %>%
    rename("temp" = "value",
           "year" = "X1",
           "month" = "X2",
           "day" = "X3",
           "hour" = "X4")
  
  # Drop unnecessary variables
  keeps <- c("x", "y", "temp", "year", "month", "day", "hour")
  t2m <- t2m[keeps]
  
  # Change temperature to Celsius
  t2m <- t2m %>%
    mutate(temp = temp - 273.15)
  
  # Generate monthly median, average, min, and max temperatures
  t2m <- t2m %>%
    group_by(x, y, year, month) %>%
    mutate(tmed = median(temp, na.rm = TRUE),
           tmin = min(temp, na.rm = TRUE),
           tmax = max(temp, na.rm = TRUE),
           tavg = mean(temp, na.rm = TRUE))
  
  # Only keep year and month
  t2m <- t2m %>% group_by(x, y, year, month) %>% filter(row_number(temp) == 1)
  
  # Drop unnecessary variables
  keeps <- c("x", "y", "tavg", "tmax", "tmin", "tmed", "year", "month")
  t2m <- t2m[keeps]
  
  # Save as csv
  write.csv(t2m, csv.out)
}

for (country in countries) {
  for (year in years) {
    clean_t2m(
      csv.in  = file.path(csv_dir, country, paste(country, "_", year, "_t2m.csv", sep = "")),
      csv.out = file.path(csv_dir, country, paste(country, "_", year, "_t2m_clean.csv", sep = ""))
    )
    message("Temperature cleaned: ", country, " ", year)
  }
}

# =============================================================================
# Clean Precipitation
# =============================================================================
# ---- 1. hourly to daily precipitation --------------------------

read_daily_tp <- function(csv.in) {
  
  # Read the tp file
  tp <- read.csv(csv.in, row.names = 1)
  
  # Remove the "X" character that appears in the beginning of all dates
  tp$date <- substr(tp$variable, 2, 20)
  
  # Split the date variable by the "." character
  tp <- tp %>%
    data.frame(do.call("rbind", strsplit(as.character(tp$date), ".", fixed = TRUE)))
  
  # Rename the date variable
  tp <- tp %>%
    rename("prcp" = "value",
           "year" = "X1",
           "month" = "X2",
           "day" = "X3",
           "hour" = "X4")
  
  # Drop unnecessary variables
  keeps <- c("x", "y", "prcp", "year", "month", "day", "hour")
  tp <- tp[keeps]
  
  # Change m to mm
  tp <- tp %>%
    mutate(prcp = prcp * 1000)
  
  # Replace negative rainfall values with 0
  tp$prcp[tp$prcp < 0] <- 0
  
  # Combine year, month and day columns into a date
  tp$date <- as.POSIXct(paste(tp$year, tp$month, tp$day, sep = "-"), tz = "GMT")
  
  # Generate sum of daily rainfall
  tp <- tp %>%
    group_by(x, y, year, month, day) %>%
    mutate(prcp_daily = sum(prcp))
  
  # Only keep year, month and day
  tp <- tp %>%
    group_by(x, y, year, month, day) %>%
    filter(row_number(prcp_daily) == 1)
  
  # Calculate annual average rainfall by grid cell and add it to the data frame
  tp <- tp %>%
    group_by(x, y, year) %>%
    mutate(AvgAnnualRainfall = mean(prcp_daily, na.rm = TRUE)) %>%
    ungroup()
  
  # Calculate daily rainfall anomaly
  tp <- tp %>%
    group_by(x, y, year) %>%
    mutate(DailyRainfallAnomaly = prcp_daily - AvgAnnualRainfall)
  
  # Sort
  tp <- tp %>%
    arrange(x, y, date)
  
  # Calculate the day of the year (1 to 365, or 366 in leap years) and the
  # rainfall accumulation for each year and grid cell
  tp <- tp %>%
    group_by(x, y, year) %>%
    arrange(date) %>%
    mutate(
      DayOfYear = as.numeric(format(date, "%j")),
      RainfallAccumulation = cumsum(DailyRainfallAnomaly[!is.na(DailyRainfallAnomaly)])
    ) %>%
    ungroup()
  
  tp
}

# ---- Monthly precipitation statistics --------------------------------------------
add_monthly_stats <- function(tp) {
  # Generate median, average, min, max and total precipitation monthly values
  tp <- tp %>%
    group_by(x, y, year, month) %>%
    mutate(PMed = median(prcp_daily, na.rm = TRUE),
           PMin = min(prcp_daily, na.rm = TRUE),
           PMax = max(prcp_daily, na.rm = TRUE),
           PAvg = mean(prcp_daily, na.rm = TRUE),
           PTotal = sum(prcp_daily, na.rm = TRUE))
  
  # Sort
  tp <- tp %>%
    arrange(x, y, year, month, day)
  
  # Only keep monthly data
  tp %>% group_by(x, y, year, month) %>% filter(row_number(day) == 1)
}

# ---- One rainy season per year (Liebmann and Marengo, 2001) ------------------------
clean_tp_one_season <- function(csv.in, csv.out) {
  tp <- read_daily_tp(csv.in)
  
  # Calculate the Day of Year for minimum and maximum Rainfall Accumulation per year and grid cell
  rainfall_onset_data <- tp %>%
    group_by(x, y, year) %>%
    summarize(RainfallOnsetDayOfYear = DayOfYear[which.min(RainfallAccumulation)],
              RainfallEndDayOfYear = DayOfYear[which.max(RainfallAccumulation)]) %>%
    ungroup()
  
  # Merge the calculated data with the original data frame
  tp <- left_join(tp, rainfall_onset_data, by = c("x", "y", "year"))
  
  # Calculate the number of dry spell days for each grid cell and year
  dry_spell_days <- tp %>%
    group_by(x, y, year) %>%
    arrange(date) %>%
    mutate(
      CumulativeRainfall3Days = zoo::rollsum(prcp_daily, k = 3, fill = NA, align = "right"),
      DrySpellDay = ifelse(CumulativeRainfall3Days < 0.85, 1, 0)
    ) %>%
    filter(DayOfYear >= RainfallOnsetDayOfYear,
           DayOfYear <= RainfallEndDayOfYear) %>%
    summarise(TotalDrySpellDays = sum(DrySpellDay, na.rm = TRUE)) %>%
    ungroup()
  
  # Sort dry_spell_days
  dry_spell_days <- dry_spell_days %>%
    arrange(x, y, year)
  
  # Add dry days to onset data frame
  tp <- left_join(tp, dry_spell_days, by = c("x", "y", "year"))
  
  tp <- add_monthly_stats(tp)
  
  # Drop unnecessary variables
  keeps <- c("x", "y", "year", "month", "AvgAnnualRainfall", "RainfallOnsetDayOfYear",
             "RainfallEndDayOfYear", "TotalDrySpellDays", "PMed", "PAvg", "PTotal")
  tp <- tp[keeps]
  
  # Save as csv
  write.csv(tp, csv.out)
}

# ---- Up to two rainy seasons per year (Dunning et al., 2016) -----------------------
clean_tp_two_seasons <- function(csv.in, csv.out) {
  tp <- read_daily_tp(csv.in)
  
  # Step 1: Compute a smoothed RainfallAccumulation using a 30-day running mean
  tp <- tp %>%
    group_by(x, y, year) %>%
    mutate(
      SmoothedRainfallAccumulation = rollmean(RainfallAccumulation, k = 30, fill = NA, align = "center")
    ) %>%
    ungroup()
  
  # Step 2: Find days with minima and maxima in RainfallAccumulation.
  # A minimum occurs if the smoothed accumulation is lower than 4 days before
  # and 4 days after. A maximum occurs if it is higher than 4 days before and
  # 4 days after.
  tp <- tp %>%
    group_by(x, y, year) %>%
    mutate(
      is_minima = SmoothedRainfallAccumulation < dplyr::lag(SmoothedRainfallAccumulation, 4) &
        SmoothedRainfallAccumulation < dplyr::lead(SmoothedRainfallAccumulation, 4),
      is_maxima = SmoothedRainfallAccumulation > dplyr::lag(SmoothedRainfallAccumulation, 4) &
        SmoothedRainfallAccumulation > dplyr::lead(SmoothedRainfallAccumulation, 4)
    ) %>%
    ungroup()
  
  # Step 3: Find the rainfall onset and end dates
  tp <- tp %>%
    group_by(x, y, year) %>%
    mutate(
      RainfallOnset_1 = min(DayOfYear[is_minima], na.rm = TRUE),
      RainfallEnd_1 = min(DayOfYear[is_maxima & DayOfYear > RainfallOnset_1], na.rm = TRUE),
      RainfallOnset_2 = min(DayOfYear[is_minima & DayOfYear > RainfallEnd_1], na.rm = TRUE),
      RainfallEnd_2 = min(DayOfYear[is_maxima & DayOfYear > RainfallOnset_2], na.rm = TRUE)
    ) %>%
    ungroup()
  
  # Step 4: Set to missing where the conditions could not be fulfilled
  tp <- tp %>%
    group_by(x, y, year) %>%
    mutate(
      RainfallOnset_1 = ifelse(is.na(RainfallOnset_1) | is.infinite(RainfallOnset_1), NA, RainfallOnset_1),
      RainfallEnd_1 = ifelse(is.na(RainfallEnd_1) | is.infinite(RainfallEnd_1), NA, RainfallEnd_1),
      RainfallOnset_2 = ifelse(is.na(RainfallOnset_2) | is.infinite(RainfallOnset_2), NA, RainfallOnset_2),
      RainfallEnd_2 = ifelse(is.na(RainfallEnd_2) | is.infinite(RainfallEnd_2), NA, RainfallEnd_2)
    ) %>%
    ungroup()
  
  # Calculate the number of dry spell days in the first rainy season
  dry_spell_days <- tp %>%
    group_by(x, y, year) %>%
    arrange(date) %>%
    mutate(
      CumulativeRainfall3Days = zoo::rollsum(prcp_daily, k = 3, fill = NA, align = "right"),
      DrySpellDay = ifelse(CumulativeRainfall3Days < 0.85, 1, 0)
    ) %>%
    filter(DayOfYear >= RainfallOnset_1,
           DayOfYear <= RainfallEnd_1) %>%
    summarise(TotalDrySpellDays = sum(DrySpellDay, na.rm = TRUE)) %>%
    ungroup()
  
  # Sort dry_spell_days
  dry_spell_days <- dry_spell_days %>%
    arrange(x, y, year)
  
  # Add dry days to onset data frame
  tp <- left_join(tp, dry_spell_days, by = c("x", "y", "year"))
  
  tp <- add_monthly_stats(tp)
  
  # Drop unnecessary variables
  keeps <- c("x", "y", "year", "month", "AvgAnnualRainfall", "RainfallOnset_1", "RainfallOnset_2",
             "RainfallEnd_1", "RainfallEnd_2", "TotalDrySpellDays", "PMed", "PAvg", "PTotal")
  tp <- tp[keeps]
  
  # Save as csv
  write.csv(tp, csv.out)
}

for (country in countries) {
  clean_tp <- if (country %in% two_season_countries) clean_tp_two_seasons else clean_tp_one_season
  for (year in years) {
    clean_tp(
      csv.in  = file.path(csv_dir, country, paste(country, "_", year, "_tp.csv", sep = "")),
      csv.out = file.path(csv_dir, country, paste(country, "_", year, "_tp_clean.csv", sep = ""))
    )
    message("Precipitation cleaned: ", country, " ", year)
  }
}

# =============================================================================
# Calculate SPEI
# 1. Potential evapotranspiration (PET) is estimated with the Thornthwaite
#    method.
# 2. For the reference period, the mean and standard deviation of monthly
#    precipitation and PET are calculated across communities.
# 3. The climatic water balance is calculated as standardised precipitation
#    minus standardised PET, using the reference-period values.
# =============================================================================

for (country in countries) {
  folder <- file.path(spei_dir, country, "SPEI-by community")

  # ---- Reference period ------------------------------------------------------------
  ref_precip <- list()
  ref_pet <- list()

  for (location in 1:n_communities[[country]]) {
    # Read the CSV file
    ref_data <- read.csv(file.path(folder, paste("SPEI_", location, ".csv", sep = "")))

    # Filter data for the reference period
    ref_data <- subset(ref_data, year >= min(ref_years) & year <= max(ref_years))

    # Calculate PET for reference period
    ref_data$PET <- thornthwaite(ref_data$tmed, ref_data$y[1], na.rm = TRUE)

    # Store reference precipitation and PET
    ref_precip[[location]] <- ref_data$ptotal
    ref_pet[[location]] <- ref_data$PET
  }

  # Calculate climatology for the reference period
  ref_precip <- do.call(rbind, ref_precip)
  ref_pet <- do.call(rbind, ref_pet)

  mean_precip <- apply(ref_precip, 2, mean, na.rm = TRUE)
  sd_precip <- apply(ref_precip, 2, sd, na.rm = TRUE)
  mean_pet <- apply(ref_pet, 2, mean, na.rm = TRUE)
  sd_pet <- apply(ref_pet, 2, sd, na.rm = TRUE)

  for (location in 1:n_communities[[country]]) {
    # Read the CSV file
    SPEI_data <- read.csv(file.path(folder, paste("SPEI_", location, ".csv", sep = "")))

    # Calculate PET
    SPEI_data$PET <- thornthwaite(SPEI_data$tmed, SPEI_data$y[1], na.rm = TRUE)
    # Calculate balance (BAL)
    SPEI_data$BAL <- (SPEI_data$ptotal - mean_precip) / sd_precip - (SPEI_data$PET - mean_pet) / sd_pet
    # Convert to a time series object
    SPEI_ts <- ts(SPEI_data[, "BAL"], start = c(SPEI_data$y[1], SPEI_data$m[1]), frequency = 12)
    plot(SPEI_ts)

    # Calculate SPEI at each time scale
    for (scale in spei_scales) {
      spei_fit <- spei(SPEI_ts, scale)
      plot(spei_fit)

      # Extract SPEI values and convert to a data frame
      spei_values <- spei_fit$fitted
      spei_out <- data.frame(date = time(spei_values), spei = as.numeric(spei_values))
      names(spei_out)[2] <- paste("spei", scale, sep = "")

      # Write SPEI data to CSV file
      spei_file <- file.path(folder, paste("V", location, "_spei", scale, "_reference.csv", sep = ""))
      write.csv(spei_out, spei_file, row.names = FALSE)
    }
  }
  message("SPEI calculated: ", country)
}
