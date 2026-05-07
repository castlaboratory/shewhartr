# Shewhart — Plano de Reformulação (v0.2.0 → v1.0.0)

> *"All models are wrong, but some are useful."* — George E. P. Box
>
> *"The greatest value of a picture is when it forces us to notice what we never expected to see."* — John W. Tukey
>
> *"Some statisticians ask 'how can I use my method on this data?' The right question is: what does this data demand of a method?"* — paráfrase do espírito de Abraham Wald

---

## 1. Reposicionamento

A versão 0.1.1 nasceu de um problema concreto (monitoramento de óbitos por COVID-19 em Recife) e a arquitetura atual reflete isso: um único modo de operação — **carta de regressão com transformação log/loglog/Gompertz e regra de 7 pontos**. Isso é, na verdade, um caso particular interessante de uma família muito mais ampla.

A v1.0.0 será um **pacote de Statistical Process Control (SPC) tidyverse-nativo**, com cinco vantagens competitivas claras frente a `qcc` (clássico, API S3 antiga, sem tidyverse) e `qicharts2` (focado em healthcare, plots fixos):

1. **API tidyverse-nativa** — tidy evaluation, `data` em primeira posição, `.by` group-aware, retorno tibble + objeto S3.
2. **Integração broom** — `tidy()`, `glance()`, `augment()` para todas as cartas.
3. **Cartas baseadas em regressão como cidadã de primeira classe** — diferencial real: nenhum pacote R as trata bem, e é exatamente o que o pacote já faz.
4. **Diagnóstico estatístico embutido** — ARL simulado, OC curves, Box-Cox, runs tests configuráveis. Tudo o que livros como Montgomery e Wheeler ensinam mas raramente está em pacote.
5. **Phase I / Phase II explícitos** — separação clara de calibração vs monitoramento (Woodall 2000), que praticamente nenhum pacote R implementa.

A aplicação a COVID-19 vira **uma vinheta** ("Estudo de caso: monitoramento epidemiológico com cartas de regressão"), não o organizador do pacote.

---

## 2. Auditoria das funções existentes

### `shewhart_fit()` — refatorar como `regression_chart_fit()` interno

Função correta no espírito mas com 3 problemas:

1. Magic numbers nos chutes do Gompertz (`Asym = 10000, b2 = 2, b3 = 0.02`) calibrados implicitamente para contagens de óbitos. Trocar por `SSgompertz` self-starting puro.
2. Para Gompertz, `dummy_col` é silenciosamente ignorado com `warning()`. Tukey chamaria isso de "violação do princípio de fail-loud". Trocar por `cli::cli_abort()`.
3. Controle de fluxo em `tryCatch` com retorno `NA` seguido de checagem `inherits` é confuso. Refatorar para `safely()` ou estrutura `if-else` explícita.

### `shewhart_model()` — refatorar como `regression_chart()` (objeto S3)

Função central com cinco issues sérios:

1. `min(index_col) + start_base` assume **espaçamento integer/diário regular**. Para séries irregulares falha em silêncio (Date + 10 = 10 dias, não 10 obs). Solução: indexar por posição via `dplyr::nth()` ou `dplyr::row_number()`.
2. Truque `if_else(phase == max(phase), lag(fit), fit)` — herdar o ajuste anterior na última fase é correto conceitualmente (a fase atual ainda não tem dados suficientes para reestimação), mas o controle por `if_else` é frágil. Substituir por status explícito: `phase_status %in% c("calibrated", "extrapolated", "monitoring")`.
3. **`2.66 × MR-bar`** — a constante 2,66 é `3/d2` para n=2 (carta I-MR). Está **correta** para individuais. Mas:
   - Aplicada em resíduos da regressão, assume **resíduos i.i.d. aproximadamente normais** — raramente verdade para resíduos de log de contagens.
   - Sem nenhum diagnóstico (Q-Q, Ljung-Box, ACF). Box exigiria.
   - Não há alternativa robusta. Tukey exigiria mediana das MR e biweight.
