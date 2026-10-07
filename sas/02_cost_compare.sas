/* Cost comparison across engines. PRICES ARE PLACEHOLDERS - verify on each vendor's pricing page. */
data prices;
  length engine $30;
  input engine $ in_per_mtok out_per_mtok;
  datalines;
OpenAI_gpt-4o-mini 0.15 0.60
OpenAI_gpt-4o      2.50 10.00
Anthropic_Sonnet   3.00 15.00
Anthropic_Haiku    0.80 4.00
Google_Gemini_Flash 0.10 0.40
;
run;

/* Token usage captured from each run (prompt_tokens/completion_tokens from the API 'usage' block) */
%let calls_per_month = 5000;
%let avg_in  = 1200;
%let avg_out = 600;

data cost;
  set prices;
  cost_per_call = (&avg_in*in_per_mtok + &avg_out*out_per_mtok)/1e6;
  monthly_cost  = cost_per_call * &calls_per_month;
  format cost_per_call monthly_cost dollar12.4;
run;
proc sort data=cost; by monthly_cost; run;
proc print data=cost noobs; run;
