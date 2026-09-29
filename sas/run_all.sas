/******************************************************************************
 Program : run_all.sas
 Purpose : Convenience driver for the complete workflow. API work is split
           into queue preparation, bounded execution, and parsing so each
           stage can be run and inspected independently.
******************************************************************************/

/* Bootstrap config.sas from the directory containing this program.
   Keep this in open code: SAS Studio does not support open-code %IF/%DO/%END
   in all execution contexts. _SASPROGRAMFILE is supplied by SAS Studio when
   this program is submitted. */
%let __run_path = %sysfunc(dequote(%superq(_SASPROGRAMFILE)));
%let __run_dir  = %sysfunc(prxchange(s#[/\\][^/\\]*$##,1,%superq(__run_path)));

%include "&__run_dir./00_setup/config.sas";

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
