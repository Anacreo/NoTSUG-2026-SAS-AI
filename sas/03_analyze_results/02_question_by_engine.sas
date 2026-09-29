/******************************************************************************
 Program : question_by_engine.sas
 Purpose : Wide-format side-by-side comparison: one row per survey response
           (the "question"), with each Claude engine's decision, reliability
           score, and a correctness/error indicator laid out as its own set
           of columns. This complements compare_engines.sas, which only
           reports per-engine aggregates.

 Requires : proj.claude_results has been produced by
            02_call_claude/03_parse_requests.sas.
 Output   : proj.question_by_engine (wide table), printed report.
 ******************************************************************************/

%assert_lib_exists(proj);

proc format;
  invalue bucket_rank
    "Never"     = 1
    "Rarely"    = 2
    "Sometimes" = 3
    "Often"     = 4
    "Always"    = 5
    other       = .;
run;

/* Score each engine's response the same way compare_engines.sas does, so
   the two reports never disagree. */
data work.scored;
  set proj.claude_results;
  true_rank     = input(true_bucket, bucket_rank.);
  decision_rank = input(decision, bucket_rank.);
  parse_error   = missing(true_rank) or missing(decision_rank);

  length flag $12;
  if parse_error then flag='ERROR';
  else if upcase(decision) = upcase(true_bucket) then flag='CORRECT';
  else flag='WRONG';
run;

proc sort data=work.scored;
  by respondent_id engine_label;
run;

/* Attach the original open-text question/response so the wide table is
   self-describing without a join back to proj.survey_responses. */
proc sql;
  create table work.scored_with_text as
  select s.*, r.open_text
  from work.scored as s
  left join proj.survey_responses as r
    on s.respondent_id = r.respondent_id;
quit;

proc sort data=work.scored_with_text;
  by respondent_id engine_label;
run;

/* Transpose decision/reliability_score/flag out to one column set per
   engine so every question is a single row across all engines. */
proc transpose data=work.scored_with_text out=work.t_decision(drop=_name_) prefix=decision_;
  by respondent_id true_bucket open_text;
  id engine_label;
  var decision;
run;

proc transpose data=work.scored_with_text out=work.t_reliability(drop=_name_) prefix=reliability_;
  by respondent_id true_bucket open_text;
  id engine_label;
  var reliability_score;
run;

proc transpose data=work.scored_with_text out=work.t_flag(drop=_name_) prefix=flag_;
  by respondent_id true_bucket open_text;
  id engine_label;
  var flag;
run;

data proj.question_by_engine;
  merge work.t_decision work.t_reliability work.t_flag;
  by respondent_id true_bucket open_text;
run;

title "Per-Question Comparison Across Claude Engines";
proc print data=proj.question_by_engine noobs;
run;
title;
