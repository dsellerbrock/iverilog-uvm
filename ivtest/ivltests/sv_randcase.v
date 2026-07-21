// IEEE 1800-2017 18.16: randcase selects one branch at random, weighted by
// each item's expression. Weights are evaluated once per execution; a zero
// total weight executes no branch. Previously randcase emitted a `sorry`.
module sv_randcase;
  int hits[3];
  int evals = 0;
  function int w3();  // side-effect witness: must be evaluated exactly once
    evals++;
    return 3;
  endfunction
  int errors = 0;
  initial begin
    // Weighted distribution: with weights 1:2:3 over 6000 draws each bucket
    // should be within a wide tolerance of 1000:2000:3000.
    for (int i = 0; i < 6000; i++)
      randcase
        1: hits[0]++;
        2: hits[1]++;
        3: hits[2]++;
      endcase
    if (!(hits[0] > 500  && hits[0] < 1500)) begin $display("FAIL w1 %0d", hits[0]); errors++; end
    if (!(hits[1] > 1400 && hits[1] < 2600)) begin $display("FAIL w2 %0d", hits[1]); errors++; end
    if (!(hits[2] > 2300 && hits[2] < 3700)) begin $display("FAIL w3 %0d", hits[2]); errors++; end

    // Zero total weight: no branch runs.
    hits = '{0,0,0};
    repeat (10) randcase 0: hits[0]++; 0: hits[1]++; endcase
    if (hits[0] != 0 || hits[1] != 0) begin $display("FAIL zero-weight"); errors++; end

    // Weight expression evaluated exactly once.
    evals = 0;
    randcase w3(): ; 1: ; endcase
    if (evals != 1) begin $display("FAIL evals=%0d (expect 1)", evals); errors++; end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d)", errors);
  end
endmodule
