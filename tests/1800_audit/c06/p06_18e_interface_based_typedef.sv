interface intf_i; typedef int data_t; endinterface
module sub(intf_i p); typedef p.data_t my_data_t; my_data_t data; initial $display("SUB bits=%0d",$bits(data)); endmodule
module p06_18e; intf_i ii(); sub s(ii); endmodule
