class enum_bounds_box;
 typedef enum bit [7:0] {B_ZERO=0,B_A5=8'ha5} bit_value_t;
 typedef enum logic [7:0] {L_ZERO=0,L_A5=8'ha5} logic_value_t;
 bit_value_t bits[];logic_value_t logic_values[];int calls;
 function new;bits=new[1];bits[0]=B_A5;logic_values=new[1];logic_values[0]=L_A5;endfunction
 function logic [63:0] bad();calls++;return 64'h1_0000_0000;endfunction
 function logic [31:0] unknown();calls++;return 32'hxxxx_xxxx;endfunction
endclass
module sv_class_enum_container_packed_select_bounds;
 enum_bounds_box b=new;logic x;bit z;
 initial begin
  x=b.logic_values[0][b.bad()];if(x!==1'bx||b.calls!=1)$fatal(1,"logic OOB read");
  z=b.bits[0][b.bad()];if(z!==1'b0||b.calls!=2)$fatal(1,"bit OOB read");
  b.logic_values[0][b.bad()]=1'b0;b.bits[0][b.bad()]=1'b0;
  if(b.calls!=4||b.logic_values[0]!==8'ha5||b.bits[0]!==8'ha5)$fatal(1,"OOB stores");
  x=++b.logic_values[0][b.unknown()];
  if(x!==1'bx||b.calls!=5||b.logic_values[0]!==8'ha5)$fatal(1,"logic invalid prefix");
  z=++b.bits[0][b.unknown()];
  if(z!==1'b1||b.calls!=6||b.bits[0]!==8'ha5)$fatal(1,"bit invalid prefix");
  x=++b.logic_values[b.bad()][0];
  if(x!==1'bx||b.calls!=7||b.logic_values[0]!==8'ha5)$fatal(1,"logic invalid word prefix");
  z=++b.bits[b.bad()][0];
  if(z!==1'b1||b.calls!=8||b.bits[0]!==8'ha5)$fatal(1,"bit invalid word prefix");
  $display("PASSED");end
endmodule
