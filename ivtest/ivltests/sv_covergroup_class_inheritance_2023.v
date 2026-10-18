class base_c;
  bit a;
  covergroup cg with function sample(bit bb);
    option.at_least = 2;
    option.per_instance = 1;
    option.cross_retain_auto_bins = 0;
    anchor: coverpoint a { bins zero = {0}; option.weight = 0; }
    cb: coverpoint bb {
      bins zero = {0};
      bins one = {1};
      option.weight = 0;
    }
    keep_cross: cross anchor, cb {
      bins low_zero = binsof(anchor.zero) && binsof(cb.zero);
      bins low_one = binsof(anchor.zero) && binsof(cb.one);
    }
    replace_cross: cross anchor, cb {
      bins low_zero = binsof(anchor.zero) && binsof(cb.zero);
      bins low_one = binsof(anchor.zero) && binsof(cb.one);
    }
  endgroup
  function new; cg = new; endfunction
endclass

class derived_c extends base_c;
  bit d;
  bit e;
  covergroup extends cg;
    option.at_least = 1;
    cb: coverpoint d {
      bins zero = {0};
      bins one = {1};
      option.weight = 0;
    }
    cd: coverpoint e {
      bins off = {0};
      bins on = {1};
      option.weight = 0;
    }
    replace_cross: cross anchor, cb {
      bins low_zero = binsof(anchor.zero) && binsof(cb.zero);
      bins low_one = binsof(anchor.zero) && binsof(cb.one);
    }
    new_cross: cross cb, cd {
      bins zero_off = binsof(cb.zero) && binsof(cd.off);
      bins zero_on = binsof(cb.zero) && binsof(cd.on);
    }
  endgroup : cg
  function new; super.new(); endfunction
endclass

module test;
  base_c base_item;
  derived_c derived_item;
  base_c base_view;
  real coverage;
  initial begin
    derived_item = new;
    derived_item.a = 0;
    derived_item.d = 0;
    derived_item.e = 0;
    base_view = derived_item;
    base_view.cg.sample(0);
    derived_item.e = 1;
    base_view.cg.sample(1);
    coverage = derived_item.cg.get_inst_coverage();
    if (coverage < 83.3 || coverage > 83.4)
      $fatal(1, "derived group did not keep inherited cross sampling: %f", coverage);

    base_item = new;
    base_item.a = 0;
    base_item.cg.sample(0);
    base_item.cg.sample(0);
    coverage = base_item.cg.get_inst_coverage();
    if (coverage < 49.9 || coverage > 50.1)
      $fatal(1, "derived options contaminated base group instance: %f", coverage);
    $display("PASSED");
  end
endmodule
