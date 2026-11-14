class base_c;
  covergroup cg with function sample(bit arg);
    base_cp: coverpoint arg;
  endgroup
  function new; cg = new; endfunction
endclass

class derived_c extends base_c;
  covergroup extends cg;
    extension_cp: coverpoint arg;
  endgroup : cg
endclass

module test;
  derived_c derived_item;
  base_c item;
  initial begin
    derived_item = new;
    item = derived_item;
    item.cg.sample(1'b1);
    // IEEE 1800-2023 19.4.1: the derived group has its base's sample()
    // argument, also when a base-class handle samples it.
    if (derived_item.cg.extension_cp.get_inst_coverage() != 50.0) begin
      $display("FAILED: extension_cp=%0.1f",
               derived_item.cg.extension_cp.get_inst_coverage());
      $finish;
    end
    item.cg.sample(1'b0);
    if (derived_item.cg.extension_cp.get_inst_coverage() != 100.0) begin
      $display("FAILED: extension_cp=%0.1f after both values",
               derived_item.cg.extension_cp.get_inst_coverage());
      $finish;
    end
    $display("PASSED");
  end
endmodule
