interface ordinary_if;
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

  initial begin
    bus.value = 1'b1;
    if (bus.value !== 1'b1)
      $fatal(1, "ordinary interface parsing was changed by interface classes");
    $display("PASSED");
  end
endmodule
