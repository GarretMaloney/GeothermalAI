source("LST/doe_utilities.R")

if (!require("pacman")){
  install.packages("pacman")
  require("pacman")
} 
pacman::p_load(raster, kohonen)

if(!require("sf")){
  pacman::p_load("devtools")
  devtools::install_github("r-spatial/sf")
  pacman::p_load("sf")
}

pacman::p_load("tidyverse")
source("LST/doe_utilities.R")

##### START Function defintions ---------------------------

simple_som <- function(measures, data, grid=somgrid(3,3,"rectangular"),
                       rlen=100, seed = 42, main_title=NULL){
  # Force the same number generation for SOM
  s <- as.matrix(data[measures])
  set.seed( seed )
  s_model <- som(s, grid=grid, rlen=rlen)
  if(!is.null(main_title)){
    print(plot(s_model, main = main_title))
  }
  return(s_model)
}

simple_som_scaled <- function(measures, data, grid=somgrid(3,3,"rectangular"),
                              rlen=100, seed = 42, main_title=NULL){
  s <- scale(data[measures])
  s_center <- attr(s,"scaled:center")
  s_scale <- attr(s,"scaled:scale")
  s_fun <- function(x){
    y = x * s_scale + s_center
  }
  s_revfun <- function(x){
    y = ((x - s_centers) / s_scale)
  }
  # 
  # Force the same number generation for SOM
  set.seed( seed )
  s_model <- som(s, grid=grid, rlen=rlen)
  if(!is.null(main_title)){
    print(plot(s_model, main = main_title))
  }
  s_model$s_center <- s_center
  s_model$s_scale <- s_scale
  s_model$s_fun <- s_fun
  s_model$s_revfun <- s_revfun
  s_model$clusters<-t(apply(s_model$codes[[1]], 1, s_fun))
  return(s_model)
}

scale_xy <- function(xy_coord){
  x_max <- max(xy_coord["x"])
  y_max <- max(xy_coord["y"])
  x_min <- min(xy_coord["x"])
  y_min <- min(xy_coord["y"])
  x_length <- abs(x_max-x_min)
  y_length <- abs(y_max-y_min)
  new_scale <- min(x_length, y_length)
  x_center <- (x_max+x_min)/2
  y_center <- (y_max+y_min)/2
  xy_coord$x <- (xy_coord$x-x_center)/new_scale
  xy_coord$y <- (xy_coord$y-y_center)/new_scale
  return(xy_coord)
}
##### END   Function definitions --------------------------



brady_csv <- ("final_results/PSInSAR_for_SOM.csv")
# df_csv <- as.data.frame(read.csv(brady_csv))
df_csv <- readr::read_csv(brady_csv)
df_coord <- df_csv[c("x", "y")] 
scaled_coord <- scale_xy(df_coord)
df_headers <- names(df_csv)
som_date_hdr <- df_headers[grepl("x[0-9]{8}", df_headers)]
measures <- unlist(c("x", "y", som_date_hdr))
df_csv[c("x", "y")] <- scaled_coord
som_data <- dplyr::select(df_csv, all_of(measures))


s3_1k <- simple_som(measures, som_data,
                           grid=somgrid(3,3,"rectangular"),
                           rlen=1000,
                           main_title = "SOM Displacement for Brady(3x3)")
saveRDS(s3_1k, "final_results/s3_1k.RDS")
s5_1k <- simple_som(measures, som_data,
                    grid=somgrid(5,5,"rectangular"),
                    rlen=1000,
                    main_title = "SOM Displacement for Brady(5x5)")
saveRDS(s5_1k, "final_results/s5_1k.RDS")
s7_1k <- simple_som(measures, som_data,
                    grid=somgrid(7,7,"rectangular"),
                    rlen=1000,
                    main_title = "SOM Displacement for Brady(7x7)")
saveRDS(s7_1k, "final_results/s7_1k.RDS")
##################

### Plotting ------------
s3_codes <- as.data.frame(s3_1k$codes[[1]])
s3_code_hdr <- colnames(s3_codes)
s3_date_hdr <- s3_code_hdr[grep("x[0-9]{8}", s3_code_hdr)]
s3_codes <- s3_codes[s3_date_hdr]
y_dates <- as.Date(s3_date_hdr, "x%Y%m%d")
matplot(y=t(s3_codes), x=y_dates, type="l")
matplot(y=t(s3_codes), x=y_dates, type="l",
        xlim = c(min(y_dates), max(y_dates)),
        ylim = c(-20, 20),
        xlab = "Date",
        ylab = "Displacement (mm)",
        main = "Cluster Displacement (mm)",
        xaxs = "r",
        yaxs = "i",
        axes=T)


s5_codes <- s5_1k$codes[[1]]
# sum(s5_1k$unit.classif==5)
# sum(s5_1k$unit.classif==21)
# sum(s5_1k$unit.classif==4)
# sum(s5_1k$unit.classif==22)
# s5_codes <- s5_codes[c(4,22), s3_date_hdr]
s5_codes <- s5_codes[, s3_date_hdr]
matplot(y=t(s5_codes), x=y_dates, type="l",
        xlab = "Date",
        ylab = "Displacement (mm)",
        main = "Cluster Displacement (mm)",
        xaxs = "i",
        yaxs = "i",
        axes=T)
