module top;
  import uvm_pkg::*;

  logic [7:0] mem [0:255];
  uvm_hdl_data_t value;
  string path;
  integer pass, i;

  initial begin
    for (i = 0; i < 256; i = i + 1)
      mem[i] = (i * 37 + 11) & 8'hff;

    // Repeat the same real UVM DPI reads so path-resolution cost is visible.
    for (pass = 0; pass < 8; pass = pass + 1) begin
      for (i = 0; i < 256; i = i + 1) begin
        path = $sformatf("top.mem[%0d]", i);
        if (!uvm_hdl_read(path, value))
          $fatal(1, "uvm_hdl_read failed for %s", path);
        if (value[7:0] !== mem[i])
          $fatal(1, "bad value at %s: got %02x expected %02x",
                 path, value[7:0], mem[i]);
      end
    end

    // A later backdoor read must see the updated signal value.
    mem[7] = 8'h5a;
    if (!uvm_hdl_read("top.mem[7]", value) || value[7:0] !== 8'h5a)
      $fatal(1, "UVM HDL read returned a stale value");

    $display("PASS uvm_hdl_read_backdoor calls=2049");
    $finish;
  end
endmodule