4. `pmax(0, ...)` em todos os limites distorce a probabilidade de cobertura. Fora do contexto de contagens (que vão para cartas Poisson/NB próprias), isso é incorreto. Tornar opcional via `lower_bound = c(NA, 0, "auto")`.
5. Locale hardcoded em PT/EN. Trocar por sistema de mensagens com `cli` que respeita `LANGUAGE` do usuário ou parâmetro `language = "auto"`.

### `shewhart_7points()` — generalizar para `runs_test()`

A regra de 7 pontos consecutivos do mesmo lado da CL é uma variante simplificada da regra 2 de Nelson (que usa 9 pontos). Problemas:

1. Critério único, hardcoded. **Wald insistiria** que a regra deve ser explícita e que sua taxa de falso alarme seja documentada. Sob H₀ com p = 0,5, a probabilidade de 7 pontos seguidos do mesmo lado é `2 × 0.5⁷ ≈ 0.0156`, ou seja ARL₀ ≈ 64. Para 9 pontos (Nelson): ARL₀ ≈ 256.
2. Sem teste de significância opcional (ex: runs test de Wald-Wolfowitz).
3. Iteração `for (i in seq_len(ceiling(nrow(subdata)/7)))` é heurística. Trocar por `repeat { ... if (no_new_change) break }`.
4. `autodate_vector + 1` — integer arithmetic em Date. Frágil. Usar `lead(index_col)`.

A função substituta `shewhart_runs()` aplica todas as 8 regras de Nelson (configuráveis), retorna tibble com `(rule, position, evidence)`. Internamente é um conjunto de funções `runs_*()` testáveis isoladamente.

### `shewhart()` (a função de plot, em `R/plot.R`) — quebrar em 3

400 linhas misturando: validação, detecção, modelagem, plot ggplot, plot plotly, manipulação de `LC_TIME`. Refatoração em:

- `regression_chart()` — construtor, retorna S3 `shewhart_chart`
- `autoplot.shewhart_chart()` — método ggplot2
- `plotly_chart()` ou `as_plotly()` — método interativo separado

### `Gompertz()`, `loglog()`, `iloglog()`, `SSgompertzDummy()`, `fit_gompertz_dummy()`

Matemática correta. **Manter**, mas:

- `loglog()` e `iloglog()` viram funções utilitárias documentadas no grupo "transformações", não exportadas como API principal.
- `Gompertz()` integrar à família `growth_curves()` como uma de várias parametrizações.
- `SSgompertzDummy` — manter (raríssimo ter gradiente analítico em pacote R, é uma jóia). Adicionar testes.
- `fit_gompertz_dummy()` — exigir colunas `x, y, dummy` é restritivo. Generalizar com tidy eval.

### `rolling_sum()`, `color_hue()`

Utilitários internos. Tirar do export, mover para `R/utils.R` com `@noRd` ou `@keywords internal`.

### `.onAttach`

Tirar a mensagem `---> CASTLab.org: Version X of Y <---`. Anti-padrão CRAN: pacotes não devem imprimir mensagens no attach a menos que seja informação operacional crítica (CRAN reclama explicitamente). Mover para mensagem opcional em `cli::cli_inform()` na primeira chamada relevante, ou simplesmente remover.

---

## 3. Lacunas metodológicas críticas

| # | Problema | Quem reclamaria | Solução |
|---|---|---|---|
| 1 | Sem cartas clássicas (I-MR, X̄/R, X̄/S, p, np, c, u) | Shewhart no túmulo | Implementar família clássica |
| 2 | Sem capacidade de processo (Cp, Cpk, Pp, Ppk) | Indústria inteira | `shewhart_capability()` |
| 3 | Sem ARL, sem OC curve | Wald | `shewhart_arl()` por simulação |
| 4 | Sem Phase I / Phase II explícito | Woodall (2000) | `calibrate()` + `monitor()` |
| 5 | Sem diagnóstico de modelo | Box | `shewhart_diagnostics()` |
| 6 | Sem alternativa robusta | Tukey | `shewhart_robust()` opções |
| 7 | Sem cartas para contagens nativas (Poisson exato, NB) | Box ("don't transform if you can model") | `shewhart_c()`, `shewhart_u()` com limites de Poisson |
| 8 | Sem cartas modernas (EWMA, CUSUM) | Page (1954), Hawkins (1998) | Sprint posterior |
| 9 | `Depends: tidyverse, tidymodels, tibbletime` | CRAN, qualquer revisor | Migrar para `Imports` específicos |
| 10 | Sem testes (`tests/testthat/`) | Hadley, todo mundo | Cobertura ≥ 80% |

