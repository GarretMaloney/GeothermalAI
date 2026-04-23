# This code makes use of the CSV output files from SARPROZ
#
# CSV file fields:
#
# ID - point reference id (sequential)
# LAT, LON - latitude and longitude
# SVET, LVET – sample and line, pixel SAR coordinates
# HEIGHT – relative to sea level (m)
# HEIGHT WRT DEM – relative to the external DEM (m)
# SIGMA HEIGHT – height estimation standard deviation
# VEL – deformation velocity in mm/year
# SIGMA VEL – velocity standard deviation
# SEASONAL - seasonal trend coefficient
# CUMUL.DISP. - point cumulative displacement (mm)
# COHER - tepomral coherence
# IN, FIN - target point on-off model
# STDEV - phase standard deviation from estimated model
#
# psi_std_headers: ("ID", "X", "Y", "LAT", "LON", "HEIGHT", "HEIGHT.WRT.DEM",
#                    "SIGMA.HEIGHT", "VEL", "SIGMA.VEL", "SEASONAL",
#                    "CUMUL.DISP.", "COHER", "SVET", "LVET", "IN",
#                    "FIN", "STDEV")
#
# Input data is generated in SARPROZ by using SARPROZ Sparse Data Export
# [Excerpt from https://sarproz.com/manual/dbf_sito.html]
#
# With this function, the tool exports data on a point-wise basis.
# Data can be exported in 3 main formats. Choose:
# - csv files (text tables in csv format)
#
# Data are color-coded according to the selected parameter ("Color Code").
# Look at "Load Mask" for the full list of parameters.
# The color can be saturated passing minimum and maximum values.
# A spatial linear trend can be removed by selecting the corresponding check-box
# A reference point can be selected as well (it should have been saved by the
# "APS estimation" module).
# Default reference point is automatically selected.
# By clicking on "No Orthorect." you can geocode points (convert from SAR to
# geographic coordinates) without using the estimate height. This is useful 
# in cases where the accuracy of height estimation is low
# (e.g. in case of Sentinel data) and if you want to have your points aligned
# with the geocoded SAR images/data.
#
# Finally, time series ***must*** be included in the exported data by selecting
# the corresponding check-box.
# The time series export operation is available only if MISP processing options
# are already loaded. It means, if after MISP you access this module, the 
# software will use the same options to generate and export time series.
# If no processing options are loaded, use the "time series module" to generate
# and export time series.

if (!require("pacman")) {
  install.packages("pacman")
  require("pacman")
}
pacman::p_load(dplyr, raster, ggplot2)

#' Read a SARPROZ csv file, cleaning up and standardizing to a data frame
#'
#' @param x File name of a SARPROZ csv output file
#' @param e (Optional) Raster used to crop the data and define new projection
#' @param psi_old_headers (Optional) Which headers to keep (non-date)
#' @param psi_new_headers (Required if psi_headers used) New names for headers
#'
#' @return A data frame with standardized columns and dates as column names
#'
#' @examples
#' psi_csv <- read_sarproz("my_psi_file.csv")
read_sarproz <- function(x,
                         e = NULL,
                         psi_old_headers = c("coher", "vel"),
                         psi_new_headers = c("coherence", "velocity")) {
  if (is.null(e)) {
    e <- raster(
      xmn = 325209,
      xmx = 336531,
      ymn = 4395438,
      ymx = 4412103,
      res = c(3, 3),
      crs = crs("+init=epsg:32611")
    )
  }
  x_extent <- extent(projectExtent(e, "+proj=longlat +datum=WGS84"))
  
  psinsar_csv <-
    read.csv(x)
  cropped_psi <-
    psinsar_csv %>% filter(LON >= x_extent@xmin,
                           LON <= x_extent@xmax,
                           LAT >= x_extent@ymin,
                           LAT <= x_extent@ymax)
  nrow(cropped_psi)
  nrow(psinsar_csv)
  rm(psinsar_csv)
  #nobody likes screaming
  names(cropped_psi) <- tolower(names(cropped_psi))
  # Reproject coordinates no raster's crs
  longlat_df <- data.frame(cropped_psi[c("lon", "lat")])
  coordinates(longlat_df) <- c("lon", "lat")
  proj4string(longlat_df) <- CRS("+proj=longlat +datum=WGS84")
  # Reprojects data based on extent's CRS
  reproject_df <-
    data.frame(coordinates(spTransform(longlat_df, crs(
      e
    ))))
  rm(longlat_df)
  names(reproject_df) <- c("x", "y")
  psi_headers <- names(cropped_psi)
  # old filter was: "x[0-9]+([:.:][0-9]+)+$"
  date_headers <-
    psi_headers[grepl("x[0-9]{8}$", psi_headers)]
  date_list <-
    as.Date(gsub("x", "", gsub("[:.:]", "/", date_headers)), "%Y%m%d")
  psi_valid_date_list <-
    date_headers[(as.Date(date_list) >= as.Date("2017-12-20"))]
  psi_valid_date_list
  psi_date_values <- cropped_psi[psi_valid_date_list]
  non_date_headers <-
    psi_headers[!grepl("x[0-9]+([:.:][0-9]+)*$", psi_headers)]
  psi_std_headers <-
    c(
      "lat",
      "lon",
      "height",
      "height.wrt.dem",
      "sigma.height",
      "vel",
      "sigma.vel",
      "seasonal",
      "cumul.disp.",
      "coher",
      "svet",
      "lvet",
      "in",
      "fin",
      "stdev"
    )
  # Default headers: ("lat", "lon", "coher", "vel")
  cropped_psi <- cropped_psi[psi_old_headers]
  # print(paste(names(cropped_psi), collapse = ","))
  # Reaname headers
  names(cropped_psi) <- psi_new_headers
  print(paste("Renaming headers to:", paste0(names(cropped_psi), collapse = ", ")))
  # Columnwise sweep (subtract) the first column values
  psi_date_values <-
    sweep(psi_date_values, 1, STATS = psi_date_values[, 1])
  cropped_psi <-
    cbind(reproject_df, cropped_psi[c(psi_new_headers)], psi_date_values)
  return(cropped_psi)
}

