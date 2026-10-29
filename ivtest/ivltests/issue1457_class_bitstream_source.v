typedef byte byte_t;

class C;
  byte value;
endclass

module top;
  C source;
  byte_t destination;

  initial begin
    source = new;
    source.value = 8'h5a;
    destination = byte_t'(source);
    if (destination != 8'h5a)
      $fatal(1, "class bit-stream source=%h", destination);
    $display("PASS public class bit-stream source");
    $display("PASSED");
  end
endmodule
