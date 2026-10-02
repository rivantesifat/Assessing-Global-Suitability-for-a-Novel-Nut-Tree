rm(list = ls())
gc()
#Load packages 
library(geodata)
library(Recocrop) # EcoCrop-based crop suitability modelling
library(raster) # Read and process raster data
library(terra)  # Modern package for raster and spatial data
library(rasterVis)  #Improved visualisation of raster data
library(dplyr)       # Data manipulation
library(rgbif)# Access species occurrence data from GBIF
library(sp)

setwd("S:/Spatial_Engineering_MSC/Climate_Risk_Assesment/Case_Study_C/Data")

#SHP
admin_prt <- vect("Portugal/geoBoundaries-PRT-ADM0.shp") #Reading the shapefile for the national boundary Portuaga
admin1_prt <- vect("Portugal/geoBoundaries-PRT-ADM1.shp") #Reading the shapefile for the provinces boundary Portugal

admin_pru <- vect("Peru/geoBoundaries-PER-ADM0.shp") #Reading the shapefile for the national boundary Peru
admin1_pru <- vect("Peru/geoBoundaries-PER-ADM1.shp") #Reading the shapefile for the provinces boundary Peru

admin_vt <- vect("Vietnam/geoBoundaries-VNM-ADM0.shp") #Reading the shapefile for the national boundary Vietnam
admin1_vt <- vect("Vietnam/geoBoundaries-VNM-ADM1.shp") #Reading the shapefile for the provinces boundary Vietnam

admin_tn <- vect("Tanzania/geoBoundaries-TZA-ADM0.shp") #Reading the shapefile for the national boundary Tanzania
admin1_tn <- vect("Tanzania/geoBoundaries-TZA-ADM1.shp") #Reading the shapefile for the provinces boundary Tanzania
#plot(admin_prt)
#plot(admin1_pru)
#plot(admin1_vt)
#plot(admin1_tn)

# ---  Loading GLOBAL current-climate data once ---
prec_glob <- rast(list.files(path="Prec_Data_World/prec_2-5m/climate/wc2.1_2.5m/", pattern="\\.tif$", full.names=TRUE))
crs(prec_glob) <- "+proj=longlat +datum=WGS84 +no_defs"

tavg_glob <- rast(list.files(path="Temp_Data_World/tavg_2-5m/climate/wc2.1_2.5m/", pattern="\\.tif$", full.names=TRUE))
crs(tavg_glob) <- "+proj=longlat +datum=WGS84 +no_defs"

soilph_glob <- rast("Soil_Ph_Data_World/global_soil_phh2o_0-5cm_mean_1000.tif")
soilph_glob_rep <- project(
  soilph_glob,
  crs(prec_glob),
  method = "bilinear"
)
soilph_glob_red <- soilph_glob_rep / 10
#crs(soilph_glob) <- "+proj=longlat +datum=WGS84 +no_defs"

# --- 2. Load country boundary as a SpatVector (terra needs this, not the sp object from shapefile()) ---
#admin_prt <- vect("SHP/geoBoundaries-PRT-ADM0.shp")

# --- 3. Crop to the country's bounding box, then mask to the actual polygon outline --- for Portugal
prec_prt  <- crop(prec_glob, admin_prt) |> mask(admin_prt)
tavg_prt  <- crop(tavg_glob, admin_prt) |> mask(admin_prt)
soilph_prt <- crop(soilph_glob_red, admin_prt) |> mask(admin_prt)

# --- 4. Crop to the country's bounding box, then mask to the actual polygon outline --- for Peru
prec_pru  <- crop(prec_glob, admin_pru) |> mask(admin_pru)
tavg_pru  <- crop(tavg_glob, admin_pru) |> mask(admin_pru)
soilph_pru <- crop(soilph_glob_red, admin_pru) |> mask(admin_pru)

# --- 5. Crop to the country's bounding box, then mask to the actual polygon outline --- for Vietnam
prec_vt  <- crop(prec_glob, admin_vt) |> mask(admin_vt)
tavg_vt  <- crop(tavg_glob, admin_vt) |> mask(admin_vt)
soilph_vt <- crop(soilph_glob_red, admin_vt) |> mask(admin_vt)

# --- 6. Crop to the country's bounding box, then mask to the actual polygon outline --- for Tanzania
prec_tn  <- crop(prec_glob, admin_tn) |> mask(admin_tn)
tavg_tn  <- crop(tavg_glob, admin_tn) |> mask(admin_tn)
soilph_tn <- crop(soilph_glob_red, admin_tn) |> mask(admin_tn)

### Reordering the resolutions
soilph_prt <- resample(soilph_prt, prec_prt[[1]], method="bilinear")

