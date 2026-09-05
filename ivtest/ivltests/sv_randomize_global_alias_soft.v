// IEEE 1800-2017 18.5.9, 18.5.14.1 / IEEE 1800-2023 18.5.8, 18.5.13.1.
class alias_leaf;
  rand bit value;
  constraint child_preference { soft value == 0; }
endclass
class alias_root;
  rand alias_leaf selected;
  alias_leaf state_view;
  function new(); selected = new; state_view = selected; endfunction
  constraint parent_preference { soft state_view.value == 1; }
endclass
module main;
  alias_root root = new;
  initial begin
    repeat (10) begin
      if (!root.randomize()) $fatal(1, "compatible soft graph rejected");
      if (root.selected.value != 1 || root.state_view.value != 1)
        $fatal(1, "active field through state alias lost parent soft priority");
    end
    $display("PASSED");
  end
endmodule
