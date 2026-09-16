// IEEE 1800-2017/2023 A.2.10: assertion_variable_declaration is
// data_type list_of_variable_decl_assignments ';' -- a comma-separated
// identifier list, same as any other variable declaration. Confirmed
// independently: slang (--std 1800-2017) accepts `logic [5:0] x, y;`
// and `int a, b;` inside a property's local-variable section with 0
// errors, 0 warnings.
//
// Real, unmodified Caliptra formal-verification source relies on
// exactly this shape (src/ecc/formal/properties/
// fv_ecc_pm_ctrl_abstract.sv, three properties each declaring
// `logic[5:0] addra,addrb;`): before this fix it was rejected with a
// plain "syntax error" pointing at the declaration line, because every
// alternative of parse.y's sva_int_local_declarations nonterminal
// accepted exactly one IDENTIFIER per statement -- there was no comma
// continuation within a single declaration, only the (different,
// already-working) ability to chain separate `;'-terminated
// declarations of the SAME kind one after another.
//
// Deliberately does not mix `int` and `logic` local declarations within
// one property: that combination hits a separate, pre-existing defect
// (undeclared even with zero commas involved -- see DISCOVERED_DEBT.md)
// unrelated to the comma-list gap this test targets.
module main;
  bit clk = 0;
  int fails = 0;

  always #5 clk = ~clk;
  default clocking cb @(posedge clk); endclocking

  // logic[N:0] form, two comma-separated identifiers -- the exact shape
  // used by the real Caliptra source.
  property p_logic_pair;
    logic [5:0] x, y;
    (1'b1, x = 6'd5) ##1 (1'b1, y = 6'd9) ##1 (x == 6'd5 && y == 6'd9);
  endproperty
  ap_logic: assert property (p_logic_pair) else fails++;

  // int form, two comma-separated identifiers, chained with a further
  // separate same-kind declaration -- exercises both the base rule and
  // the "sva_int_local_declarations sva_int_local_declarations ..."
  // chain rule added by this fix.
  property p_int_chain;
    int a, b;
    int c;
    (1'b1, a = 1) ##1 (1'b1, b = 2) ##1 (1'b1, c = 3)
      ##1 (a == 1 && b == 2 && c == 3);
  endproperty
  ap_int: assert property (p_int_chain) else fails++;

  initial begin
    @(posedge clk); #1;
    @(posedge clk); #1;
    @(posedge clk); #1;
    @(posedge clk); #1;
    if (fails != 0) begin
      $display("FAILED, fails=%0d", fails);
      $finish;
    end
    $display("PASSED");
    $finish;
  end
endmodule