### START - Read SARPROZ csv file and filter. Keep time series ------

brady_psi <- read_sarproz("../data/SARPROZ/Brady_72img_TS_7.csv")

f <-
  write.csv(brady_psi, "final_results/HyMapPSInSAR.csv", row.names = FALSE)
rm(f, brady_psi)
### END - Output is new file with filtered data -----



### Recalculate Velocities, linear models are built from scatch -----
brady_psi <- read.csv("final_results/HyMapPSInSAR.csv")
n_col <- ncol(brady_psi)
csv_headers <- names(brady_psi)
date_headers <- csv_headers[grepl("x[0-9]{8}$", csv_headers)]
psi_data <- brady_psi[, date_headers]
psi_headers <- names(psi_data)
date_list <-
  as.Date(date_headers, "x%Y%m%d")
date_df <- data.frame(date_list)
names(date_df) <- "date"
y <- data.frame(t(psi_data))

names(y) <-
  do.call(paste, expand.grid("x", seq_len(ncol(y)), sep = "",
                             stringsAsFactors = FALSE))
my_model_df <- as.data.frame(cbind(date_df, y))

# Offset date to make it simpler
my_model_df[["date"]] <-
  as.integer(my_model_df[["date"]] - min(my_model_df[["date"]]))


# Plot one example, first point
point_to_plot <- 90000 # Noisy
point_to_plot <- 6518  # Subsidence
point_to_plot <- 10717 # Uplift
point_label <- names(y)[point_to_plot]

the_model <- lm(get(point_label) ~ date,
               data = my_model_df[c("date", point_label)])
cat(paste("Slope:", coef(the_model)[2] * 365, "mm per year"))
cat("StdError:")
print( sqrt(diag(vcov(the_model))))
if (FALSE) summary(the_model)
df_model_dates <- as.Date(date_df$date, "%Y-%m-%d")
g_plot <- ggplot(data = my_model_df,
                 mapping = aes(x = df_model_dates,
                               y = my_model_df[, point_label])) +
  geom_point() +
  labs(
    x = "Date",
    y = paste("Displacement (", point_label, ")", sep = ""),
    title = "Displacement",
    subtitle = paste("Point", names(my_model_df[point_label]), sep = " ")
  ) + geom_smooth(method = "lm")
g_plot

model_store <- list()
counter <- 0
for (i in names(y)) {
  # Calculate Linear Regression to get slope
  the_model <- lm(get(i) ~ date, data = my_model_df[c("date", i)])
  # Transform from daily velocity to annual by multiplying by 365.24
  model_store[[i]] <- coef(the_model)[2] * 365.24
  if (counter %% 750 == 0) {
    print(paste("Processed", i))
  }
  if (counter %% 3000 == 0) {
    print("Saving...")
    saveRDS(model_store, "all_slopes.RData")
  }
  counter <- counter + 1
}
saveRDS(model_store, "all_slopes.RData")

model_store <- data.frame(model_store)
model_store[1, 1:10]

model_store <- as.data.frame(t(model_store))
names(model_store) <- "velocity"
model_store[1:10, 1]

calculated_velocity <- cbind(brady_psi[c("x", "y")], model_store)
f <-
  write.csv(calculated_velocity,
            "final_results/Velocity_171222_191224.csv",
            row.names = FALSE)
rm(f)


d <- brady_psi
d["velocity"] <- model_store
d["lat"] <- NULL
d["lon"] <- NULL
f <- write.csv(d, "final_results/PSInSAR_for_SOM.csv", row.names = FALSE)
rm(f, brady_psi, g_plot, my_model_df, y, psi_data, calculated_velocity)
rm(model_store, d)
psi_data_som <- read.csv("final_results/PSInSAR_for_SOM.csv")
#### END -- New velocities and Linear models saved ------------------

