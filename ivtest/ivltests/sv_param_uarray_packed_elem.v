// An unpacked-array PARAMETER whose element is a multi-dimensional packed
// vector, read with a constant index and with a run-time index.
//
// Every check here compares the parameter against a plain VARIABLE of the
// identical type holding the identical values. The variable is the oracle:
// the two spellings must agree, and where they disagree the parameter path
// is the one that is wrong.
//
// What this pins:
//
//  * `P[1][1]` on `localparam logic [1:0][5:0] P [2]` returned bit 1
//    instead of the upper 6-bit ELEMENT. Exit 0, no error, no warning --
//    a silent wrong result. The element's dimensions were taken from the
//    per-element INFERRED type, which flattens a multi-dimensional packed
//    element to a single dimension.
//
//  * `P[i][11:2]` -- a run-time element index FOLLOWED by a further
//    select -- was refused outright ("a variable element index combined
//    with further selects on array parameter is not supported"). That is
//    OpenTitan spi_tpm.sv:786. It needs the same element dimensions,
//    delivered to the variable-index table instead.
//
//  * ASCENDING array declarations. The element table is always laid out
//    ascending from the low index, so an array dimension handed to the
//    index normalizer as (left, right) rather than (max, min) silently
//    REVERSES `[1:4]` and `[0:3]` -- ASC[1] would read ASC[4]. There is
//    no diagnostic for that, so it is checked by value here.
module sv_param_uarray_packed_elem;

  // Multi-dimensional packed element, descending array bounds.
  localparam logic [1:0][5:0] P [2] = '{12'h024, 12'h824};
  logic [1:0][5:0] V [2];

  // Ascending array bounds, both origins.
  localparam logic [7:0] ASC1 [1:4] = '{8'h11, 8'h22, 8'h33, 8'h44};
  localparam logic [7:0] ASC0 [0:3] = '{8'hA0, 8'hB1, 8'hC2, 8'hD3};
  logic [7:0] WASC1 [1:4];
  logic [7:0] WASC0 [0:3];

  // The OpenTitan spi_tpm.sv:786 shape: run-time index, then a part select.
  localparam logic [11:0] TPM [2] = '{12'h024, 12'h824};
  logic [11:0] WTPM [2];

  integer errors = 0;

  task ck(input [31:0] got, input [31:0] exp, input [127:0] what);
    begin
      if (got !== exp) begin
        $display("MISMATCH %0s: got %0h expected %0h", what, got, exp);
        errors = errors + 1;
      end
    end
  endtask

  integer i;

  initial begin
    V[0] = 12'h024; V[1] = 12'h824;
    WASC1[1] = 8'h11; WASC1[2] = 8'h22; WASC1[3] = 8'h33; WASC1[4] = 8'h44;
    WASC0[0] = 8'hA0; WASC0[1] = 8'hB1; WASC0[2] = 8'hC2; WASC0[3] = 8'hD3;
    WTPM[0] = 12'h024; WTPM[1] = 12'h824;

    // --- constant element index, then a packed-element index ---
    // P[1] is 12'h824 == {6'h20, 6'h24}; [1] selects the UPPER element.
    ck(P[0][1], 6'h00, "P[0][1]");
    ck(P[1][1], 6'h20, "P[1][1]");
    ck(P[0][0], 6'h24, "P[0][0]");
    ck(P[1][0], 6'h24, "P[1][0]");
    // ...and against the variable oracle.
    ck(P[0][1], V[0][1], "P[0][1] vs V");
    ck(P[1][1], V[1][1], "P[1][1] vs V");
    ck(P[0][0], V[0][0], "P[0][0] vs V");
    ck(P[1][0], V[1][0], "P[1][0] vs V");

    // --- run-time element index, whole element ---
    for (i = 0; i < 2; i = i + 1)
      ck(TPM[i], WTPM[i], "TPM[i] vs W");

    // --- run-time element index, then a further select ---
    for (i = 0; i < 2; i = i + 1) begin
      ck(P[i][1], V[i][1], "P[i][1] vs V");
      ck(P[i][0], V[i][0], "P[i][0] vs V");
      ck(TPM[i][11:2],  WTPM[i][11:2],  "TPM[i][11:2] vs W");
      ck(TPM[i][8],     WTPM[i][8],     "TPM[i][8] vs W");
      ck(TPM[i][11-:4], WTPM[i][11-:4], "TPM[i][11-:4] vs W");
    end

    // ...and the same on ASCENDING bounds, where a (left,right) array
    // dimension would reverse the table with no diagnostic.
    for (i = 1; i <= 4; i = i + 1)
      ck(ASC1[i][7:4], WASC1[i][7:4], "ASC1[i][7:4] vs W");
    for (i = 0; i <= 3; i = i + 1)
      ck(ASC0[i][3:0], WASC0[i][3:0], "ASC0[i][3:0] vs W");

    // --- ascending array bounds must not reverse ---
    for (i = 1; i <= 4; i = i + 1)
      ck(ASC1[i], WASC1[i], "ASC1[i] vs W");
    for (i = 0; i <= 3; i = i + 1)
      ck(ASC0[i], WASC0[i], "ASC0[i] vs W");
    // Pinned by value too, so a reversal that also flipped the oracle
    // could not hide.
    ck(ASC1[1], 8'h11, "ASC1[1]");
    ck(ASC1[4], 8'h44, "ASC1[4]");
    ck(ASC0[0], 8'hA0, "ASC0[0]");
    ck(ASC0[3], 8'hD3, "ASC0[3]");

    if (errors == 0)
      $display("PASSED");
    else
      $display("FAILED -- %0d mismatches", errors);
    $finish;
  end

endmodule
