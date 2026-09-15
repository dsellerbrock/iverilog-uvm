class enum_select_ascending_box;
 typedef enum logic [0:7] {E_ZERO=0,E_81=8'h81} value_t;
 value_t values[]; value_t queue[$];
 function new; values=new[1];values[0]=E_81;queue.push_back(E_81);endfunction
endclass
module sv_class_enum_container_packed_select_ascending;
 enum_select_ascending_box b=new;
 initial begin
  if(b.values[0][0]!==1'b1||b.values[0][1:3]!==3'b000||b.queue[0][7]!==1'b1)$fatal(1,"ascending reads");
  b.values[0][1:3]=3'b111;
  if(b.values[0]!==8'hf1)$fatal(1,"ascending part write %h",b.values[0]);
  b.queue[0][0:7]=8'h3c;
  if(b.queue[0]!==8'h3c)$fatal(1,"full width vector write");
  $display("PASSED");
 end
endmodule
