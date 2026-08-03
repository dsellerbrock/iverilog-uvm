`begin_keywords "1800-2012"

module main;
  logic       clk;
  logic       reset_n;
  logic       low_enable;
  logic       high_enable;
  logic [3:0] low_data;
  logic [3:0] high_data;
  logic [7:0] state;

  // OpenTitan uses separate generated always_ff processes for disjoint packed
  // fields. Each asynchronous reset covers every field owned by its process,
  // even though it intentionally covers only part of the shared vector.
  always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n)
      state[3:0] <= '0;
    else if (low_enable)
      state[3:0] <= low_data;
  end

  always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n)
      state[7:4] <= '0;
    else if (high_enable)
      state[7:4] <= high_data;
  end

  task automatic tick;
    #1 clk = 1'b1;
    #1 clk = 1'b0;
  endtask

  task automatic fail(input string label, input logic [7:0] expected);
    $display("FAILED -- %s state=%h expected=%h", label, state, expected);
    $finish;
  endtask

  (* ivl_synthesis_off *)
  initial begin
    clk = 1'b0;
    reset_n = 1'b1;
    low_enable = 1'b0;
    high_enable = 1'b0;
    low_data = 4'h0;
    high_data = 4'h0;

    #1 reset_n = 1'b0;
    #1;
    if (state !== 8'h00) fail("asynchronous reset", 8'h00);
    reset_n = 1'b1;

    low_enable = 1'b1;
    high_enable = 1'b1;
    low_data = 4'h5;
    high_data = 4'ha;
    tick();
    if (state !== 8'ha5) fail("both fields update", 8'ha5);

    low_enable = 1'b0;
    high_enable = 1'b1;
    low_data = 4'hf;
    high_data = 4'h3;
    tick();
    if (state !== 8'h35) fail("low field holds", 8'h35);

    $display("PASSED");
    $finish;
  end
endmodule

`end_keywords
