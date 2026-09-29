/******************************************************************************
 Program : run_all.sas
 Purpose : Convenience driver that runs the whole "Ad Frequency Perception"
           workflow end to end, in SAS Studio or batch mode. %include each
           step individually instead if you want to inspect results between
           stages.
******************************************************************************/

%let proj_root = %sysfunc(translate(%sysget(SAS_EXECFILEPATH), /, \));
%let proj_root = %substr(&proj_root., 1, %length(&proj_root.) - %length(%scan(&proj_root., -1, /)) - 1);

%include "&proj_root./00_setup/config.sas";
%include "&proj_root./01_generate_fake_data/generate_survey_data.sas";
%include "&proj_root./02_call_claude/call_claude_api.sas";
%include "&proj_root./03_analyze_results/compare_engines.sas";
