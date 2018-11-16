################################################################################
################################################################################
########	
########  Extraction of TPI, aspect and slope values for the MATRIX plots
########
########  Script: Roman Link (rlink@gwdg.de)	
########	
################################################################################
################################################################################

# This script uses a rasterized digital elevation model from Ungerechts, 2010 to 
# calculate topographical position index, aspect and slope. Please note that if
# you downloaded the project folder from github, you are lacking the source file 
# with the DEM raster,  which due to its size you will have to download separately 
# from the ECSF website.

# Contents: --------------------------------------------------------------------
# 1. Load and inspect raw data
# 2. Calculate and export raster with TPI values with the tpic() function
# 3. Calculate and export rasters with slope and aspect using terrain()
# 4. Prepare data for extraction
# 5. Check consistency of TPI values with the values used in my MSc thesis
# 6. Extract and export values for the matrix plots

########  Preparations ---------------------------------------------------------
## load packages
# create list of packages 
pkgs <-c("raster", "rgdal")  
# raster - handling of raster data
# rdgal  - geodata handling, projections etc. using the gdal engine
#          (no rdgal functions are called directly in the code, but raster does
#           not work properly if gdal is not installed!)

# check for existence of packages and install if necessary
to_install<-pkgs[!(pkgs %in% installed.packages()[,1])]
if (length(to_install)>0)  for (i in seq(to_install)) install.packages(to_install[i])
# load all required packages
for (i in 1:(length(pkgs))) require(pkgs[i], character.only = T)

# source circular_tpi.r script (created during my MSc thesis to calculate
# topographical position indices based on a circular reference area)
source("R/circular_tpi.r")


# 1. Load and inspect raw data ------------------------------------------------

# load plot positions
pos <- read.csv("data/csv/Matrix_Plots_positions_neu.csv") 
head(pos)

coordinates(pos) <- ~utmx + utmy
crs <- "+proj=utm +zone=17 +south +ellps=WGS84 +datum=WGS84 +units=m +no_defs +towgs84=0,0,0"
projection(pos)<- CRS(crs)

# load full digital elevation model from Ungerechts, 2010
dem <- raster("rasters/Ungerechts 2010/ortho_bw_dgm_10m.asc",
              crs = crs)


# 2. Calculate and export raster with TPI values with the tpic() function -----

# calculate tpi values with a reference diameter of 200 m (the resolution of the
# digital elevation model is 10 m, so r is set to 20)

# Be careful, this will take a while!
system.time(tpi200 <-tpic(dem, r = 20, norm = T)) # 102.401 sec on my system
tpi200
# set name of the raster layer
names(tpi200) <- "TPI_200m_circular"

# export tpi raster -- this takes even more time!
system.time(writeRaster(tpi200, 
                        filename= "output/rasters/tpi_radius_200m_res_10m_UTM17_WGS24.asc",
                        format="ascii", 
                        overwrite = T)
            )  # 250.647 sec on my system | 516.068 on a different computer...



# 3. Calculate and export rasters with slope and aspect using terrain() -------

# note that while terrain() also contains an option to calculate CPI, this 
# method does only include the 8 adjacent cells and does not allow for circular
# neighbourhoods

# this will take a while again (but much faster than TPI)
system.time(slope <-terrain(dem, opt = "slope", unit = "degrees")) # 15.13 sec on my system
slope

system.time(aspect <-terrain(dem, opt = "aspect", unit = "degrees")) # 14.866 sec on my system
aspect

# export slope and aspect rasters -- this takes even more time!
system.time(writeRaster(slope, 
                        filename= "output/rasters/slope_degrees_res_10m_UTM17_WGS24.asc",
                        format="ascii", 
                        overwrite = T)
)  # 433.042 sec
system.time(writeRaster(aspect, 
                        filename= "output/rasters/aspect_degrees_res_10m_UTM17_WGS24.asc",
                        format="ascii", 
                        overwrite = T)
)  # 443.647


# 4. Prepare data for extraction ----------------------------------------------

# get extent of the data (+ some extra margin) for plotting and faster data
# extraction
ext <- extent(pos) + 1000

# crop the output rasters and combine to a single raster stack
# (the TPI output has a different extent because on the outer margins NA values
# are generated that are trimmed off in the TPIc function)
stacked <- stack(crop(tpi200, ext), 
                 crop(slope, ext), 
                 crop(aspect, ext))

# first graphical check
# TPI
plot(stacked[[1]])
points(pos)
# slope
plot(stacked[[2]])
points(pos)
# aspect
plot(stacked[[3]])
points(pos)


# 5. Check consistency of TPI values with the values used in my MSc thesis ----

# load the TPI values calculated in my master's thesis
# to compare to the new TPI values
tpi_old <- raster("rasters/TPI MSc thesis/tpi200.asc")

# extract TPI observations 
# (using a circular buffer whose diameter is equal to the plot diagonal)
tpi_check <- data.frame(
  tpi_old = extract(tpi_old,      pos, buffer = sqrt(20^2+20^2)/2, fun = mean),
  tpi_new = extract(stacked[[1]], pos, buffer = sqrt(20^2+20^2)/2, fun = mean))
tail(tpi_check)

# plot relationship between original and new values
plot(tpi_new~tpi_old, na.omit(tpi_check))
abline(0,1)

# fit lm between original and new values
(lm1 <- lm(tpi_new~tpi_old, tpi_check)) 
abline(lm1, col = 4)
# the new values are on average 112% of the small values...

# check bivariate correlation
cor(na.omit(tpi_check))    
# ...but the different TPI estimates are very highly correlated
 
# The difference likely arises from the the normalization with the
# raw TPI values from different extents which comprise landscapes
# that differ in topography. It does not really matter for our
# purposes as both will serve equally well as a dimensionless correlate 
# with topographic position


# 6. Extract and export values for the matrix plots ---------------------------

# get extracted values for TPI, slope and aspect
extracted <- extract(stacked, pos, buffer = sqrt(20^2+20^2)/2, fun = mean)

# prepare output
output <- cbind(as.data.frame(pos), extracted)
tail(output)

# export output
write.csv(output, "output/Matrix_Plots_positions_complete_TPI_aspect_slope.csv",
          row.names = F) 
