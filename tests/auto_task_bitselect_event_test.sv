// Regression: an event control that senses a bit-select of a vector inside
// an automatic task (@(posedge sig[i])) lowers the bit-select to a
// synthesized local .part net. That net is local/automatic and is elided
// when the scope is drawn, but the fork's draw_input_from_net still emitted
// the elided net's "v..." label as the event operand, giving a runtime
// "unresolved vvp_net reference" (the image aborted before any output).
// The fix makes such an event reference the nexus driver (the .part
// functor) instead of the absent net.
//
// Single automatic-task activation: a driver and a bit-select waiter run in
// the same frame via fork/join. Prints PASS only if the bit-select edge is
// observed.
module top;
  task automatic watch(output int fired);
    reg [5:1] pos;
    fired = 0;
    pos = 5'b00000;
    fork
      begin #10 pos[2] = 1; end          // posedge pos[2]
      begin @(posedge pos[2]) fired = 1; end
    join
  endtask

  int f;
  initial begin
    watch(f);
    if (f === 1) $display("PASS: auto-task bit-select event");
    else         $display("FAIL: fired=%0d expected 1", f);
    $finish;
  end
endmodule
