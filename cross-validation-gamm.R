#runs cross validation using BROKE-West data
#fits asreml model developed in simulation to BROKE-West data
#cross-validation uses drop one station and drop one arm
#author: Lisa-Marie Harrison
#date: 05/02/2015

setwd(dir = "C:/Users/Lisa/Documents/phd/southern ocean/Mixed models/Data")
dat <- read.csv(file = "procCTD.csv", header= T)
library(asreml)
library(mgcv)
library(lattice)

#simplify names
names(dat) <- c("survey", "stn", "lat", "long", "start.time", "end.time", "depth", "transmittance", "cond", "temp", "sal", "par", "oxygen", "fluoro", "x2", "ice", "wm")

#remove null values
dat$sal[dat$sal == -9] <- NA
dat$temp[dat$temp == -9] <- NA
dat$par[dat$par == -9] <- NA
dat$fluoro[dat$fluoro == -9] <- NA

#compute log transformed fluoro values
dat$l.fluoro <- log(dat$fluoro)
dat$l.fluoro[is.nan(dat$l.fluoro)] <- NA

#get latitude and longitude for each station
n.station <- length(unique(dat$stn))
lat  <- dat$lat[duplicated(dat$stn) == FALSE]
long <- dat$long[duplicated(dat$stn) == FALSE]

#plot location of BROKE-West station with station number overlayed
plot(long, lat, col = "white", xlab = "longitude", ylab = "latitude")
text(long, lat, c(2:118))
title("location of BROKE-West CTD stations")

deg2rad <- function(deg) {
  #converts degrees to radians
  #input: degree coordinate
  #returns: radian coordinate 
  
  return(deg*pi/180)
}

gcd.hf <- function(lat1, long1, lat2, long2) {
  #calculates distance between two coordinates using the Haversine formula (hf)
  #input: radian latitude and longitude coordinates
  #returns: distance between coordinates in km
  
  R <- 6371 # Earth mean radius [km]
  delta.long <- (long2 - long1)
  delta.lat  <- (lat2 - lat1)
  a <- sin(delta.lat/2)^2 + cos(lat1) * cos(lat2) * sin(delta.long/2)^2
  c <- 2 * asin(min(1, sqrt(a)))
  d = R * c
  return(d) 
  
}

#distance of each station from station 1 in x and y directions
x <- 0
y <- 0
rad_long <- deg2rad(long)
rad_lat  <- deg2rad(lat)
top_lat <- deg2rad(max(lat))
top_long <- deg2rad(max(long))
for (i in 1:n.station) {
  x[i] <- gcd.hf(rad_lat[i], top_long, top_lat, top_long)/100    
  y[i] <- gcd.hf(top_lat, rad_long[i], top_lat, top_long)/100
}


#data frame
glm.spl <- data.frame(dat$l.fluoro, dat$depth, as.factor(dat$stn), rep(x, 1, each = length(unique(dat$depth))), rep(y, 1, each = length(unique(dat$depth))), dat$temp, dat$par, dat$sal, dat$oxygen, dat$ice, as.factor(dat$wm))
names(glm.spl) <- c("l.obs", "z", "stn", "x", "y", "temp", "par", "sal", "oxy", "ice", "wm")
glm.spl$z.fact <- as.factor(as.integer(glm.spl$z))
glm.spl$x.fact <- as.factor(glm.spl$x)
glm.spl$y.fact <- as.factor(glm.spl$y)
glm.spl <- glm.spl[order(glm.spl$z, glm.spl$x, glm.spl$y), ] #sort by order of rcov structure
glm.spl$l.obs[glm.spl$l.obs == -Inf] <- NA

#centre and scale covariates to mean = 0 and sd = 1
#this is required if using na.method = "include" since this sets the missing values to 0
glm.spl$temp <- scale(glm.spl$temp)
glm.spl$par  <- scale(glm.spl$par)
glm.spl$sal  <- scale(glm.spl$sal)
glm.spl$oxy  <- scale(glm.spl$oxy)
glm.spl$ice  <- scale(glm.spl$ice)
glm.spl$oxy  <- scale(glm.spl$oxy)

#----------------------------- DROP WHOLE ARM AT ONCE -------------------------------#

survey_arms <- list('1' = 27:44, '2' = 45:59, '3' = 60:71, '4' = 72:85, '5' = 86:102, '6' = 103:118, '7' = 2:26)


dropArm <- function(arm, dat, N) {
  #cross validation by randomly dropping one station
  #station = complete list of stations
  #dat = data frame containing all data (glm.spl format)
  #N = number of times to run cross-validation
  #return = station number, observed values, predicted values and depth for N stations
  
  
  station_set <- arm[N]
  
  #fit gamm to compare
  gamm.fit <- gamm(l.obs ~ s(z) + s(temp, by = wm) + s(par) + s(ice), random = list(stn =~ 1, x =~1, y =~1), 
                   data = dat[!(dat$stn %in% station_set[[1]]), ], correlation = corAR1(0.9, 1 ~ z | x | y))

  
  pred <- predict.gam(gamm.fit$gam, newdata = dat[dat$stn %in% station_set[[1]], ], se.fit = TRUE)
  
  predicted <- pred$fit
  std_error <- pred$se.fit 
  observed <- dat[dat$stn %in% station_set[[1]], ]$l.obs
  stn <- dat[dat$stn %in% station_set[[1]], ]$stn
  depth = dat[dat$stn %in% station_set[[1]], ]$z
  
  
  return(list(depth = depth, stn = stn, std_error = std_error, observed = observed, predicted = predicted))
  
}

cross_val <- dropArm(arm = survey_arms, dat = glm.spl, 6)


cross_val$predicted[is.na(cross_val$observed)] <- NA

#plot fitted against observed for all dropped stations
lat.plot <- xyplot(cross_val$observed + cross_val$predicted ~ cross_val$depth | cross_val$stn, 
                   outer = FALSE, type = "l", xlab = list("depth (m)", cex = 2), ylab = list("l.fluoro", cex = 2), scales = list(cex = 2), cex.axis = 2)
update(lat.plot, par.settings = simpleTheme(lwd = c(2, 1), col = c("dodgerblue", "red")), lwd = 2,  cex.axis = 2, cex.lab = 2)



#plot distance in x and y direction against residuals
plot(glm.spl$x[glm.spl$stn %in% cross_val$stn], cross_val$observed - cross_val$predicted, xlab = "latitudinal distance (100km)",
     ylab = "residuals")
title("Residuals by x distance from top right corner of survey area")
