%let decision_threshold = 0.5;

data work.customers;
    call streaminit(2026);
    do customer_id = 1 to 1000;
        tenure_months = floor(rand('uniform') * 60) + 1;
        support_calls = rand('poisson', 1.5);
        monthly_charge = round(40 + rand('uniform') * 100, 0.01);

        if rand('uniform') < 0.5 then contract_type = 'Month-to-month';
        else contract_type = 'Annual';

        linear_predictor = -2.5
            - 0.035 * tenure_months
            + 0.50 * support_calls
            + 0.018 * (monthly_charge - 70)
            + 1.0 * (contract_type = 'Month-to-month');
        churn_probability = 1 / (1 + exp(-linear_predictor));
        churn = rand('bernoulli', churn_probability);

        if rand('uniform') < 0.7 then partition = 'TRAIN';
        else partition = 'TEST';
        output;
    end;
run;

ods graphics on;
proc logistic data=work.customers(where=(partition='TRAIN')) plots(only)=roc;
    class contract_type(ref='Annual') / param=ref;
    model churn(event='1') =
        tenure_months support_calls monthly_charge contract_type;
    score data=work.customers(where=(partition='TEST'))
        out=work.test_scores;
run;
ods graphics off;

data work.test_predictions;
    set work.test_scores;
    predicted_churn = (P_1 >= &decision_threshold);
run;

title 'Held-out Test Set: Actual vs. Predicted Churn';
proc freq data=work.test_predictions;
    tables churn * predicted_churn / norow nocol nopercent;
run;

title 'Mean Predicted Churn Probability by Actual Outcome';
proc means data=work.test_predictions mean;
    class churn;
    var P_1;
run;
title;