---

## 4. Arquitetura proposta

### 4.1 Núcleo: classe S3 `shewhart_chart`

Toda função construtora retorna objeto com estrutura:

```r
structure(
  list(
    data        = <tibble>,        # dados originais
    augmented   = <tibble>,        # dados + fitted/limits/flags
    fits        = <list>,          # ajustes por fase (se aplicável)
    limits      = <tibble>,        # CL, UCL, LCL, sigma, fórmula
    rules       = <tibble>,        # regras violadas: (rule, position, evidence)
    type        = <chr>,           # "i_mr", "xbar_r", "p", "regression", ...
    phase       = <chr>,           # "phase_1" ou "phase_2"
    call        = <call>,
    metadata    = <list>           # n, sigma_hat, ARL_0_estimated, ...
  ),
  class = c(paste0("shewhart_", type), "shewhart_chart")
)
```

Métodos genéricos: `print()`, `summary()`, `plot()`, `autoplot()`, `tidy()`, `glance()`, `augment()`.

Subclasses específicas (ex: `shewhart_i_mr`, `shewhart_regression`, `shewhart_p`) permitem despacho fino quando necessário.

### 4.2 Famílias de funções (organização do pacote)

```
R/
  shewhart-package.R       # documentação raiz
  zzz.R                    # .onLoad (sem mensagem)
  
  # Família 1 — Cartas clássicas (variáveis)
  chart-i-mr.R             # shewhart_i_mr()
  chart-xbar-r.R           # shewhart_xbar_r()
  chart-xbar-s.R           # shewhart_xbar_s()
  
  # Família 2 — Cartas clássicas (atributos)
  chart-p.R                # shewhart_p()
  chart-np.R               # shewhart_np()
  chart-c.R                # shewhart_c()
  chart-u.R                # shewhart_u()
  
  # Família 3 — Cartas baseadas em regressão (especialidade)
  chart-regression.R       # shewhart_regression() — substitui shewhart()
  models-growth.R          # Gompertz(), SSgompertzDummy(), logístico, von Bertalanffy
  transforms.R             # loglog(), iloglog(), box_cox()
  
  # Família 4 — Cartas modernas (sprint posterior)
  chart-ewma.R
  chart-cusum.R
  
  # Família 5 — Diagnóstico e desempenho
  runs-tests.R             # shewhart_runs() com regras de Nelson
  arl.R                    # shewhart_arl()
  diagnostics.R            # shewhart_diagnostics() painel Tukey
  capability.R             # shewhart_capability()
  
  # Família 6 — Phase I / II
  calibrate.R              # calibrate() / monitor()
  
  # Família 7 — Métodos S3 + broom
  print.R
  summary.R
  autoplot.R
  plotly.R
  broom.R                  # tidy / glance / augment
  
  # Família 8 — Internos
  utils-validation.R       # check_*() com cli
  utils-constants.R        # tabela A2, A3, B3-B6, c4, d2, d3, D3, D4
  utils-helpers.R          # rolling_sum(), color_hue()
```

---

## 5. API proposta

### 5.1 Cartas clássicas — variáveis

```r
# Individuais com Moving Range
shewhart_i_mr(data, value, .by = NULL, sigma_method = c("mr", "sd", "biweight"))

# Subgrupos racionais — média e amplitude
shewhart_xbar_r(data, value, subgroup, sigma_method = c("range", "pooled_sd"))

# Subgrupos racionais — média e desvio
shewhart_xbar_s(data, value, subgroup, sigma_method = c("pooled_sd", "biweight"))
```

### 5.2 Cartas clássicas — atributos