matplot(y=t(s5_codes), x=y_dates, type="l",
        xlim = c(min(y_dates), max(y_dates)),
        ylim = c(-20, 20),
        xlab = "Date",
        ylab = "Displacement (mm)",
        main = "Cluster Displacement (mm)",
        xaxs = "r",
        yaxs = "i",
        axes=T)

# axis(2)
# axis(1, xaxs="r", at = y_dates, labels = y_dates)
plot(s5_1k)
#################

s3_1k <- simple_som(measures, rp_df, grid=somgrid(3,3,"rectangular"), rlen=1000, main_title = "SOM Displacement for Brady(3x3)")
s5_1k <- simple_som(measures, rp_df, grid=somgrid(5,5,"rectangular"), rlen=1000, main_title = "SOM Displacement for Brady(5x5)")
plot(s3_1k, main= "SOM Sparse 3x3")
plot(s5_1k, main= "SOM Sparse 5x5")


r3 <- rp_df[c("x", "y")]
r5 <- rp_df[c("x", "y")]
r3 <- cbind(r3, s3_1k$unit.classif)
r5 <- cbind(r5, s5_1k$unit.classif)
r1_3 <- as.data.frame(r3)
r1_5 <- as.data.frame(r5)

coordinates(r1_3) <- ~x+y
proj4string(r1_3)<- crs(brady_nor)
gridded(r1_3)<-TRUE
spplot(r1_3, main= "SOM Sparse 3x3")
r1_3 <- stack(r1_3)

coordinates(r1_5) <- ~x+y
proj4string(r1_5)<- crs(brady_nor)
gridded(r1_5)<-TRUE
spplot(r1_5, main= "SOM Sparse 5x5")
r1_5 <- stack(r1_5)



##### Remove vvvvvvvvvv -------------------
df_coord <- df_csv[c("x", "y")] 
df_csv <- dplyr::select(df_csv, -c("x", "y"))

df_sp <- coords2spatial(df_coord, df_csv)


#euclidean_distance <- function(x,y){
#  sqrt(sum((x - y)^2))
#}

brady_USA <-process_def_csv(brady_csv, bra_extent_ras, coherence = 0.0, radius = 1200, influence_radius = 90)
spplot(brady_USA, main = "Brady Subsidence, Uplift and Anomaly")
df_USA <- as.data.frame(brady_USA)
brady_USA_rp <- rasterToPoints(brady_USA)
brady_USA_df <- as.data.frame(brady_USA_rp)


spg <- brady_USA_df
coordinates(spg) <- ~x+y
gridded(spg) <- TRUE
rasterDf <- stack(spg)

doe_writeRaster(rasterDf, "D:/DOE/Papers/Displacement/SOM/Resultt/Brady_MS_USA")
writeRaster(rasterDf, "D:/DOE/Papers/Displacement/SOM/Result/Brady_MS_USA.tif", "GTiff")

# Chagnde the proj of df file ***********
d1 <- brady_csv_data 
t_cols <- ncol(d1)
# data to analyze starts in column 17
s_col <- 17

id_coherence <- d1["COHER"]>=coherence
d1_coord <- df_csv[c("LAT","LON")]
coord.dec <- SpatialPoints(cbind(d1_coord$LON,d1_coord$LAT), proj4string = CRS("+proj=longlat"))
coord.UTM <- spTransform(coord.dec, CRS("+proj=utm +zone=11 +datum=WGS84 +units=m +no_defs +ellps=WGS84 +towgs84=0,0,0"))
d1_coord <- as.data.frame(coord.UTM)
names(d1_coord) <- c("x","y")
d1 <- cbind(d1_coord, d1[,3:t_cols])
d1 <- d1[id_coherence, ]
m1 <- as.matrix(d1[, s_col:t_cols])
#**************************

# SOM for MtoS Sparse*************************************************************************
setwd("D:/DOE/Papers/Displacement/SOM")
brady_xls <- read_excel("Brady_72img_TS_7_MtoS_Vel.xlsx")
brady_df <- as.data.frame(brady_xls)
brady_ras <- rasterize( brady_df[, c("X","Y")], bra_extent_ras, (brady_df[1:73]))
brady_nor <- normalize_raster(brady_ras, num_points = 60000)
#brady_norXY <- normalize_raster(brady_ras[[1:2]], num_points = 60000)
#brady_nor_disp <- brady_nor[[3:73]]*365
#d1_df <- cbind(brady_norXY_df, brady_nor_disp_df[,3:71])
#d1_df2 <- is.na(d1_df)

brady_org_csv <- read.csv("Brady_72img_TS_7.csv")
brady_org_csv_df <- as.data.frame(brady_org_csv)
brady_org_csv_ras <- rasterize( brady_org_csv_df[, c("X","Y")], bra_extent_ras, brady_org_csv_df[[12]])
bardy_org_csv_ras <- brady_org_csv_ras*r1_5
bardy_org_csv_ras[bardy_org_csv_ras==0] <- NA
brady_org_csv_ras_df <- as.data.frame(brady_org_csv_ras)
write.csv(brady_org_csv_ras_df, "D:/DOE/Papers/Displacement/SOM/Brady_CumDisp.csv")



