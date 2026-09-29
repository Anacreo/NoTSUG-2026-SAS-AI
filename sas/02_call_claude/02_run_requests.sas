/******************************************************************************
 Program : 02_run_requests.sas
 Purpose : Executes a bounded batch from PROJ.CLAUDE_REQUESTS.

 Usage:
   - Run 01_prepare_requests.sas first.
   - Set batch_size below to control how much output is produced per run.
   - Rerun this file to continue processing PENDING requests.
   - No survey text is passed through macro parameters; it remains in SAS
     data rows, avoiding commas/quotes/ampersands breaking macro parsing.
 ******************************************************************************/

%assert_lib_exists(proj);
%include "&proj_root./02_call_claude/claude_prompt_template.sas";

%let batch_size = 5;
%let claude_max_tokens = 200;

proc sql noprint outobs=&batch_size.;
  create table work.batch as
  select *
  from proj.claude_requests
  where upcase(status)='PENDING'
  order by request_id;
  select count(*) into :batch_count trimmed from work.batch;
quit;

%macro run_batch;
  %local request_id engine_id engine_label open_text respondent_id true_bucket
         req_file resp_file raw_response http_status error_message;

  %do request_n=1 %to &batch_count.;
    data _null_;
      set work.batch(firstobs=&request_n. obs=&request_n.);
      call symputx('request_id', request_id, 'L');
      call symputx('engine_id', engine_id, 'L');
      call symputx('engine_label', engine_label, 'L');
      call symputx('open_text', open_text, 'L');
      call symputx('respondent_id', respondent_id, 'L');
      call symputx('true_bucket', true_bucket, 'L');
    run;

    filename reqbody temp encoding='utf-8';
    data _null_;
      file reqbody lrecl=32767;
      length system_text user_text body $32767;
      system_text = symget('claude_system_prompt');
      user_text = cats('Survey response: "', symget('open_text'), '"');

      /* JSON escape order matters: backslash first, then quotes and controls. */
      system_text = tranwrd(system_text, '\', '\\');
      system_text = tranwrd(system_text, '"', '\"');
      system_text = tranwrd(system_text, '0D0A'x, '\n');
      system_text = tranwrd(system_text, '0A'x, '\n');
      system_text = tranwrd(system_text, '0D'x, '\n');
      user_text = tranwrd(user_text, '\', '\\');
      user_text = tranwrd(user_text, '"', '\"');
      user_text = tranwrd(user_text, '0D0A'x, '\n');
      user_text = tranwrd(user_text, '0A'x, '\n');
      user_text = tranwrd(user_text, '0D'x, '\n');

      body = cats('{"model":"', symget('engine_id'),
                  '","max_tokens":', "&claude_max_tokens.",
                  ',"system":"', strip(system_text),
                  '","messages":[{"role":"user","content":"',
                  strip(user_text), '"}]}');
      put body;
    run;

    filename resp temp;
    %let http_status=;
    %let raw_response=;

    proc http method='POST'
      url="&anthropic_api_url."
      in=reqbody out=resp;
      headers
        'x-api-key'="&anthropic_api_key."
        'anthropic-version'="&anthropic_api_version."
        'content-type'='application/json';
    run;

    %let http_status=&SYS_PROCHTTP_STATUS_CODE.;

    data _null_;
      infile resp lrecl=32767 truncover;
      length line $32767 all_text $8000;
      retain all_text '';
      input line $char32767.;
      all_text = cats(all_text, line);
      call symputx('raw_response', all_text, 'L');
    run;

    data work.one_http_log;
      length request_id 8 engine_id $40 engine_label $60 respondent_id 8
             http_status 8 status $20 error_message $500 raw_response $8000;
      request_id=&request_id.;
      engine_id=symget('engine_id');
      engine_label=symget('engine_label');
      respondent_id=&respondent_id.;
      http_status=input(symget('http_status'), best32.);
      raw_response=symget('raw_response');
      if 200 <= http_status < 300 then status='SUCCESS';
      else status='ERROR';
      if status='ERROR' then error_message=substr(raw_response,1,500);
    run;

    proc append base=proj.claude_http_log data=work.one_http_log force; run;

    /* Persist the response and status so a later parse step can inspect it. */
    proc sql;
      update proj.claude_requests
      set status=case when &http_status. between 200 and 299 then 'RECEIVED'
                      else 'ERROR' end,
          http_status=&http_status.,
          error_message=case when &http_status. between 200 and 299 then ''
                             else substr("%superq(raw_response)",1,500) end,
          raw_response="%superq(raw_response)",
          completed_at=datetime()
      where request_id=&request_id.;
    quit;

    %put NOTE: request=&request_id engine=&engine_id http_status=&http_status.;
  %end;
%mend run_batch;

%if &batch_count. > 0 %then %do;
  %run_batch;
%end;
%else %do;
  %put NOTE: No PENDING requests remain in PROJ.CLAUDE_REQUESTS.;
%end;

proc sql;
  select status, count(*) as requests
  from proj.claude_requests
  group by status;
quit;