```r
# Proporção de defeituosos (n variável ou constante)
shewhart_p(data, defects, n, .by = NULL)

# Número de defeituosos (n constante)
shewhart_np(data, defects, n, .by = NULL)

# Número de defeitos por unidade (área de inspeção constante)
shewhart_c(data, defects, .by = NULL, limits = c("3sigma", "poisson"))

# Defeitos por unidade (área variável)
shewhart_u(data, defects, exposure, .by = NULL, limits = c("3sigma", "poisson"))
```

A opção `limits = "poisson"` usa quantis exatos da Poisson em vez de ±3σ, alinhando com o conselho de Box: "don't transform if you can model the right distribution."

### 5.3 Cartas baseadas em regressão (especialidade)

```r
shewhart_regression(
  data, value, index,
  model         = c("auto", "log", "loglog", "linear", "gompertz", "logistic"),
  formula       = NULL,                    # fórmula custom opcional
  start_base    = 10,
  phase_changes = NULL,
  rules         = c("nelson_2_seven"),      # ver §5.5
  sigma_method  = c("mr", "biweight"),
  lower_bound   = NULL,                     # NA = sem clipping; 0 para contagens
  .by           = NULL                       # group-aware
)
```

Quando `model = "auto"`, faz Box-Cox internamente para escolher entre `log`, `loglog`, `linear`. Quando `model = "gompertz"` ou `"logistic"`, ajusta curva de crescimento via `nls`.

### 5.4 Cartas modernas (sprint 4)

```r
shewhart_ewma(data, value, lambda = 0.2, L = 2.7)
shewhart_cusum(data, value, target, k = 0.5, h = 4)
```

### 5.5 Diagnóstico e desempenho

```r
# Aplica regras de Nelson e/ou Western Electric configuráveis
shewhart_runs(
  chart,
  rules = c(
    "nelson_1_beyond_3s",     # 1 ponto além de 3σ
    "nelson_2_nine_same",      # 9 pontos consecutivos do mesmo lado
    "nelson_3_six_trend",      # 6 pontos crescentes/decrescentes
    "nelson_4_alternating",    # 14 pontos alternando
    "nelson_5_two_of_three",   # 2 de 3 pontos além de 2σ
    "nelson_6_four_of_five",   # 4 de 5 pontos além de 1σ
    "nelson_7_stratification", # 15 pontos dentro de 1σ
    "nelson_8_mixture",        # 8 pontos fora de 1σ ambos lados
    "we_seven_same"            # versão antiga (compat com 0.1.1)
  )
)

# ARL via simulação Monte Carlo
shewhart_arl(
  chart_spec,
  shift   = seq(0, 3, by = 0.5),  # em unidades de sigma
  n_sim   = 10000,
  rules   = c("nelson_1_beyond_3s")
)
# → tibble com (shift, arl, sd_arl, ci_lower, ci_upper)

# Painel Tukey de diagnósticos
shewhart_diagnostics(chart)
# → objeto que printa painel: residuals~fitted, Q-Q, ACF, MR plot,
#   Ljung-Box, Shapiro-Wilk, lambda Box-Cox sugerido

# Box-Cox standalone
shewhart_box_cox(data, value, lambda_range = c(-2, 2))
```

### 5.6 Capacidade

```r
shewhart_capability(
  chart,
  lsl, usl, target = NULL,
  ci_level = 0.95,
  method   = c("normal", "non_parametric", "box_cox", "johnson")
)
# → glance() retorna Cp, Cpk, Pp, Ppk, com IC bootstrap
```

### 5.7 Phase I / Phase II

```r
# Fase I — calibração
calib <- calibrate(
  data, value,
  method = "i_mr",
  trim_outliers = TRUE,
  min_n = 25
)

# Fase II — monitoramento de novos dados contra limites calibrados
new_data |> 
  monitor(calib, alert = c("any_rule"))
```

### 5.8 Métodos S3 + broom

```r
fit <- shewhart_i_mr(production_data, weight)

print(fit)           # resumo conciso: tipo, n, n violações
summary(fit)         # tabela de limites + violações
autoplot(fit)        # ggplot2 padrão
autoplot(fit, type = "mr")  # apenas a carta MR

tidy(fit)            # tibble: term, estimate (CL, UCL, LCL, sigma_hat)
glance(fit)          # 1-row: n, n_violations, sigma_hat, ARL_0_est
augment(fit)         # data + .fitted + .lower + .upper + .flag + .rule
```