brady_nor_df <- as.data.frame(brady_nor)
write.csv(brady_nor_df, "D:/DOE/Papers/Displacement/SOM/MtoS_Sparse_Normalized_IncXY.csv")


spplot(brady_nor, main = "M to S Stack Normalized")
spplot(brady_nor2[[3:73]], main = "Delta Stack Normalized")

measures <- names(brady_nor)
brady_rp <- rasterToPoints(brady_nor)
rp_df <- as.data.frame(brady_rp)
rp_df[is.na(rp_df)] <- 0
s3_1k <- simple_som(measures, rp_df, grid=somgrid(3,3,"rectangular"), rlen=1000, main_title = "SOM Displacement for Brady(3x3)")
s5_1k <- simple_som(measures, rp_df, grid=somgrid(5,5,"rectangular"), rlen=1000, main_title = "SOM Displacement for Brady(5x5)")
plot(s3_1k, main= "SOM Sparse 3x3")
plot(s5_1k, main= "SOM Sparse 5x5")


r3 <- rp_df[c("x", "y")]
r5 <- rp_df[c("x", "y")]
r3 <- cbind(r3, s3_1k$unit.classif)
r5 <- cbind(r5, s5_1k$unit.classif)
r1_3 <- as.data.frame(r3)
r1_5 <- as.data.frame(r5)

coordinates(r1_3) <- ~x+y
proj4string(r1_3)<- crs(brady_nor)
gridded(r1_3)<-TRUE
spplot(r1_3, main= "SOM Sparse 3x3")
r1_3 <- stack(r1_3)

coordinates(r1_5) <- ~x+y
proj4string(r1_5)<- crs(brady_nor)
gridded(r1_5)<-TRUE
spplot(r1_5, main= "SOM Sparse 5x5")
r1_5 <- stack(r1_5)

doe_writeRaster(r1_3, "D:/DOE/Papers/Displacement/SOM/Result/MtoS_Sparse_SOM")
writeRaster(r1_3, "D:/DOE/Papers/Displacement/SOM/Result/MtoS_Sparse_SOM.tif", "GTiff", overwrite=TRUE)

doe_writeRaster(r1_5, "D:/DOE/Papers/Displacement/SOM/Result/MtoS_Sparse_SOM_5")
writeRaster(r1_5, "D:/DOE/Papers/Displacement/SOM/Result/MtoS_Sparse_SOM_5.tif", "GTiff", overwrite=TRUE)

r1_5[r1_5 ==25] <- 0
r1_5[r1_5 ==24] <- 0
r1_5[r1_5 ==23] <- 0
r1_5[r1_5 ==22] <- 0
r1_5[r1_5 ==21] <- 0
r1_5[r1_5 ==20] <- 0
r1_5[r1_5 ==19] <- 0
r1_5[r1_5 ==18] <- 0
r1_5[r1_5 ==17] <- 0
r1_5[r1_5 ==16] <- 0
r1_5[r1_5 ==15] <- 0
r1_5[r1_5 ==14] <- 0
r1_5[r1_5 ==13] <- 0
r1_5[r1_5 ==12] <- 0
r1_5[r1_5 ==11] <- 0
r1_5[r1_5 ==10] <- 0
r1_5[r1_5 ==9] <- 0
r1_5[r1_5 ==8] <- 0
r1_5[r1_5 ==6] <- 0
r1_5[r1_5 ==5] <- 0
r1_5[r1_5 ==4] <- 0

spplot(brady_ras, main = "M to S Stack Normalized - 23")
SOM_1 <- brady_ras * r1_5
SOM_1[SOM_1==0] <- NA
spplot(r1_5, main = "r1_5")
spplot(SOM_1[[73]], main = "MtoS Sparse Cluster 1,2,3,7")
SOM_1_Df <- as.data.frame(SOM_1)
write.csv(SOM_1_Df, "D:/DOE/Papers/Displacement/SOM/MtoS_SOM_Clu_1237.csv")

doe_writeRaster(SOM_1, "D:/DOE/Papers/Displacement/SOM/Result/MtoS_Sparse_SOM_12345711")
writeRaster(SOM_1, "D:/DOE/Papers/Displacement/SOM/Result/MtoS_Sparse_SOM_12345711.tif", "GTiff", overwrite=TRUE)

doe_writeRaster(SOM_1, "D:/DOE/Papers/Displacement/SOM/Result/MtoS_Sparse_SOM_12345711")
writeRaster(SOM_1, "D:/DOE/Papers/Displacement/SOM/Result/MtoS_Sparse_SOM_12345711.tif", "GTiff", overwrite=TRUE)


