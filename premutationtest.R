## ---------------------------
## Data + outcome
## ---------------------------
preservative <- c(1,1,1,1,0,0,0,0,1,1,1,1,0,0,0,0)
water <- c(rep("filter",8), rep("tap",8))
total <- c(12,16,11,8,9,14,9,20,12,11,6,7,7,11,9,8)
dead <- c(0,1,3,1,9,9,2,15,0,1,0,0,2,4,1,5)
dying <- c(0,3,4,1,0,5,7,1,0,4,3,4,5,7,8,3)

df <- data.frame(
  preservative = factor(preservative, levels = c(0,1), labels = c("no","yes")),
  water = factor(water, levels = c("filter","tap")),
  total = total,
  dead = dead,
  dying = dying
)
df$nonfresh <- (df$dead + df$dying) / df$total   # outcome y_i


## ---------------------------
## Helper: difference in means
## ---------------------------
stat_diff <- function(y, g) {
  m <- tapply(y, g, mean)
  as.numeric(m[2] - m[1])  # (second level) - (first level)
}

T_obs_pres  <- stat_diff(df$nonfresh, df$preservative)  # preservative main effect
T_obs_water <- stat_diff(df$nonfresh, df$water)         # water main effect


## ---------------------------
## Exact blocked permutations
## ---------------------------
# Utility: enumerate all label permutations for a single block
# given an original factor vector 'lab_block' (e.g., 8-length with 4 "yes", 4 "no").
# Returns a matrix with nrow = length(block), ncol = number of unique permutations.
enumerate_block_labels <- function(lab_block) {
  lab_block <- factor(lab_block)  # ensure factor, keep counts
  lev <- levels(lab_block)
  stopifnot(length(lev) == 2)     # binary labels only here
  
  n <- length(lab_block)
  k <- sum(lab_block == lev[2])   # count of "second" level (e.g., "yes")
  
  # choose positions (indices) that will take lev[2]
  comb <- combn(n, k)
  nperm <- ncol(comb)
  M <- matrix(lev[1], nrow = n, ncol = nperm)  # start all as lev[1]
  for (j in seq_len(nperm)) {
    M[comb[, j], j] <- lev[2]
  }
  # Convert to factor with same levels
  apply(M, 2, function(col) factor(col, levels = lev))
}

## Indices for blocks
idx_by_water <- split(seq_len(nrow(df)), df$water)          # two blocks of size 8
idx_by_pres  <- split(seq_len(nrow(df)), df$preservative)   # two blocks of size 8

## ---------------------------
## (A) Test preservative effect: permute 'preservative' within each water block
## ---------------------------
# For each water block, enumerate all ways to assign 4 "yes" and 4 "no"
block_perm_pres <- lapply(idx_by_water, function(idx) {
  enumerate_block_labels(df$preservative[idx])
})
# block_perm_pres is a list of two matrices, each 8 x 70 (since choose(8,4)=70)

# Cartesian product of the two blocks → 70*70 = 4900 permutations
nA <- ncol(block_perm_pres[[1]])
nB <- ncol(block_perm_pres[[2]])
T_perm_pres_all <- numeric(nA * nB)

counter <- 1L
for (a in seq_len(nA)) {
  for (b in seq_len(nB)) {
    # build full permuted label vector
    pres_perm <- df$preservative
    pres_perm[idx_by_water[[1]]] <- block_perm_pres[[1]][, a]
    pres_perm[idx_by_water[[2]]] <- block_perm_pres[[2]][, b]
    # statistic under this permutation
    T_perm_pres_all[counter] <- stat_diff(df$nonfresh, pres_perm)
    counter <- counter + 1L
  }
}

# Exact two-sided p-value
p_pres_exact <- mean(abs(T_perm_pres_all) >= abs(T_obs_pres))

## ---------------------------
## (B) Test water effect: permute 'water' within each preservative block
## ---------------------------
block_perm_water <- lapply(idx_by_pres, function(idx) {
  enumerate_block_labels(df$water[idx])
})
# Again 70 per block → 4900 total permutations
nA <- ncol(block_perm_water[[1]])
nB <- ncol(block_perm_water[[2]])
T_perm_water_all <- numeric(nA * nB)

counter <- 1L
for (a in seq_len(nA)) {
  for (b in seq_len(nB)) {
    water_perm <- df$water
    water_perm[idx_by_pres[[1]]] <- block_perm_water[[1]][, a]
    water_perm[idx_by_pres[[2]]] <- block_perm_water[[2]][, b]
    T_perm_water_all[counter] <- stat_diff(df$nonfresh, water_perm)
    counter <- counter + 1L
  }
}

p_water_exact <- mean(abs(T_perm_water_all) >= abs(T_obs_water))

