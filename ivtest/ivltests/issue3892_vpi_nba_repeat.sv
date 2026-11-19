module top;
  bit clk, q, rhs, guard, timed_q, clocked_q;
  logic signed [7:0] count_base;

  task automatic reported;
    begin
      q <=
        repeat (
          6'sd2)
        @(posedge clk) rhs;
      rhs = 0;
    end
  endtask

  logic signed [5:0] count_words [4:3];
  localparam logic [7:0] count_param = 8'hfd;

  task cases;
    begin : controls
      q <= repeat (5'd0) @(posedge clk) rhs;
      q <= repeat (5'sd1) @(posedge clk) rhs;
      q <= repeat (6'sb00xz00) @(posedge clk) rhs;
      q <= repeat (count_base + 8'sd1) @(posedge clk iff guard) rhs;
      q <= rhs;
      q <= @(posedge clk) rhs;
      q <= repeat ($issue3892_count() + 1) @(posedge clk) rhs;
      q <= repeat (count_words[3]) @(posedge clk) rhs;
      q <= repeat (16'($unsigned(count_base))) @(posedge clk) rhs;
      q <= repeat ($signed(count_param)) @(posedge clk) rhs;
    end
  endtask

  clocking cb @(posedge clk);
    output clocked_q;
  endclocking

  task clocked;
    cb.clocked_q <= ##2 rhs;
  endtask

  initial begin
    count_base = 1;
    count_words[3] = 7;
    $issue3892_probe(2);
    rhs = 1;
    timed_q <= repeat (count_base + 8'sd1) @(posedge clk) rhs;

    count_base = 4;
    rhs = 0;
    $issue3892_probe(5);
    if (timed_q !== 0) $fatal(1, "NBA before the first edge");
    #1 clk = 1;
    #1;
    if (timed_q !== 0) $fatal(1, "NBA after just one edge");
    clk = 0;
    #1 clk = 1;
    #1;
    if (timed_q !== 1) $fatal(1, "NBA failed to update with captured RHS");
    $issue3892_finish;
  end
endmodule
