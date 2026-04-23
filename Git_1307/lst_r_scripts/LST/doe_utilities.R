#### Utility functions, used for DOE project #
####

if (!require("pacman")) {
  install.packages("pacman")
  require("pacman")
}
pacman::p_load(raster, rgdal)

# Landsat-8 LST files use Albers projection in meters
# Resolution is 30 by 30 mts
extent_hymap_lst <-
  raster(
    xmn = 325209,
    xmx = 336531,
    ymn = 4395438,
    ymx = 4412103,
    res = c(30, 30),
    crs = "+init=epsg:32611"
  )
extent_hymap <-
  raster(
    xmn = 325209,
    xmx = 336531,
    ymn = 4395438,
    ymx = 4412103,
    res = c(3, 3),
    crs = "+init=epsg:32611"
  )

#' Save a raster object to a standard format (GRD) and creates
#' an ENVI-style header files to preserve raster layer(s) name(s).
#' This is a wrapper for the raster::writeRaster function
#'
#' @param x Raster. A raster or stack object
#' @param filename Character. A file name (with no extension or .grd extension)
#' @param format Character. a format from the raster::writeFormats list, default
#' is "raster"
#' @param overwrite Boolean. either TRUE or FALSE
#' @param bandorder Character. 'BIL', 'BIP', or 'BSQ'. For 'native' file formats only.
#'
#' @return A file handle to the written file
#'
#' @examples
#' doe_write_raster(raster01, "my_doe_file")
#' doe_write_raster(raster01, "my_doe_file", overwrite = FALSE)
#' 
doe_write_raster <-
  function(x,
           filename,
           format = "raster",
           overwrite = TRUE,
           bandorder = "BSQ") {
    if (tools::file_ext(filename) != "grd") {
      filename <- tools::file_path_sans_ext(filename)
      filename <- paste(filename, ".grd", sep = "")
    }
    f1 <- writeRaster(
      x = x,
      filename = filename,
      bandorder = bandorder,
      format = format,
      overwrite = overwrite
    )
    hdr(f1, "ENVI")
    return(f1)
  }


#' Transforms a 2 column table of coordinates into a Spatial Points object
#'
#' @param coord Array. 2 column table with (x, y) coordinates for each point
#' @param sp_data Array. 1-dimensional array with the data for each point
#' @param projection CRS. A coordinate system for the projection. Uses UTM, Zone 11N projection by default
#'
#' @return A SpatialPoints object
#'
#' @examples 
#' sp01 <- coords2spatial(coordinates, values, crs("+init=epsg:4326")) # coordinates in lat/long format
coords2spatial <-
  function(coord,
           sp_data,
           projection = crs("+init=epsg:32611")) {
    print("Creating Points")
    d0 <- SpatialPoints(coord, proj4string = projection)
    print("converting")
    sp_data <- as.data.frame(sp_data)
    print("Assigning values")
    d0$sp_data <- sp_data
    return(d0)
  }

#' Transforms a coordinates array to a spatial data frame object
#'
#' @param coord Array. 2 column table with (x, y) coordinates for each point
#' @param sp_data Array. 1-dimensional array with the data for each point
#' @param projection CRS. A coordinate system for the projection. Uses UTM, Zone 11N projection by default
#' 
#' @return SpatialPointsDataFrame object
#'
#' @examples
#' spdf01 <- coords2spatialdf(coordinates, values, crs("+init=epsg:4326")) # coordinates in lat/long format
coords2spatialdf <-
  function(coord,
           sp_data,
           projection = crs("+init=epsg:32611")) {
    d0 <-
      SpatialPointsDataFrame(coord, sp_data, proj4string = projection)
    return(d0)
  }

#' Clustering/summary function
#'
#' @param df_data DataFrame. An input data frame
#'
#' @return DataFrame. A data frame containing basic statistics for each column of the df_data data frame
#'
#' @examples
#' df_cluster <- cluster_fun(my_dataframe)
cluster_fun <- function(df_data) {
  clusters <- data.frame(matrix(ncol = 6, nrow = 0))
  colnames(clusters) <-
    c("image", "avg", "min", "max", "stddev", "range")
  for (i in names(df_data)) {
    sub_cluster <- df_data[i]
    s_mean <- sapply(sub_cluster, mean, na.rm = TRUE)
    s_min <- sapply(sub_cluster, min, na.rm = TRUE)
    s_max <- sapply(sub_cluster, max, na.rm = TRUE)
    s_sd  <- sapply(sub_cluster, sd, na.rm = TRUE)
    clusters[i, 1:6] <-
      list(i, s_mean, s_min, s_max, s_sd, s_max - s_min)
  }
  return(clusters)
}

#' Plot a data frame based on x & y coordinates
#'
#' @param df_img DataFrame. A data frame where the first 2 columns are (x, y) coordinates
#' @param save_file Boolean or Character. Whether a GeoTiff file must be created, if not FALSE, it must contain the save_file name
#' @param projection CRS. A coordinate system for the projection. Uses UTM, Zone 11N projection by default
#'
#' @return A plottable image (raster)
#'
#' @examples
df_plot <- function(df_img, save_file = FALSE,
                    projection = crs("+init=epsg:32611")) {
  plt_img <- df_img
  coordinates(plt_img) <- ~ x + y
  proj4string(plt_img)  <- projection
  gridded(plt_img) <- TRUE
  plot(plt_img)
  if (save_file != FALSE) {
    writeRaster(
      raster(plt_img),
      filename = save_file,
      format = "GTiff",
      overwrite = TRUE
    )
  }
  return(plt_img)
}

#' Extract the columns x and y, and img_name from a data frame using a mask and class
#'
#' @param a_df_lst List of DataFrames.A data frame list 
#' @param a_df_mask A mask to select items from the data frame list
#' @param img_name Characters. Name of the image (column name)
#' @param a_class Character. A class
#'
#' @return
#'
#' @examples
get_subset <- function(a_df_lst, a_df_mask, img_name, a_class) {
  return(a_df_lst[(a_df_mask[img_name] == a_class), c("x", "y", img_name)])
}

#' Plots and saves a K-Means clustering plot in PNG format
#'
#' @param a_raster Raster. Raster object to print
#' @param a_name Characters. The name of the file to create, or FALSE to not save a file
#'
#' @return None
#'
#' @examples
#' save_plot(my_raster, "file_name")
save_plot <- function(a_raster, a_name) {
  png(paste0(a_name, ".png"), width = 600, height = 800)
  print(spplot(
    a_raster[[a_name]],
    col.regions = c("Yellow", "Cyan", "Magenta",
                    "Green", "Red", "Black"),
    main = paste0("K-means clustering (", a_name, ")")
  ))
  if (FALSE) {
    plot(a_raster[[a_name]],
         col = c("Black", "Yellow", "Cyan",
                 "Magenta", "Green", "Red"))
  }
  dev.off()
}

