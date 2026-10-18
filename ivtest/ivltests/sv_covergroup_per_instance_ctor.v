module test;
  bit save_instance;
  covergroup cg(int keep) with function sample(bit value);
    option.per_instance = keep;
    cp: coverpoint value { bins zero = {0}; bins one = {1}; }
  endgroup
  covergroup default_cg;
    cp: coverpoint save_instance;
  endgroup

  cg retired, hidden, live;
  default_cg default_instance;

  initial begin
    default_instance = new;
    if (default_instance.option.per_instance !== 1'b0)
      $fatal(1, "default per_instance value");

    save_instance = 1;
    retired = new(save_instance);
    if (retired.option.per_instance !== 1'b1)
      $fatal(1, "constructor per_instance value");

    save_instance = 0;
    hidden = new(save_instance);
    if (hidden.option.per_instance !== 1'b0)
      $fatal(1, "disabled per_instance value");

    save_instance = 1;
    live = new(save_instance);
    save_instance = 0;
    if (live.option.per_instance !== 1'b1)
      $fatal(1, "per_instance value was not captured at construction");

    retired.sample(0);
    retired.sample(1);
    hidden.sample(0);
    live.sample(1);
    retired = null;
    $display("PASSED");
  end
endmodule