---

## 6. Modernização cli + tidyverse

### 6.1 Padrão de validação

Todas as funções usam o padrão `check_*()`:

```r
check_data <- function(data, arg = caller_arg(data), call = caller_env()) {
  if (!is.data.frame(data)) {
    cli::cli_abort(
      c("{.arg {arg}} deve ser um {.cls data.frame}.",
        "x" = "Recebido: {.obj_type_friendly {data}}."),
      call = call
    )
  }
}

check_column <- function(data, col, arg = caller_arg(col), call = caller_env()) {
  col_name <- rlang::as_name(rlang::enquo(col))
  if (!col_name %in% names(data)) {
    cli::cli_abort(
      c("Coluna {.var {col_name}} não encontrada em {.arg data}.",
        "i" = "Colunas disponíveis: {.var {head(names(data), 10)}}{cli::qty(length(names(data)))}{?  ou mais}."),
      call = call
    )
  }
}

check_subgroup_size <- function(n, min = 2, max = 25, ...) {
  if (n < min) cli::cli_abort("Tamanho de subgrupo {.val {n}} é menor que o mínimo {.val {min}}.", ...)
  if (n > max) cli::cli_warn("Tamanho de subgrupo {.val {n}} é maior que o usual ({.val {max}}). Considere {.fn shewhart_xbar_s}.")
}
```

### 6.2 Padrão de feedback (verbose opcional)

```r
shewhart_regression <- function(..., verbose = getOption("shewhart.verbose", interactive())) {
  if (verbose) cli::cli_alert_info("Detectando mudanças de fase pela regra de {.val 7} pontos.")
  # ...
  if (verbose) cli::cli_alert_success("{.val {n}} mudança{?s} detectada{?s} em {.val {round(elapsed, 2)}}s.")
}
```

### 6.3 Imports — substituir Depends

```yaml
# DESCRIPTION
Imports:
    rlang (>= 1.1.0),
    cli (>= 3.6.0),
    dplyr (>= 1.1.0),
    tidyr (>= 1.3.0),
    purrr (>= 1.0.0),
    tibble (>= 3.2.0),
    ggplot2 (>= 3.5.0),
    broom (>= 1.0.0),
    slider (>= 0.3.0),
    lubridate (>= 1.9.0),
    stats,
    utils
Suggests:
    plotly (>= 4.10.0),
    testthat (>= 3.2.0),
    vdiffr (>= 1.0.0),
    knitr,
    rmarkdown,
    pkgdown
```

`tidyverse`, `tidymodels`, `tibbletime`, `pals`, `scales` saem.  
`plotly` vai para `Suggests` (carregado lazily na função `as_plotly()`).

### 6.4 Outras mudanças de estilo

- Trocar `"NULL" != dummy_name` por `!rlang::quo_is_null(rlang::enquo(dummy_col))`.
- Trocar `dplyr::if_else` aninhados por `dplyr::case_when()` ou `switch()`.
- Padronizar nomes de saída em snake_case (`upper_limit` em vez de `UCL`/`UL_EXP`).
- Adicionar `.by` argumento group-aware onde fizer sentido.
- Erros sempre via `cli::cli_abort()`, nunca `stop()`.
- Mensagens condicionais via `cli::cli_alert_*()`, nunca `print()` ou `cat()`.

---

## 7. Datasets de exemplo

Ampliar o `inst/extdata/` com casos clássicos de SPC. Sugestões (todos sintéticos, gerados com seed fixa, documentados):

| Dataset | Tipo | Uso primário | Tamanho |
|---|---|---|---|
| `tablet_weight` | X-bar/R | Peso de comprimidos farmacêuticos, n=5/subgrupo | 25 subgrupos |
| `bottle_fill` | I-MR | Volume de enchimento individual | 100 obs |
| `pcb_solder` | c | Defeitos de solda em placas | 50 placas |
| `claims_p` | p | Proporção de chamados com erro, n variável | 30 dias |
| `temperature_drift` | regressão | Sensor com tendência térmica | 200 obs |
| `bacterial_growth` | regressão Gompertz | Curva de crescimento clássica | 80 obs |
| `cvd_recife` *(mantido)* | regressão | Aplicação real epidemiológica | 100+ obs |

