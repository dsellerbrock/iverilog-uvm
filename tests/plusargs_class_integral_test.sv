// $value$plusargs must treat an integral class property as an lvalue.
// OpenTitan's dv_base_test depends on this for its test_timeout_ns override.
class plusarg_cfg;
  bit              enabled = 0;
  byte signed      offset = 0;
  int unsigned     count = 1;
  longint unsigned timeout_ns = 200_000_000;
endclass

module plusargs_class_integral_test;
  initial begin
    plusarg_cfg cfg;
    int match_count;

    cfg = new;
    match_count = 0;

    match_count += $value$plusargs("ENABLED=%d", cfg.enabled);
    match_count += $value$plusargs("OFFSET=%d", cfg.offset);
    match_count += $value$plusargs("COUNT=%h", cfg.count);
    match_count += $value$plusargs("TIMEOUT_NS=%d", cfg.timeout_ns);

    if (match_count != 4 || cfg.enabled !== 1'b1 || cfg.offset !== -8'sd7 ||
        cfg.count !== 32'hdead_beef || cfg.timeout_ns !== 64'd1_000_000) begin
      $display("FAIL: matches=%0d enabled=%0d offset=%0d count=%h timeout=%0d",
               match_count, cfg.enabled, cfg.offset, cfg.count, cfg.timeout_ns);
      $finish(1);
    end

    $display("PASS: class integral plusarg copy-out");
  end
endmodule
