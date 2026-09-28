# NoTSUG 2026: SAS with AI

A self-contained demonstration of a predictive AI workflow in SAS. The program
creates synthetic customer data, trains a churn model with `PROC LOGISTIC`,
scores a held-out test set, and summarizes its predictions. No customer data,
external services, or API credentials are required.

## Run the demo

1. Open [`sas/customer_churn_ai_demo.sas`](sas/customer_churn_ai_demo.sas) in
   SAS 9.4 with SAS/STAT or in SAS Viya.
2. Submit the program.
3. Review the model results, test-set confusion table, and mean predicted churn
   probability by actual outcome in the SAS results.

The program writes its generated data and results to the `WORK` library, so
they are temporary and are removed when the SAS session ends. It uses a fixed
random seed so the synthetic example is reproducible. Adjust
`decision_threshold` in the program to see how the classification tradeoff
changes.

This is a compact example of predictive machine learning in SAS, not a
generative-AI integration. It demonstrates a complete model workflow without
requiring a licensed external AI service or exposing data to one.
