# Advanced Statistical Modeling on E-Commerce Dynamics: GEE & GLMM Analysis on Brazilian E-Commerce Records

![PostgreSQL](https://img.shields.io/badge/Database-PostgreSQL_14+-336791?logo=postgresql&logoColor=white)
![R](https://img.shields.io/badge/Language-R_4.x-276DC3?logo=r&logoColor=white)
![Methods](https://img.shields.io/badge/Methodology-GEE_%7C_GLMM_%7C_VPC-blueviolet)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

An enterprise-grade econometric and biostatistical modeling pipeline analyzing ~100k customer orders from the **Olist Brazilian E-Commerce Dataset**. This project integrates an enterprise relational database (PostgreSQL) with advanced longitudinal and hierarchical regression methods (Generalized Estimating Equations and Generalized Linear Mixed Models) to address core behavioral questions surrounding customer retention, logistics friction, and merchant service heterogeneity.

---

## Scientific Questions

The analytical core of this research investigates two complementary business perspectives using GEE and GLMM frameworks:

### Perspective 1: Customer Repurchase Behavior
* **SQ 1.1:** Controlling for order price, freight ratio, cross-state status, and review scores, what is the marginal odds ratio of delivery delay on the overall customer population's repurchase rate? Which working correlation structure (Independence, Exchangeable, AR-1) best describes the temporal dependence of customers?
* **SQ 1.2:** How large is the unobserved heterogeneity among customers ($\sigma^2_u$)? Do the subject-specific parameters ($\beta^{\ast}$) under the conditional model and the GEE marginal parameters ($\beta$) satisfy the theoretical shrinkage formula $\beta \approx \beta^{\ast} / \sqrt{1 + c^2 \sigma^2_u}$?
* **SQ 1.3:** Is the negative impact of freight ratio on repurchases "heterogeneous across individuals"?

### Perspective 2: Seller Complaint Counts & Review of Order
* **SQ 2.1:** Controlling for delay delivery, cross-state ratio, and freight ratio, and using total order volume as the exposure $\text{(Offset: } \log(\text{Total Orders})\text{)}$, can the random intercept of seller state (seller_state) fully absorb overdispersion? Is a Poisson GLMM sufficient, or is a Negative Binomial GLMM (NB GLMM) with a dispersion parameter ($\theta$) required?
* **SQ 2.2:** For binary complaint events at the order level ($Y_{ijk} \in \lbrace 0, 1 \rbrace$), what proportion of extreme negative review occurrences comes from "seller-level individual heterogeneity" versus "seller state-level clusters"?

---

## End-to-End Project Workflow

<pre><code>[Kaggle CSV Data (9 Files)]
            │
            ▼
┌──────────────────────────────────────┐
│  Phase 1: PostgreSQL DDL & Indexing  │  ──► Schema definition, PK/FK, B-tree indexes
└──────────────────────────────────────┘
            │
            ▼
┌──────────────────────────────────────┐
│  Phase 2: Analytical View Modeling   │  ──► analytical_orders_master (CTEs & KPIs)
└──────────────────────────────────────┘
            │
            ▼
┌──────────────────────────────────────┐
│  Phase 3: R Pipeline & Serialization │  ──► Database pull via DBI/RPostgres, Parquet/RDS
└──────────────────────────────────────┘
            │
      ┌─────┴────────────────────────┐
      ▼                              ▼
┌──────────────────────────┐   ┌─────────────────────────────────┐
│ Perspective 1: Customers │   │ Perspective 2: Sellers          │
│ - Longitudinal panel     │   │ - Count-data offset aggregation │
│ - GEE (geepack, QIC)     │   │ - Poisson vs. NB GLMM           │
│ - Conditional GLMM (lme4)│   │ - Multilevel VPC (3-tier)       │
└──────────────────────────┘   └─────────────────────────────────┘</code></pre>

### Step 1: Relational Schema Architecture & Data Ingestion (`01_schema_and_indexes.sql`)
- Implemented an 8-table relational schema matching Olist's entity boundaries (`raw_customers`, `raw_orders`, `raw_order_items`, `raw_order_payments`, `raw_order_reviews`, `raw_products`, `raw_sellers`, `raw_category_translation`).
- Enforced strict data integrity via primary and composite keys (e.g., `(order_id, order_item_id)`).
- Established targeted B-tree indices on foreign keys and temporal fields (`customer_id`, `seller_id`, `order_purchase_timestamp`, `order_id`) to optimize multi-table query performance.

### Step 2: Analytical Master View & Metric Engineering (`02_analytical_orders_master.sql`)
- Built the canonical analytical view `analytical_orders_master` using Common Table Expressions (CTEs):
  - **Item-level aggregation:** Total item counts, unique seller count per order, primary category identification via English lookup, order GMV, and total freight value.
  - **Review & Payment aggregation:** Minimum and mean review scores, complaint indicators ($\text{Review Score} \le 2$), and maximum installments.
  - **Domain feature derivation:** Exact delivery duration and delay days extracted via epoch differentials ($(\text{actual} - \text{estimated}) / 86400$), freight cost ratios, and binary interstate transaction flags.
- Filtered observations strictly to successfully delivered orders with complete timestamps ($N = 96,470$).

### Step 3: R Session Ingestion, Preprocessing & Panel Construction
- Interfaced R directly with PostgreSQL via `DBI` and `RPostgres` drivers.
- Constructed three specialized analytical datasets:
  1. `df_repeat_panel` ($N = 5,869$ orders across $2,792$ repeat customer clusters): Formatted as longitudinal panels tracking order sequences ($t = 1, 2, \dots$), days elapsed between purchases, and subsequent repurchase binary flags ($Y_{it}$).
  2. `df_seller_complaints` ($N = 1,742$ active merchants): Aggregated complaint frequency, mean delivery delays, interstate ratios, and exposure offsets $\text{(}\log(\text{Total Orders})\text{)}$.
  3. `df_order_complaints` ($N = 95,195$ single-seller transactions): High-dimensional order records with nested seller and geographical identifiers.
- Serialized cleaned analytical tables into dual high-performance formats (`.parquet` and `.rds`).
- Applied z-score standardization ($\mu = 0, \sigma = 1$) to continuous predictors to guarantee convergence across Laplace approximation algorithms.

### Step 4: Marginal Effect Estimation via GEE (SQ 1.1)
- Fitted Generalized Estimating Equations across three distinct working correlation structures: Independence, Exchangeable, and Autoregressive (AR-1).
- Computed Quasi-Likelihood under the Independence Model Criterion (QIC / QICu) using `MESS::QIC` to select the empirical correlation structure.
- Derived population-averaged Marginal Odds Ratios (OR) with Huber-White sandwich robust standard errors.

### Step 5: Unobserved Heterogeneity & Conditional-Marginal Bridge (SQ 1.2)
- Formulated a subject-specific Logit-link GLMM with customer random intercepts $\text{(}b_i \sim \mathcal{N}(0, \sigma_u^2)\text{)}$ using the BOBYQA numerical optimizer.
- Evaluated customer-level unobserved variance component ($\sigma_u^2$) and calculated the Variance Partition Coefficient (VPC).
- Empirically tested parameter convergence against the theoretical attenuation/shrinkage equation linking subject-specific coefficients ($\beta^{\ast}$) to population-averaged coefficients ($\beta$).

### Step 6: Individual Freight Sensitivity & Random Slope Testing (SQ 1.3)
- Expanded the mixed model to include random slopes for freight ratio $\text{(}b_{0i} + b_{1i}\,\text{FreightRatio}_{it}\text{)}$ via formula `(1 + freight_ratio_z | customer_unique_id)`.
- Conducted a formal Likelihood Ratio Test (LRT / $\chi^2$ nested ANOVA) against the random-intercept baseline to test whether price sensitivity varies across individual shoppers.

### Step 7: Overdispersion Diagnostics & Negative Binomial GLMM (SQ 2.1)
- Fitted a baseline Poisson GLMM with state random intercepts and log-order exposure offsets.
- Diagnosed overdispersion using simulated residual testing (`performance::check_overdispersion`).
- Refitted under a quadratic Negative Binomial GLMM parameterization (`glmmTMB`, `nbinom2`) to estimate the scalar dispersion parameter ($\theta$ / $\alpha$), observing model selection via AIC minimization and computing Incidence Rate Ratios (IRR).

### Step 8: Multilevel Variance Decomposition (VPC) for Order Complaints (SQ 2.2)
- Implemented a 3-level hierarchically nested Binomial GLMM incorporating both seller random intercepts $\text{(}v_{jk} \sim \mathcal{N}(0, \sigma_{\text{seller}}^2)\text{)}$ and state clusters $\text{(}u_k \sim \mathcal{N}(0, \sigma_{\text{state}}^2)\text{)}$.
- Executed Variance Partition Coefficient (VPC) decomposition on the logistic latent variable scale ($\sigma_{\text{resid}}^2 = \pi^2/3 \approx 3.2899$) to quantify the relative attribution of negative customer reviews.

---

## Mathematical & Statistical Foundations

### 1. Generalized Estimating Equations (GEE)
Models the population-averaged (marginal) expectation $E[Y_{it} \mid X_{it}] = \mu_{it}$ using a logit link function:

$$\text{logit}(\mu_{it}) = \log\left(\frac{\mu_{it}}{1 - \mu_{it}}\right) = X_{it}^\top \beta$$

Variance is structured as $V_i = \phi A_i^{1/2} R_i(\alpha) A_i^{1/2}$, where $R_i(\alpha)$ is the working correlation matrix (Independence, Exchangeable, or AR-1). Parameter estimates are obtained through Generalized Estimating Equations:

$$\sum_{i=1}^K D_i^\top V_i^{-1} (Y_i - \mu_i) = 0$$

Standard errors are evaluated using the Huber-White sandwich estimator $\text{Cov}(\beta) = B^{-1} M B^{-1}$, where the bread matrix $B$ and meat matrix $M$ are defined as:

$$B = \sum_{i=1}^K D_i^\top V_i^{-1} D_i, \qquad M = \sum_{i=1}^K D_i^\top V_i^{-1} \text{Cov}(Y_i) V_i^{-1} D_i$$

Model selection is determined via QIC:

$$\text{QIC} = -2 Q(\beta(R); I) + 2 \text{trace}(\Omega_I^{-1} V_R)$$

### 2. Generalized Linear Mixed Models (GLMM)
Models conditional subject-specific trajectories given customer/seller random effects $u_i \sim \mathcal{N}(0, G)$:

$$\eta_{ij} = g(\mu_{ij}) = X_{ij}^\top \beta^{\ast} + Z_{ij}^\top u_i$$

Parameters are estimated by maximizing marginal log-likelihood integrated over random effect distributions via Laplace approximation:

$$L(\beta^{\ast}, \theta) = \prod_i \int \prod_j f(y_{ij} \mid u_i; \beta^{\ast}) \cdot \phi(u_i \mid G) \, du_i$$

### 3. Theoretical Parameter Shrinkage (Marginal vs. Conditional)
For logistic mixed models, conditional parameters ($\beta^{\ast}$) are systematically larger in absolute magnitude than marginal parameters ($\beta$) due to unobserved heterogeneity. The relationship is governed by the theoretical attenuation factor:

$$\beta \approx \frac{\beta^{\ast}}{\sqrt{1 + c^2 \sigma_u^2}}, \quad \text{where } c = \frac{16\sqrt{3}}{15\pi} \approx 0.588 \implies c^2 \approx 0.346$$

### 4. Count Data Modeling & Overdispersion Correction
When count data violates the Poisson equi-dispersion property $\text{(}E[Y] = \text{Var}(Y)\text{)}$, excess variance is parameterized via the Negative Binomial distribution ($\text{NB2}$):

$$\log(\lambda_i) = \log(T_i) + X_i^\top \beta + u_{\text{state}(i)}$$

$$\text{Var}(Y_i \mid \mu_i) = \mu_i + \alpha \mu_i^2 = \mu_i + \frac{\mu_i^2}{\theta}$$

where $\log(T_i)$ serves as the fixed exposure offset (log total orders), and $\alpha$ is the dispersion parameter.

### 5. Multilevel Variance Partition Coefficient (VPC)
In a latent-variable threshold formulation of binary logistic regression $\text{(}Y^{\ast} = \eta + \epsilon, \; \epsilon \sim \text{Logistic}(0, \pi^2/3)\text{)}$, total latent variance decomposes additively:

$$\text{Var}_{\text{latent}} = \sigma_{\text{seller}}^2 + \sigma_{\text{state}}^2 + \frac{\pi^2}{3}$$

$$\text{VPC}_{\text{seller}} = \frac{\sigma_{\text{seller}}^2}{\sigma_{\text{seller}}^2 + \sigma_{\text{state}}^2 + \pi^2/3}$$

---

## Technical Stack & Tooling

| Domain | Tools / Technologies | Key Libraries & Functions | Purpose |
|---|---|---|---|
| **Database Architecture** | PostgreSQL 14+, pgAdmin | DDL, CTEs, B-Tree Indexes, Epoch Differentials | Relational modeling, high-speed joins, automated KPI views |
| **Data Engineering** | R, Apache Arrow | `DBI`, `RPostgres`, `arrow`, `readr`, `dplyr`, `tidyr` | Database streaming, parquet serialization, longitudinal lag/window transforms |
| **Statistical Computing** | R Statistical Core (4.x) | `geepack`, `MESS`, `lme4`, `glmmTMB` | GEE estimation, Laplace mixed modeling, Negative Binomial regression |
| **Model Diagnostics** | R Diagnostics Toolkit | `performance`, `broom`, `MuMIn` | Overdispersion ratio tests, singular fit detection, QIC/AIC/BIC comparison |
| **Environment** | JupyterLab, R Kernel | Markdown, KaTeX, Python-R interoperability | Reproducible research notebooks and documentation |

---

## Key Empirical Findings

1. **Marginal Impact of Delivery Friction (SQ 1.1):** 
   - Independence working correlation yielded the lowest QIC ($8118.21$).
   - Delivery delay is a statistically significant deterrent to repurchase: holding other covariates constant, a 1-standard-deviation increase in delivery delay reduces the population repurchase odds by **7.36%** ($\text{OR} = 0.9264, p = 0.012$).
2. **Customer Heterogeneity & Shrinkage Collapse (SQ 1.2 & SQ 1.3):**
   - The estimated customer-level random intercept variance was singular ($\sigma_u^2 = 0.000, \text{VPC} = 0.00\%$).
   - Because $\sigma_u^2 = 0$, the theoretical attenuation denominator $\sqrt{1 + 0.346 \times 0} = 1$, meaning conditional parameters collapsed exactly to marginal parameters ($\beta \equiv \beta^{\ast}$).
   - Likelihood Ratio Test for individual freight sensitivity ($\text{LRT } \chi^2 = 0, df = 2, p = 1.00$) confirmed that freight sensitivity does not vary significantly across repeat buyers.
3. **Overdispersion in Complaint Counts (SQ 2.1):**
   - Baseline Poisson GLMM exhibited severe overdispersion (Dispersion Ratio $= 2.854, p < 0.001$), underestimating standard errors.
   - Transitioning to a Negative Binomial GLMM improved model fit drastically ($\Delta\text{AIC} = -639.59$; AIC dropped from $7550.39$ to $6910.80$). 
   - A 1-SD increase in average shipping delay escalates the merchant complaint rate by **22.79%** ($\text{IRR} = 1.2279, p < 0.001$).
4. **Complaint Risk Attribution (SQ 2.2):**
   - In multilevel modeling, state-level variance accounted for **0.00%** ($\sigma_{\text{state}}^2 = 0.000$), while individual merchant heterogeneity explained **7.18%** ($\sigma_{\text{seller}}^2 = 0.2546$) of latent complaint risk.
   - Severe negative reviews stem overwhelmingly from individual seller operational quality rather than regional logistics infrastructure.

---

## Repository Structure

<pre><code>├── sql/
│   ├── 01_schema_and_indexes.sql       # DDL schema definition, table creation, indexes
│   └── 02_analytical_orders_master.sql # Multi-table aggregation view with engineered features
├── notebooks/
│   └── olist-ecommerce-gee-glmm.ipynb  # Primary reproducible Jupyter analysis notebook (R Kernel)
├── data/                               # Cached analytical partitions (Parquet & RDS)
│   ├── df_repeat_panel.parquet
│   ├── df_seller_complaints.parquet
│   └── df_order_complaints.parquet
├── README.md
└── LICENSE</code></pre>

---

## Replication Guide

### 1. Database Initialization
Execute the SQL scripts sequentially inside your PostgreSQL environment:

<pre><code>psql -U postgres -d postgres -f sql/01_schema_and_indexes.sql
psql -U postgres -d postgres -f sql/02_analytical_orders_master.sql</code></pre>

### 2. R Environment Setup
Launch R or JupyterLab and install the required dependencies:

<pre><code>install.packages(c(
  "DBI", "RPostgres", "dplyr", "tidyr", "lubridate", 
  "readr", "arrow", "geepack", "MESS", "lme4", 
  "glmmTMB", "performance", "broom", "ggplot2"
))</code></pre>

### 3. Notebook Execution
Open `notebooks/olist-ecommerce-gee-glmm.ipynb`, update your database credentials in Cell `[2]`, and execute all cells sequentially.
