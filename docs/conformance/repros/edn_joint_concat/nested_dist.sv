class Child;
  rand bit x;
  constraint x_c { x inside {0, 1}; }
endclass

class Parent;
  rand bit [3:0] boot_mode;
  rand bit [3:0] auto_mode;
  rand Child child;

  function new;
    child = new;
  endfunction

  constraint mode_c {
    {boot_mode, auto_mode} dist {8'h12 := 1, 8'h34 := 1};
  }
endclass

module tb;
  initial begin
    Parent cfg;
    cfg = new;
    if (!cfg.randomize()) $fatal(1, "nested concat dist failed");
    if ({cfg.boot_mode, cfg.auto_mode} != 8'h12 &&
        {cfg.boot_mode, cfg.auto_mode} != 8'h34)
      $fatal(1, "illegal mode pair %h", {cfg.boot_mode, cfg.auto_mode});
    $display("PASS mode pair %h", {cfg.boot_mode, cfg.auto_mode});
  end
endmodule