Datasets ficam em `data/` (binário) e ganham documentação roxygen com `@docType data`. Os pequenos vão acessíveis direto via `Shewhart::tablet_weight`.

---

## 8. Plano pkgdown

### 8.1 Estrutura do site

```
Home (README otimizado, hex logo, badges CRAN/check/cov)
├─ Get Started (vinheta de 5 min com I-MR clássico)
├─ Articles
│  ├─ Cartas para variáveis: I-MR, X̄-R, X̄-S
│  ├─ Cartas para atributos: p, np, c, u (e o pulo do gato Poisson exato)
│  ├─ Cartas baseadas em regressão: o diferencial do pacote
│  ├─ Phase I vs Phase II: estimando e monitorando
│  ├─ Quão boa é uma regra? Estudo de ARL via simulação
│  ├─ Diagnóstico de modelo à la Tukey
│  ├─ Escolhendo a transformação: Box-Cox na prática
│  └─ Estudo de caso: monitoramento epidemiológico (COVID-19 em Recife)
├─ Reference
│  ├─ Cartas clássicas — variáveis
│  ├─ Cartas clássicas — atributos
│  ├─ Cartas baseadas em regressão
│  ├─ Diagnóstico e desempenho (ARL, runs, Box-Cox)
│  ├─ Capacidade
│  ├─ Phase I / II
│  ├─ Métodos S3 e broom
│  └─ Datasets
└─ News (CHANGELOG.md)
```

### 8.2 `_pkgdown.yml` reescrito

Ponto de partida limpo, sem o YAML truncado atual:

```yaml
url: https://castlaboratory.github.io/shewhartr/
template:
  package: tidytemplate
  bootstrap: 5
  light-switch: true
  bslib:
    primary: "#0054AD"
    
navbar:
  structure:
    left:  [intro, reference, articles, news]
    right: [search, github]

reference:
  - title: "Cartas clássicas — variáveis"
    contents: [shewhart_i_mr, shewhart_xbar_r, shewhart_xbar_s]
  - title: "Cartas clássicas — atributos"
    contents: [shewhart_p, shewhart_np, shewhart_c, shewhart_u]
  - title: "Cartas baseadas em regressão"
    contents: [shewhart_regression, Gompertz, SSgompertzDummy, loglog, iloglog]
  - title: "Diagnóstico e desempenho"
    contents: [shewhart_runs, shewhart_arl, shewhart_diagnostics, shewhart_box_cox]
  - title: "Capacidade de processo"
    contents: [shewhart_capability]
  - title: "Phase I / Phase II"
    contents: [calibrate, monitor]
  - title: "Métodos S3 e broom"
    contents: 
      - starts_with("autoplot")
      - starts_with("tidy")
      - starts_with("glance")
      - starts_with("augment")
  - title: "Datasets"
    contents: 
      - has_keyword("datasets")

articles:
  - title: "Começando"
    contents: [getting-started]
  - title: "Cartas"
    contents: [variables-charts, attributes-charts, regression-charts]
  - title: "Estatística e desempenho"
    contents: [phase1-phase2, arl-simulation, diagnostics, box-cox]
  - title: "Estudos de caso"
    contents: [covid-recife]
```

### 8.3 GitHub Actions

Três workflows:
- `R-CMD-check.yaml` — matriz Linux/macOS/Windows × release/devel/oldrel
- `pkgdown.yaml` — build e deploy para `gh-pages`
- `test-coverage.yaml` — codecov

---

## 9. Roadmap por sprint

