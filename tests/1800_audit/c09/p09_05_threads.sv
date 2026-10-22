// IEEE 1800-2017 §9.5 (p. 224) / IEEE 1800-2023 §9.5 (p. 240)
// Probe each thread form listed by §9.5 in both language editions.
module test;
  bit clk = 0;
  bit en = 0;
  bit d = 0;
  int initial_ran = 0;
  int always_ran = 0;
  int comb_ran = 0;
  int latch_ran = 0;
  int ff_ran = 0;
  int fork_ran = 0;
  int dynamic_ran = 0;
  int src_val = 0;
  wire wire_val;

  assign wire_val = src_val;

  always @(src_val) begin
    always_ran = (src_val != 0);
  end

  always_comb begin
    comb_ran = (wire_val != 0);
  end

  always_latch begin
    if (en) latch_ran = d;
  end

  always_ff @(posedge clk) begin
    ff_ran = d;
  end

  initial begin
    initial_ran = 1;

    #1;
    src_val = 1;

    #1;
    en = 1;
    d = 1;

    #1;
    clk = 1;

    fork
      begin
        #5;
        fork_ran = 1;
      end
      begin
        process p;
        p = process::self();
        if (p != null) dynamic_ran = 1;
      end
    join

    #10;
    if (!initial_ran || !always_ran || !comb_ran || !latch_ran || !ff_ran || !fork_ran || !dynamic_ran) begin
      $fatal(1, "Thread execution failed: init=%0d alw=%0d comb=%0d latch=%0d ff=%0d fork=%0d dyn=%0d",
             initial_ran, always_ran, comb_ran, latch_ran, ff_ran, fork_ran, dynamic_ran);
    end
    $display("PASS all process execution threads clause 9.5");
    $finish;
  end

  final begin
    if (initial_ran && always_ran && comb_ran && latch_ran && ff_ran && fork_ran && dynamic_ran) begin
      $display("PASS final procedure thread clause 9.5");
    end
  end
endmodule
