// Coverage row 2: sample() called ONLY from a module-scope task.
module top;
  logic [7:0] v;
  covergroup g; coverpoint v { bins a = {8'hA5}; bins b = {8'h5A}; } endgroup
  g cg;
  task do_sample();          // module-scope task, not the initial block
    cg.sample();
  endtask
  initial begin
    cg = new();
    v = 8'hA5; do_sample();
    v = 8'h5A; do_sample();
    $display("sample() from a module task: %0.1f%% (want 100)", cg.get_coverage());
    $finish(0);
  end
endmodule
