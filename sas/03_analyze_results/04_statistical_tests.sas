/******************************************************************************
 Program : 04_statistical_tests.sas
 Purpose : Adds statistical analyses to the Claude engine comparison:
             1. Cochran's Q test for paired differences in binary accuracy.
             2. Brier score for self-reported reliability/confidence.
             3. Reliability bins comparing stated confidence with observed accuracy.
             4. Ordinal agreement / weighted kappa output for bucket predictions.

 Requires : proj.claude_results has been produced by
            02_call_claude/03_parse_requests.sas.
 Output   : proj.brier_scorecard, proj.reliability_bins,
            proj.cochran_q_result, printed statistical reports.

 Interpretation notes:
   - Cochran's Q uses only respondents with valid results from all engines.
   - Brier score is lower when confidence is better calibrated.
   - PROC FREQ AGREE reports agreement statistics, including kappa measures.
 ******************************************************************************/

%assert_lib_exists(proj);

/* ---- 1. Prepare a common scored data set ------------------------------- */
data work.stat_scored;
  set proj.claude_results;
  length engine_key $12;

  select (engine_id);
    when ('claude-haiku-4-5-20251001') engine_key='HAIKU';
    when ('claude-sonnet-5')           engine_key='SONNET';
    when ('claude-opus-5-5')           engine_key='OPUS';
    otherwise                          engine_key='OTHER';
  end;

  /* Only valid bucket decisions can be scored as correct/incorrect. */
  valid_decision = upcase(decision) in
                   ('NEVER','RARELY','SOMETIMES','OFTEN','ALWAYS');
  valid_truth = upcase(true_bucket) in
                ('NEVER','RARELY','SOMETIMES','OFTEN','ALWAYS');
  valid_score = valid_decision and valid_truth;

  if valid_score then do;
    correct = (upcase(decision)=upcase(true_bucket));
    brier_component = (reliability_score - correct)**2;
  end;
  else do;
    correct = .;
    brier_component = .;
  end;

  confidence_bin = min(9, max(0, floor(10*reliability_score)));
  confidence_bin_label = cats(confidence_bin/10, '-', (confidence_bin+1)/10);
run;

/* ---- 2. Brier score and confidence calibration ------------------------- */
proc sql;
  create table proj.brier_scorecard as
  select engine_label,
         count(*) as n_responses,
         sum(valid_score) as n_valid,
         sum(not valid_score) as n_invalid,
         mean(brier_component) as brier_score format=8.4,
         mean(reliability_score) as avg_confidence format=8.3,
         mean(correct) as observed_accuracy format=percent8.1
  from work.stat_scored
  group by engine_label
  order by calculated brier_score;
quit;

title "Brier Score and Confidence Calibration by Engine";
proc print data=proj.brier_scorecard noobs label;
  label engine_label       = "Engine"
        n_responses        = "N Responses"
        n_valid            = "N Valid Scores"
        n_invalid          = "N Invalid/Parse Errors"
        brier_score        = "Brier Score (lower is better)"
        avg_confidence     = "Average Confidence"
        observed_accuracy  = "Observed Accuracy";
run;
title;

proc sql;
  create table proj.reliability_bins as
  select engine_label,
         confidence_bin,
         confidence_bin_label,
         count(*) as n_valid,
         mean(reliability_score) as mean_confidence format=8.3,
         mean(correct) as observed_accuracy format=percent8.1,
         calculated observed_accuracy - calculated mean_confidence
           as calibration_gap format=8.3
  from work.stat_scored
  where valid_score=1 and not missing(reliability_score)
  group by engine_label, confidence_bin, confidence_bin_label
  order by engine_label, confidence_bin;
quit;

title "Reliability Bins: Stated Confidence vs. Observed Accuracy";
proc print data=proj.reliability_bins noobs label;
  label engine_label        = "Engine"
        confidence_bin_label= "Confidence Bin"
        n_valid             = "N"
        mean_confidence     = "Mean Stated Confidence"
        observed_accuracy   = "Observed Accuracy"
        calibration_gap     = "Accuracy - Confidence";
run;
title;

/* ---- 3. Cochran's Q test for paired accuracy --------------------------- */
/* Create one row per respondent with one binary correctness value per model.
   Complete cases only are used because Cochran's Q requires every subject to
   have a result from every condition. */
proc sql;
  create table work.cochran_wide as
  select respondent_id,
         max(case when engine_key='HAIKU'  then correct end) as correct_haiku,
         max(case when engine_key='SONNET' then correct end) as correct_sonnet,
         max(case when engine_key='OPUS'   then correct end) as correct_opus
  from work.stat_scored
  where valid_score=1
  group by respondent_id
  having calculated correct_haiku is not missing
     and calculated correct_sonnet is not missing
     and calculated correct_opus is not missing;
quit;

proc iml;
  use work.cochran_wide;
    read all var {correct_haiku correct_sonnet correct_opus} into X;
  close work.cochran_wide;

  n = nrow(X);
  k = ncol(X);
  result = j(1,5,.);
  if n > 0 then do;
    rowTotals = X[,+];
    colTotals = X[+,];
    grandTotal = sum(X);
    denominator = k*grandTotal - sum(rowTotals##2);

    if denominator > 0 then do;
      q_stat = (k-1) * (k*sum(colTotals##2) - grandTotal##2)
               / denominator;
      p_value = 1 - cdf('CHISQUARE', q_stat, k-1);
    end;
    else do;
      q_stat = 0;
      p_value = 1;
    end;

    result = n || k || q_stat || (k-1) || p_value;
  end;

  create work.cochran_result from result[colname={'n_complete' 'n_engines'
      'q_statistic' 'df' 'p_value'}];
    append from result;
  close work.cochran_result;
quit;

data proj.cochran_q_result;
  set work.cochran_result;
  format q_statistic 8.3 p_value pvalue8.4;
run;

title "Cochran's Q Test: Paired Accuracy Across Engines";
proc print data=proj.cochran_q_result noobs label;
  label n_complete  = "Complete Respondents"
        n_engines   = "Engines Compared"
        q_statistic = "Cochran Q"
        df          = "Degrees of Freedom"
        p_value     = "P-Value";
run;
title;

/* ---- 4. Ordinal agreement / weighted-kappa reports -------------------- */
proc sort data=work.stat_scored(where=(valid_score=1)) out=work.kappa_input;
  by engine_key;
run;

title "Ordinal Agreement with True Bucket by Engine";
proc freq data=work.kappa_input;
  by engine_key;
  tables true_bucket * decision / agree;
run;
title;

/* ---- 5. Simple effect-size summary for paired accuracy ----------------- */
proc sql;
  create table work.paired_accuracy_summary as
  select
    mean(correct_haiku) as haiku_accuracy format=percent8.1,
    mean(correct_sonnet) as sonnet_accuracy format=percent8.1,
    mean(correct_opus) as opus_accuracy format=percent8.1,
    count(*) as n_complete
  from work.cochran_wide;
quit;

title "Paired Accuracy Summary Used by Cochran's Q";
proc print data=work.paired_accuracy_summary noobs;
run;
title;
