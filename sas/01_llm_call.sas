/* Call an LLM from SAS with PROC HTTP. API key comes from an env var / secured autoexec, never hard-coded. */
%let api_key = %sysget(OPENAI_API_KEY);
%let model   = gpt-4o-mini;   /* swap per engine; see 02_cost_compare.sas */

filename req temp;
filename resp temp;

data _null_;
  file req;
  put '{"model":"' "&model." '",'
      '"messages":[{"role":"system","content":"You write SAS 9.4 code. Return only code."},'
      '{"role":"user","content":"Write a PROC SQL that counts rows by region in sashelp.shoes"}],'
      '"temperature":0}';
run;

proc http url="https://api.openai.com/v1/chat/completions" method="POST"
          in=req out=resp;
  headers "Authorization"="******"
          "Content-Type"="application/json";
run;
%put NOTE: HTTP status = &SYS_PROCHTTP_STATUS_CODE.;

libname r json fileref=resp;
proc sql;
  select content, prompt_tokens, completion_tokens
  from (select m.content from r.choices_message m) a,
       (select u.prompt_tokens, u.completion_tokens from r.usage u) b;
quit;
/* Write generated code to a file, review it, then %include */
