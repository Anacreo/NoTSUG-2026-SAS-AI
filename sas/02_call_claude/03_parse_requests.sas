/******************************************************************************
 Program : 03_parse_requests.sas
 Purpose : Parses successful Claude responses after 02_run_requests.sas.
           HTTP errors remain visible in PROJ.CLAUDE_REQUESTS and are not
           converted into misleading result rows.
 ******************************************************************************/

%assert_lib_exists(proj);

proc sql;
  create table work.received as
  select *
  from proj.claude_requests
  where upcase(status)='RECEIVED';
quit;

data work.parsed_results;
  set work.received;
  length decision $20 inner_text $1000;
  retain rx_text;
  if missing(rx_text) then rx_text=prxparse('/"text"\s*:\s*"(.*)"\s*\}\s*\]/');

  if prxmatch(rx_text, raw_response) then do;
    call prxposn(rx_text, 1, start, length);
    inner_text=substr(raw_response,start,length);
    inner_text=tranwrd(inner_text,'\"','"');
    inner_text=tranwrd(inner_text,'\\','\');
    decision=json_field(inner_text,'decision');
    reliability_score=input(json_field(inner_text,'reliability_score'),best32.);
  end;
  else do;
    decision='PARSE_ERROR';
    reliability_score=.;
  end;

  keep engine_id engine_label respondent_id true_bucket decision
       reliability_score inner_text raw_response http_status;
run;

proc datasets lib=proj nolist;
  delete claude_results;
quit;

proc append base=proj.claude_results data=work.parsed_results force; run;

proc print data=proj.claude_http_log(obs=20) noobs;
  var request_id engine_id respondent_id http_status status error_message;
run;

proc print data=proj.claude_results(obs=20) noobs;
  var engine_label respondent_id true_bucket decision reliability_score http_status;
run;
