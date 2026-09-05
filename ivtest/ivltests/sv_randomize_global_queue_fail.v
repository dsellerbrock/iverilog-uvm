// IEEE 1800-2017/2023 18.4.2: fail unsupported histories before prefill.
class wide_leaf;
  randc bit [20:0] data[$];
  constraint c { data.size()==1; }
endclass
class fixed_leaf;
  randc bit [1:0] data[2][$];
  function new(); data[0].push_back(1); data[1].push_back(2); endfunction
endclass
class wide_root;
  rand wide_leaf c;
  function new(); c = new; endfunction
endclass
class fixed_root;
  rand fixed_leaf c;
  function new(); c = new; endfunction
endclass
module main;
  wide_root w = new;
  fixed_root f = new;
  initial begin
    if (w.randomize() || w.c.data.size()!=0)
      $fatal(1, "unsupported future queue history allocated entries");
    if (f.randomize() || f.c.data[0].size()!=1 || f.c.data[1].size()!=1
        || f.c.data[0][0]!=1 || f.c.data[1][0]!=2)
      $fatal(1, "fixed queue history silently accepted or changed values");
    $display("PASSED");
  end
endmodule
