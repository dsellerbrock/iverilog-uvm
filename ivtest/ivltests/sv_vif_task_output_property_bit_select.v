// IEEE 1800-2017/2023 13.5, 11.5.1: an output actual may be a bit or part
// select of a class property. Called through a virtual interface the copy-out
// was lowered as an associative-array store, so the write was dropped
// (OpenTitan i2c_monitor: get_bit_data(..., mon_dut_item.addr[i]) left the
// address zero).
class item;
  bit [9:0] addr;
  logic [7:0] data;
endclass
class holder;
  item it;
endclass
interface ifc;
  task automatic put_bit(input bit v, output bit o);
    o = v;
  endtask
  task automatic put_nib(input bit [3:0] v, output bit [3:0] o);
    o = v;
  endtask
endinterface
module main;
  ifc i();
  virtual ifc vif;
  item it;
  holder h;
  int errors;
  initial begin
    vif = i; it = new; h = new; h.it = it;
    it.addr = 0;
    for (int n = 6; n >= 0; n--) vif.put_bit(1'b1, it.addr[n]);
    if (it.addr !== 10'h07f) begin $display("FAILED var-index bits %h", it.addr); errors++; end
    vif.put_bit(1'b0, it.addr[3]);
    if (it.addr !== 10'h077) begin $display("FAILED clear bit %h", it.addr); errors++; end
    vif.put_nib(4'ha, it.addr[9:6]);
    if (it.addr !== 10'h2b7) begin $display("FAILED part select %h", it.addr); errors++; end
    it.data = 8'hxx;
    vif.put_bit(1'b1, it.data[0]);
    if (it.data !== 8'bxxxxxxx1) begin
      $display("FAILED four-state property %b", it.data); errors++;
    end
    h.it.addr = 0;
    vif.put_bit(1'b1, h.it.addr[9]);
    if (it.addr !== 10'h200) begin $display("FAILED nested receiver %h", it.addr); errors++; end
    if (errors == 0) $display("PASSED");
  end
endmodule
