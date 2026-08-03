module std_randomize_opentitan_constraints_test;
  typedef struct packed {
    bit [106:0] payload;
    bit ready;
    bit valid;
  } wide_req_t;

  bit [3:0] mask;
  bit [3:0] valid_mask = 4'b0101;
  bit [7:0] x;
  bit [7:0] signed_match;
  byte signed_source = 8'h8d;
  bit [7:0] pending[$];
  int index;
  int failed;
  wide_req_t wide_req;

  initial begin
    pending.push_back(8'h12);
    pending.push_back(8'h34);

    if (!std::randomize(wide_req) with {
          wide_req.valid == 1'b0;
          wide_req.ready == 1'b1;
        }) failed++;
    if (wide_req.valid != 0 || wide_req.ready != 1) failed++;

    if (!std::randomize(signed_match) with {
          signed_match == signed_source;
        }) $fatal(1, "signed-byte std::randomize constraint was unsatisfiable");
    if (signed_match !== 8'h8d)
      $fatal(1, "signed-byte std::randomize value changed width: %h",
             signed_match);

    repeat (20) begin
      if (!std::randomize(mask) with {
            $countones(mask ^ {mask[2:0], 1'b0}) <= 2;
            foreach (valid_mask[i]) {
              !valid_mask[i] -> !mask[i];
            }
          }) failed++;
      if ((mask & ~valid_mask) != 0) failed++;
      if ($countones(mask ^ {mask[2:0], 1'b0}) > 2) failed++;

      if (!std::randomize(index) with { valid_mask[index] == 1; })
        failed++;
      if (index < 0 || index > 3 || !valid_mask[index]) failed++;

      if (!std::randomize(x) with {
            !(x inside {pending});
            (x >> 6) == 0;
          }) failed++;
      if (x inside {pending}) failed++;

      if (!std::randomize(x) with {
            (x & 8'h3f) inside {[8'd10:8'd20]};
          }) failed++;
      if ((x & 8'h3f) < 10 || (x & 8'h3f) > 20) failed++;
    end

    if (failed == 0)
      $display("PASS: OpenTitan scope-randomize constraint forms");
    else
      $display("FAIL: %0d scope-randomize violations", failed);
  end
endmodule
