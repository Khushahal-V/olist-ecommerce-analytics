# E-Commerce Growth & Retention Analytics — Olist Brazil

An end-to-end analytics project on the Olist Brazilian E-Commerce dataset. I wanted to go beyond just building a dashboard — the goal was to actually dig into a real-looking marketplace dataset and answer the kind of questions a growth/product team would care about, using SQL for the data layer, Power BI for the dashboard, and Python for statistical testing.

## What I was trying to answer

- How's revenue trending, and what's driving it — which categories, which regions?
- How loyal are customers, actually? What's a repeat buyer worth compared to a one-time buyer?
- Does delivery speed have a real, measurable effect on satisfaction, or is that just assumed?
- How do customer cohorts retain over time?

## Tools used
- **PostgreSQL** — schema, queries, views
- **Power BI** — 3-page dashboard
- **Python** (pandas, scipy, statsmodels) — hypothesis testing on delivery speed vs. satisfaction

## How I approached it

### SQL first
Loaded the 8 raw Olist tables (~99K orders, ~103K payments, ~99K reviews, ~33K products) into Postgres and wrote queries to answer the business questions above — monthly revenue, MoM growth using window functions, top categories, repeat purchase rate, delivery-vs-review correlation, and cohort retention using CTEs. Also built 3 views (`vw_customer_rfm`, `vw_delivery_review`, `vw_cohort_retention`) so the logic lives in the database once instead of getting rewritten inside Power BI.

### Then the dashboard
**Executive Summary** — revenue/orders/customers/AOV at a glance, monthly revenue trend, top 10 categories, top 10 states by order volume.

**Customer Analytics** — customers segmented by purchase frequency, average spend per segment, and delivery speed vs. review score.

**Cohort Retention** — a heatmap showing how each month's cohort of new customers fades out over time.

### And finally, the stats
The dashboard shows delivery speed correlates with review score, but I wanted to know if that difference was actually meaningful or just noise. Ran a one-way ANOVA across the three delivery-speed buckets (fast/medium/slow), followed by pairwise t-tests and Cohen's d to check effect size — since with ~96K orders, almost anything comes back "statistically significant," so effect size is what actually tells you if it matters. Also did a quick power analysis to figure out how much traffic you'd actually need to detect different effect sizes in a real randomized test.

## What I found

**Revenue grew steadily through 2017** — from under R$50K/month near launch to a peak above R$1.15M/month by November 2017, then flattened out through 2018.

**Repeat purchase rate is only 3%.** Out of roughly 93K customers, fewer than 2,800 placed a second order. That's low even for a marketplace, and points to the seller/category mix not doing much to bring people back.

**Loyal customers (4+ orders) spend about 5x more on average** (~R$780) than one-time buyers (~R$160). It's a tiny segment, but clearly worth more attention than it's getting.

**Delivery speed genuinely affects satisfaction, but not evenly.** Average review scores go 4.41 → 4.29 → 3.65 [total drop = 0.76] across fast/medium/slow delivery. All the pairwise differences are statistically significant (p < 0.001), but the effect sizes tell the real story — fast vs. medium delivery barely matters (Cohen's d = 0.11, negligible), while fast vs. slow is a real, medium-to-large gap (d = 0.59). So the actual lever here is fixing the slowest deliveries, not shaving a day or two off ones that are already reasonable.

**São Paulo alone accounts for way more orders than any other state** — Rio de Janeiro and Minas Gerais are a distant second and third. Good for now, but a lot of concentration risk if anything goes wrong there.

**On sample size** — for future experiments, Olist's order volume can easily detect even a small effect (d = 0.2) with only ~400 customers per group, so most product experiments here would be feasible within a week of traffic, not months.

## What I'd recommend

- Dig into why repeat rate is so low — break it down by category/seller, since it's probably not uniform, and double down wherever repeat demand does exist.
- Focus delivery improvements on the slow tail specifically, not average delivery time — that's where the satisfaction hit actually comes from.
- Build a retention push aimed at the "occasional" segment (2-3 orders) to nudge them toward loyal status, given how much more they'd be worth.
- Reduce the geographic concentration risk by pushing demand outside São Paulo/the Southeast.

## Repo structure
```
/sql          schema, queries, views
/dashboard    page screenshots
/notebook     A/B testing analysis (Jupyter)
README.md     this file
```
## Power BI Link : https://drive.google.com/file/d/11YJFMKPAly7mneSS00NRFHGfznL6vRMk/view?usp=sharing
## Dataset Link : https://drive.google.com/drive/folders/1IoUsCSFr6yplzj2xRz_bvHHRBVqWX3SQ?usp=sharing
## Limitations
The A/B test here is observational, not a randomized experiment — delivery speed wasn't randomly assigned, so there could be confounders (location, order value, category) I haven't controlled for. Worth keeping in mind before treating "slow delivery causes low reviews" as more than a strong association.