soilph_pru <- resample(soilph_pru, prec_pru[[1]], method="bilinear")

soilph_vt <- resample(soilph_vt, prec_vt[[1]], method="bilinear")

soilph_tn <- resample(soilph_tn, prec_tn[[1]], method="bilinear")

res(prec_prt); res(tavg_prt); res(soilph_prt)   # should all match
compareGeom(prec_prt, tavg_prt, soilph_prt)  # throws an error if extents/res/crs disagree
compareGeom(prec_pru, tavg_pru, soilph_pru)
compareGeom(prec_vt,  tavg_vt,  soilph_vt)
compareGeom(prec_tn,  tavg_tn,  soilph_tn)

####### setting up the new crop####
crop_list <- ecocropPars()
View(crop_list)
# look for perennials/trees — e.g. "Olive", "Almond", "Walnut", "Cashew", "Avocado"
#crop_list[grep("olive|almond|cashew|avocado|walnut", crop_list$NAME, ignore.case=TRUE), ]

tree <- ecocropPars("Cashew")   # swap for whichever template you settle on
tree$name <- "Novel nut tree"  # optional, just for labeling in plots

tree$parameters[,1] <- c(230, NA, 200, 340)   # duration
tree$parameters[,2] <- c(-4, 1, Inf, Inf)     # ktmp
tree$parameters[,3] <- c(12, 15, 27, 36)      # tavg
tree$parameters[,4] <- c(80, 155, 279, 535)   # prec
#tree$parameters[,5] <- c(0, 3, 11, 14)

tree
tree <- ecocrop(tree)   # decide + document this assumption in your slides
plot(tree)
control(tree, get_max = TRUE)

tree.suit.prt <- predict(tree, prec=prec_prt, tavg=tavg_prt, ph=soilph_prt, wopt=list(names="tree"))
tree.suit.pru <- predict(tree, prec=prec_pru, tavg=tavg_pru, ph=soilph_pru, wopt=list(names="tree"))
tree.suit.vt  <- predict(tree, prec=prec_vt,  tavg=tavg_vt,  ph=soilph_vt,  wopt=list(names="tree"))
tree.suit.tn  <- predict(tree, prec=prec_tn,  tavg=tavg_tn,  ph=soilph_tn,  wopt=list(names="tree"))

tree.ras.prt <- raster(tree.suit.prt)
tree.ras.pru <- raster(tree.suit.pru)
tree.ras.vt  <- raster(tree.suit.vt)
tree.ras.tn  <- raster(tree.suit.tn)

plot(tree.ras.prt, main="Portugal")
plot(tree.ras.pru, main="Peru")
plot(tree.ras.vt,  main="Vietnam")
plot(tree.ras.tn,  main="Tanzania")
######
suit_col <- colorRampPalette(c("grey95", "salmon3", "gold", "palegreen2", "forestgreen"))(100)

plot(tree.ras.prt, main = "Portugal", col = suit_col, zlim = c(0,1))
plot(tree.ras.pru, main = "Peru", col = suit_col, zlim = c(0,1))
plot(tree.ras.vt, main = "Vietnam", col = suit_col, zlim = c(0,1))
plot(tree.ras.tn, main = "Tanzania", col = suit_col, zlim = c(0,1))

par(mfrow = c(2,2))
plot(tree.ras.prt, main = "Portugal", col = suit_col, zlim = c(0,1))
plot(tree.ras.pru, main = "Peru",     col = suit_col, zlim = c(0,1))
plot(tree.ras.vt,  main = "Vietnam",  col = suit_col, zlim = c(0,1))
plot(tree.ras.tn,  main = "Tanzania", col = suit_col, zlim = c(0,1))
par(mfrow = c(1,1))
######
global(tree.suit.prt, c("min", "max", "mean"), na.rm=TRUE)     # count of non-NA cells — is it 0?

class.mat <- matrix(c(0, 0.50, 0,
                      0.50, 1, 1), ncol = 3, byrow = TRUE)

tree.cl.prt <- classify(tree.suit.prt, class.mat)
tree.cl.pru <- classify(tree.suit.pru, class.mat)
tree.cl.vt  <- classify(tree.suit.vt,  class.mat)
tree.cl.tn  <- classify(tree.suit.tn,  class.mat)

#National % suitable area
national_pct <- function(cl_rast) {
  tab <- freq(cl_rast)               # terra: counts per class
  tab$pct <- tab$count / sum(tab$count) * 100
  tab
}
national_pct(tree.cl.prt) #0 %
national_pct(tree.cl.pru) #38.312%
national_pct(tree.cl.vt) #0.294%
national_pct(tree.cl.tn) #0.085%

#Provincal % suitable
# Check what the province name field is actually called first:
names(admin1_prt)          # look for something like "shapeName"