# SOM for Delta Sparse *********************************************************************
setwd("D:/DOE/Papers/Displacement/SOM")
brady_xls2 <- read_excel("Brady_72img_TS_7_DeltaVel.xlsx")
brady_df2 <- as.data.frame(brady_xls2)
brady_ras2 <- rasterize( brady_df2[, c("X","Y")], bra_extent_ras, brady_df2[1:72])
brady_nor2 <- normalize_raster(brady_ras2, num_points = 60000)

spplot(brady_nor2, main = "Delta Stack Normalized")
spplot(brady_nor2[[3:72]], main = "Delta Stack Normalized without XY")


doe_writeRaster(brady_nor2, "D:/DOE/Papers/Displacement/SOM/Result/Delta_Sparse_Norm")
writeRaster(brady_nor2, "D:/DOE/Papers/Displacement/SOM/Result/Delta_Sparse_Norm.tif", "GTiff", overwrite=TRUE)
brady_nor2_df <- as.data.frame(brady_nor2)
write.csv(brady_nor2_df, "D:/DOE/Papers/Displacement/SOM/Delta_Sparse_Normalized_IncXY.csv")


measures <- names(brady_nor2)
brady_rp2 <- rasterToPoints(brady_nor2)
rp_df2 <- as.data.frame(brady_rp2)
rp_df2[is.na(rp_df2)] <- 0
s3_1k2 <- simple_som(measures, rp_df2, grid=somgrid(3,3,"rectangular"), rlen=1000, main_title = "SOM Delta Sparse Displacement for Brady")

r3 <- rp_df2[c("x", "y")]
r3 <- cbind(r3, s3_1k2$unit.classif)
r <- as.data.frame(r3)
coordinates(r) <- ~x+y
proj4string(r)<- crs(brady_nor2)
gridded(r)<-TRUE
spplot(r, main = "Delta Normalized Sparse SOM")
r1 <- stack(r)
doe_writeRaster(r1, "D:/DOE/Papers/Displacement/SOM/Result/Delta_Sparse_SOM")
writeRaster(r1, "D:/DOE/Papers/Displacement/SOM/Result/Delta_Sparse_SOM.tif", "GTiff", overwrite=TRUE)

# SOM for MtoS Fill-Out *************************************************************************
setwd("D:/DOE/Papers/Displacement/SOM")
brady_xls <- read_excel("Brady_72img_TS_7_MtoS_Vel.xlsx")
brady_MSfo_df <- as.data.frame(brady_xls)
bra_extent_ras # Create and extent of brady , code is above
brady_ras <- rasterize(brady_MSfo_df[, c("X","Y")], bra_extent_ras, brady_MSfo_df[1:73])
summary(brady_ras)

brady_nor <- normalize_raster(brady_ras, num_points = 60000)
Ms_nor_df <- as.data.frame(brady_nor)

s <- brady_nor
f <- c(1:ncol(Ms_nor_df))
base_raster1 <- bra_extent_ras
for(i in seq(f)) {
  s_i <- s[[i]]
  fi_r <- fill_out(s_i, radius=220, base_raster1)
  names(fi_r) <- sprintf("d%02d", i)
  base_raster1  <- stack(base_raster1, fi_r)
}

spplot(base_raster1, main = "M to S Fill-Out Stack Normalized Including X and Y")
doe_writeRaster(base_raster1, "D:/DOE/Papers/Displacement/SOM/Result/MtoS_FillOut_IncXY_SOM")
writeRaster(base_raster1, "D:/DOE/Papers/Displacement/SOM/Result/MtoS_FillOut_IncXY_SOM.tif", "GTiff", overwrite=TRUE)

base_raster11 <- base_raster1[[2:74]]
measures <- names(base_raster11)
brady_rp <- rasterToPoints(base_raster11)
rp_df <- as.data.frame(brady_rp)
rp_df[is.na(rp_df)] <- 0
s3_1k <- simple_som(measures, rp_df, grid=somgrid(3,3,"rectangular"), rlen=1000, main_title = "SOM Displacement MtoS Fill-Out Normalized Including XY for Brady")

r3 <- rp_df[c("x", "y")]
r3 <- cbind(r3, s3_1k$unit.classif)
r <- as.data.frame(r3)
coordinates(r) <- ~x+y
proj4string(r)<- crs(brady_nor)
gridded(r)<-TRUE
spplot(r, main= " SOM Displacement MtoS Fill-Out Normalized Including XY for Brady ")
r1 <- stack(r)
doe_writeRaster(r1, "D:/DOE/Papers/Displacement/SOM/Result/MtoS_FillOut_Norm_XY_SOM")
writeRaster(r1, "D:/DOE/Papers/Displacement/SOM/Result/MtoS_FillOut_Norm_XY_SOM.tif", "GTiff", overwrite=TRUE)

base_raster11_df <- as.data.frame(base_raster11)
write.csv(base_raster11_df, "D:/DOE/Papers/Displacement/SOM/MtoS_FillOut_IncXY_SOM.csv")

# SOM for DELTA Fill-Out *************************************************************************
setwd("D:/DOE/Papers/Displacement/SOM")
brady_xls2 <- read_excel("Brady_72img_TS_7_DeltaVel.xlsx")
brady_Deltafo_df <- as.data.frame(brady_xls2)
bra_extent_ras # Create and extent of brady , code is above
View(brady_Deltafo_df)
brady_ras <- rasterize(brady_Deltafo_df[, c("X","Y")], bra_extent_ras, brady_Deltafo_df[1:72])
summary(brady_ras)

