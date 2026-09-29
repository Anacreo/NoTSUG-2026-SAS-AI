/******************************************************************************
 Program : cost_by_request.sas
 Purpose : Estimates USD cost per Claude API call and aggregates it by engine,
           using the token usage counters Anthropic returns in every response
           envelope (input_tokens, output_tokens, and cache token fields).

           NOTE: Anthropic's API does not return a dollar cost directly - only
           token counts. This script converts those counts to an estimated
           cost using a small, editable PROJ.MODEL_PRICING rate table. Update
           that table whenever list prices change; treat the result as an
           estimate, not an invoice-grade figure (it ignores things like
           volume discounts and any batch-API pricing).

 Requires : proj.claude_requests has raw_response for RECEIVED/ERROR rows
            (populated by 02_call_claude/02_run_requests.sas).
 Output   : proj.claude_request_cost   (one row per request, with cost)
            proj.engine_cost_summary   (aggregated cost/tokens per engine)
            printed reports.
 ******************************************************************************/

%assert_lib_exists(proj);

/* ---- 1. Editable price list ($ per 1,000,000 tokens) -------------------- */
/* Source: Anthropic published API pricing, checked 2026-09-29. Re-verify
   before relying on this for real budgeting - prices change over time and
   can vary by cache/batch usage, which this scaffold does not price out. */
data proj.model_pricing;
  length engine_id $40 input_price_per_mtok 8 output_price_per_mtok 8;
  input engine_id $ input_price_per_mtok output_price_per_mtok;
  datalines;
claude-haiku-4-5-20251001 1  5
claude-sonnet-5           2  10
claude-opus-5-5           4  20
;
run;

/* ---- 2. Pull token usage counters out of the raw response envelope ------ */
/* Claude's JSON usage block looks like:
     "usage":{"input_tokens":213,"cache_creation_input_tokens":0,
               "cache_read_input_tokens":0,"output_tokens":200, ...}
   json_field() (99_utils/extract_json.sas) extracts one flat field at a
   time, so it works fine directly against the raw envelope here - unlike
   the "decision"/"reliability_score" fields, these usage fields are never
   nested inside escaped text. */
data work.request_usage;
  set proj.claude_requests(where=(raw_response is not missing));
  length input_tokens_raw cache_creation_raw cache_read_raw output_tokens_raw $40;

  input_tokens_raw   = json_field(raw_response, 'input_tokens');
  cache_creation_raw = json_field(raw_response, 'cache_creation_input_tokens');
  cache_read_raw     = json_field(raw_response, 'cache_read_input_tokens');
  output_tokens_raw  = json_field(raw_response, 'output_tokens');

  input_tokens             = input(input_tokens_raw, ?? best32.);
  cache_creation_tokens     = input(cache_creation_raw, ?? best32.);
  cache_read_tokens         = input(cache_read_raw, ?? best32.);
  output_tokens             = input(output_tokens_raw, ?? best32.);

  /* Treat cache-write tokens like ordinary input tokens for this estimate;
     Anthropic actually prices cache writes/reads differently, but that
     level of nuance is out of scope for this scaffold. */
  billable_input_tokens  = sum(0, input_tokens, cache_creation_tokens, cache_read_tokens);
  billable_output_tokens = sum(0, output_tokens);

  usage_found = not missing(input_tokens) or not missing(output_tokens);

  keep request_id engine_id engine_label respondent_id http_status status
       usage_found input_tokens cache_creation_tokens cache_read_tokens
       output_tokens billable_input_tokens billable_output_tokens;
run;

/* ---- 3. Apply pricing and compute estimated cost per request ------------ */
proc sql;
  create table proj.claude_request_cost as
  select
    u.request_id,
    u.engine_id,
    u.engine_label,
    u.respondent_id,
    u.http_status,
    u.status,
    u.usage_found,
    u.billable_input_tokens,
    u.billable_output_tokens,
    p.input_price_per_mtok,
    p.output_price_per_mtok,
    (u.billable_input_tokens  * p.input_price_per_mtok  / 1000000) as input_cost  format=dollar12.6,
    (u.billable_output_tokens * p.output_price_per_mtok / 1000000) as output_cost format=dollar12.6,
    calculated input_cost + calculated output_cost as est_cost_usd format=dollar12.6
  from work.request_usage as u
  left join proj.model_pricing as p
    on u.engine_id = p.engine_id;
quit;

title "Rows Missing Usage Counters or Pricing (review before trusting totals)";
proc print data=proj.claude_request_cost noobs;
  where usage_found = 0 or missing(input_price_per_mtok);
  var request_id engine_id respondent_id http_status status;
run;
title;

title "Estimated Cost per Request (first 20)";
proc print data=proj.claude_request_cost(obs=20) noobs;
  var request_id engine_label respondent_id billable_input_tokens
      billable_output_tokens est_cost_usd http_status;
run;
title;

/* ---- 4. Aggregate cost per engine ---------------------------------------- */
proc sql;
  create table proj.engine_cost_summary as
  select
    engine_label,
    count(*)                          as n_requests,
    sum(usage_found)                  as n_with_usage,
    sum(billable_input_tokens)        as total_input_tokens,
    sum(billable_output_tokens)       as total_output_tokens,
    sum(est_cost_usd)                 as total_est_cost_usd  format=dollar14.4,
    mean(est_cost_usd)                as avg_cost_per_request format=dollar12.6,
    calculated total_est_cost_usd / max(1, sum(usage_found)) as avg_cost_per_scored_request format=dollar12.6
  from proj.claude_request_cost
  group by engine_label
  order by calculated total_est_cost_usd desc;
quit;

title "Estimated Claude API Cost by Engine (all requests, incl. errors)";
proc print data=proj.engine_cost_summary noobs label;
  label engine_label                 = "Engine"
        n_requests                  = "N Requests"
        n_with_usage                = "N With Usage Counters"
        total_input_tokens          = "Total Input Tokens"
        total_output_tokens         = "Total Output Tokens"
        total_est_cost_usd          = "Total Estimated Cost"
        avg_cost_per_request        = "Avg Cost / Request"
        avg_cost_per_scored_request = "Avg Cost / Request w/ Usage";
run;
title;

title "Grand Total Estimated Cost Across All Engines";
proc sql;
  select sum(est_cost_usd) as total_est_cost_usd format=dollar14.4
  from proj.claude_request_cost;
quit;
title;
