// IEEE 1800-2017 10.4 / 10.9: an assignment pattern written
// NON-BLOCKING into a WHOLE unpacked array.
//
// The blocking spelling has always worked -- the code generator
// distributes the pattern's entries across the array's words. The
// non-blocking spelling had no path: the r-value evaluator pushed a
// zero of the l-value's width in place of the pattern, and because a
// whole-array l-value carries no word index the code generator then
// ABORTED (`assign_to_lvector: Assertion 'word_ix' failed'). Every
// shape below aborted the compiler.
//
// OpenTitan's otbn_kmac_if.sv:734 is the one-line version:
//     kmac_cfg_q <= '{default: kmac_cfg_t'('0)};
//
// Covered here: packed-struct elements, a `default:' fill, a
// multi-dimensional array (nested patterns), and an intra-assignment
// delay -- which must land every word at the same instant.
module sv_uarray_nb_pattern;

  typedef struct packed {
    logic [3:0] hi;
    logic [3:0] lo;
  } cfg_t;

  cfg_t       q [2];        // packed-struct elements, explicit entries
  logic [7:0] f [2];        // `default:' fill
  logic [7:0] w [2][3];     // multi-dimensional, nested patterns
  logic [7:0] d [2];        // intra-assignment delay

  reg clk = 0;
  integer errors = 0;

  always #5 clk = ~clk;

  always_ff @(posedge clk) q <= '{cfg_t'(8'h12), cfg_t'(8'h34)};
  always_ff @(posedge clk) f <= '{default: 8'h5A};
  always_ff @(posedge clk) w <= '{'{8'h11, 8'h22, 8'h33},
                                  '{8'h44, 8'h55, 8'h66}};
  always @(posedge clk)    d <= #1 '{8'h7E, 8'h8F};

  task check(input [7:0] got, input [7:0] exp, input [127:0] what);
    begin
      if (got !== exp) begin
        $display("MISMATCH %0s: got %h expected %h", what, got, exp);
        errors = errors + 1;
      end
    end
  endtask

  initial begin
    foreach (q[i]) q[i] = '0;
    foreach (f[i]) f[i] = 8'h00;
    foreach (w[i,j]) w[i][j] = 8'h00;
    foreach (d[i]) d[i] = 8'h00;

    @(posedge clk);
    @(posedge clk);

    $display("q = %h %h", q[0], q[1]);
    $display("f = %h %h", f[0], f[1]);
    $display("w = %h %h %h / %h %h %h",
             w[0][0], w[0][1], w[0][2], w[1][0], w[1][1], w[1][2]);
    $display("d = %h %h", d[0], d[1]);

    check(q[0], 8'h12, "q[0]");
    check(q[1], 8'h34, "q[1]");

    check(f[0], 8'h5A, "f[0]");
    check(f[1], 8'h5A, "f[1]");

    check(w[0][0], 8'h11, "w[0][0]");
    check(w[0][1], 8'h22, "w[0][1]");
    check(w[0][2], 8'h33, "w[0][2]");
    check(w[1][0], 8'h44, "w[1][0]");
    check(w[1][1], 8'h55, "w[1][1]");
    check(w[1][2], 8'h66, "w[1][2]");

    check(d[0], 8'h7E, "d[0]");
    check(d[1], 8'h8F, "d[1]");

    if (errors == 0)
      $display("PASSED");
    else
      $display("FAILED -- %0d mismatches", errors);
    $finish;
  end

endmodule
