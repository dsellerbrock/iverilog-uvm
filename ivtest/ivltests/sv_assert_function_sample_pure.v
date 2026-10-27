module top;
  bit clk = 0;
  logic value = 1'b1;
  logic [3:0] vector_value = 4'b0010;
  logic [3:0] memory [0:0];
  real real_value = 1.0;

  function automatic logic identity(input logic sample);
    identity = sample;
  endfunction

  function automatic real real_identity(input real sample);
    real_identity = sample;
  endfunction

  always #5 clk = ~clk;

  signal_sample: assert property (@(posedge clk) identity(value))
    else $fatal(1, "signal sample failed");
  constant_sample: assert property (@(posedge clk) identity(1'b1))
    else $fatal(1, "constant sample failed");
  select_sample: assert property (@(posedge clk) identity(vector_value[1]))
    else $fatal(1, "select sample failed");
  array_sample: assert property (@(posedge clk) identity(memory[0][1]))
    else $fatal(1, "array sample failed");
  real_sample: assert property (@(posedge clk) real_identity(real_value) > 0.0)
    else $fatal(1, "real sample failed");

  initial begin
    memory[0] = 4'b0010;
    #12;
    $display("PASSED");
    $finish(0);
  end
endmodule
