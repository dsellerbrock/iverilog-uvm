// IEEE 1800-2017/2023 18.7.1: a randomized target member takes precedence
// over a same-named task inherited by the caller (OpenTitan alert-handler lock).
class shadow_field;
  rand bit value;
endclass

class shadow_target;
  rand shadow_field en;
  rand shadow_field lock;
  function new();
    en = new;
    lock = new;
  endfunction
endclass

class shadow_caller_base;
  task lock();
    $fatal(1, "caller task was selected");
  endtask
endclass

class shadow_caller extends shadow_caller_base;
  task run();
    shadow_target target;
    target = new;
    if (!target.randomize() with { en.value == 0; lock.value == 1; })
      $fatal(1, "randomization failed");
    if (target.en.value !== 0 || target.lock.value !== 1)
      $fatal(1, "wrong target member value");
    $display("PASSED");
  endtask
endclass

module main;
  shadow_caller caller;
  initial begin
    caller = new;
    caller.run();
  end
endmodule