brady_nor_Delta <- normalize_raster(brady_ras, num_points = 60000)
Delta_nor_df <- as.data.frame(brady_nor_Delta)

s1 <- brady_nor_Delta
f1 <- c(1:ncol(Delta_nor_df))
base_raster2 <- bra_extent_ras
for(i in seq(f1)) {
  s_i <- s1[[i]]
  fi_r <- fill_out(s_i, radius=220, base_raster2)
  names(fi_r) <- sprintf("d%02d", i)
  base_raster2  <- stack(base_raster2, fi_r)
}

doe_writeRaster(base_raster2, "D:/DOE/Papers/Displacement/SOM/Result/Delta_FillOut_IncXY_SOM")
writeRaster(base_raster2, "D:/DOE/Papers/Displacement/SOM/Result/Delta_FillOut_IncXY_SOM.tif", "GTiff", overwrite=TRUE)

base_raster2_df <- as.data.frame(base_raster2)
write.csv(base_raster2_df, "D:/DOE/Papers/Displacement/SOM/Delta_FillOut_IncXY_SOM.csv")
spplot(base_raster2, main = "DELTA Fill-Out Stack Normalized Including X and Y")

base_raster21 <- base_raster2[[2:73]]
measures <- names(base_raster21)
brady_rp <- rasterToPoints(base_raster21)
rp_df <- as.data.frame(brady_rp)
rp_df[is.na(rp_df)] <- 0
s3_1k <- simple_som(measures, rp_df, grid=somgrid(3,3,"rectangular"), rlen=1000, main_title = "SOM Displacement DELTA Fill-Out Normalized Including XY for Brady")

r3 <- rp_df[c("x", "y")]
r3 <- cbind(r3, s3_1k$unit.classif)
r <- as.data.frame(r3)
coordinates(r) <- ~x+y
proj4string(r)<- crs(brady_nor)
gridded(r)<-TRUE
spplot(r, main= " SOM Displacement DELTA Fill-Out Normalized Including XY for Brady ")
r1 <- stack(r)
doe_writeRaster(r1, "D:/DOE/Papers/Displacement/SOM/Result/Delta_FillOut_Norm_XY_SOM")
writeRaster(r1, "D:/DOE/Papers/Displacement/SOM/Result/Delta_FillOut_Norm_XY_SOM.tif", "GTiff", overwrite=TRUE)

# SOM for MtoS Sparse Uplift/subsidence   ***************************
setwd("D:/DOE/Papers/Displacement/SOM")
brady_csv <- ("Brady_72img_TS_7_MtoS_Vel.csv")
filename <- read.csv("Brady_72img_TS_7_MtoS_Vel.csv")
brady_xls <- read_excel("Brady_72img_TS_7_MtoS_Vel.xlsx")
brady_df <- as.data.frame(filename)
brady_ras <- rasterize( brady_df[, c("X","Y")], bra_extent_ras, brady_df[1:73])
brady_nor <- normalize_raster(brady_ras, num_points = 60000)

brady_nor_df <- as.data.frame(brady_nor)
write.csv(brady_nor_df, "D:/DOE/Papers/Displacement/SOM/MtoS_Sparse_Normalized_IncXY.csv")


spplot(brady_nor, main = "M to S Stack Normalized")
spplot(brady_nor2[[3:73]], main = "Delta Stack Normalized")

measures <- names(brady_nor)
brady_rp <- rasterToPoints(brady_nor)
rp_df <- as.data.frame(brady_rp)
rp_df[is.na(rp_df)] <- 0
s3_1k <- simple_som(measures, rp_df, grid=somgrid(3,3,"rectangular"), rlen=1000, main_title = "SOM Displacement for Brady")

r3 <- rp_df[c("x", "y")]
r3 <- cbind(r3, s3_1k$unit.classif)
r <- as.data.frame(r3)
coordinates(r) <- ~x+y
proj4string(r)<- crs(brady_nor)
gridded(r)<-TRUE
spplot(r)
r1 <- stack(r)
doe_writeRaster(r1, "D:/DOE/Papers/Displacement/SOM/Result/MtoS_Sparse_SOM")
writeRaster(r1, "D:/DOE/Papers/Displacement/SOM/Result/MtoS_Sparse_SOM.tif", "GTiff", overwrite=TRUE)
bra_extent_ras

nor <-function(x) { (x -min(x))/(max(x)-min(x))   }

process_def_csv2 <- function(filename, 
                             new_extent = NA, 
                             coherence = 0.0, 
                             radius = 120,
                             influence_radius = 90)
