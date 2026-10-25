`timescale 1ns/1ns

module p31_tchk3;
  reg rst_recrem = 0, clk_recrem = 0;
  reg c1_timeskew = 0, c2_timeskew = 0;
  reg c3_ref_first = 0, c4_ref_first = 0;
  reg c3_data_first = 0, c4_data_first = 0;
  reg edge_clk = 0, edge_data = 0;
  reg cond_clk = 0, cond_data = 0, cond_en = 0;
  reg [3:0] vector_data = 0;
  reg vector_clk = 0;
  reg notifier = 0;
  integer notifier_changes = 0;

  specify
    $recrem(posedge rst_recrem, posedge clk_recrem, 3, 2, notifier);
    $timeskew(posedge c1_timeskew, posedge c2_timeskew, 2, notifier);
    $fullskew(posedge c3_ref_first, posedge c4_ref_first, 2, 2, notifier);
    $fullskew(posedge c3_data_first, posedge c4_data_first, 2, 2, notifier);
    $setup(edge_data, edge [01] edge_clk, 3, notifier);
    $setup(cond_data &&& cond_en, posedge cond_clk, 3, notifier);
    $setup(vector_data, posedge vector_clk, 3, notifier);
  endspecify

  always @(notifier) notifier_changes++;

  initial begin
    #10 rst_recrem = 1;
    #1 clk_recrem = 1;
    #4 clk_recrem = 0;
    rst_recrem = 0;
    #5 clk_recrem = 1;
    #1 rst_recrem = 1;
  end

  initial begin
    #40 c1_timeskew = 1;
    #3 c2_timeskew = 1;
  end

  initial begin
    #60 c3_ref_first = 1;
    #3 c4_ref_first = 1;
    c3_ref_first = 0;
    #1 c3_ref_first = 1;
  end

  initial begin
    #70 c4_data_first = 1;
    #3 c3_data_first = 1;
    c4_data_first = 0;
    #1 c4_data_first = 1;
  end

  initial begin
    #100 edge_data = 1;
    #1 edge_clk = 1;
    #1 edge_clk = 0;
    #8 edge_data = 0;
    #1 edge_clk = 1'bx;
    #9 edge_data = 1;
    #1 edge_clk = 1;
  end

  initial begin
    #129 cond_en = 1;
    cond_data = 1;
    #1 cond_clk = 1;
    #2 cond_clk = 0;
    #7 cond_en = 0;
    cond_data = 0;
    #1 cond_clk = 1;
  end

  initial begin
    #149 vector_data[0] = 1;
    #1 vector_clk = 1;
  end

  initial begin
    #160 $display("N %0d %b", notifier_changes, notifier);
  end
endmodule