prov_stats_prt <- extract(tree.cl.prt, admin1_prt, fun = mean, na.rm = TRUE, ID = FALSE)
admin1_prt$pct_suitable <- prov_stats_prt$tree * 100

prov_stats_pru <- extract(tree.cl.pru, admin1_pru, fun = mean, na.rm = TRUE, ID = FALSE)
admin1_pru$pct_suitable <- prov_stats_pru$tree * 100

prov_stats_vt <- extract(tree.cl.vt, admin1_vt, fun = mean, na.rm = TRUE, ID = FALSE)
admin1_vt$pct_suitable <- prov_stats_vt$tree * 100

prov_stats_tn <- extract(tree.cl.tn, admin1_tn, fun = mean, na.rm = TRUE, ID = FALSE)
admin1_tn$pct_suitable <- prov_stats_tn$tree * 100

plot(admin1_prt, "pct_suitable", main = "Portugal — % area suitable by province",
     col = hcl.colors(5, "Greens", rev = TRUE),
     breaks = c(0, 20, 40, 60, 80, 100), border = "grey40")
plot(admin1_pru, "pct_suitable", main = "Peru — % area suitable by province",
     col = hcl.colors(5, "Greens", rev = TRUE), 
     breaks = c(0, 20, 40, 60, 80, 100), border = "grey40")
plot(admin1_vt, "pct_suitable", main = "Vietnam — % area suitable by province",
     col = hcl.colors(5, "Greens", rev = TRUE), border = "grey40")
plot(admin1_tn, "pct_suitable", main = "Tanzania — % area suitable by province",
     col = hcl.colors(5, "Greens", rev = TRUE), border = "grey40")

as.data.frame(admin1_prt[, c("shapeName","pct_suitable")])
as.data.frame(admin1_pru[, c("shapeName","pct_suitable")])
as.data.frame(admin1_vt[, c("shapeName","pct_suitable")])
as.data.frame(admin1_tn[, c("shapeName","pct_suitable")])

subset(as.data.frame(admin1_prt[,  c("shapeName","pct_suitable")]), pct_suitable > 0)
subset(as.data.frame(admin1_pru[, c("shapeName","pct_suitable")]), pct_suitable > 0)
subset(as.data.frame(admin1_vt[,  c("shapeName","pct_suitable")]), pct_suitable > 0)
subset(as.data.frame(admin1_tn[,  c("shapeName","pct_suitable")]), pct_suitable > 0)

summary_df <- data.frame(
  country = c("Portugal","Peru","Vietnam","Tanzania"),
  pct_suitable = c(0, 38.31, 0.294, 0.0845)
)

#alternate Plot
bp <- barplot(summary_df$pct_suitable, names.arg = summary_df$country,
              ylab = "% national area suitable", col = "forestgreen",
              main = "National suitability comparison", ylim = c(0, 42))

text(x = bp, y = summary_df$pct_suitable + 1.5,
     labels = sprintf("%.2f%%", summary_df$pct_suitable),
     cex = 0.9)

#another Plot Zoomed
par(mfrow = c(1, 2))   # 1 row, 2 panels

# Panel 1: full scale, shows Peru's dominance
bp1 <- barplot(summary_df$pct_suitable, names.arg = summary_df$country,
               ylab = "% national area suitable", col = "forestgreen",
               main = "All countries (full scale)", ylim = c(0, 42), las = 2)
text(x = bp1, y = summary_df$pct_suitable + 1.5,
     labels = sprintf("%.2f%%", summary_df$pct_suitable), cex = 0.8)

# Panel 2: zoomed, excludes Peru, shows the small values properly
small_df <- subset(summary_df, country != "Peru")
bp2 <- barplot(small_df$pct_suitable, names.arg = small_df$country,
               ylab = "% national area suitable", col = "forestgreen",
               main = "Portugal / Vietnam / Tanzania",
               ylim = c(0, max(small_df$pct_suitable) * 1.4), las = 2)
text(x = bp2, y = small_df$pct_suitable + max(small_df$pct_suitable)*0.08,
     labels = sprintf("%.3f%%", small_df$pct_suitable), cex = 0.8)

par(mfrow = c(1, 1))   # reset layout after


breaks_vt <- c(0, 0.001, 1, 3, 10)   # tailored to Vietnam's small-value range
labels_vt <- c("0%", "0–1%", "1–3%", "3–10%")

plot(admin1_vt, "pct_suitable", main = "Vietnam — % area suitable by province",
     col = hcl.colors(length(breaks_vt)-1, "Greens", rev = TRUE),
     breaks = breaks_vt,
     border = "grey40")

admin1_vt$suitable_flag <- ifelse(admin1_vt$pct_suitable > 0, "Suitability found", "Not suitable")

