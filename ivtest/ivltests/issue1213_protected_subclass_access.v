class Base #(parameter int N = 0);
  protected int value = N;
  protected function int protected_read();
    return value;
  endfunction
  function int read_other(Base#(1) other);
    return other.value;
  endfunction
endclass

class Derived #(parameter int N = 0) extends Base#(N);
  function int bump();
    value = value + 1;
    return protected_read();
  endfunction
endclass

module top;
  Derived#(8) d;
  Base#(1) peer;
  initial begin
    int result;
    d = new;
    peer = new;
    result = d.bump();
    $display("subclass access=%0d", result);
    if (result != 9) $fatal(1, "protected subclass access failed");
    result = d.read_other(peer);
    $display("specialization access=%0d", result);
    if (result != 1) $fatal(1, "protected specialization access failed");
    $display("passed");
  end
endmodule
