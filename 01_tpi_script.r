################################################################################
################################################################################
########	
########  Extraction of TPI values for the MATRIX plots
########
########  Script: Roman Link (rlink@gwdg.de)	
########	
################################################################################
################################################################################

################################################################################
########  Preparations
################################################################################
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

################################################################################
######## Loading, and inspecting raw data
################################################################################
# load plot positions
pos <- read.csv("data/csv/Matrix_Plots_positions_neu.csv") 
head(pos)

coordinates(pos) <- ~utmx + utmy
crs <- "+proj=utm +zone=17 +south +ellps=WGS84 +datum=WGS84 +units=m +no_defs +towgs84=0,0,0"
projection(pos)<- CRS(crs)

# load full digital elevation model from Ungerechts, 2010
dem <- raster("rasters/Ungerechts 2010/ortho_bw_dgm_10m.asc",
              crs = crs)

################################################################################
######## Calculate and export raster with TPI values with the tpic() function
################################################################################
# calculate tpi values with a reference diameter of 200 m (the resolution of the
# digital elevation model is 10 m, so r is set to 20)

# Be careful, this will take a while!
system.time(tpi200 <-tpic(dem, r = 20, norm = T)) # 109.904 sec on my system
tpi200

# export tpi raster -- this takes even more time!
system.time(writeRaster(tpi200, 
                        filename= "output/tpi_radius_200m_res_10m_UTM17_WGS24.asc",
                        format="ascii", 
                        overwrite = T)
            )  # 250.647 sec on my system

# crop orinal raster to the extent of the matrix plot coordinates + 1km 
# (for plotting and faster extracting)
tpi_cropped <- crop(tpi200, extent(pos) + 1000)

# first graphical check
plot(tpi_cropped)
points(pos)

################################################################################
######## Extract values for the matrix plots from the raster 
################################################################################
# load the TPI values calculated in my master's thesis
# to compare to the new TPI values
tpi_old <- raster("rasters/TPI MSc thesis/tpi200.asc")

# extract TPI observations 
# (using a circular buffer whose diameter is equal to the plot diagonal)
extracted <- data.frame(
  tpi_old = extract(tpi_old,     pos, buffer = sqrt(20^2+20^2)/2, fun = mean),
  tpi_new = extract(tpi_cropped, pos, buffer = sqrt(20^2+20^2)/2, fun = mean))
tail(extracted)

# plot relationship between original and new values
plot(tpi_new~tpi_old, na.omit(extracted))
abline(0,1)

# fit lm between original and new values
(lm1 <- lm(tpi_new~tpi_old, extracted)) 
abline(lm1, col = 4)
# the new values are on average 112% of the small values...

# check bivariate correlation
cor(na.omit(extracted))    
# ...but the different TPI estimates are very highly correlated
 
# The difference likely arises from the the normalization with the
# raw TPI values from different extents which comprise landscapes
# that differ in topography. It does not really matter for our
# purposes as both will serve equally well as a dimensionless correlate 
# with topographic position

# prepare output
output <- cbind(as.data.frame(pos), extracted)
tail(output)

# export output
write.csv(output, "output/Matrix_Plots_positions_complete_TPI.csv",
          row.names = F) 


################################################################################
######## Extract slope and exposition with terrain()
################################################################################
