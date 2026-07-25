// IEEE 1800-2017 10.9.1: `'{default: value}' supplies every element or
// member the pattern does not name.
//
// The parser built the standalone form as a ONE-ELEMENT POSITIONAL
// pattern, discarding the `default' key, so every use was an arity error
// -- "Unpacked array assignment pattern expects 4 element(s) ... Found
// 1" -- for fixed arrays, multidimensional arrays, packed arrays and
// structs alike. It is the named form with the sole key `default', and
// the target's own dimension (or member list) says how many copies it
// stands for.
//
// Against the pre-fix compiler this file produced five elaboration
// errors and no output at all.
module main;

  typedef struct packed { bit [3:0] x; bit [3:0] y; } pst;
  typedef struct { int a; int b; } ust;

  int    fixed [4];
  int    init  [4] = '{default:7};   // declaration initializer
  int    multi [2][3];
  bit [3:0] packed_arr [2];
  bit [2:0][3:0] pk;                 // packed array of four-bit elements
  pst    ps;
  ust    us;
  int    partial_named [4];

  int fails = 0;

  initial begin
    fixed = '{default:5};
    for (int i = 0; i < 4; i++)
      if (fixed[i] != 5) begin
        fails++;
        $display("FAILED -- fixed[%0d]=%0d (want 5)", i, fixed[i]);
      end

    for (int i = 0; i < 4; i++)
      if (init[i] != 7) begin
        fails++;
        $display("FAILED -- declaration initializer init[%0d]=%0d (want 7)", i, init[i]);
      end

    multi = '{default:3};
    for (int i = 0; i < 2; i++)
      for (int j = 0; j < 3; j++)
        if (multi[i][j] != 3) begin
          fails++;
          $display("FAILED -- multi[%0d][%0d]=%0d (want 3)", i, j, multi[i][j]);
        end

    packed_arr = '{default:4'hA};
    for (int i = 0; i < 2; i++)
      if (packed_arr[i] !== 4'hA) begin
        fails++;
        $display("FAILED -- packed_arr[%0d]=%0h (want a)", i, packed_arr[i]);
      end

    pk = '{default:4'h6};
    if (pk !== 12'h666) begin
      fails++;
      $display("FAILED -- packed array pk=%0h (want 666)", pk);
    end

    ps = '{default:4'h9};
    if (ps !== 8'h99) begin
      fails++;
      $display("FAILED -- packed struct ps=%0h (want 99)", ps);
    end

    us = '{default:11};
    if (us.a != 11 || us.b != 11) begin
      fails++;
      $display("FAILED -- unpacked struct us.a=%0d us.b=%0d (want 11,11)", us.a, us.b);
    end

    // `default' alongside explicit members: the named ones win.
    us = '{a: 1, default: 2};
    if (us.a != 1 || us.b != 2) begin
      fails++;
      $display("FAILED -- mixed named/default us.a=%0d (want 1) us.b=%0d (want 2)",
               us.a, us.b);
    end

    // A.6.7.1 replication form: `'{N{...}}'. The count was parsed and then
    // dropped everywhere, so this assigned a SINGLE element -- an arity
    // error for an unpacked target, and silently wrong for a packed one
    // (the value landed in the low element, the rest stayed zero).
    fixed = '{4{6}};
    for (int i = 0; i < 4; i++)
      if (fixed[i] != 6) begin
        fails++;
        $display("FAILED -- replication fixed[%0d]=%0d (want 6)", i, fixed[i]);
      end

    pk = '{3{4'h5}};
    if (pk !== 12'h555) begin
      fails++;
      $display("FAILED -- packed replication pk=%0h (want 555)", pk);
    end

    multi = '{2{'{3{9}}}};
    for (int i = 0; i < 2; i++)
      for (int j = 0; j < 3; j++)
        if (multi[i][j] != 9) begin
          fails++;
          $display("FAILED -- nested replication multi[%0d][%0d]=%0d (want 9)",
                   i, j, multi[i][j]);
        end

    // A later whole-array pattern must still work normally.
    partial_named = '{1, 2, 3, 4};
    if (partial_named[0] != 1 || partial_named[3] != 4) begin
      fails++;
      $display("FAILED -- positional pattern broke: %0d..%0d",
               partial_named[0], partial_named[3]);
    end

    if (fails == 0) $display("PASSED");
    $finish(0);
  end

endmodule