#************************************************************************
# SOM for MtoS Sparse*************************************************************************
setwd("D:/DOE/Papers/Displacement/SOM")
brady_xls <- read_excel("Brady_72img_TS_7_MtoS_Vel.xlsx")
brady_df <- as.data.frame(brady_xls)
brady_ras2 <- rasterize( brady_df[, c("X","Y")], bra_extent_ras, (brady_df[3:73]*365))
#brady_nor <- normalize_raster(brady_ras, num_points = 60000)
brady_norXY <- normalize_raster(brady_ras[[1:2]], num_points = 60000)
brady_nor_disp <- brady_nor[[3:73]]*365
brady_nor_disp_df <- as.data.frame(brady_nor_disp)
d1_df <- cbind(brady_norXY_df, brady_nor_disp_df[,3:71])
d1_df2 <- is.na(d1_df)

setwd("D:/DOE/Papers/Displacement/SOM")
brady_xls <- read_excel("Brady_72img_TS_7_MtoS_Vel.xlsx")
brady_df <- as.data.frame(brady_xls)
brady_ras1 <- rasterize( brady_df[, c("X","Y")], bra_extent_ras, (brady_df[3:73]*365))
brady_norXY <- normalize_raster(brady_ras[[1:2]], num_points = 60000)

brady_norXY_df <- as.data.frame(brady_norXY)
brady_nor_disp_df <- as.data.frame(brady_ras1)
d1_df <- cbind(brady_norXY_df, brady_nor_disp_df[,3:71])
d1_df2 <- is.na(d1_df)

measures <- names(d1_df2)
brady_rp <- rasterToPoints(brady_nor)
rp_df <- as.data.frame(brady_rp)
d1_df2 <- na.omit(d1_df2)
s3_1k <- simple_som(measures, d1_df, grid=somgrid(5,5,"rectangular"), rlen=1000, main_title = "SOM Displacement for Brady")

r3 <- rp_df[c("x", "y")]
r3 <- cbind(r3, s3_1k$unit.classif)
r <- as.data.frame(r3)
coordinates(r) <- ~x+y
proj4string(r)<- crs(brady_nor)
gridded(r)<-TRUE
spplot(r)
r1 <- stack(r)
doe_writeRaster(r1, "D:/DOE/Papers/Displacement/SOM/Result/MtoS_Sparse_SOM")
writeRaster(r1, "D:/DOE/Papers/Displacement/SOM/Result/MtoS_Sparse_SOM.tif", "GTiff", overwrite=TRUE)
  

# SOM for Delta Sparse *********************************************************************
setwd("D:/DOE/Papers/Displacement/SOM")
brady_xls2 <- read_excel("Brady_72img_TS_7_DeltaVel.xlsx")
brady_df2 <- as.data.frame(brady_xls2)
brady_ras2 <- rasterize( brady_df2[, c("X","Y")], bra_extent_ras, brady_df2[1:72])
brady_nor2 <- normalize_raster(brady_ras2, num_points = 60000)

spplot(brady_nor2, main = "Delta Stack Normalized")
spplot(brady_nor2[[3:72]], main = "Delta Stack Normalized without XY")


doe_writeRaster(brady_nor2, "D:/DOE/Papers/Displacement/SOM/Result/Delta_Sparse_Norm")
writeRaster(brady_nor2, "D:/DOE/Papers/Displacement/SOM/Result/Delta_Sparse_Norm.tif", "GTiff", overwrite=TRUE)
brady_nor2_df <- as.data.frame(brady_nor2)
write.csv(brady_nor2_df, "D:/DOE/Papers/Displacement/SOM/Delta_Sparse_Normalized_IncXY.csv")


measures <- names(brady_nor2)
brady_rp2 <- rasterToPoints(brady_nor2)
rp_df2 <- as.data.frame(brady_rp2)
rp_df2[is.na(rp_df2)] <- 0
s3_1k2 <- simple_som(measures, rp_df2, grid=somgrid(3,3,"rectangular"), rlen=1000, main_title = "SOM Delta Sparse Displacement for Brady")
s5_1k2 <- simple_som(measures, rp_df2, grid=somgrid(5,5,"rectangular"), rlen=1000, main_title = "SOM Delta Sparse Displacement for Brady")
plot(s3_1k2, main= "SOM Delta Sparse 3x3")
plot(s5_1k2, main= "SOM Delta Sparse 5x5")

r5 <- rp_df[c("x", "y")]
r5 <- cbind(r5, s5_1k2$unit.classif)
r1_5 <- as.data.frame(r5)
coordinates(r1_5) <- ~x+y
proj4string(r1_5)<- crs(brady_nor)
gridded(r1_5)<-TRUE
spplot(r1_5, main= "SOM Delta Sparse 5x5")
r1_5 <- stack(r1_5)

doe_writeRaster(r1_5, "D:/DOE/Papers/Displacement/SOM/Result/Delta_Sparse_SOM_5x5")
writeRaster(r1_5, "D:/DOE/Papers/Displacement/SOM/Result/Delta_Sparse_SOM_5x5.tif", "GTiff", overwrite=TRUE)

r3 <- rp_df2[c("x", "y")]
r3 <- cbind(r3, s3_1k2$unit.classif)
r <- as.data.frame(r3)
coordinates(r) <- ~x+y
proj4string(r)<- crs(brady_nor2)
gridded(r)<-TRUE
spplot(r, main = "SOM Delta Sparse 3x3")
r1 <- stack(r)

