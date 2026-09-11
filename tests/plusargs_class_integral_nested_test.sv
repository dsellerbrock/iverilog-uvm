// L34: $value$plusargs must treat a NESTED integral class property as an
// lvalue -- the direct case (cfg.enabled etc.) is covered by
// plusargs_class_integral_test.sv; this exercises a property access
// chained through another class-typed property, which used to fall back
// to a discarded rvalue-only temporary and silently drop the write. Same
// gap as L33 (string properties), for the identical reason. See
// docs/conformance/BLOCKERS.md L34.
class inner_cfg;
  byte signed offset = 0;
  int unsigned count = 1;
endclass

class outer_cfg;
  inner_cfg inner;
  function new();
    inner = new;
  endfunction
endclass

module plusargs_class_integral_nested_test;
  initial begin
    outer_cfg cfg;
    int match_count;

    cfg = new;
    match_count = 0;

    // nested property chain: cfg.inner.offset/count are not direct signal
    // properties of cfg -- they are properties of the object stored IN
    // cfg's "inner" property, resolved dynamically at each access.
    match_count += $value$plusargs("OFFSET=%d", cfg.inner.offset);
    match_count += $value$plusargs("COUNT=%h", cfg.inner.count);

    if (match_count != 2 || cfg.inner.offset !== -8'sd7 ||
        cfg.inner.count !== 32'hdead_beef) begin
      $display("FAIL: matches=%0d offset=%0d count=%h",
               match_count, cfg.inner.offset, cfg.inner.count);
      $finish(1);
    end

    $display("PASS: nested class integral plusarg copy-out");
  end
endmodule
