/******************************************************************************
 Program : compare_engines.sas
 Purpose : Compares each Claude engine's ability to translate natural
           language into a frequency bucket (something SAS has no native
           procedure for) against the known "true_bucket" baked into the
           fake data, and checks whether each engine's self-reported
           reliability_score actually tracks its accuracy.

 Requires : proj.claude_results has been produced by
            02_call_claude/call_claude_api.sas.
 Output   : proj.engine_scorecard, printed report, and a bar chart comparing
            accuracy vs. average reliability score per engine.
******************************************************************************/

%assert_lib_exists(proj);

/* Ordinal mapping so we can also look at "how far off" a wrong answer was
   (e.g. Often vs Always is a much smaller miss than Never vs Always). */
proc format;
  invalue bucket_rank
    "Never"     = 1
    "Rarely"    = 2
    "Sometimes" = 3
    "Often"     = 4
    "Always"    = 5
    other       = .;
run;

data work.scored;
  set proj.claude_results;
  true_rank     = input(true_bucket, bucket_rank.);
  decision_rank = input(decision, bucket_rank.);
  correct       = (upcase(decision) = upcase(true_bucket));
  abs_rank_diff = abs(true_rank - decision_rank);
run;

/* ---- Per-engine scorecard: accuracy, average reliability, calibration -- */
proc sql;
  create table proj.engine_scorecard as
  select
    engine_label,
    count(*)                                   as n_scored,
    mean(correct)                               as accuracy       format=percent8.1,
    mean(reliability_score)                     as avg_reliability format=6.2,
    mean(abs_rank_diff)                         as avg_bucket_miss format=6.2,
    /* Calibration: correlation between an engine's own confidence and
       whether it was actually right. A well-calibrated engine should show
       higher reliability_score on responses it got correct. */
    mean(case when correct = 1 then reliability_score end) as avg_reliability_when_correct format=6.2,
    mean(case when correct = 0 then reliability_score end) as avg_reliability_when_wrong   format=6.2
  from work.scored
  group by engine_label
  order by calculated accuracy desc;
quit;

title "Claude Engine Scorecard: Ad-Frequency Perception Task";
proc print data=proj.engine_scorecard noobs label;
  label engine_label                   = "Engine"
        n_scored                      = "N Responses Scored"
        accuracy                      = "Accuracy vs True Bucket"
        avg_reliability               = "Avg Reliability Score"
        avg_bucket_miss               = "Avg |Bucket| Miss (0=perfect)"
        avg_reliability_when_correct  = "Avg Reliability (Correct)"
        avg_reliability_when_wrong    = "Avg Reliability (Wrong)";
run;
title;

/* ---- Confusion matrix per engine: where does each engine get confused? */
proc freq data=work.scored;
  by engine_label;
  tables true_bucket * decision / norow nocol nopercent;
  title "Confusion Matrix: True Bucket vs Claude Decision, by Engine";
run;
title;

/* ---- Visual comparison: accuracy vs. average reliability per engine --- */
data work.scorecard_long;
  set proj.engine_scorecard;
  length metric $ 20;
  metric = "Accuracy";        value = accuracy;         output;
  metric = "Avg Reliability"; value = avg_reliability;  output;
  keep engine_label metric value;
run;

ods graphics / width=800px height=500px;
proc sgplot data=work.scorecard_long;
  title "Accuracy vs. Self-Reported Reliability by Claude Engine";
  vbar engine_label / response=value group=metric groupdisplay=cluster;
  yaxis label="Score" values=(0 to 1 by 0.1);
  xaxis label="Engine";
  keylegend / location=outside;
run;
title;
