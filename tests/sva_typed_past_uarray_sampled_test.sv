package sva_typed_past_uarray_sampled_pkg;
  typedef enum logic [3:0] { Off = 4'h5, On = 4'ha } state_e;
  function automatic logic is_on(state_e value);
    return value == On;
  endfunction
endpackage

module sva_typed_past_uarray_sampled_test;
  import sva_typed_past_uarray_sampled_pkg::*;

  bit clk, rst_n, stable_trig, changed_trig;
  state_e [0:0] state_words;
  logic [127:0] data_words [2];
  int stable_passes, changed_passes, failures;

  always #5 clk = ~clk;

  assert property (@(posedge clk) disable iff (!rst_n)
                   stable_trig |=>
                     is_on($past(state_words[0])) && $stable(data_words))
    stable_passes++; else begin
      failures++;
      $display("stable/typed-past assertion failed at %0t", $time);
    end

  assert property (@(posedge clk) disable iff (!rst_n)
                   changed_trig |=> $changed(data_words))
    changed_passes++; else begin
      failures++;
      $display("changed-array assertion failed at %0t", $time);
    end

  initial begin
    rst_n = 0;
    state_words[0] = On;
    data_words = '{128'h10000000000000000000000000,
                   128'h20000000000000000000000000};
    @(negedge clk);
    rst_n = 1;
    stable_trig = 1;
    @(negedge clk);
    stable_trig = 0;
    repeat (2) @(negedge clk);

    changed_trig = 1;
    @(negedge clk);
    changed_trig = 0;
    data_words[1][120] = ~data_words[1][120];
    repeat (2) @(negedge clk);

    if (stable_passes != 1 || changed_passes != 1 || failures != 0)
      $fatal(1, "typed $past / unpacked sampled functions: %0d/%0d/%0d",
             stable_passes, changed_passes, failures);
    $display("PASS: typed $past and whole-array $stable/$changed");
    $finish;
  end
endmodule
