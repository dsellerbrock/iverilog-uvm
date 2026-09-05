// IEEE 1800-2017 18.4/18.5.8.1/18.5.9; 2023 18.4/18.5.7.1/18.5.8.
typedef enum bit [2:0] { TWO=2, FIVE=5 } code_e;
typedef struct { rand code_e code; } enum_s;
class domain_leaf;
  rand bit [7:0] data[];
  rand enum_s item;
  int count, offset;
  code_e forbidden;
  constraint c {
    data.size() == count;
    foreach (data[i]) data[i] == i + offset;
    item.code >= 1; item.code != forbidden;
  }
endclass
class domain_root;
  rand domain_leaf left, right;
  function new();
    left = new; right = new;
    left.count = 2; left.offset = 7; left.forbidden = TWO;
    right.count = 3; right.offset = 11; right.forbidden = FIVE;
  endfunction
  constraint c { left.count == 2; right.count == 3; }
endclass
class parameter_leaf #(int ID=0);
  static rand bit [1:0] value;
endclass
class parameter_root;
  rand parameter_leaf #(0) left;
  rand parameter_leaf #(1) right;
  function new(); left = new; right = new; endfunction
  constraint c { left.value == 1; right.value == 2; }
endclass
module main;
  domain_root r = new;
  parameter_root p = new;
  initial begin
    repeat (20) begin
      if (!r.randomize()) $fatal(1, "independent owner domains rejected");
      if (r.left.data.size() != 2 || r.right.data.size() != 3)
        $fatal(1, "equal property indices shared size");
      foreach (r.left.data[i])
        if (r.left.data[i] != i+7) $fatal(1, "left foreach owner lost");
      foreach (r.right.data[i])
        if (r.right.data[i] != i+11) $fatal(1, "right foreach owner lost");
      if (r.left.item.code != FIVE || r.right.item.code != TWO)
        $fatal(1, "enum literal domain lost through nested alias");
      if (!p.randomize() || p.left.value != 1 || p.right.value != 2)
        $fatal(1, "different parameter statics share solver identity");
    end
    $display("PASSED");
  end
endmodule
