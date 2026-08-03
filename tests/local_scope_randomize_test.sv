class local_scope_item;
  rand bit [7:0] data;
  rand bit parity;
endclass

class local_scope_sequence;
  local_scope_item req;
  bit [7:0] data;
  bit parity;

  task body;
    req = new;
    data = 8'h5a;
    parity = 1'b1;
    if (!req.randomize() with {
          data == local::data;
          parity == local::parity;
        }) begin
      $error("randomize failed for local:: caller values");
      $finish_and_return(1);
    end
    if (req.data !== data || req.parity !== parity) begin
      $error("local:: bound to the randomized object: data=%h parity=%b",
             req.data, req.parity);
      $finish_and_return(1);
    end
  endtask

  // A byte is signed. Values with bit 7 set caught a solver-boundary bug
  // where local:: values were forced to 32 bits and sign-extended even
  // though the randomized property remained an unsigned 8-bit vector.
  task check_signed_byte(byte data);
    req = new;
    if (!req.randomize() with { data == local::data; }) begin
      $error("randomize failed for signed-byte local:: value %h", data);
      $finish_and_return(1);
    end
    if (req.data !== 8'h8d) begin
      $error("signed-byte local:: value changed width: got %h", req.data);
      $finish_and_return(1);
    end
  endtask
endclass

module local_scope_randomize_test;
  local_scope_sequence seq;
  initial begin
    seq = new;
    seq.body();
    seq.check_signed_byte(8'h8d);
    $display("PASSED: inline constraints preserve local:: binding");
    $finish;
  end
endmodule
