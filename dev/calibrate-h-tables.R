# Recalibrate the default decision intervals of the MEWMA and MCUSUM charts
#
# Audit 2026-09-25, findings 5 and 6: the tables shipped in 1.3.0 held
# ARL_0 ~ 200 only for p = 2. This script re-derives every cell by
# Monte Carlo so the tables in R/chart-mewma.R and R/chart-mcusum.R can
# be regenerated and audited.
#
# Method. With known in-control parameters both statistics are
# invariant to affine transformations of X, so paths are simulated from
# N_p(0, I). Neither statistic depends on h (MEWMA has no reset, the
# Crosier MCUSUM shrinks towards 0 using k only), so one set of paths
# serves every candidate h: for each path we keep the records of the
# running maximum (t, value). The run length at h is the time of the
# first record exceeding h, which makes ARL(h) cheap to evaluate and
# lets a plain bisection solve ARL(h) = 200 on common random numbers.
# Paths are censored at `max_run`; at ARL_0 = 200 the chance of staying
# in control for 5000 steps is ~ exp(-25), i.e. zero in practice.
#
# MEWMA is calibrated both for the time-varying covariance (the package
# default, steady_state = FALSE) and for the steady-state covariance
# (steady_state = TRUE). MCUSUM uses k = 0.5.
#
# Usage: Rscript dev/calibrate-h-tables.R      (H_PATHS env var = paths)
# Output: printed tables + dev/h-tables.rds

n_paths <- as.integer(Sys.getenv("H_PATHS", "20000"))
max_run <- 5000L
target  <- 200

# Records of the running maximum of a statistic, simulated in parallel
# over paths. `step(state, x, t)` returns list(state, stat).
run_records <- function(p, n_paths, max_run, init, step, h_hi, seed) {
  set.seed(seed)
  state  <- init(n_paths, p)
  curmax <- rep(-Inf, n_paths)
  rp <- list(); rt <- list(); rv <- list(); j <- 0L
  for (t in seq_len(max_run)) {
    x   <- matrix(stats::rnorm(n_paths * p), n_paths, p)
    res <- step(state, x, t)
    state <- res$state
    w <- which(res$stat > curmax)
    if (length(w)) {
      j <- j + 1L
      rp[[j]] <- w; rt[[j]] <- rep.int(t, length(w)); rv[[j]] <- res$stat[w]
      curmax[w] <- res$stat[w]
    }
    if (all(curmax > h_hi)) break
  }
  list(path = unlist(rp), t = unlist(rt), val = unlist(rv), n = n_paths,
       max_run = max_run)
}

arl_at <- function(rec, h) {
  hit <- rec$val > h
  rl  <- rep(rec$max_run, rec$n)
  # records are stored in time order, so the first hit per path is the
  # first crossing
  hp <- rec$path[hit]; ht <- rec$t[hit]
  first <- !duplicated(hp)
  rl[hp[first]] <- ht[first]
  c(arl = mean(rl), se = stats::sd(rl) / sqrt(rec$n))
}

solve_h <- function(rec, lo, hi, tol = 1e-4) {
  while (hi - lo > tol) {
    mid <- (lo + hi) / 2
    if (arl_at(rec, mid)[["arl"]] < target) lo <- mid else hi <- mid
  }
  h <- round((lo + hi) / 2, 2)
  a <- arl_at(rec, h)
  c(h = h, arl = unname(a["arl"]), se = unname(a["se"]))
}

mewma_records <- function(p, lambda, steady_state, seed) {
  ratio <- lambda / (2 - lambda)
  run_records(
    p, n_paths, max_run,
    init = function(n, p) matrix(0, n, p),
    step = function(Z, x, t) {
      Z <- lambda * x + (1 - lambda) * Z
      v <- if (steady_state) ratio else ratio * (1 - (1 - lambda)^(2 * t))
      list(state = Z, stat = rowSums(Z^2) / v)
    },
    h_hi = 40, seed = seed
  )
}

mcusum_records <- function(p, k, seed) {
  run_records(
    p, n_paths, max_run,
    init = function(n, p) matrix(0, n, p),
    step = function(S, x, t) {
      V <- S + x
      C <- sqrt(rowSums(V^2))
      shrink <- ifelse(C <= k, 0, 1 - k / C)
      S <- V * shrink
      list(state = S, stat = sqrt(rowSums(S^2)))
    },
    h_hi = 30, seed = seed
  )
}

t0 <- Sys.time()

mcusum <- data.frame(p = 2:10, k = 0.5, h = NA_real_, arl = NA_real_,
                     se = NA_real_)
for (i in seq_len(nrow(mcusum))) {
  rec <- mcusum_records(mcusum$p[i], 0.5, seed = 2000 + i)
  s <- solve_h(rec, 0.5, 30)
  mcusum$h[i] <- s[["h"]]; mcusum$arl[i] <- s[["arl"]]; mcusum$se[i] <- s[["se"]]
  cat(sprintf("MCUSUM k=0.5 p=%2d h=%6.2f ARL0=%6.1f (se %.1f)\n",
              mcusum$p[i], s[["h"]], s[["arl"]], s[["se"]]))
}

lambdas <- c(0.05, 0.10, 0.20, 0.40)
mewma <- expand.grid(lambda = lambdas, p = 2:6, steady_state = c(FALSE, TRUE))
mewma$h <- mewma$arl <- mewma$se <- NA_real_
for (i in seq_len(nrow(mewma))) {
  rec <- mewma_records(mewma$p[i], mewma$lambda[i], mewma$steady_state[i],
                       seed = 1000 + i)
  s <- solve_h(rec, 1, 40)
  mewma$h[i] <- s[["h"]]; mewma$arl[i] <- s[["arl"]]; mewma$se[i] <- s[["se"]]
  cat(sprintf("MEWMA  lambda=%.2f p=%d ss=%-5s h=%6.2f ARL0=%6.1f (se %.1f)\n",
              mewma$lambda[i], mewma$p[i], mewma$steady_state[i],
              s[["h"]], s[["arl"]], s[["se"]]))
}

cat("\nElapsed:", format(Sys.time() - t0), "\n")
cat("\nMEWMA h (rows lambda, cols p), time-varying (steady_state = FALSE):\n")
print(xtabs(h ~ lambda + p, mewma[!mewma$steady_state, ]))
cat("\nMEWMA h (rows lambda, cols p), steady-state (steady_state = TRUE):\n")
print(xtabs(h ~ lambda + p, mewma[mewma$steady_state, ]))
cat("\nMCUSUM h, k = 0.5:\n")
print(mcusum)
saveRDS(list(mewma = mewma, mcusum = mcusum, n_paths = n_paths,
             max_run = max_run),
        file.path("dev", "h-tables.rds"))
