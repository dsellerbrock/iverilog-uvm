interface ordinary_if;
  logic value;
endinterface

interface class_prefixed_if;
  logic value;
endinterface

interface /* comments are whitespace */ class commented_if;
  pure virtual function int value();
endclass

interface
class newline_if;
  pure virtual task run();
endclass

typedef interface class forward_if;
interface class forward_if;
  pure virtual function int marker();
endclass

module test;
  ordinary_if bus();
  class_prefixed_if prefixed();

  initial begin
    bus.value = 1'b1;
    prefixed.value = 1'b1;
    if (bus.value !== 1'b1)
      $fatal(1, "ordinary interface parsing was changed by interface classes");
    if (prefixed.value !== 1'b1)
      $fatal(1, "an ordinary interface name beginning with class was mis-tokenized");
    $display("PASSED");
  end
endmodule
