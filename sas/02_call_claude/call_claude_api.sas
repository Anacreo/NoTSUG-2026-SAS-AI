/******************************************************************************
 Program : call_claude_api.sas
 Purpose : Sends each fake survey response to every Claude engine listed in
           proj.claude_engines, asking it to (a) decide which frequency
           bucket the free text expresses and (b) report its own
           reliability/confidence score for that decision. Results are
           stacked into proj.claude_results for later comparison against
           the known "true_bucket" in 03_analyze_results.

 Requires : 00_setup/config.sas and 01_generate_fake_data/generate_survey_data.sas
            have already been run.

 Notes    :
   - To keep the example fast/cheap, only &max_responses. survey rows are
     scored per engine by default. Raise this once you're happy with the
     flow and your API budget.
   - PROC HTTP requires SAS/ACCESS to internet-capable HTTP and outbound
     network access from your SAS session to api.anthropic.com.
******************************************************************************/

%assert_lib_exists(proj);
%include "&proj_root./02_call_claude/claude_prompt_template.sas";

%let max_responses = 20;   /* cap per engine for the demo / cost control */
%let claude_max_tokens = 200;

/* Pull the (small) sample of survey rows we will score. */
proc sql noprint;
  create table work.sample_responses as
  select * from proj.survey_responses(obs=&max_responses.);
  select count(*) into :n_engines from proj.claude_engines;
quit;

data _null_;
  set proj.claude_engines end=last;
  call symputx(cats('engine_id', _n_), engine_id);
  call symputx(cats('engine_label', _n_), engine_label);
  if last then call symputx('n_engines', _n_);
run;

/* Fresh output dataset, appended to inside the engine/response loops below. */
proc datasets lib=proj nolist nowarn;
  delete claude_results;
quit;

%macro call_claude_for_engine(engine_id, engine_label);

  data _null_;
    set work.sample_responses;
    call symputx(cats('resp_id', _n_), respondent_id);
    call symputx(cats('resp_text', _n_), open_text);
    call symputx(cats('resp_true', _n_), true_bucket);
  run;

  proc sql noprint;
    select count(*) into :n_resp from work.sample_responses;
  quit;

  %do r = 1 %to &n_resp.;

    %let one_text = &&resp_text&r.;
    %let user_msg = %claude_user_message(&one_text.);

    /* Build the JSON request body. Quotes/backslashes in the system prompt
       and survey text are escaped via TRANWRD before insertion so the
       payload stays valid JSON even though the prompt itself contains
       literal quotes and braces. If you point this at real, uncontrolled
       survey text, review escaping for additional edge cases (e.g. control
       characters). */
    filename reqbody temp;
    data _null_;
      file reqbody;
      length body $ 4000 sys_esc $ 2000 user_esc $ 500;
      sys_esc  = tranwrd(symget('claude_system_prompt'), '"', '\"');
      user_esc = tranwrd(symget('user_msg'), '"', '\"');
      body = '{'
        || '"model":"' || "&engine_id." || '",'
        || '"max_tokens":' || &claude_max_tokens. || ','
        || '"system":"' || trim(sys_esc) || '",'
        || '"messages":[{"role":"user","content":"' || trim(user_esc) || '"}]'
        || '}';
      put body;
    run;

    filename resp temp;

    proc http
        method="POST"
        url="&anthropic_api_url."
        in=reqbody
        out=resp;
      headers
        "x-api-key" = "&anthropic_api_key."
        "anthropic-version" = "&anthropic_api_version."
        "content-type" = "application/json";
    run;

    /* Read the raw response text back in for regex parsing. */
    data _null_;
      infile resp lrecl=32767 length=len;
      input raw_text $varying32767. len;
      call symputx('raw_response', raw_text);
    run;

    data work.one_result;
      length engine_id $ 40 engine_label $ 60 respondent_id 8
             true_bucket $ 10 decision $ 10 reliability_score 8
             inner_text $ 500 raw_response $ 8000;
      engine_id    = "&engine_id.";
      engine_label = "&engine_label.";
      respondent_id = &&resp_id&r.;
      true_bucket  = "&&resp_true&r.";
      raw_response = symget('raw_response');

      /* Claude wraps our requested JSON inside content[0].text, with inner
         quotes backslash-escaped, e.g.:
           "text":"{\"decision\": \"Often\", \"reliability_score\": 0.82}"
         Pull that text out up to the closing "} ] that ends the content
         array entry, unescape \" -> ", then parse the now-flat inner JSON
         with JSON_FIELD() (see 99_utils/extract_json.sas). */
      rx_text = prxparse('/"text"\s*:\s*"(.*)"\s*\}\s*\]/');
      if prxmatch(rx_text, raw_response) then do;
        call prxposn(rx_text, 1, s, l);
        inner_text = substr(raw_response, s, l);
      end;
      call prxfree(rx_text);
      inner_text = tranwrd(inner_text, '\"', '"');

      decision          = json_field(inner_text, 'decision');
      reliability_score = input(json_field(inner_text, 'reliability_score'), best32.);
      output;
    run;

    proc append base=proj.claude_results data=work.one_result force; run;

  %end;

%mend call_claude_for_engine;

%macro run_all_engines;
  %do e = 1 %to &n_engines.;
    %put NOTE: Scoring responses with engine &&engine_id&e. (&&engine_label&e.)...;
    %call_claude_for_engine(&&engine_id&e., &&engine_label&e.);
  %end;
%mend run_all_engines;

%run_all_engines;

title "Sample of Claude Decisions & Reliability Scores";
proc print data=proj.claude_results(obs=15) noobs;
  var engine_label respondent_id true_bucket decision reliability_score;
run;
title;
