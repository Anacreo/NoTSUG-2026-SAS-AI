/******************************************************************************
 Program : extract_json.sas
 Purpose : Defines a reusable DATA step function, JSON_FIELD(), that pulls a
           "field": "value" (or "field": value) pair out of a small, flat
           JSON string using PRX regular expressions.

           Claude is instructed (see claude_prompt_template.sas) to always
           reply with a compact, flat JSON object such as:
             {"decision": "Often", "reliability_score": 0.82}
           so a full JSON parser is not required for this scaffold - a
           regex-based extractor keeps the example short and easy to adapt.

           This function assumes the JSON has already been "unwrapped" to
           the flat object above (no nested/escaped quotes). Pulling that
           flat text out of Claude's full API response envelope is handled
           separately in call_claude_api.sas, since that step needs to
           unescape backslash-escaped quotes first.
******************************************************************************/

options cmplib = work.funcs;

proc fcmp outlib = work.funcs.utils;
  function json_field(json $, field $) $ 200;
    length re $ 400 result $ 200;
    length rx s l 8;
    /* Matches: "field" : "quoted text"  OR  "field" : 0.82 (bare number) */
    re = cats('/"', trim(field), '"\s*:\s*"?([^",}]+)"?/');
    rx = prxparse(re);
    result = ' ';
    if prxmatch(rx, json) then do;
      call prxposn(rx, 1, s, l);
      result = strip(substr(json, s, l));
    end;
    call prxfree(rx);
    return(result);
  endsub;
quit;
