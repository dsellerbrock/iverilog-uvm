// Two defects on a packed array whose element is a packed STRUCT.
//
// 1. An assignment pattern onto such a target (IEEE 1800-2017 10.9.2)
//    was rejected. The declared type flattens to a dimension list that
//    has already dissolved the struct into a bit range, so the nested
//    pattern was matched against that WIDTH -- a 65-bit struct was told
//    it "expects 65 element(s)" -- and the member names had nowhere to
//    bind.
//
// 2. Selecting an element of such a PARAMETER silently produced the
//    wrong value: a zero of the parameter's FULL width, with no error
//    and no warning. The identical bit pattern declared as
//    `logic [1:0][63:0]' read back correctly, so the two spellings of
//    one value disagreed. That is the defect this test exists for; the
//    P/Q pair below is the direct comparison.
//
// Member access ON a parameter (`P[0].base') is a separate, still
// unimplemented construct -- it is rejected loudly -- so element values
// are compared as whole elements, and members are read through a
// variable copy.
module sv_packed_struct_array_pattern;

  typedef struct packed {
    logic [31:0] base;
    logic [31:0] limit;
    logic        en;
  } r_t;

  // (1) assignment pattern onto a packed array of packed structs
  localparam r_t [0:0] R1 = '{
    '{ base: 32'h0000_0000, limit: 32'hFFFF_FFFF, en: 1'b1 }
  };
  localparam r_t [1:0] R2 = '{
    '{ base: 32'h1111_1111, limit: 32'h2222_2222, en: 1'b0 },
    '{ base: 32'h3333_3333, limit: 32'h4444_4444, en: 1'b1 }
  };

  // (2) the same 130 bits, declared two ways. Built by concatenation so
  // the two elements are unambiguous.
  localparam logic [64:0] E1 = {32'h1111_1111, 32'h2222_2222, 1'b0};
  localparam logic [64:0] E0 = {32'h3333_3333, 32'h4444_4444, 1'b1};
  localparam logic [1:0][64:0] P = {E1, E0};
  localparam r_t  [1:0]        Q = {E1, E0};

  r_t [1:0] rv;
  r_t       one;
  int errors = 0;

  task ck(input string t, input [64:0] got, input [64:0] exp);
    if (got !== exp) begin
      $display("FAIL %0s: got %h expected %h", t, got, exp);
      errors = errors + 1;
    end
  endtask

  initial begin
    // -- pattern built the right constant, element by element --
    // '{a, b} fills left to right, so a lands in the LEFTMOST index.
    ck("R1[0]",  R1[0], {32'h0000_0000, 32'hFFFF_FFFF, 1'b1});
    ck("R2[1]",  R2[1], {32'h1111_1111, 32'h2222_2222, 1'b0});
    ck("R2[0]",  R2[0], {32'h3333_3333, 32'h4444_4444, 1'b1});

    // -- struct element select must agree with the vector spelling --
    ck("P[1]", P[1], E1);
    ck("P[0]", P[0], E0);
    ck("Q[1]", Q[1], P[1]);
    ck("Q[0]", Q[0], P[0]);
    // width, not just value: a full-width zero-extension used to hide here
    if ($bits(Q[1]) != 65) begin
      $display("FAIL Q[1] width: %0d expected 65", $bits(Q[1]));
      errors = errors + 1;
    end

    // -- members, read through a variable copy --
    one = Q[1];
    ck("Q1.base",  {33'b0, one.base},  {33'b0, 32'h1111_1111});
    ck("Q1.limit", {33'b0, one.limit}, {33'b0, 32'h2222_2222});
    ck("Q1.en",    {64'b0, one.en},    65'd0);
    one = R2[0];
    ck("R20.base", {33'b0, one.base},  {33'b0, 32'h3333_3333});
    ck("R20.en",   {64'b0, one.en},    65'd1);

    // -- the same pattern onto a VARIABLE, with direct member reads --
    rv = '{ '{ base: 32'hAAAA_AAAA, limit: 32'hBBBB_BBBB, en: 1'b1 },
            '{ base: 32'hCCCC_CCCC, limit: 32'hDDDD_DDDD, en: 1'b0 } };
    ck("rv1.base", {33'b0, rv[1].base},  {33'b0, 32'hAAAA_AAAA});
    ck("rv1.limit",{33'b0, rv[1].limit}, {33'b0, 32'hBBBB_BBBB});
    ck("rv1.en",   {64'b0, rv[1].en},    65'd1);
    ck("rv0.base", {33'b0, rv[0].base},  {33'b0, 32'hCCCC_CCCC});
    ck("rv0.en",   {64'b0, rv[0].en},    65'd0);

    if (errors == 0) $display("PASSED");
    else $display("FAILED with %0d errors", errors);
  end

endmodule