doe_writeRaster(r1, "D:/DOE/Papers/Displacement/SOM/Result/Delta_Sparse_SOM")
writeRaster(r1, "D:/DOE/Papers/Displacement/SOM/Result/Delta_Sparse_SOM.tif", "GTiff", overwrite=TRUE)

#********************************* SOM MtoS Cluster Analysis ********************************************
setwd("D:/DOE/Papers/Displacement/SOM")
r1_5 <- stack("D:/DOE/Papers/Displacement/SOM/Result/MtoS_Sparse_SOM_5.tif")
r1_5_7 <- r1_5==7
r1_5_7[r1_5_7==0] <- NA
r1_5_7[is.na(r1_5_7)] <- 0
spplot(r1_5_7, main= "MtoS Cluster 7")

#Cell Stat and graph for Cumulative Displacement with Cluster 7 in MtoS ********************************
brady_org_csv <- read.csv("Brady_72img_TS_7.csv")
brady_org_csv_df <- as.data.frame(brady_org_csv)
brady_org_csv_ras <- rasterize( brady_org_csv_df[, c("X","Y")], bra_extent_ras, brady_org_csv_df[[12]])
spplot(brady_org_csv_ras, main= "Original Cumulative Analysis Result")
bardy_org_csv_ras1 <- brady_org_csv_ras*r1_5_7
bardy_org_csv_ras1[bardy_org_csv_ras1==0] <- NA
spplot(bardy_org_csv_ras1, main= "Original Cumulative Analysis Result x Cluster 7")
#brady_org_csv_ras_df <- as.data.frame(brady_org_csv_ras)
#write.csv(brady_org_csv_ras_df, "D:/DOE/Papers/Displacement/SOM/Brady_CumDisp.csv")
cellStats(bardy_org_csv_ras1,"max", na.rm=TRUE)
cellStats(bardy_org_csv_ras1,"min", na.rm=TRUE)
cellStats(bardy_org_csv_ras1,"mean", na.rm=TRUE)
cellStats(bardy_org_csv_ras1,"sd", na.rm=TRUE)

#Cell Stat and graph for MtoS Original Value  with Cluster 7 in MtoS ********************************
brady_MtoS <- stack("D:/DOE/Papers/Displacement/Pair_Analysis/BradyPairStack")
brady_MtoS_1 <- brady_MtoS*r1_5_7
brady_MtoS_1[brady_MtoS_1==0] <- NA
spplot(brady_MtoS_1, main= "Original MtoS x Cluster 7")

brady_MtoS_df <- as.data.frame(brady_MtoS_1)
#brady_MtoS_df1 <- is.na(brady_MtoS_df)
#brady_MtoS_df1 <- na.omit(brady_MtoS_df)
write.csv(brady_MtoS_df, "D:/DOE/Papers/Displacement/SOM/ClusterDetailAnalysis/brady_MtoS_Cluster7.csv")

#Cell Stat and graph for DELTA Original Value  with Cluster 7 in DELTA ********************************

setwd("D:/DOE/Papers/Displacement/SOM")
r5d <- stack("D:/DOE/Papers/Displacement/SOM/Result/Delta_Sparse_SOM_5x5.tif")
r5d_7 <- r5d == 7
r5d_7[r5d_7==0] <- NA
r5d_7[is.na(r5d_7)] <- 0
spplot(r5d_7, main= "Delta Cluster 7")


brady_Delta <- stack("D:/DOE/Papers/Displacement/Pair_Analysis/BradyPairStack_Delta_Original")
spplot(brady_Delta, main= "Original Delta Time-Series Data")
brady_Delta_1 <- brady_Delta*r5d_7
brady_Delta_1[brady_Delta_1==0] <- NA
spplot(brady_Delta_1, main= "Original Delta x Cluster 7")

brady_Delta_df <- as.data.frame(brady_Delta_1)
#brady_Delta_df1 <- is.na(brady_Delta_df)
brady_Delta_df1 <- na.omit(brady_Delta_df)
write.csv(brady_Delta_df1, "D:/DOE/Papers/Displacement/SOM/ClusterDetailAnalysis/brady_Delta_Cluster7.csv")


#Cell Stat and graph for MtoS Original Value  with Cluster XXXX in MtoS ********************************
setwd("D:/DOE/Papers/Displacement/SOM")

brady_vel_csv <- read.csv("Brady_72img_TS_7_MtoS_Vel4.csv")
brady_vel_df <- as.data.frame(brady_vel_csv)
names(brady_vel_df)[1] <- "X"
#brady_vel_df <- as.numeric(brady_vel_df)
brady_vel_df_ras <- rasterize(brady_vel_df[, c("X","Y")], bra_extent_ras, brady_vel_df[3:75])
spplot(brady_vel_df_ras[[1]], main= "Original MtoS Velocity")
brady_MtoS <- brady_vel_df_ras

