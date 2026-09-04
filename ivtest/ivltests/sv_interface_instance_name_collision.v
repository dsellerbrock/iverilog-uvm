// IEEE 1800-2017/2023 25.3 with 23.3.2 -- an interface INSTANCE may be named
// after its own interface type. `tl_if tl_if (...)' and `rstmgr_if rstmgr_if
// (...)' are pervasive in OpenTitan DV.
//
// The lexer hands such a name back as TYPE_IDENTIFIER, and
// `expr_primary: TYPE_IDENTIFIER' (parse.y, added so a type name can be a
// parameter actual, e.g. uvm_object_registry #(uvm_pool #(KEY,T))) is declared
// EARLIER than `hierarchy_identifier: TYPE_IDENTIFIER', so it won the
// reduce/reduce conflict. Member access still parsed, which is why the failure
// looked arbitrary -- only the indexed and l-value forms broke:
//
//     assign w = rstmgr_if.resets_o;      // accepted before the fix
//     assign w = rstmgr_if.resets_o[0];   // syntax error
//     rstmgr_if.resets_o = 4'd1;          // syntax error
//
// A shadowed struct typedef (`t t; ... t.a[0]') does NOT hit this: the lexer's
// scope test finds the variable and returns IDENTIFIER. An interface instance
// is not registered that way, so its name stays a type identifier.
//
// OpenTitan reaches this at rstmgr tb.sv:43,
//   .rst_n(rstmgr_if.resets_o.rst_lc_io_n[rstmgr_pkg::DomainMainSel])
// the first hard diagnostic for five rstmgr cores.

package sel_pkg;
  parameter int DomainMainSel = 1;
endpackage

interface rstmgr_if(input logic clk);
  typedef struct packed { logic [3:0] rst_lc_io_n; } resets_t;
  resets_t    resets_o;
  logic [3:0] flat_o;
endinterface

interface tl_if(input logic clk, input logic rst_n);
  logic [7:0] data;
endinterface

module main;

  int errors = 0;
  logic clk = 0;
  wire  w_idx, w_pkgidx, w_nested;

  // Instance named after its own interface type, referenced BEFORE it is
  // declared -- module items are order independent.
  tl_if tl_if (
    .clk,
    .rst_n(rstmgr_if.resets_o.rst_lc_io_n[sel_pkg::DomainMainSel])
  );

  rstmgr_if rstmgr_if (.clk);

  // continuous assigns through the collided name
  assign w_idx    = rstmgr_if.flat_o[0];
  assign w_pkgidx = rstmgr_if.flat_o[sel_pkg::DomainMainSel];
  assign w_nested = rstmgr_if.resets_o.rst_lc_io_n[2];

  // a distinct instance name is the control: this always worked
  rstmgr_if u_named (.clk);
  wire w_ctrl;
  assign w_ctrl = u_named.flat_o[0];

  task automatic check(string what, logic got, logic exp);
    if (got !== exp) begin
      $display("FAILED: %0s got %b want %b", what, got, exp);
      errors += 1;
    end
  endtask

  initial begin
    // l-values through the collided name, unindexed and indexed
    rstmgr_if.flat_o = 4'b0101;
    rstmgr_if.resets_o.rst_lc_io_n = 4'b0100;
    rstmgr_if.flat_o[1] = 1'b1;
    u_named.flat_o = 4'b0001;
    #1;

    check("flat_o[0] via collided name",      w_idx,    1'b1);
    check("flat_o[pkg param] via collided",   w_pkgidx, 1'b1);
    check("nested struct member index",       w_nested, 1'b1);
    check("distinct-name control",            w_ctrl,   1'b1);
    check("port connection through collided", tl_if.rst_n, 1'b0);

    // indexed l-value must have landed
    if (rstmgr_if.flat_o !== 4'b0111) begin
      $display("FAILED: indexed l-value got %b want 0111", rstmgr_if.flat_o);
      errors += 1;
    end

    // reading the collided name in a procedural expression
    if (rstmgr_if.resets_o.rst_lc_io_n[2] !== 1'b1) begin
      $display("FAILED: procedural read"); errors += 1;
    end

    if (errors == 0) $display("PASSED");
    else $display("FAILED with %0d error(s)", errors);
  end

endmodule