## ---------------------------
## Results
## ---------------------------
list(
  observed_stats = c(preservative = T_obs_pres, water = T_obs_water),
  n_perm_each = c(preservative = length(T_perm_pres_all), water = length(T_perm_water_all)),
  exact_p_values = c(preservative = p_pres_exact, water = p_water_exact)
)


# multiple testing

## ---------------------------
## Max-T (Westfall–Young) exact p-values (no 24M loop)
## ---------------------------
abs_pres  <- abs(T_perm_pres_all)
abs_water <- abs(T_perm_water_all)
Npres <- length(abs_pres)   # 4900
Nwater <- length(abs_water) # 4900

thr_pres  <- abs(T_obs_pres)
thr_water <- abs(T_obs_water)

count_below <- function(v, t) sum(v < t)

# Exact max-T adjusted p-values
p_adj_pres  <- 1 - (count_below(abs_pres,  thr_pres)  * count_below(abs_water, thr_pres))  / (Npres * Nwater)
p_adj_water <- 1 - (count_below(abs_pres,  thr_water) * count_below(abs_water, thr_water)) / (Npres * Nwater)

## (Optional) add +1 finite-sample correction (conservative):
# p_adj_pres  <- ( (Npres*Nwater) - count_below(abs_pres, thr_pres)  * count_below(abs_water, thr_pres)  + 1 ) / (Npres*Nwater + 1)
# p_adj_water <- ( (Npres*Nwater) - count_below(abs_pres, thr_water) * count_below(abs_water, thr_water) + 1 ) / (Npres*Nwater + 1)

list(
  observed_stats = c(preservative = T_obs_pres, water = T_obs_water),
  raw_exact_p    = c(preservative = p_pres_exact, water = p_water_exact),
  maxT_exact_p   = c(preservative = p_adj_pres,  water = p_adj_water),
  n_perm_each    = c(preservative = Npres, water = Nwater),
  n_joint_pairs  = Npres * Nwater
)


# Viasualization

# Histogram
par(mfrow=c(1,2))
hist(T_perm_pres_all, breaks=30, col="lightgray", border="white",
     main="Permutation Null: Preservative Effect", xlab="Difference in mean nonfresh")
abline(v = T_obs_pres, col="red", lwd=2)
abline(v = -T_obs_pres, col="red", lwd=2, lty=2)
mtext(sprintf("Observed = %.3f\np = %.4f", T_obs_pres, p_pres_exact), side=3, line=-2, col="red")

hist(T_perm_water_all, breaks=30, col="lightgray", border="white",
     main="Permutation Null: Water Effect", xlab="Difference in mean nonfresh")
abline(v = T_obs_water, col="blue", lwd=2)
abline(v = -T_obs_water, col="blue", lwd=2, lty=2)
mtext(sprintf("Observed = %.3f\np = %.4f", T_obs_water, p_water_exact), side=3, line=-2, col="blue")


# ECDF
plot(ecdf(abs(T_perm_pres_all)), col="red", lwd=2, main="ECDF of |Test statistic|",
     xlab="|Difference in mean nonfresh|", ylab="Cumulative probability", xlim=c(0, max(abs(T_perm_pres_all), abs(T_perm_water_all))))
lines(ecdf(abs(T_perm_water_all)), col="blue", lwd=2)
abline(v = abs(T_obs_pres), col="red", lwd=2, lty=2)
abline(v = abs(T_obs_water), col="blue", lwd=2, lty=2)
legend("bottomright", legend=c("Preservative","Water"), col=c("red","blue"), lwd=2, bty="n")


# Max-T histogram

library(ggplot2)

df_joint <- expand.grid(T_pres = T_perm_pres_all,
                        T_water = T_perm_water_all)

ggplot(df_joint, aes(x=T_pres, y=T_water)) +
  geom_bin2d(bins=50) +
  scale_fill_viridis_c(option="plasma") +
  geom_vline(xintercept = T_obs_pres, color="red", lwd=1.2) +
  geom_hline(yintercept = T_obs_water, color="blue", lwd=1.2) +
  labs(title="Joint null distribution (max-T)",
       x="Preservative statistic", y="Water statistic") +
  theme_minimal()


# Effect size plot

library(dplyr)
df_summary <- df %>%
  group_by(preservative, water) %>%
  summarise(mean_nonfresh = mean(nonfresh), .groups='drop')

ggplot(df_summary, aes(x=water, y=mean_nonfresh, fill=preservative)) +
  geom_col(position="dodge") +
  geom_text(aes(label=sprintf("%.2f", mean_nonfresh)), vjust=-0.5, position=position_dodge(0.9)) +
  labs(title="Mean proportion of nonfresh blossoms",
       x="Water type", y="Mean nonfresh proportion",
       fill="Preservative") +
  theme_minimal()


