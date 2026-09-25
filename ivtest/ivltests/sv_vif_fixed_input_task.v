`include "ivltests/sv_vif_fixed_input_common.vh"

class vif_fixed_input_holder_t;
  virtual vif_fixed_input_if vif;
  int failures;

  task run(input bit second);
    vif_lock_t actual[2:0];
    actual[2] = second ? 2'b10 : 2'b01;
    actual[1] = second ? 2'b11 : 2'b10;
    actual[0] = second ? 2'b01 : 2'b11;
    vif.consume(actual);
    if (actual[2] !== (second ? 2'b10 : 2'b01)) failures++;
    if (actual[1] !== (second ? 2'b11 : 2'b10)) failures++;
    if (actual[0] !== (second ? 2'b01 : 2'b11)) failures++;
  endtask

  task run_logic();
    logic [3:0] actual[0:2];
    actual[0] = 4'b10xz;
    actual[1] = 4'b0110;
    actual[2] = 4'bx001;
    vif.consume_logic(actual);
    if (actual[0] !== 4'b10xz || actual[1] !== 4'b0110 ||
        actual[2] !== 4'bx001) failures++;
  endtask

  task run_static(input bit second);
    logic [3:0] first_arg[0:1];
    logic [3:0] second_arg[1:0];
    first_arg[0] = second ? 4'h5 : 4'h1;
    first_arg[1] = second ? 4'h6 : 4'h2;
    second_arg[1] = second ? 4'h7 : 4'h3;
    second_arg[0] = second ? 4'h8 : 4'h4;
    vif.consume_static(first_arg, second_arg);
    if (first_arg[0] !== (second ? 4'h5 : 4'h1) ||
        first_arg[1] !== (second ? 4'h6 : 4'h2) ||
        second_arg[1] !== (second ? 4'h7 : 4'h3) ||
        second_arg[0] !== (second ? 4'h8 : 4'h4)) failures++;
  endtask
endclass

module sv_vif_fixed_input_task;
  vif_fixed_input_if first();
  vif_fixed_input_if second();
  vif_fixed_input_holder_t holder;
  initial begin
    holder = new;
    holder.vif = first;
    holder.run(0);
    holder.run_static(0);
    holder.vif = second;
    holder.run(1);
    holder.run_static(1);
    holder.run_logic();
    if (holder.failures || first.calls != 1 || second.calls != 1 ||
        first.seen !== 6'b01_10_11 || second.seen !== 6'b10_11_01 ||
        first.static_calls != 1 || second.static_calls != 1 ||
        first.static_seen !== 16'h1234 || second.static_seen !== 16'h5678 ||
        first.logic_calls != 0 || second.logic_calls != 1 ||
        second.logic_seen !== 12'b10xz_0110_x001)
      $fatal(1, "fixed input dispatch/order/copy failed");
    $display("PASSED");
    $finish(0);
  end
endmodule
