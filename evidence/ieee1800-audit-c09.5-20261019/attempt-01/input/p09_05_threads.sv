// IEEE 1800-2017 §9.5 (p. 224) / IEEE 1800-2023 §9.5 (p. 240)
// Thread creation for initial, always_comb, fork branch, dynamic process,
// continuous assignment, and final procedure.
module test;
  int initial_ran = 0;
  int comb_ran = 0;
  int fork_ran = 0;
  int dynamic_ran = 0;
  int src_val = 0;
  wire wire_val;

  assign wire_val = src_val;

  always_comb begin
    comb_ran = (wire_val != 0);
  end

  initial begin
    initial_ran = 1;
    src_val = 1;

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
    if (!initial_ran || !comb_ran || !fork_ran || !dynamic_ran) begin
      $fatal(1, "Thread execution failed: init=%0d comb=%0d fork=%0d dyn=%0d",
             initial_ran, comb_ran, fork_ran, dynamic_ran);
    end
    $display("PASS process execution threads clause 9.5");
    $finish;
  end

  final begin
    if (initial_ran && comb_ran && fork_ran && dynamic_ran) begin
      $display("PASS final procedure thread clause 9.5");
    end
  end
endmodule
