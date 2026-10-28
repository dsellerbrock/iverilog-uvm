module issue1361_past_omitted_depth;
  bit clk = 0;
  logic gate = 0, data = 0;
  integer cycle = 0;

  always #5 clk = ~clk;
  always @(posedge clk) cycle <= cycle + 1;

  always @(negedge clk) begin
    case (cycle)
      1: begin data = 1; gate = 1; end
      2: begin data = 0; gate = 1; end
      3: begin data = 1; gate = 0; end
    endcase
  end

  assert property (@(posedge clk) (cycle == 2) |->
                   ($past(data,,gate) === 1'b1))
    else $fatal(1, "gated past mismatch at cycle %0d", cycle);

  assert property (@(posedge clk) (cycle == 2) |->
                   ($past(data, , , @(posedge clk)) === 1'b1))
    else $fatal(1, "explicit-clock past mismatch at cycle %0d", cycle);

  assert property (@(posedge clk) (cycle == 3) |->
                   ($past(data,,gate) === 1'b0))
    else $fatal(1, "gated hold mismatch at cycle %0d", cycle);

  initial begin
    #46;
    $display("issue1361 omitted $past depth PASS");
    $finish(0);
  end
endmodule
