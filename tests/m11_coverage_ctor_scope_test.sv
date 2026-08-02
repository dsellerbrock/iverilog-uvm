// IEEE 1800-2017 19.3: constructor formals belong to the covergroup
// declaration. Separate covergroups may reuse the same formal name.
module m11_coverage_ctor_scope_test;
  class wrapper;
    covergroup first_cg(string name) with function sample(bit value);
      option.name = name;
      cp: coverpoint value {
        bins zero = {0};
        bins one = {1};
      }
    endgroup

    covergroup second_cg(string name) with function sample(bit value);
      option.name = name;
      cp: coverpoint value {
        bins zero = {0};
        bins one = {1};
      }
    endgroup

    function new();
      first_cg = new("first");
      second_cg = new("second");
    endfunction
  endclass

  wrapper obj;
  initial begin
    obj = new();
    obj.first_cg.sample(0);
    obj.first_cg.sample(1);
    obj.second_cg.sample(0);
    obj.second_cg.sample(1);
    if (obj.first_cg.get_inst_coverage() != 100.0 ||
        obj.second_cg.get_inst_coverage() != 100.0) begin
      $display("M11 COVERGROUP CTOR SCOPE TEST: FAIL first=%0.1f second=%0.1f",
               obj.first_cg.get_inst_coverage(),
               obj.second_cg.get_inst_coverage());
      $finish(1);
    end
    $display("M11 COVERGROUP CTOR SCOPE TEST: PASS");
    $finish(0);
  end
endmodule
