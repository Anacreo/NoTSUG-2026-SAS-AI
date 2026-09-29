/******************************************************************************
 Program : 00_list_models.sas
 Purpose : Enumerate available Anthropic models for the current API key.

 Usage:
   1) Run 00_setup/config.sas first.
   2) %include this file.

 Output:
   - WORK.MODELS_RAW contains the raw response body.
   - PROJ.ANTHROPIC_MODELS contains normalized model rows when the JSON
     response includes an auto-mapped table with an ID column.
   - The JSON engine's discovered tables and columns are printed for diagnosis.
   - Each discovered model_id / display_name is also written to the LOG via
     %put so the enumeration is visible without switching to the Results tab.
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

filename mdljson temp;
data _null_;
  file mdljson lrecl=32767;
  set work.models_raw;
  put raw_response;
run;

libname mdljson json fileref=mdljson;

/* The JSON engine's table/column names can vary. Inspect what SAS created. */
title 'JSON tables discovered under MDLJSON';
proc datasets lib=mdljson nolist;
quit;
title;

proc sql noprint;
  select distinct memname into :mdljson_tables separated by ' '
  from dictionary.tables
  where upcase(libname)='MDLJSON';

  select distinct memname into :model_table trimmed
  from dictionary.columns
  where upcase(libname)='MDLJSON'
    and upcase(name)='ID'
    and upcase(memname) not like '%CONTENT%';
quit;

%put NOTE: MDLJSON tables = &mdljson_tables.;
%put NOTE: Table containing ID column = &model_table.;

%macro print_json_metadata;
  %local i table;
  %let i=1;
  %let table=%scan(&mdljson_tables.,&i.,%str( ));
  %do %while(%length(&table.) > 0);
    title "Columns in MDLJSON.&table.";
    proc contents data=mdljson.&table.; run;
    title;
    %let i=%eval(&i.+1);
    %let table=%scan(&mdljson_tables.,&i.,%str( ));
  %end;
%mend print_json_metadata;

%print_json_metadata;

%if %length(%superq(model_table)) = 0 %then %do;
  %put ERROR: Could not find an auto-mapped JSON table with an ID column.;
  %put ERROR: Review the JSON table/column metadata printed above.;
  libname mdljson clear;
  %return;
%end;

/* Normalize the model rows without hard-coding optional column names. */
data proj.anthropic_models;
  length model_id $120 model_type $40 display_name $200
         created_at $40 name $200;
  set mdljson.&model_table.;
  model_id     = strip(vvaluex('ID'));
  model_type   = strip(vvaluex('TYPE'));
  display_name = strip(vvaluex('DISPLAY_NAME'));
  created_at   = strip(vvaluex('CREATED_AT'));
  name         = strip(vvaluex('NAME'));
  if not missing(model_id);
  keep model_id model_type display_name created_at name;
run;

libname mdljson clear;

/* Write the enumeration straight to the log, not just the Results tab. */
data _null_;
  set proj.anthropic_models end=last;
  if _n_=1 then put "NOTE: ---- Anthropic model enumeration begin ----";
  put "NOTE: model_id=" model_id +(-1) " display_name=" display_name
      +(-1) " type=" model_type +(-1) " created_at=" created_at;
  if last then do;
    put "NOTE: ---- Anthropic model enumeration end (" _n_ " models) ----";
  end;
run;

title 'Available Anthropic Models (from /v1/models)';
proc print data=proj.anthropic_models noobs;
run;
title;
