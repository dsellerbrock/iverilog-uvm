// IEEE 1800-2017 16.5.1: assertion operands are sampled in the Preponed
// region. A member reached through a statically bound interface modport is
// still the concrete interface signal, including when a packed select is
// applied to that member.
interface sv_assert_modport_preponed_if;
  logic [3:0] value = 4'h0;
  modport monitor(input value);
endinterface

module sv_assert_modport_preponed_checker(
    input logic clk,
    sv_assert_modport_preponed_if.monitor bus
);
  int failures = 0;

  whole_value: assert property (@(posedge clk) bus.value == 4'h0)
    else failures++;
  selected_bit: assert property (@(posedge clk) bus.value[3] == 1'b0)
    else failures++;
endmodule

module sv_assert_modport_preponed_sample;
  logic clk = 0;
  sv_assert_modport_preponed_if bus();
  sv_assert_modport_preponed_checker dut(.clk(clk), .bus(bus));

  initial begin
    // The blocking data update and clock edge share a time slot. The sampled
    // value is the old zero, while an incorrect Active/Observed live read is
    // 4'ha and fails both properties.
    #5 bus.value = 4'ha;
       clk = 1'b1;
    #1;
    if (dut.failures != 0)
      $fatal(1, "modport operand was read live: failures=%0d",
             dut.failures);
    $display("PASSED");
    $finish;
  end
endmodule
