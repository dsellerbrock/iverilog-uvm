// U15 permanent regression: lossless native attribute capture.
// Companion to recording_lifecycle.sv (which is deliberately independent of
// attribute support). +reject_test selects the rejection-path run (expected
// nonzero exit); the default run is the happy path (expected exit 0).
`timescale 1ns/1ps
module main;
  import "DPI-C" context function int ivl_uvm_record_open(input string filename);
  import "DPI-C" context function int ivl_uvm_record_stream(input int owner,h,input string name,kind,scope);
  import "DPI-C" context function int ivl_uvm_record_begin(input int owner,h,stream,input string kind,name,label,desc,input longint unsigned begin_time);
  import "DPI-C" context function int ivl_uvm_record_end(input int owner,h,input longint unsigned end_time);
  import "DPI-C" context function int ivl_uvm_record_free(input int owner,h);

  int a;
  // 65-bit signed packed value spanning 3 words, with x/z bits in word0 to
  // exercise aval/bval separately (not just all-defined bits).
  logic signed [64:0] packed_value = 65'h1_80000000_x000000z;
  real real_value = 1.2345678901234567;
  string string_value = "line\nquote\"\\tail";

  initial begin
    a = ivl_uvm_record_open($test$plusargs("reject_test") ? "reject.jsonl" : "happy.jsonl");
    if (a <= 0 || !ivl_uvm_record_stream(a,1,"s","test","")
        || !ivl_uvm_record_begin(a,2,1,"transaction","t","","",0))
      $fatal(1,"lifecycle setup");

    if ($test$plusargs("reject_test")) begin
      // A second, disposable transaction to exercise ended/freed rejection
      // without disturbing handle 2's happy-path use elsewhere.
      if (!ivl_uvm_record_begin(a,3,1,"transaction","t2","","",0)) $fatal(1,"second begin");
      if (!ivl_uvm_record_end(a,3,0)) $fatal(1,"end");
      if (!ivl_uvm_record_begin(a,4,1,"transaction","t3","","",0)) $fatal(1,"third begin");
      if (!ivl_uvm_record_free(a,4)) $fatal(1,"free");
      $ivl_uvm_record_attribute(99,"unknown_handle",32'h1);     // never registered
      $ivl_uvm_record_attribute(1,"wrong_kind_stream",32'h1);   // a stream, not a transaction
      $ivl_uvm_record_attribute(3,"ended_transaction",32'h1);   // already ended
      $ivl_uvm_record_attribute(4,"freed_transaction",32'h1);   // already freed
      $display("REJECT_TEST_COMPLETED");
    end else begin
      $ivl_uvm_record_attribute(2,"packed",packed_value);
      $ivl_uvm_record_attribute(2,"real",real_value);
      $ivl_uvm_record_attribute(2,"string_var",string_value);
      // Raw literal with an embedded zero byte: a string VARIABLE cannot
      // legally hold one (6.16), so only the literal path proves losslessness.
      $ivl_uvm_record_attribute(2,"string_literal","\000AB\000C");
      $display("HAPPY_TEST_COMPLETED");
    end
  end
endmodule
