// IEEE 1800-2023 7.4.5 and 18.3 (parallel rules in IEEE 1800-2017).
class state_selected_two_state_x_index;
  integer selector;
  bit [7:0] values[2];
  rand bit witness;

  constraint selected_read { values[selector] == 0; witness == 1; }
endclass

module test;
  state_selected_two_state_x_index obj;
  initial begin
    obj = new;
    obj.values[0] = 8'h55;
    obj.values[1] = 8'haa;
    obj.witness = 0;

    obj.selector = 'x;
    if (obj.values[obj.selector] !== 8'h00)
      $fatal(1, "ordinary X-index read did not use two-state zero default");
    if (obj.randomize())
      $fatal(1, "X four-state constraint operand did not cause an error");
    if (obj.witness != 0)
      $fatal(1, "X-index constraint error did not roll back");

    obj.selector = 'z;
    if (obj.values[obj.selector] !== 8'h00)
      $fatal(1, "ordinary Z-index read did not use two-state zero default");
    if (obj.randomize())
      $fatal(1, "Z four-state constraint operand did not cause an error");
    if (obj.witness != 0)
      $fatal(1, "Z-index constraint error did not roll back");

    $display("PASSED");
  end
endmodule
