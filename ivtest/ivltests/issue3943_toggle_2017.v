`line 1 "issue3943_toggle.sv" 0

module issue3943_toggle_leaf;
  logic [1:0][1:0] data;
endmodule

module issue3943_toggle_wrapper;
  if (1) begin : gen
    logic generated_bit;
    issue3943_toggle_leaf a();
    issue3943_toggle_leaf b();
  end
endmodule

module issue3943_toggle_port(inout wire [1:0] bus);
endmodule

module issue3943_toggle_driver;
  logic [1:0] left = 0, right = 0;
  wire [1:0] bus;
  assign bus = left;
  assign bus = right;
  issue3943_toggle_port p(bus);
  issue3943_toggle_port q(bus);
endmodule

module issue3943_toggle_mixed;
  bit from_zero;
  logic [1:0] unsupported [2];
endmodule

module issue3943_toggle_unsupported;
  real storage;
endmodule

`define CTL(op, scope, target) $coverage_control(op, `SV_COV_TOGGLE, scope, target)
`define MAX(scope, target) $coverage_get_max(`SV_COV_TOGGLE, scope, target)
`define HITS(scope, target) $coverage_get(`SV_COV_TOGGLE, scope, target)
`define M `SV_COV_MODULE
`define H `SV_COV_HIER
`define EXPECT(expr, wanted, label) \
  if ((expr) !== (wanted)) $fatal(1, "%s: expected %0d", label, wanted);

module issue3943_toggle;
  issue3943_toggle_wrapper w();
  issue3943_toggle_driver d();
  issue3943_toggle_mixed mixed();
  issue3943_toggle_unsupported unsupported();

  initial begin
    if ($test$plusargs("expect-disabled")) begin
      w.gen.a.data = 0;
      w.gen.a.data = 15;
      `EXPECT(`CTL(`SV_COV_CHECK, `H, $root), `SV_COV_NOCOV, "disabled CHECK")
      `EXPECT(`CTL(`SV_COV_START, `M, w.gen.a), `SV_COV_NOCOV, "disabled START")
      `EXPECT(`MAX(`M, w.gen.a), 0, "disabled max")
      `EXPECT(`HITS(`M, w.gen.a), 0, "disabled hits")
      `EXPECT(`CTL(`SV_COV_STOP, `M, w.gen.a), `SV_COV_OK, "disabled STOP")
      `EXPECT(`CTL(`SV_COV_RESET, `M, w.gen.a), `SV_COV_OK, "disabled RESET")
    end else begin
      `EXPECT(`CTL(`SV_COV_CHECK, `M, w.gen.a), `SV_COV_OK, "leaf CHECK")
      `EXPECT(`CTL(`SV_COV_CHECK, `M, issue3943_toggle), `SV_COV_NOCOV, "empty wrapper")
      `EXPECT(`CTL(`SV_COV_CHECK, `M, unsupported), `SV_COV_NOCOV, "unsupported CHECK")
      `EXPECT(`CTL(`SV_COV_START, `M, unsupported), `SV_COV_NOCOV, "unsupported START")
      `EXPECT(`CTL(`SV_COV_STOP, `M, unsupported), `SV_COV_OK, "unsupported STOP")
      `EXPECT(`CTL(`SV_COV_RESET, `M, unsupported), `SV_COV_OK, "unsupported RESET")
      `EXPECT(`CTL(`SV_COV_START, `M, mixed), `SV_COV_PARTIAL, "mixed START")
      `EXPECT(`CTL(`SV_COV_CHECK, `H, $root), `SV_COV_PARTIAL, "root CHECK")
      `EXPECT(`CTL(`SV_COV_STOP, `H, "no_such_module"), `SV_COV_ERROR, "invalid definition")
      `EXPECT(`MAX(`M, w.gen.a), 4, "leaf max")
      `EXPECT(`MAX(`M, w), 1, "generate declaration belongs to wrapper")
      `EXPECT(`MAX(`H, w), 9, "generate hierarchy max")
      `EXPECT(`MAX(`M, "issue3943_toggle_leaf"), 8, "definition max")
      `EXPECT(`MAX(`H, "issue3943_toggle_wrapper"), 9, "definition hierarchy max")
      `EXPECT(`MAX(`M, "issue3943_toggle_driver"), 6, "driver max")
      `EXPECT(`MAX(`H, "issue3943_toggle_driver"), 10, "collapsed declarations count separately")
      `EXPECT(`MAX(`H, $root), 20, "root max")

      w.gen.a.data = 4'b0xx0;
      w.gen.a.data = 4'b1zz0;
      w.gen.b.data = 4'bx100;
      w.gen.b.data = 4'bx000;
      w.gen.generated_bit = 0;
      w.gen.generated_bit = 1;
      mixed.from_zero = 1;
      #1;
      w.gen.a.data = 4'b1xx1;
      `EXPECT(`HITS(`M, w.gen.a), 2, "same-slot writes and X/Z")
      `EXPECT(`HITS(`M, w.gen.b), 1, "sibling hits")
      `EXPECT(`HITS(`M, mixed), 1, "initial visible two-state zero")
      `EXPECT(`HITS(`M, "issue3943_toggle_leaf"), 3, "definition hits")
      `EXPECT(`HITS(`H, "issue3943_toggle_wrapper"), 4, "definition hierarchy hits")

      `EXPECT(`CTL(`SV_COV_STOP, `M, d.q), `SV_COV_OK, "stop one collapsed declaration")
      d.left = 2'b11;
      #1;
      `EXPECT(d.bus, 2'bxx, "resolved contention")
      `EXPECT(`HITS(`M, d.p), 0, "unresolved driver values do not count")
      force d.bus[0] = 1'b1;
      #1;
      `EXPECT(`HITS(`M, d.p), 1, "partial force")
      `EXPECT(`HITS(`M, d.q), 0, "collapsed STOP is instance-local")
      `EXPECT(`CTL(`SV_COV_RESET, `M, d.p), `SV_COV_OK, "reset forced net coverage")
      force d.bus[0] = 1'b0;
      d.right = 2'b11;
      #1;
      `EXPECT(d.bus, 2'b10, "masked driver value")
      `EXPECT(`HITS(`M, d.p), 0, "forced lane hides the drive")
      release d.bus[0];
      #1;
      `EXPECT(d.bus, 2'b11, "partial release exposes the drive")
      `EXPECT(`HITS(`M, d.p), 1, "partial release counts")
      `EXPECT(`CTL(`SV_COV_CHECK, `M, d.q), `SV_COV_OK, "stopped points are available")
      `EXPECT(`HITS(`M, d.q), 0, "collapsed sibling remains stopped")
      `EXPECT(`HITS(`M, "issue3943_toggle_driver"), 6, "driver hits")
      `EXPECT(`HITS(`H, "issue3943_toggle_driver"), 7, "driver hierarchy hits")
      `EXPECT(`CTL(`SV_COV_RESET, `M, $root), `SV_COV_ERROR, "invalid root selector")
      `EXPECT(`HITS(`H, $root), 12, "root hits")

      `EXPECT(`CTL(`SV_COV_STOP, `M, w.gen.a), `SV_COV_OK, "leaf STOP")
      w.gen.a.data = 0;
      w.gen.a.data = 15;
      w.gen.a.data = 4'b1xx1;
      `EXPECT(`HITS(`M, w.gen.a), 2, "frozen hits")
      `EXPECT(`CTL(`SV_COV_START, `M, w.gen.a), `SV_COV_OK, "leaf START")
      `EXPECT(`HITS(`M, w.gen.a), 2, "retained hits")
      w.gen.a.data[0][1] = 0;
      w.gen.a.data[0][1] = 1;
      `EXPECT(`HITS(`M, w.gen.a), 3, "resumed partial writes")
      `EXPECT(`CTL(`SV_COV_STOP, `M, w.gen.a), `SV_COV_OK, "second STOP")
      `EXPECT(`CTL(`SV_COV_RESET, `M, w.gen.a), `SV_COV_OK, "leaf RESET")
      w.gen.a.data = 0;
      w.gen.a.data = 15;
      `EXPECT(`HITS(`M, w.gen.a), 0, "RESET preserves STOP")
      `EXPECT(`MAX(`M, w.gen.a), 4, "RESET preserves max")
      `EXPECT(`CTL(`SV_COV_START, `M, w.gen.a), `SV_COV_OK, "second START")
      w.gen.a.data[1][1] = 0;
      `EXPECT(`HITS(`M, w.gen.a), 0, "RESET clears both masks")
      w.gen.a.data[1][1] = 1;
      `EXPECT(`HITS(`M, w.gen.a), 1, "fresh hit after RESET")
      `EXPECT(`HITS(`M, w.gen.b), 1, "sibling data retained")
      `EXPECT(`MAX(`H, $root), 20, "root max is fixed")
    end
    $display("PASSED");
  end
endmodule

`undef CTL
`undef MAX
`undef HITS
`undef M
`undef H
`undef EXPECT
