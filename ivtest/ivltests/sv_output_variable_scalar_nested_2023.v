interface scalar_if;
  wire response;
  logic external_value;
  logic active;
  assign response = active ? external_value : 1'bz;
endinterface

module scalar_source(input logic value, output logic out);
  always_comb out = value;
endmodule

module scalar_wrapper(input logic value, output logic out);
  scalar_source source(value, out);
endmodule

module test;
  scalar_if bus();
  logic value;
  scalar_wrapper wrapper(value, bus.response);
  initial begin
    bus.active = 0;
    bus.external_value = 0;
    value = 1;
    #1;
    if (bus.response !== 1 || wrapper.out !== 1 || wrapper.source.out !== 1)
      $fatal(1, "initial scalar direction");
    bus.active = 1;
    #1;
    if (bus.response !== 1'bx || wrapper.out !== 1
        || wrapper.source.out !== 1)
      $fatal(1, "scalar conflict fed back");
    bus.active = 0;
    value = 0;
    #1;
    if (bus.response !== 0 || wrapper.out !== 0 || wrapper.source.out !== 0)
      $fatal(1, "scalar release");
    $display("PASS scalar nested output");
  end
endmodule
