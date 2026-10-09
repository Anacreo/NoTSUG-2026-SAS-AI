/******************************************************************************
 Program : call_claude_api.sas
 Purpose : Compatibility wrapper for the split API workflow.

 Run these files individually for easier diagnostics:
   01_prepare_requests.sas
   02_run_requests.sas
   03_parse_requests.sas

 This wrapper prepares the queue, executes one small batch, then parses only
 successful responses. Increase BATCH_SIZE in 02_run_requests.sas gradually.
 ******************************************************************************/

%include "&proj_root./02_call_claude/01_prepare_requests.sas";
%include "&proj_root./02_call_claude/02_run_requests.sas";
%include "&proj_root./02_call_claude/03_parse_requests.sas";
