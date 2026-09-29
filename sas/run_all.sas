/******************************************************************************
 Program : run_all.sas
 Purpose : Convenience driver for the complete workflow. API work is split
           into queue preparation, bounded execution, and parsing so each
           stage can be run and inspected independently.
******************************************************************************/

/* Bootstrap config.sas from the location of this program. Do not depend on
   proj_root here because an autoexec or prior session may define it incorrectly. */
%let __run_path = %sysfunc(dequote(%superq(_SASPROGRAMFILE)));

%if %length(&__run_path.) = 0 %then %do;
  %let __run_path = %sysfunc(dequote(%sysget(SAS_EXECFILEPATH)));
%end;

%if %length(&__run_path.) > 0 %then %do;
  %let __run_path = %sysfunc(tranwrd(%superq(__run_path),%str(\),/));
  %let __run_dir = %substr(
    &__run_path.,
    1,
    %eval(%length(&__run_path.) - %length(%scan(&__run_path., -1, /)) - 1)
  );

  %include "&__run_dir./00_setup/config.sas";
%end;
%else %do;
  /* Fallback for sessions where SAS does not expose the executing file path. */
  %include "/home/&sysuserid./NoTSUG-2026-SAS-AI/sas/00_setup/config.sas";
%end;

%include "&proj_root./01_generate_fake_data/generate_survey_data.sas";
/* Optional model inventory step (uncomment when you need to verify IDs):
%include "&proj_root./02_call_claude/00_list_models.sas";
*/
%include "&proj_root./02_call_claude/01_prepare_requests.sas";
%include "&proj_root./02_call_claude/02_run_requests.sas";
%include "&proj_root./02_call_claude/03_parse_requests.sas";
%include "&proj_root./03_analyze_results/01_compare_engines.sas";
%include "&proj_root./03_analyze_results/02_question_by_engine.sas";
%include "&proj_root./03_analyze_results/03_cost_by_request.sas";
%include "&proj_root./03_analyze_results/04_statistical_tests.sas";
