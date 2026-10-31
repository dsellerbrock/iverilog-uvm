class match_item_recorder;
  int calls = 0;
  int last_value = 0;
  task automatic record(input int value);
    calls++;
    last_value = value;
  endtask
endclass

module sv_sva_match_item_args;
  logic clk = 0;
  logic first = 0;
  logic second = 0;
  int sampled = 0;
  int calls = 0;
  int function_calls = 0;
  int function_local = 0;
  int local_seen = 0;
  int sampled_seen = 0;
  match_item_recorder recorder;

  task automatic record(input int local_value, input int sampled_value);
    calls++;
    local_seen = local_value;
    sampled_seen = sampled_value;
  endtask

  function automatic void record_function(input int local_value);
    function_calls++;
    function_local = local_value;
    if (local_value != 3 && local_value != 9)
      $fatal(1, "function received wrong local value");
  endfunction

  sequence saves_and_calls;
    int local_value;
    @(posedge clk) (first, local_value = sampled)
      ##1 (second, record(local_value, sampled),
           record_function(local_value), recorder.record(local_value),
           $display("MATCH %0d", local_value));
  endsequence

  sequence cover_calls;
    int local_value;
    @(posedge clk) (first, local_value = sampled)
      ##1 (second, record(local_value, sampled),
           record_function(local_value), recorder.record(local_value),
           $display("COVER %0d", local_value));
  endsequence

  assert property (saves_and_calls);
  cover property (cover_calls);

  initial begin
    recorder = new;
    #1 first = 1; sampled = 3;
    #1 clk = 1;
    #1 clk = 0; second = 1; sampled = 9;
    #1 clk = 1;
    #1 clk = 0;
    #1 clk = 1;
    #1;
    if (calls != 4 || function_calls != 4 || recorder.calls != 4
        || recorder.last_value != 9
        || local_seen != 9 || function_local != 9 || sampled_seen != 9)
      $fatal(1, "match-item arguments: calls=%0d functions=%0d local=%0d function-local=%0d sampled=%0d",
             calls, function_calls, local_seen, function_local, sampled_seen);
    $display("PASSED");
    $finish;
  end
endmodule