| Sprint | Duração | Entrega | Quebra API? |
|---|---|---|---|
| **1 — Higiene** | 1-2 dias | `Imports`/`Suggests` arrumados, `cli` em validações, esqueleto `tests/testthat/`, remover `.onAttach` | Não |
| **2 — Refatoração arquitetural** | 3-4 dias | Classe S3 `shewhart_chart`, métodos `print/summary/autoplot`, `regression_chart()` substitui `shewhart()` (com deprecation aviso) | **Sim** |
| **3 — Cartas clássicas variáveis** | 2-3 dias | `shewhart_i_mr()`, `shewhart_xbar_r()`, `shewhart_xbar_s()`, tabela de constantes interna, testes contra Montgomery | Não |
| **4 — Cartas clássicas atributos** | 2 dias | `shewhart_p()`, `shewhart_np()`, `shewhart_c()`, `shewhart_u()`, opção `limits = "poisson"` | Não |
| **5 — Diagnóstico** | 3-4 dias | `shewhart_runs()` com 8 regras de Nelson, `shewhart_arl()` por simulação, `shewhart_diagnostics()`, `shewhart_box_cox()` | Não |
| **6 — Phase I/II + capacidade** | 2-3 dias | `calibrate()`, `monitor()`, `shewhart_capability()` com IC bootstrap | Não |
| **7 — broom + datasets** | 2 dias | `tidy/glance/augment`, datasets sintéticos documentados | Não |
| **8 — Site e docs** | 2-3 dias | Vinhetas, GitHub Actions, deploy gh-pages, README reescrito | Não |
| **9 — Cartas modernas (opcional v1.1)** | 3-4 dias | EWMA, CUSUM tabular, Hotelling T² | Não |

**Total v1.0.0: ~17-21 dias de trabalho focado.**

---

## 10. Decisões pendentes (precisam de input do André)

1. **Quebra de API.** A função `shewhart()` atual será mantida com `lifecycle::deprecate_warn()` por uma versão (0.2.x) ou removida direto na v1.0.0?
2. **Default da regra de detecção em `shewhart_regression()`.** Mantém Western Electric "7 pontos" (compat) ou troca para Nelson 1+2 (1 ponto fora 3σ + 9 pontos mesmo lado, mais robusto)?
3. **Locale.** Mantém PT/EN hardcoded ou migra para sistema baseado em `LANGUAGE` do usuário (mais flexível, menos código)?
4. **Plotly.** Mantém como cidadão de primeira classe (parâmetro `type = "plotly"`) ou move para método separado `as_plotly(chart)` em `Suggests`? Recomendação: o segundo, reduz dependências pesadas.
5. **Nome do construtor da carta de regressão.** `shewhart_regression()`, `regression_chart()`, ou simplesmente manter `shewhart()` com `type = "regression"` como default?
6. **Cartas modernas (EWMA, CUSUM)** — ✓ resolvido. Entraram na v1.0.0
   (sprint 9): `shewhart_ewma()` (Roberts 1959, com limites time-varying
   e steady-state) e `shewhart_cusum()` (Page 1954, two-sided tabular).
   Vinheta `memory-based-charts.Rmd` cobre escolha de parâmetros e ARL.
7. **Testes contra referência.** Vale comparar saídas de `shewhart_xbar_r()` contra exemplos do Montgomery (livro) ou contra `qcc::qcc()` para validação numérica?

---

## 11. Pós-v1.0.0 (priorizado)

Itens que ficaram fora da v1.0.0 deliberadamente, em ordem de prioridade
declarada:

1. **Hotelling T² multivariado** (`shewhart_hotelling()`). ✓ resolvido na
   v1.1.0. Individual + subgrupado, Phase I (Beta exata) e Phase II (F
   preditiva), tidyselect API, decomposição de contribuição por variável
   (Mason et al. 1995), `monitor_hotelling()`, vinheta
   `multivariate-charts`. Versão T²-PCA para `p` grande fica para v1.3.

2. **Phase II para EWMA/CUSUM via `calibrate()`/`monitor()`.** ✓ resolvido
   na v1.1.0. `monitor_ewma()` continua a recursão a partir do estado
   final da calibração com limites steady-state; `monitor_cusum()`
   continua ambos os acumuladores; `calibrate()` aceita `chart =
   "ewma" | "cusum" | "hotelling"`.

