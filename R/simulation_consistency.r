
# Last changed on: 29th Nov 2020
# Last changed by: Marianne 

# set flags: 

useSAMdgm <- TRUE 

# load required libraries and files:

library(foreach)
library(doMC)
library(doRNG)

source("dgm.r")
source("consistency_simul_functions.r")

if (useSAMdgm)
{
   source("estimator_test_sam_dgm.r")
   num_min_prox_val <- 120
   c_val <- 1
}

if (!useSAMdgm)
{
   source("estimator.r")
   num_min_prox_val <- 2
}

max_cores <- 16
registerDoMC(min(detectCores() - 1, max_cores))

sample_sizes <- c(25, 50, 75)
num_dec_points <- 100
nsim <- 20

# FOR TESTING:
# sample_sizes <- c(25, 50)
# num_dec_points <- 100
# nsim <- 2

result_df_collected <- data.frame()
compar_mat <- data.frame()

for (i_ss in 1:length(sample_sizes)) 
{
    sample_size <- sample_sizes[i_ss]
    print(paste0("sample_size: ", sample_size))

    result <- list() 
    for (isim in 1:nsim) 
    {
        print(paste0("   isim: ", isim))

        set.seed(i_ss * isim)

        M <- NULL 
        I <- NULL

        if (useSAMdgm)
        {
            dgm <- dgm_sam(
                num_users = sample_size, 
                num_dec_points = num_dec_points, 
                num_min_prox = num_min_prox_val, 
                c_val = c_val
            )
    
            beta_true <- c(dgm[['beta_01_true']], dgm[['beta_11_true']], dgm[['beta_02_true']], dgm[['beta_12_true']])

            fit_e <- estimating_equation_dgm_sam(
                dta = dgm, 
                M = M, 
                I = I, 
                num_min_prox = num_min_prox_val, 
                num_users = sample_size, 
                num_dec_points = num_dec_points
            )
        }

        if (!useSAMdgm)
        {
            dgm <- dgm_trivariate_categorical_covariate(
                sample_size = sample_size, 
                total_T = num_dec_points, 
                time_window_for_Y = num_min_prox_val
            )

            dta <- dgm[['data']]

            beta_true <- dgm[['beta_true']]

            fit_e <- estimating_equation(
                dta = dta,
                time_window_for_Y = num_min_prox_val,
                control_varname = "S",
                miss_at_rand_varname = "S",
                moderator_varname = "X",
                avail_varname = NULL,
                missing_varname = NULL
            )
        }
        
        result[isim] <- list(fit_e = fit_e)
    }

    beta_hat_mat <- matrix(0, 0, 4) 
    colnames(beta_hat_mat) <- c("beta_01", "beta_11", "beta_02", "beta_12")
    for (isim in 1:nsim) 
        beta_hat_mat <- rbind(beta_hat_mat, as.vector(result[[isim]]$beta_hat))

    beta_hat_se_mat <- matrix(0, 0, 4) 
    colnames(beta_hat_se_mat) <- c("beta_01", "beta_11", "beta_02", "beta_12")
    for (isim in 1:nsim) 
        beta_hat_se_mat <- rbind(beta_hat_se_mat, as.vector(result[[isim]]$beta_se))

    beta_01_true <- beta_true[1]
    beta_11_true <- beta_true[2]
    beta_02_true <- beta_true[3]
    beta_12_true <- beta_true[4]

    beta_true <- c(beta_01_true, beta_11_true, beta_02_true, beta_12_true)

    beta_hat <- beta_hat_mat
    beta_hat_se <- beta_hat_se_mat

    result <- compute_result_beta(beta_true, beta_hat, beta_hat_se, moderator_vars = "X", control_vars = "S", significance_level = 0.05)

    result_df <- data.frame(ss = rep(sample_size, 1),
                            bias = result$bias,
                            sd = result$sd,
                            se = result$ave_beta_se,
                            rmse = result$rmse,
                            cp = result$coverage_prob)

    names(result_df) <- c("ss", "bias", "sd", "se", "rmse", "cp")
    rownames(result_df) <- NULL
    
    result_df_collected <- rbind(result_df_collected, result_df)

    print(result_df_collected)

    compar_mat <- rbind(compar_mat, as.data.frame(result$compar_mat))

    print(compar_mat)
}



