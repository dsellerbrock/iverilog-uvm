// A variable driven continuously on one packed element and
// procedurally on OTHERS is legal -- IEEE 1800-2017 6.5 prohibits
// mixing drivers on the same BITS, not on the same variable. Written
// with both drivers at module level this was already accepted; put the
// procedural driver inside a GENERATE block and it was rejected with
// "Variable 'st' cannot be driven by a continuous assignment".
//
// The var->uwire promotion in elab_net.cc ran before the l-value's bit
// range was known and gave up on peek_lref() != 0, a whole-signal count
// with no bit information -- and a generate block's processes register
// their l-values before a module-level continuous assign is elaborated.
// So the same design was accepted or rejected depending on elaboration
// order.
//
// This checks VALUES, not just acceptance: the chained rounds only
// produce the expected result if each element is driven by the driver
// that owns it.
module sv_uwire_promote_generate;

  parameter int N = 3;

  logic [N:0][7:0] st;
  logic      [7:0] seed;
  int errors = 0;

  // element 0 continuously, elements 1..N procedurally from a generate
  assign st[0] = seed;
  for (genvar r = 0; r < N; r++) begin : gen_round
    // Deliberately no intermediate variable: an always_comb that reads
    // a packed element, writes another element of the same variable,
    // AND writes an intermediate ends up with an empty sensitivity set
    // (a separate, pre-existing defect -- see
    // docs/conformance/repros/always_comb_temp_packed_sens.sv). Keeping
    // it out of this test keeps this test about the uwire promotion.
    always_comb st[r + 1] = (st[r] ^ 8'h0F) + 8'd1;
  end

  // a second, disjoint packed variable driven the other way round
  logic [31:0] v;
  always_comb v[7:0] = seed;
  assign v[15:8] = 8'hC3;

  task ck(input string t, input [7:0] got, input [7:0] exp);
    if (got !== exp) begin
      $display("FAIL %0s: got %h expected %h", t, got, exp);
      errors = errors + 1;
    end
  endtask

  function [7:0] round(input [7:0] x);
    round = (x ^ 8'h0F) + 8'd1;
  endfunction

  initial begin
    seed = 8'hA5; #1;
    ck("st0", st[0], 8'hA5);
    ck("st1", st[1], round(8'hA5));
    ck("st2", st[2], round(round(8'hA5)));
    ck("st3", st[3], round(round(round(8'hA5))));
    ck("v_lo", v[7:0],  8'hA5);
    ck("v_hi", v[15:8], 8'hC3);

    seed = 8'h3C; #1;
    ck("st0b", st[0], 8'h3C);
    ck("st1b", st[1], round(8'h3C));
    ck("st3b", st[3], round(round(round(8'h3C))));
    ck("v_lob", v[7:0],  8'h3C);
    ck("v_hib", v[15:8], 8'hC3);

    if (errors == 0) $display("PASSED");
    else $display("FAILED with %0d errors", errors);
  end

endmodule