3. **Validação numérica vs `qcc`.** ✓ resolvido na v1.2.0. Adicionado
   `tests/testthat/test-vs-qcc.R` (skip silencioso quando `qcc` ausente)
   comparando limites contra os datasets canônicos do `qcc`
   (`pistonrings`, `orangejuice`, `circuit`); todos os center / UCL /
   LCL coincidem com `qcc` em tolerância 1e-3.

4. **Suporte plotly via `as_plotly()`.** ✓ resolvido na v1.2.0. Genérico
   + método para `shewhart_chart` que produz `plotly::ggplotly` para
   single-panel e `plotly::subplot` (com x-axis compartilhado) para
   two-panel charts.

5. **Bug numérico em `SSgompertzDummy` self-starter.** ✓ resolvido na
   v1.1.0. Starting values agora derivados dos dados (`Asym`, `b2`,
   `b3`, `Beta` calculados a partir do dummy-zero subset com fórmulas
   da inversa Gompertz e regressão `log(-log(y/Asym))` para a taxa).
   Convergiu cleanly em y-escala 10, 100, 10000 e em vários ranges de
   taxa. Exemplo voltou de `\dontrun{}` para `\donttest{}`.

---

## 12. Bugs descobertos e corrigidos pós-v1.2.0

Sessão de revisão de qualidade de saída revelou três bugs sobrepostos
no autoplot da carta de regressão:

1. **`get_index_col()` ignorava colunas começando com `.`.** `cvd_recife`
   tem `.t` como índice; o helper caía no fallback e selecionava
   `new_deaths` (a resposta) como eixo X. Corrigido para usar
   `metadata$index_name` quando disponível e excluir apenas uma
   allow-list explícita de colunas internas.

2. **`detect_phases()` era greedy demais.** O loop só exigia
   `nrow(last_phase) > 9` e aceitava o primeiro hit da regra. Com
   `we_seven_same`, fases recém-criadas eram cortadas no 7º ponto.
   Corrigido para exigir `2 × n_consec` pontos e ignorar hits dentro
   da janela de warm-up. `cvd_recife` resolve em 9 fases agora,
   alinhado com Ferraz et al. (2020) §3.

3. **`autoplot.shewhart_regression` ficava ilegível com 9+ fases.**
   Reescrito para: ribbon pálido por fase, CL e limites contidos no
   segmento, paleta sequencial ordenada no tempo
   (`shewhart_phase_palette()`), pontos coloridos pela fase. Visualmente
   próximo da Figura 4 do paper SBPO 2020.

Plus: 4 vinhetas estavam com `eval = FALSE` global (covid-recife,
memory-based-charts, multivariate-charts) ou em chunks individuais
(regression-charts), de modo que **nenhum gráfico renderizava no site**
para essas seções. Corrigido; `arl-simulation` mantém `eval = FALSE`
porque o Monte Carlo é caro demais para vignette build.

---

## 13. Próximos passos (v1.3.0+, sem prioridade fixa)

### Multivariate

* **MEWMA** (multivariate EWMA, Lowry et al. 1992) — extensão natural
  do Hotelling para detecção de pequenos shifts conjuntos.
  ARL_0 ≈ 200, recurso: `Z_i = λ X_i + (1-λ) Z_{i-1}`,
  `T²_i = (Z_i - μ)' Σ_Z⁻¹ (Z_i - μ)`.
* **MCUSUM** (Crosier 1988, Pignatiello & Runger 1990) — análogo
  multivariado da CUSUM. Bom complemento ao MEWMA.
* **T² baseado em PCA** quando `p` é grande (Jackson 1991, ch. 1).

### Diagnostics e modelagem

* **Autocorrelation handling** na regression chart. Mencionado na
  vinheta `regression-charts` mas não implementado: ajuste com
  estrutura ARMA nos resíduos (Box-Jenkins) e limites estendidos.
* **Capacity multivariate** (Cp/Cpk multivariado, Wang 2005).

### Polimentos

* **MYT decomposition** sequencial em `shewhart_hotelling` para
  diagnóstico mais rico (atualmente só decomposição marginal).
* **Examples + case studies** adicionais: tablet weight, claims_p
  como vinhetas de aplicação ao invés de só datasets.
