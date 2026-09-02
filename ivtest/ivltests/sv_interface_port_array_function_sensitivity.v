// IEEE 1800-2017/2023 9.2.2.2.1 and 13.4.1: always_comb sensitivity
// includes expressions read by called functions. A function called through a
// constant word of an interface-port array must read the corresponding actual
// instance and wake when that function-body dependency changes.
interface port_array_function_if;
  int value;

  function automatic int read_value();
    return value;
  endfunction

  modport access(input value, import read_value);
endinterface

module port_array_function_consumer(
  port_array_function_if.access ports [0:1],
  output int value0,
  output int value1
);
  // Keep each selected word in a distinct process. If function-body
  // sensitivity accidentally includes only one concrete candidate, combining
  // both calls in one process could let the other call's dependencies mask
  // the missing edge.
  always_comb begin
    value0 = ports[0].read_value();
  end

  always_comb begin
    value1 = ports[1].read_value();
  end
endmodule

module sv_interface_port_array_function_sensitivity;
  int value0;
  int value1;
  port_array_function_if bus [0:1] ();
  port_array_function_consumer consumer(
    .ports(bus),
    .value0(value0),
    .value1(value1)
  );

  initial begin
    bus[0].value = 11;
    bus[1].value = 22;
    #1;
    if (value0 != 11 || value1 != 22)
      $fatal(1, "initial interface-port-array function result was wrong");

    bus[1].value = 37;
    #1;
    if (value0 != 11 || value1 != 37)
      $fatal(1, "always_comb missed function-body sensitivity");

    bus[0].value = 49;
    #1;
    if (value0 != 49 || value1 != 37)
      $fatal(1, "per-word interface function dispatch was wrong");
    $display("PASSED");
  end
endmodule
