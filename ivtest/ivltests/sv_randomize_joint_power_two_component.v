class power_two_field;
  rand bit [63:0] value;
  int unsigned size;
  constraint fits { value < (64'h1 << size); }
  function new(int unsigned n); size = n; endfunction
endclass

class power_two_reg;
  rand power_two_field id, mf;
  rand bit preferred, weighted;
  function new(); id = new(16); mf = new(8); endfunction
  constraint preferences { soft preferred == 1; }
  constraint distribution { weighted dist {0 := 1, 1 := 3}; }
endclass

class power_two_single;
  rand power_two_field f;
  function new(int unsigned n); f = new(n); endfunction
endclass

class non_power_leaf;
  rand bit [63:0] value;
  constraint non_power { value < 1024; value != 17; }
endclass

class full_width_leaf;
  rand bit [63:0] value;
endclass

class full_width_item;
  rand full_width_leaf child;
  function new(); child = new(); endfunction
endclass

class non_power_item;
  rand non_power_leaf child;
  function new(); child = new(); endfunction
endclass

class holed_power_leaf;
  rand bit [63:0] value;
  constraint holed_power { value < 2048; value != 1024; }
endclass

class holed_power_item;
  rand holed_power_leaf child;
  function new(); child = new(); endfunction
endclass

class impossible_power_field extends power_two_field;
  constraint impossible { value < 8; value > 12; }
  function new(); super.new(8); endfunction
endclass

class impossible_power_reg;
  rand impossible_power_field f;
  function new(); f = new(); endfunction
endclass

module main;
  power_two_reg r;
  power_two_single at_limit, over_limit;
  non_power_item irregular;
  full_width_item full_width;
  holed_power_item holed;
  impossible_power_reg impossible;
  bit [63:0] previous;
  initial begin
    r = new();
    at_limit = new(10);
    over_limit = new(11);
    irregular = new();
    full_width = new();
    holed = new();
    impossible = new();

    if (!r.randomize()) $fatal(1, "nested 16/8-bit solve failed");
    if (r.id.value >= 65536 || r.mf.value >= 256 || r.preferred != 1)
      $fatal(1, "nested field or soft constraint failed");
    if (!at_limit.randomize() || at_limit.f.value >= 1024)
      $fatal(1, "size-10 enumeration boundary failed");
    if (!over_limit.randomize() || over_limit.f.value >= 2048)
      $fatal(1, "size-11 full power-of-two solve failed");
    if (!full_width.randomize())
      $fatal(1, "full 64-bit nested domain solve failed");
    repeat (20) begin
      if (!irregular.randomize() || irregular.child.value >= 1024 ||
          irregular.child.value == 17)
        $fatal(1, "non-power-of-two exact enumeration failed");
    end
    holed.child.value = 7;
    if (holed.randomize())
      $fatal(1, "interior hole was mistaken for a full power-of-two set");
    if (holed.child.value != 7) $fatal(1, "holed failure did not roll back");
    impossible.f.value = 5;
    previous = impossible.f.value;
    if (impossible.randomize()) $fatal(1, "impossible constraints succeeded");
    if (impossible.f.value != previous) $fatal(1, "failed solve did not roll back");

    $display("PASS");
  end
endmodule
