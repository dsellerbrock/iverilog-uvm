// IEEE 1800-2017 18.5.8.1/18.5.9; 2023 18.5.7.1/18.5.8.
class size_leaf;
  rand bit [2:0] value;
endclass
class size_root;
  rand size_leaf items[];
  int count = 2;
  function new();
    items = new[2]; foreach (items[i]) items[i] = new;
  endfunction
  constraint c { items.size() == count; foreach (items[i]) items[i].value == i+2; }
endclass
module main;
  size_root r = new;
  size_leaf saved;
  initial begin
    saved = r.items[0];
    if (!r.randomize() || r.items[0] != saved || r.items[0].value != 2)
      $fatal(1, "stable handle collection rejected or replaced");
    r.count = 3;
    if (r.randomize()) $fatal(1, "unsupported handle growth silently succeeded");
    if (r.items.size() != 2 || r.items[0] != saved || r.items[0].value != 2)
      $fatal(1, "failed handle growth changed graph");
    $display("PASSED");
  end
endmodule
