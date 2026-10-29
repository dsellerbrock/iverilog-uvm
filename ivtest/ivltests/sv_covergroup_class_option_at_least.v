class item;
  protected bit value;
  local bit enabled;
  local int threshold;
  covergroup cg;
    option.at_least = threshold;
    cp: coverpoint value iff (enabled) { bins high = {1}; }
  endgroup
  function new();
    threshold = 2;
    cg = new;
    enabled = 1;
    value = 1;
  endfunction
  function void sample_once(); cg.sample(); endfunction
endclass
module test;
  item obj = new;
  initial begin
    obj.sample_once();
    $display("AFTER_ONE=%0.1f", obj.cg.get_inst_coverage());
    obj.sample_once();
    $display("AFTER_TWO=%0.1f", obj.cg.get_inst_coverage());
  end
endmodule