plot(admin1_vt, "suitable_flag", main = "Vietnam — provinces with any suitable area",
     col = c("grey90", "forestgreen"), border = "grey40")
admin1_tn$suitable_flag <- ifelse(admin1_tn$pct_suitable > 0, "Suitability found", "Not suitable")
plot(admin1_tn, "suitable_flag", main = "Tanzania — provinces with any suitable area",
     col = c("grey90", "forestgreen"), border = "grey40")
admin1_prt$suitable_flag <- ifelse(admin1_prt$pct_suitable > 0, "Suitability found", "Not suitable")
plot(admin1_prt, "suitable_flag", main = "Portugal — provinces with any suitable area",
     col = c("grey90", "forestgreen"), border = "grey40")
admin1_pru$suitable_flag <- ifelse(admin1_pru$pct_suitable > 0, "Suitability found", "Not suitable")
plot(admin1_pru, "suitable_flag", main = "Peru — provinces with any suitable area",
     col = c("grey90", "forestgreen"), border = "grey40")

admin1_prt$suitable_flag <- ifelse(admin1_prt$pct_suitable > 0, "Suitability found", "Not suitable")
admin1_pru$suitable_flag <- ifelse(admin1_pru$pct_suitable > 0, "Suitability found", "Not suitable")
admin1_vt$suitable_flag  <- ifelse(admin1_vt$pct_suitable  > 0, "Suitability found", "Not suitable")
admin1_tn$suitable_flag  <- ifelse(admin1_tn$pct_suitable  > 0, "Suitability found", "Not suitable")

flag_col <- c("Not suitable" = "grey90", "Suitability found" = "forestgreen")

par(mfrow = c(2,2))
plot(admin1_prt, "suitable_flag", main = "Portugal", col = flag_col, border = "grey40", plg = list(cex=0.7))
plot(admin1_pru, "suitable_flag", main = "Peru",     col = flag_col, border = "grey40", plg = list(cex=0.7))
plot(admin1_vt,  "suitable_flag", main = "Vietnam",  col = flag_col, border = "grey40", plg = list(cex=0.7))
plot(admin1_tn,  "suitable_flag", main = "Tanzania", col = flag_col, border = "grey40", plg = list(cex=0.7))
par(mfrow = c(1,1))

# 1. Extract mean continuous suitability score per province in Peru
prov_mean_pru <- extract(tree.suit.pru, admin1_pru, fun = mean, na.rm = TRUE, ID = FALSE)

# 2. Assign the score back to the SpatVector attribute table
# Note: check names(tree.suit.pru) to match the extracted column; here it is "tree"
admin1_pru$avg_suitability <- prov_mean_pru$tree

# 3. View as a clean data frame sorted from highest to lowest score
peru_avg_df <- as.data.frame(admin1_pru[, c("shapeName", "avg_suitability")])
peru_avg_df <- peru_avg_df[order(-peru_avg_df$avg_suitability), ]
print(peru_avg_df, row.names = FALSE)

# 4. Map the continuous average suitability score across Peru's provinces
plot(admin1_pru, "avg_suitability",
     main = "Peru — Average Suitability Score by Province",
     col = hcl.colors(10, "YlGn", rev = TRUE),
     range = c(0, 1),
     border = "grey40")


# 1. Extract mean continuous suitability score per province in VIetnam
prov_mean_vt <- extract(tree.suit.vt, admin1_vt, fun = mean, na.rm = TRUE, ID = FALSE)

# 2. Assign the score back to the SpatVector attribute table
# Note: check names(tree.suit.pru) to match the extracted column; here it is "tree"
admin1_vt$avg_suitability <- prov_mean_vt$tree

# 3. View as a clean data frame sorted from highest to lowest score
vt_avg_df <- as.data.frame(admin1_vt[, c("shapeName", "avg_suitability")])
vt_avg_df <- vt_avg_df[order(-vt_avg_df$avg_suitability), ]
print(vt_avg_df, row.names = FALSE)

# 1. Extract mean continuous suitability score per province in VIetnam
prov_mean_tn <- extract(tree.suit.tn, admin1_tn, fun = mean, na.rm = TRUE, ID = FALSE)

# 2. Assign the score back to the SpatVector attribute table
# Note: check names(tree.suit.pru) to match the extracted column; here it is "tree"
admin1_tn$avg_suitability <- prov_mean_tn$tree

# 3. View as a clean data frame sorted from highest to lowest score
tn_avg_df <- as.data.frame(admin1_tn[, c("shapeName", "avg_suitability")])
tn_avg_df <- tn_avg_df[order(-tn_avg_df$avg_suitability), ]
print(tn_avg_df, row.names = FALSE)
