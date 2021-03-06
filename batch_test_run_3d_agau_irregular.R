#runs a simulation multiple times using the same input values to check the average
#uses ar1 process
library(asreml)
source(file = "C:/Users/Lisa/Documents/phd/southern ocean/Mixed models/R code/R-simulation-study/simData_3d_agau_irregular_grid.R")

#set all values to zero initially
stn.sd   <- 0
noise.sd <- 0
z.phi    <- 0
x.phi    <- 0
y.phi    <- 0
spline_error <- 0

stn_err <- 0
noise_err <- 0
z_err <- 0
x_err <- 0
y_err <- 0

for (i in 1:200) {
  
  glm.spl <- simData(noise.sd = 0.45, stn.sd = 0.22, z.phi = 0.35,
                     x.phi = 0.5, y.phi = 0.4)
  

  asreml.fit <- asreml(fixed = l.obs ~ z + par + temp, random =~ spl(z) + spl(par) + spl(temp) + stn, data = glm.spl, 
                         splinepoints = list(z = seq(0, 250, 25)), rcov=~ ar1(z.fact):agau(x, y), trace = F)

  #if not converged or values changed on last iteration, keep trying
  while (!asreml.fit$converge) {
    asreml.fit <- update(asreml.fit)
  }
  
  
  #predict to get SE for temp and par trends
  
  #temperature
  pred_temp <- predict(asreml.fit, classify = "temp:par")
  pval_temp <- pred_temp$predictions$pvals["predicted.value"]$predicted.value
  temp      <- pred_temp$predictions$pvals["temp"]$temp
  se_temp   <- pred_temp$predictions$pvals["standard.error"]$standard.error
  
  #par
  pred_par <- predict(asreml.fit, classify = "par")
  pval_par <- pred_par$predictions$pvals["predicted.value"]$predicted.value
  par      <- pred_par$predictions$pvals["par"]$par
  se_par   <- pred_par$predictions$pvals["standard.error"]$standard.error
  
  
  #extract variance components
  stn.sd[i]   <- summary(asreml.fit)$varcomp[4,2]^0.5
  noise.sd[i] <- summary(asreml.fit)$varcomp[5,2]^0.5
  z.phi[i]    <- summary(asreml.fit)$varcomp[6,2]
  x.phi[i]    <- summary(asreml.fit)$varcomp[7,2]
  y.phi[i]    <- summary(asreml.fit)$varcomp[8,2]
  spline_error[i] <- mean(se_temp^2) + mean(se_par^2)
  
  stn_err[i]   <- summary(asreml.fit)$varcomp[4,3]
  noise_err[i] <- summary(asreml.fit)$varcomp[5,3]
  z_err[i]    <- summary(asreml.fit)$varcomp[6,3]
  x_err[i]    <- summary(asreml.fit)$varcomp[7,3]
  y_err[i]    <- summary(asreml.fit)$varcomp[8,3]

  print(i)
  
}

dat <- cbind(stn.sd, noise.sd, z.phi, x.phi, y.phi, spline_error, stn_err, noise_err, z_err, x_err, y_err)

if (Sys.info()[4] == "SCI-6246") {
  setwd(dir = "C:/Users/43439535/Documents/Lisa/phd/Mixed models")
} else {
  setwd(dir = "C:/Users/Lisa/Documents/phd/southern ocean/Mixed models")
}

dat <- read.csv("C:/Users/43439535/Documents/Lisa/phd/aerial survey/data/pars_fixed.csv", header = T)
attach(dat)

#plot histogram of every variance component with fitted average and true values overlayed
#pdf("C:/Users/43439535/Dropbox/uni/MEE submitted/images/Figure_1.pdf")

par(mfrow = c(3, 2), oma = c(0, 6, 0, 0), lwd = 2)
line_width <- 5
text_size <- 2
hist(dat$stn.sd, main = "station random effect", xlab = "", ylab = "", cex.axis = text_size, cex.lab = text_size, cex.main = text_size)
abline(v = 0.22, col = "red", lwd = line_width)
abline(v = mean(dat$stn.sd), col = "grey50", lwd = line_width)
hist(dat$noise.sd, main = "random noise", xlab = "", ylab = "",cex.axis = text_size, cex.lab = text_size, cex.main = text_size)
abline(v = 0.45, col = "red", lwd = line_width)
abline(v = mean(dat$noise.sd), col = "grey50", lwd = line_width)
hist(dat$z.phi, main = "depth correlation", xlab = "", ylab = "",cex.axis = text_size, cex.lab = text_size, cex.main = text_size)
abline(v = 0.35, col = "red", lwd = line_width)
abline(v = mean(dat$z.phi), col = "grey50", lwd = line_width)
hist(dat$x.phi, main = "latitude correlation", xlab = "", ylab = "",cex.axis = text_size, cex.lab = text_size, cex.main = text_size)
abline(v = 0.5, col = "red", lwd = line_width)
abline(v = mean(dat$x.phi), col = "grey50", lwd = line_width)
hist(dat$y.phi, main = "longitude correlation", xlab = "", ylab = "",cex.axis = text_size, cex.lab = text_size, cex.main = text_size)
abline(v = 0.4, col = "red", lwd = line_width)
abline(v = mean(dat$y.phi), col = "grey50", lwd = line_width)
mtext("Frequency", side = 2, outer = TRUE, line = 2, cex = text_size)

#dev.off()

#table of statistics for paper
stats_tab <- matrix(round(apply(dat, 2, mean), 2), ncol = 1)
stats_tab <- cbind(stats_tab, round(apply(dat, 2, sd), 3))
stats_tab <- cbind(stats_tab, round(apply(dat, 2, min), 2))
stats_tab <- cbind(stats_tab, round(apply(dat, 2, max), 2))
stats_tab <- cbind(stats_tab,  c(quantile(stn.sd)[2], quantile(noise.sd)[2], quantile(z.phi)[2], quantile(x.phi)[2], quantile(y.phi)[2]))
stats_tab <- cbind(stats_tab,  c(quantile(stn.sd)[4], quantile(noise.sd)[4], quantile(z.phi)[4], quantile(x.phi)[4], quantile(y.phi)[4]))
rownames(stats_tab) <- c("stn.sd", "noise.sd", "depth", "lat", "long")
colnames(stats_tab) <- c("mean", "sd", "min", "max", "25% quantile", "75% quantile")
stats_tab




