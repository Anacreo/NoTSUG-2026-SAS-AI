/******************************************************************************
 Program : generate_survey_data.sas
 Purpose : Generates a fake marketing-research dataset simulating open-ended
           survey responses to the question:

               "How often does this advertisement appeal to you?"

           This is a good showcase for LLM scoring because the answers are
           free-text natural language expressing *frequency*, something SAS
           has no native way to quantify (PROC FREQ counts values it is
           given - it can't read "every once in a while" and turn it into a
           number). Each simulated respondent is drawn from a known "true"
           frequency bucket so that, later, we can measure how accurately
           each Claude engine recovers that hidden bucket from the text
           alone, and how well each engine's own reliability/confidence
           score tracks its actual accuracy.

 Requires : 00_setup/config.sas has been run (PROJ library assigned).
 Output   : proj.survey_responses
******************************************************************************/

%assert_lib_exists(proj);

/* Bank of natural-language phrasings per true frequency bucket. Multiple
   phrasings per bucket keep the "fake" text varied and realistic. */
data work.phrase_bank;
  length true_bucket $ 10 phrase $ 120;
  input true_bucket $ phrase & $120.;
  datalines;
Never     It never really grabs my attention.
Never     I don't think it's ever appealed to me at all.
Never     Not once has this ad caught my eye.
Never     Honestly, it just doesn't do anything for me, ever.
Rarely    Every once in a while it catches my eye.
Rarely    Once in a blue moon I notice it.
Rarely    It rarely stands out to me.
Rarely    Maybe one time out of ten it grabs me.
Sometimes It's hit or miss, sometimes it works for me.
Sometimes About half the time I find it interesting.
Sometimes Every now and then it appeals to me, but not always.
Sometimes It depends on my mood, sometimes it lands.
Often     Most of the time it catches my attention.
Often     It frequently appeals to me when I see it.
Often     More often than not, I end up liking it.
Often     It usually grabs me pretty quickly.
Always    It appeals to me every single time I see it.
Always    Without fail, this ad grabs my attention.
Always    Every time, no exceptions, it works on me.
Always    Consistently, it's one that always draws me in.
;
run;

/* Ad campaigns / categories used to make the fake dataset feel realistic. */
data work.ad_catalog;
  length ad_id $ 8 ad_category $ 30;
  input ad_id $ ad_category & $30.;
  datalines;
AD-1001 Streaming Service
AD-1002 Athletic Footwear
AD-1003 Fast Casual Dining
AD-1004 Auto Insurance
AD-1005 Mobile Banking App
AD-1006 Skincare Subscription
;
run;

/* ---- Simulate N_RESPONDENTS survey rows -------------------------------- */
%let n_respondents = 150;
%let seed = 20260928;

proc sql noprint;
  select count(*) into :n_phrases from work.phrase_bank;
  select count(*) into :n_ads     from work.ad_catalog;
quit;

data proj.survey_responses;
  length respondent_id 8 ad_id $ 8 ad_category $ 30
         true_bucket $ 10 open_text $ 120;
  retain seed &seed.;
  array phrase_bucket {&n_phrases.} $ 10 _temporary_;
  array phrase_text   {&n_phrases.} $ 120 _temporary_;
  array ad_ids   {&n_ads.} $ 8 _temporary_;
  array ad_cats  {&n_ads.} $ 30 _temporary_;

  if _n_ = 1 then do;
    do i = 1 to &n_phrases.;
      set work.phrase_bank point=i nobs=nph;
      phrase_bucket{i} = true_bucket;
      phrase_text{i}   = phrase;
    end;
    do i = 1 to &n_ads.;
      set work.ad_catalog point=i nobs=nad;
      ad_ids{i}  = ad_id;
      ad_cats{i} = ad_category;
    end;
  end;

  do respondent_id = 1 to &n_respondents.;
    pick_phrase = ceil(&n_phrases. * ranuni(seed));
    pick_ad     = ceil(&n_ads.     * ranuni(seed));

    true_bucket = phrase_bucket{pick_phrase};
    open_text   = phrase_text{pick_phrase};
    ad_id       = ad_ids{pick_ad};
    ad_category = ad_cats{pick_ad};

    output;
  end;

  keep respondent_id ad_id ad_category true_bucket open_text;
  stop;
run;

proc sort data=proj.survey_responses; by respondent_id; run;

title "Sample of Fake Survey Responses (Ad Frequency Appeal)";
proc print data=proj.survey_responses(obs=10) noobs; run;
title;

proc freq data=proj.survey_responses;
  tables true_bucket / nocum;
  title "Distribution of Hidden 'True' Frequency Buckets (fake data)";
run;
title;
