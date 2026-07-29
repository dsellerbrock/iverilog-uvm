// Selects on multi-dimensional packed PARAMETERS must address ELEMENTS,
// not flattened bits, for the inline and the typedef'd declaration
// alike, and every partial-selection form must land on the same
// canonical offsets a same-typed SIGNAL uses.
//
// Every check reads a VALUE: a mis-scaled offset still elaborates and
// still runs, and only the value shows it (an identity permutation that
// read 8'h77 instead of 8'ha5 is how this family was found).
module main;

  // The original OpenTitan-derived shape: an identity permutation.
  parameter logic [7:0][2:0] Perm = {
    3'd7, 3'd6, 3'd5, 3'd4,
    3'd3, 3'd2, 3'd1, 3'd0
  };

  typedef logic [7:0][2:0] perm_t;
  parameter perm_t PermT = {
    3'd7, 3'd6, 3'd5, 3'd4,
    3'd3, 3'd2, 3'd1, 3'd0
  };

  localparam logic [7:0][2:0] PermL = {
    3'd7, 3'd6, 3'd5, 3'd4,
    3'd3, 3'd2, 3'd1, 3'd0
  };

  // Ascending outer dimension.
  parameter logic [0:7][2:0] PermA = {
    3'd0, 3'd1, 3'd2, 3'd3,
    3'd4, 3'd5, 3'd6, 3'd7
  };

  // Three packed dimensions.
  localparam logic [1:0][1:0][3:0] T3 = {4'hA, 4'hB, 4'hC, 4'hD};

  // A same-typed SIGNAL as the known-good control path.
  logic [7:0][2:0] perm_sig;

  // Parameter expression used as an index.
  localparam int PIDX = 1;

  logic [7:0] lfsr;
  logic [7:0] data_o;

  // Continuous-assignment rvalue path, genvar (constant) indices.
  for (genvar i = 0; i < 8; i++) begin : g
    assign data_o[i] = lfsr[Perm[i]];
  end

  int errors = 0;

  task check_int(input string what, input int got, input int exp);
    if (got !== exp) begin
      errors++;
      $display("FAILED: %0s = %0d, expected %0d", what, got, exp);
    end
  endtask

  initial begin
    lfsr = 8'ha5;
    perm_sig = Perm;
    #1;

    // Identity permutation through the continuous-assign path.
    if (data_o !== 8'ha5) begin
      errors++;
      $display("FAILED: identity permutation gave %h, expected a5", data_o);
    end

    // Element selects, constant index: all declaration forms agree
    // with each other and with the signal control.
    for (int i = 0; i < 8; i++) begin
      check_int($sformatf("Perm[%0d]", i), Perm[i], i);
      check_int($sformatf("PermT[%0d]", i), PermT[i], i);
      check_int($sformatf("PermL[%0d]", i), PermL[i], i);
      check_int($sformatf("PermA[%0d]", i), PermA[i], i);
      check_int($sformatf("perm_sig[%0d]", i), perm_sig[i], i);
    end

    // Element select, variable index (procedural rvalue path).
    begin
      automatic int vi = 6;
      check_int("Perm[vi]", Perm[vi], 6);
      check_int("PermT[vi]", PermT[vi], 6);
      check_int("PermA[vi]", PermA[vi], 6);
    end

    // Two-index select: element then bit. Element 6 is 3'b110.
    if (Perm[6][2] !== 1'b1 || Perm[6][0] !== 1'b0) begin
      errors++;
      $display("FAILED: Perm[6][2]=%b Perm[6][0]=%b, expected 1 0",
               Perm[6][2], Perm[6][0]);
    end
    begin
      automatic int vi = 6, vj = 2;
      if (Perm[vi][vj] !== 1'b1) begin
        errors++;
        $display("FAILED: Perm[vi][vj]=%b, expected 1", Perm[vi][vj]);
      end
    end

    // Partial selection stopping before the final dimension: a part
    // select of the OUTER dimension addresses whole elements.
    if (Perm[3:2] !== {3'd3, 3'd2}) begin
      errors++;
      $display("FAILED: Perm[3:2]=%b, expected 011010", Perm[3:2]);
    end
    if (Perm[1+:2] !== {3'd2, 3'd1}) begin
      errors++;
      $display("FAILED: Perm[1+:2]=%b, expected 010001", Perm[1+:2]);
    end
    if (Perm[3-:2] !== {3'd3, 3'd2}) begin
      errors++;
      $display("FAILED: Perm[3-:2]=%b, expected 011010", Perm[3-:2]);
    end

    // Bit part-select within an element.
    if (Perm[6][1:0] !== 2'b10) begin
      errors++;
      $display("FAILED: Perm[6][1:0]=%b, expected 10", Perm[6][1:0]);
    end

    // Parameter expression as index.
    check_int("Perm[PIDX+1]", Perm[PIDX+1], 2);

    // Three-dimensional selects at every depth.
    if (T3[1] !== 8'hAB) begin
      errors++; $display("FAILED: T3[1]=%h, expected ab", T3[1]);
    end
    if (T3[1][0] !== 4'hB) begin
      errors++; $display("FAILED: T3[1][0]=%h, expected b", T3[1][0]);
    end
    if (T3[1][0][3] !== 1'b1) begin
      errors++; $display("FAILED: T3[1][0][3]=%b, expected 1", T3[1][0][3]);
    end
    begin
      automatic int k = 0;
      if (T3[1][k] !== 4'hB) begin
        errors++; $display("FAILED: T3[1][k]=%h, expected b", T3[1][k]);
      end
      if (T3[k][1] !== 4'hC) begin
        errors++; $display("FAILED: T3[k][1]=%h, expected c", T3[k][1]);
      end
    end

    // Out-of-range constant element select is x, not a wrong value.
    if (Perm[8] === 3'bxxx) ; else begin
      errors++; $display("FAILED: Perm[8]=%b, expected xxx", Perm[8]);
    end

    // Array query functions answer per dimension, like a signal.
    check_int("$size(Perm)", $size(Perm), 8);
    check_int("$size(Perm,2)", $size(Perm, 2), 3);
    check_int("$left(Perm)", $left(Perm), 7);
    check_int("$right(Perm)", $right(Perm), 0);
    check_int("$high(Perm)", $high(Perm), 7);
    check_int("$increment(Perm)", $increment(Perm), 1);
    check_int("$dimensions(Perm)", $dimensions(Perm), 2);
    check_int("$size(PermA)", $size(PermA), 8);
    check_int("$increment(PermA)", $increment(PermA), -1);
    check_int("$bits(Perm)", $bits(Perm), 24);

    if (errors == 0)
      $display("PASSED");
    else
      $display("FAILED: %0d error(s)", errors);
    $finish(0);
  end
endmodule
