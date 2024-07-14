### libraries
if (!require("ape")) install.packages("ape"); library("ape")
if (!require("diversitree")) install.packages("diversitree"); library("diversitree")
if (!require("FAmle")) install.packages("FAmle");library("FAmle")

### loading phylogenetic tree
mcc = read.tree("0_data/pruned_mcc_phylo.nwk")

### counting pruned phylognetic trees
n_phylo = length(list.files("0_data/pruned_phylos"))

### importing habitat range
habitat_range = readRDS("1_habitat_results/habitat_range.RDS")

### define states
geo_states = as.character(habitat_range$range)
geo_states[geo_states == "generalist"] = "0"
geo_states[geo_states == "forest_specialist"] = "1"
geo_states[geo_states == "open_specialist"] = "2"
geo_states = as.numeric(geo_states)
names(geo_states) = habitat_range$species

############################ FITTING MODELS ACROSS TREES  ######################
d_params = c()
sd_params = c()
sxd_params = c()
model_fit_list = list()

for (i in 1:n_phylo){
  ### pick a phylogenetic tree
  phylo_path = paste0("0_data/pruned_phylos/pruned_phylo_", as.character(i))
  phylo = read.tree(phylo_path)
  ### set models
  sxd = make.geosse(phylo, states=geo_states, sampling.f=0.75)
  sd = constrain(sxd, xA ~ xB)
  d = constrain(sxd, sA ~ sB, xA ~ xB)
  ### starting values
  start_geosse = starting.point.geosse(phylo)
  ### find mle
  # all constant
  mle_d = find.mle(d, start_geosse)
  d_params = rbind(d_params, mle_d$par)
  # varying lambda
  mle_sd = find.mle(sd, start_geosse)
  sd_params = rbind(sd_params, mle_sd$par)
  # varying lambda and mu
  mle_sxd = find.mle(sxd, start_geosse)
  sxd_params = rbind(sxd_params, mle_sxd$par)
  ### summarizing model fit
  d_fit = c(lnlik= mle_d$lnLik, n_par=length(mle_d$par))
  sd_fit = c(mle_sd$lnLik, length(mle_sd$par))
  sxd_fit = c(mle_sxd$lnLik, length(mle_sxd$par))
  fit_values = rbind(d_fit, sd_fit, sxd_fit)
  model_fit_list[[i]] = fit_values
  ### iteration done
  print(paste("Time:", Sys.time(), "Loop iterarion:", as.character(i) ) )
}

### export
saveRDS(model_fit_list, "3_diversification_results/model_fit_list.RDS")
saveRDS(d_params, "3_diversification_results/model_d_params.RDS")
saveRDS(sd_params, "3_diversification_results/model_sd_params.RDS")
saveRDS(sxd_params, "3_diversification_results/model_sxd_params.RDS")

########################### COMPARING MODELS ##############################

### model fit per tree
model_fit_list = readRDS("3_diversification_results/model_fit_list.RDS")

### N for AICC
N = Ntip(mcc)

### to keeep best model names
best_models = c()
### choose best model per phylo tree by AICc
for (i in 1:length(model_fit_list)){
  ### pick a fit from one phylo tree
  one_fit = as.data.frame(model_fit_list[[i]])
  ### AIC = -2(log-likelihood) + 2K
  aic = (2*one_fit$n_par) - (2*one_fit$lnlik)
  ### AiCc = AIC - 2k(k+1) / (n-k-1)
  aicc = aic + (((2*one_fit$n_par)*(one_fit$n_par+1))/(N-one_fit$n_par-1))
  one_fit = cbind(one_fit, aicc)
  ### ranking models
  first_lowest = one_fit[one_fit$aicc==min(one_fit$aicc),]
  minus_first = one_fit[-which(one_fit$aicc==min(one_fit$aicc) ),]
  second_lowest = minus_first[minus_first$aicc==min(minus_first$aicc),]
  ### choosing best model
  if (second_lowest$aicc - first_lowest$aicc > 2){
    best_models = rbind(best_models, rownames(first_lowest) )
  } 
  if (second_lowest$aicc - first_lowest$aicc < 2){
    if(second_lowest$n_par > first_lowest$n_par){
      best_models = rbind(best_models, rownames(first_lowest) )
    }
    if(second_lowest$n_par < first_lowest$n_par){
      best_models = rbind(best_models, rownames(second_lowest) )
    }
  }
}
  
### exporting
saveRDS(best_models, "3_diversification_results/best_models.RDS")

#################### SUMMARIZING BEST MODEL ESTIMATES #########################

### best models per phylo tree
best_models = readRDS("3_diversification_results/best_models.RDS")

### load parameter estimates
d_params = readRDS("3_diversification_results/d_params.RDS")
sd_params = readRDS("3_diversification_results/sd_params.RDS")
sxd_params = readRDS("3_diversification_results/sxd_params.RDS")

### most frequent model
most_freq = max(table(best_models))
most_freq_model = names(which(table(best_models) == most_freq) ) 

### pick estiamtes from most frequent model
if(most_freq_model == "d_fit"){
  best_params = d_params
}
if(most_freq_model == "sd_fit"){
  best_params = sd_params
}
if(most_freq_model == "sxd_fit"){
  best_params = sxd_params
}

### get final parameter estimates
final_params = best_params[which(best_models == most_freq_model),]

apply(final_params, FUN= mean, MARGIN = 2)


### export best-fit model parameters
saveRDS(final_params, "3_diversification_results/final_best_params.RDS")