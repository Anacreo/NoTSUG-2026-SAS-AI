/******************************************************************************
 program : run_all.sas
 purpose : convenience driver for the complete workflow. api work is split
           into queue preparation, bounded execution, and parsing so each
           stage can be run and inspected independently.
 ******************************************************************************/
%put note: run_all set proj_root=&proj_root;

/* robust append: handles proj_root with or without trailing slash */
%let code_root = &proj_root.sas/;
%put note: run_all set code_root=&code_root;

%include "&code_root.00_setup/config.sas";
%include "&code_root.01_generate_fake_data/generate_survey_data.sas";
/* optional model inventory step (uncomment when you need to verify ids):
%include "&code_root.02_call_claude/00_list_models.sas";
*/
%include "&code_root.02_call_claude/01_prepare_requests.sas";
%include "&code_root.02_call_claude/02_run_requests.sas";
%include "&code_root.02_call_claude/03_parse_requests.sas";
%include "&code_root.03_analyze_results/01_compare_engines.sas";
%include "&code_root.03_analyze_results/02_question_by_engine.sas";
%include "&code_root.03_analyze_results/03_cost_by_request.sas";
%include "&code_root.03_analyze_results/04_statistical_tests.sas";