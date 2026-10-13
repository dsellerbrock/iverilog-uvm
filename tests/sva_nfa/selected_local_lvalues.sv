// IEEE 1800-2017/2023 16.10; Annex A notes 46/51 require constant selects.
// NFA-EXPECT-FALLBACK: fixed-delay local updates use $past lowering.
module selected_local_lvalues;
  logic clk = 0;
  logic part_start = 0, bit_start = 0;
  logic [3:0] src = 4'ha;
  always #5 clk = ~clk;

  property p;
    logic [7:0] acc;
    (part_start, acc = 8'h50) ##1
    (1'b1, acc[3:0] = src) ##1
    (acc == {4'h5, src}) ##1
    (1'b1, acc[7:4] = src) ##1
    (acc == {src, src});
  endproperty

  property q;
    logic [7:0] acc;
    (bit_start, acc = 8'hA9) ##1
    (1'b1, acc[2] = 1'b1) ##1
    (1'b1, acc[3] = 1'b0) ##1
    (acc == 8'hA5);
  endproperty

  property r;
    logic [15:8] acc;
    (part_start, acc = 8'h50) ##1
    (1'b1, acc[11:8] = src) ##1
    (acc == {4'h5, src}) ##1
    (1'b1, acc[15:12] = src) ##1
    (acc == {src, src});
  endproperty

  property s;
    logic [0:7] acc;
    (bit_start, acc = 8'hA9) ##1
    (1'b1, acc[0:3] = 4'h5) ##1
    (acc == 8'h59) ##1
    (1'b1, acc[4:7] = 4'h3) ##1
    (acc == 8'h53);
  endproperty

  cover property (@(posedge clk) p);
  cover property (@(posedge clk) q);
  cover property (@(posedge clk) r);
  cover property (@(posedge clk) s);

  initial begin
    @(negedge clk) part_start = 1; bit_start = 1;
    @(negedge clk) part_start = 0; bit_start = 0;
    repeat (6) @(negedge clk);
    if (_ivl_sva0_cnt0 !== 1 || _ivl_sva1_cnt0 !== 1
        || _ivl_sva2_cnt0 !== 1 || _ivl_sva3_cnt0 !== 1)
      $fatal(1, "selected local lvalues: parts=%0d bits=%0d offset=%0d asc=%0d",
             _ivl_sva0_cnt0, _ivl_sva1_cnt0,
             _ivl_sva2_cnt0, _ivl_sva3_cnt0);
    $display("PASS selected local lvalues");
    $finish(0);
  end
endmodule
