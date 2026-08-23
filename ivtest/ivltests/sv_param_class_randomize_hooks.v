// A parameterized class specialization must retain the implicit method
// receiver metadata needed to call the standard randomization hooks.
class hook_item #(int TAG = 1);
  rand int value;
  int pre_calls;
  int post_calls;

  constraint fixed_value { value == TAG; }

  function void pre_randomize();
    pre_calls++;
  endfunction

  function void post_randomize();
    post_calls++;
  endfunction
endclass

module test;
  hook_item#(7) item;

  initial begin
    item = new;
    if (!item.randomize())
      $fatal(1, "randomize failed");
    if (item.value != 7 || item.pre_calls != 1 || item.post_calls != 1)
      $fatal(1, "specialized hooks mismatch: value=%0d pre=%0d post=%0d",
             item.value, item.pre_calls, item.post_calls);
    $display("PASSED");
  end
endmodule
