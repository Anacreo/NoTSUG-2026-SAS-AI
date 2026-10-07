/* Pull SAS code built in GitHub into SAS Studio */
%let repo = Anacreo/NoTSUG-2026-SAS-AI;
%let file = sas/01_llm_call.sas;

/* Option A: raw download (public repo; add Authorization header for private) */
filename gh url "https://raw.githubusercontent.com/&repo./main/&file.";
%include gh;

/* Option B: SAS git functions (SAS 9.4M6+) - clone/pull into a folder SAS Studio can see */
data _null_;
  rc = gitfn_clone("https://github.com/&repo..git", "/home/&sysuserid./NoTSUG");
  put rc=;
run;
/* then in SAS Studio: %include "/home/&sysuserid./NoTSUG/sas/01_llm_call.sas"; */
