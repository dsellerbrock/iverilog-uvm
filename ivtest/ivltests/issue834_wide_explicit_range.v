module top;
  typedef bit [255:0] wide_t;

  covergroup full_cg with function sample(input wide_t value);
    cp: coverpoint value {
      bins full = {[256'h0:256'hffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff]};
    }
  endgroup

  covergroup bounds_cg with function sample(input wide_t value);
    cp: coverpoint value {
      bins low = {[256'h0:256'h000000000000000000000000000000000000000000000000ffffffffffffffff]};
      bins high = {[256'hffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00:
                    256'hffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff]};
    }
  endgroup

  full_cg full = new();
  bounds_cg bounds = new();
  initial begin
    full.sample('0);
    if (full.get_coverage() != 100.0)
      $fatal(1, "full wide range bin was not covered");

    bounds.sample(256'h0000000000000000000000000000000000000000000000010000000000000000);
    if (bounds.get_coverage() != 0.0)
      $fatal(1, "wide range matched a value in the gap");
    bounds.sample('0);
    if (bounds.get_coverage() != 50.0)
      $fatal(1, "wide range lower endpoint was not included");
    bounds.sample(256'h000000000000000000000000000000000000000000000000ffffffffffffffff);
    bounds.sample(256'hffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00);
    if (bounds.get_coverage() != 100.0)
      $fatal(1, "wide range upper endpoint was not included");
    bounds.sample('1);

    $display("WIDE_EXPLICIT_RANGE_OK");
    $finish;
  end
endmodule
