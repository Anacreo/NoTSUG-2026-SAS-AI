/******************************************************************************
 Program : 01_prepare_requests.sas
 Purpose : Materializes the survey/model combinations before any HTTP calls.
           Run this step first so the request queue can be inspected and rerun
           independently from the API execution step.
 ******************************************************************************/

%assert_lib_exists(proj);

%let max_responses = 20;

proc sql;
  create table proj.claude_requests as
  select monotonic() as request_id,
         e.engine_id,
         e.engine_label,
         s.respondent_id,
         s.open_text,
         s.true_bucket,
         'PENDING' as status length=12,
         . as http_status,
         '' as error_message length=500,
         '' as raw_response length=8000,
         datetime() as created_at format=datetime19.,
         . as completed_at format=datetime19.
  from proj.claude_engines as e, proj.survey_responses(obs=&max_responses.) as s;
quit;

proc datasets lib=proj nolist;
  delete claude_results claude_http_log;
quit;

%put NOTE: Request queue created in PROJ.CLAUDE_REQUESTS.;
proc sql;
  select status, count(*) as requests
  from proj.claude_requests
  group by status;
quit;
