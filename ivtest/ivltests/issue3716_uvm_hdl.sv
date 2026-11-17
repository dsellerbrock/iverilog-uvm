module tb;
  typedef logic [1023:0] hdl_t;
  import "DPI-C" context function int uvm_hdl_read(string path, output hdl_t value);
  import "DPI-C" context function int uvm_hdl_deposit(string path, input hdl_t value);
  import "DPI-C" context function int uvm_hdl_check_path(string path);
  logic [7:0] matrix [2:3][1:2];
  logic [7:0] mem [0:3];
  hdl_t v; int ok; int errors = 0;
  initial begin
    matrix[2][1] = 8'h12; matrix[2][2] = 8'b10xz0110;
    matrix[3][2] = 8'h67; mem[2] = 8'h67;
    ok = uvm_hdl_read("tb.matrix[3][2]", v);
    if (ok != 1 || v[7:0] !== 8'h67) begin $display("FAIL whole %d %h",ok,v[7:0]); errors++; end
    ok = uvm_hdl_read("tb.matrix[2][2]", v);
    if (ok != 1 || v[7:0] !== 8'b10xz0110) begin $display("FAIL four-state"); errors++; end
    ok = uvm_hdl_read("tb.matrix[3][2][6:4]", v);
    if (ok != 1 || v[2:0] !== 3'h6) begin $display("FAIL part %d %h",ok,v[2:0]); errors++; end
    ok = uvm_hdl_read("tb.matrix[3][2][2]", v);
    if (ok != 1 || v[0] !== 1'b1) begin $display("FAIL bit %d %b",ok,v[0]); errors++; end
    if (uvm_hdl_check_path("tb.matrix[3][3]") != 0 || uvm_hdl_check_path("tb.matrix[3]") != 0) begin $display("FAIL invalid"); errors++; end
    v = 'hba; ok = uvm_hdl_deposit("tb.matrix[2][1]",v);
    if (ok != 1 || matrix[2][1] !== 8'hba || matrix[3][2] !== 8'h67) begin $display("FAIL deposit"); errors++; end
    v = 'h3; ok = uvm_hdl_deposit("tb.matrix[3][2][7:4]",v);
    if (ok != 1 || matrix[3][2] !== 8'h37) begin $display("FAIL part deposit %h", matrix[3][2]); errors++; end
    ok = uvm_hdl_read("tb.mem[2]",v);
    if (ok != 1 || v[7:0] !== 8'h67) begin $display("FAIL 1d"); errors++; end
    if (errors == 0) $display("PASSED"); else $fatal(1, "%0d failures", errors);
  end
endmodule
