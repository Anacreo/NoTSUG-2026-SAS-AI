/******************************************************************************
 Program : claude_prompt_template.sas
 Purpose : Defines the prompt Claude receives for each survey response. Kept
           in its own file so the prompt can be tuned/versioned without
           touching the API-calling logic in call_claude_api.sas.

 Task given to Claude:
   Read one open-ended survey answer to "How often does this advertisement
   appeal to you?" and classify the expressed frequency into one of five
   buckets (Never / Rarely / Sometimes / Often / Always), returning that
   decision plus the model's own reliability/confidence score (0-1) for
   its answer. This is exactly the kind of natural-language-to-frequency
   task SAS has no native procedure for.
******************************************************************************/

%global claude_system_prompt;

%let claude_system_prompt = %str(You are a careful market research analyst. You will be given one open-ended survey response to the question "How often does this advertisement appeal to you?". Classify the frequency the respondent is describing into exactly one of: Never, Rarely, Sometimes, Often, Always. Also provide a reliability_score between 0 and 1 representing how confident you are in that classification (1 = fully confident, 0 = a guess). Respond with ONLY a single-line, flat JSON object and no other text, in the exact form: %{"decision": "<one of the five buckets>", "reliability_score": <number>%});

/* Builds the per-response "user" message text. Called from call_claude_api.sas
   with the raw survey text already macro-quoted by the caller. */
%macro claude_user_message(open_text);
Survey response: "&open_text."
%mend claude_user_message;
