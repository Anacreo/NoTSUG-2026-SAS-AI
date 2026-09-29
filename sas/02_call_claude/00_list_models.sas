/******************************************************************************
 Program : 00_list_models.sas
 Purpose : Enumerate available Anthropic models for the current API key.

 Usage:
   1) Run 00_setup/config.sas first (loads anthropic_api_key and URL/version).
   2) %include this file.

 Output:
   - PROJ.ANTHROPIC_MODELS (if parse succeeds)
   - WORK.MODELS_RAW (raw response body)
   - PROC PRINT preview of discovered models
 ******************************************************************************/

%assert_lib_exists(proj);

%if %length(%superq(anthropic_api_key)) = 0 %then %do;
  %put ERROR: anthropic_api_key is empty. Run 00_setup/config.sas and verify key file/env var.;
  %abort cancel;
%end;

filename mdlresp temp;

proc http
  method='GET'
  url='https://api.anthropic.com/v1/models'
  out=mdlresp;
  headers
    'x-api-key'="&anthropic_api_key."
    'anthropic-version'="&anthropic_api_version."
    'content-type'='application/json';
run;

%let models_http_status=&SYS_PROCHTTP_STATUS_CODE.;
%put NOTE: /v1/models http_status=&models_http_status.;

data work.models_raw;
  length raw_response $32767;
  infile mdlresp lrecl=32767 truncover;
  input raw_response $char32767.;
run;

%if &models_http_status. < 200 or &models_http_status. >= 300 %then %do;
  title 'Anthropic /v1/models error payload';
  proc print data=work.models_raw noobs; run;
  title;
  %put ERROR: /v1/models call failed. See WORK.MODELS_RAW for response body.;
  %return;
%end;

/* Parse JSON response */
filename mdljson temp;
data _null_;
  file mdljson lrecl=32767;
  set work.models_raw;
  put raw_response;
run;

libname mdljson json fileref=mdljson;

/* Typical response shape includes a DATA array of model objects. */
proc sql;
  create table proj.anthropic_models as
  select
    coalesce(d.id, '')                         as model_id        length=120,
    coalesce(d.type, '')                       as model_type      length=40,
    coalesce(d.display_name, '')               as display_name    length=200,
    coalesce(d.created_at, '')                 as created_at      length=40,
    coalesce(d.name, '')                       as name            length=200
  from mdljson.data as d;
quit;

libname mdljson clear;

title 'Available Anthropic Models (from /v1/models)';
proc print data=proj.anthropic_models noobs;
run;
title;
