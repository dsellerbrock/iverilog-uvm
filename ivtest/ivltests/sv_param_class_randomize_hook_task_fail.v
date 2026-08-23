// Randomization callbacks are nonblocking void functions, not tasks. Reject
// illegal declarations before a parameterized specialization reaches VVP.
class hook_item #(int TAG = 1);
  rand int value;

  task pre_randomize();
  endtask

  task post_randomize();
  endtask
endclass

module test;
  hook_item#(7) item;
  initial begin
    item = new;
    void'(item.randomize());
  end
endmodule