brady_MtoS <- stack("D:/DOE/Papers/Displacement/Pair_Analysis/BradyPairStack")
plot(brady_MtoS, main= "Brady Mto S ")
brady_MtoS_df <- as.data.frame(brady_MtoS)
bradyMtoS_Df2 <- na.omit(brady_MtoS_df)
mtos_5 <- stack("D:/DOE/Papers/Displacement/SOM/Result/MtoS_Sparse_SOM_5.tif")
spplot(mtos_5, main= "Delta Cluster xxx ")
mtos_5_df2 <- as.data.frame(mtos_5)
mtos_5_df3 <- na.omit(mtos_5_df2)


ClusterSOM <- function(filename, org_data_no, cluster_data, type =FALSE){
  cluster_data <- cluster_data == org_data_no
  cluster_data[cluster_data==0] <- NA
  cluster_data[is.na(cluster_data)]<- 0
  spplot(cluster_data, main= "Delta Cluster xxx ")
  
  f1<- filename*cluster_data
  f1[f1==0] <- NA
  spplot(f1, main= "Original MtoS x Cluster XXXX")
  
  f1_df <- as.data.frame(f1)
  f1_df <- na.omit(f1_df)
  write.csv(f1_df, "D:/DOE/Papers/Displacement/SOM/ClusterDetailAnalysis/ brady_Delta_ClusterXXXX.csv")
}


mtos_5 <- stack("D:/DOE/Papers/Displacement/SOM/Result/MtoS_Sparse_SOM_5.tif")
mtos_1 <- mtos_5 == 1
mtos_1[mtos_1==0] <- NA
#mtos_x[is.na(mtos_x)] <- 0
spplot(mtos_1, main= "MtoS Cluster 1")
mtos_1_df <- as.data.fraem(mtos_1)

brady_MtoS <- stack("D:/DOE/Papers/Displacement/Pair_Analysis/BradyPairStack")

brady_MtoS_1 <- brady_MtoS *mtos_1

brady_MtoS_1 <- brady_vel_df *mtos_1
brady_MtoS_1[brady_MtoS_1==0] <- NA
spplot(brady_MtoS_1, main= "Original MtoS  Cluster 1")

brady_MtoS_df <- as.data.frame(brady_MtoS_1)
#brady_MtoS_df1 <- is.na(brady_MtoS_df)
#brady_MtoS_df1 <- na.omit(brady_MtoS_df)
write.csv(brady_MtoS_df, "D:/DOE/Papers/Displacement/SOM/ClusterDetailAnalysis/brady_MtoS_ClusterXXXX.csv")

#Cell Stat and graph for DELTA Original Value  with Cluster XXXX in DELTA ********************************

setwd("D:/DOE/Papers/Displacement/SOM")
r5d <- stack("D:/DOE/Papers/Displacement/SOM/Result/Delta_Sparse_SOM_5x5.tif")
r5d_7 <- r5d == 7
r5d_7[r5d_7==0] <- NA
r5d_7[is.na(r5d_7)] <- 0
spplot(r5d_7, main= "Delta Cluster 7")


brady_Delta <- stack("D:/DOE/Papers/Displacement/Pair_Analysis/BradyPairStack_Delta_Original")
spplot(brady_Delta, main= "Original Delta Time-Series Data")
brady_Delta_1 <- brady_Delta*r5d_7
brady_Delta_1[brady_Delta_1==0] <- NA
spplot(brady_Delta_1, main= "Original Delta x Cluster 7")

brady_Delta_df <- as.data.frame(brady_Delta_1)
#brady_Delta_df1 <- is.na(brady_Delta_df)
brady_Delta_df1 <- na.omit(brady_Delta_df)
write.csv(brady_Delta_df1, "D:/DOE/Papers/Displacement/SOM/ClusterDetailAnalysis/brady_Delta_Cluster7.csv")

#***********************************
#"1_170201",
names(brady_Delta_1) <- c(
  "2_170225",
  "3_170426",
  "4_170508",
  "5_170520",
  "6_170613",
  "7_170625",
  "8_170719",
  "9_170812",
  "10_170917",
  "11_170929",
  "12_171128",
  "13_171210",
  "14_171222",
  "15_180103",
  "16_180115",
  "17_180127",
  "18_180208",
  "19_180220",
  "20_180328",
  "21_180409",
  "22_180421",
  "23_180503",
  "24_180515",
  "25_180527",
  "26_180608",
  "27_180620",
  "28_180702",
  "29_180714",
  "30_180726",
  "31_180807",
  "32_180819",
  "33_180831",
  "34_180912",
  "35_180924",
  "36_181006",
  "37_181018",
  "38_181030",
  "39_181111",
  "40_181123",
  "41_181205",
  "42_181217",
  "43_181229",
  "44_190110",
  "45_190122",
  "46_190203",
  "47_190215",
  "48_190227",
  "49_190311",
  "50_190323",
  "51_190404",
  "52_190416",
  "53_190510",
  "54_190522",
  "55_190603",
  "56_190615",
  "57_190627",
  "58_190709",
  "59_190721",
  "60_190802",
  "61_190814",
  "62_190826",
  "63_190907",
  "64_190919",
  "65_191001",
  "66_191013",
  "67_191025",
  "68_191106",
  "69_191118",
  "70_191130",
  "71_191212",
  "72_191224")





