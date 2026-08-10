module test;
  virtual class tlm_if #(type T = int);
    virtual function void write(input T value);
      $display("FAILED base write value=%0d", value);
    endfunction
  endclass

  virtual class port_base #(type IF = tlm_if#(int)) extends IF;
  endclass

  class analysis_imp #(type T = int) extends port_base#(tlm_if#(T));
    function void write(input T value);
      $display("PASSED derived write value=%0d", value);
    endfunction
  endclass

  initial begin
    tlm_if#(byte) interface_handle;
    analysis_imp#(byte) implementation;

    implementation = new;
    interface_handle = implementation;
    interface_handle.write(8'd42);
  end
endmodule
