class enum_select_box;
 typedef enum logic signed [7:0] {E_ZERO=0,E_A5=8'ha5} value_t;
 value_t values[];value_t queue[$];int word_calls,base_calls;
 function new;values=new[2];values[0]=E_A5;values[1]=E_ZERO;queue.push_back(E_A5);endfunction
 function int word();word_calls++;return 0;endfunction
 function int base();base_calls++;return 2;endfunction
endclass
module sv_class_enum_container_packed_select;
 enum_select_box b=new;byte old;
 initial begin
  if(b.values[0][7]!==1'b1||b.values[0][6:4]!==3'b010||b.queue[0][3:1]!==3'b010)$fatal(1,"enum reads");
  b.values[b.word()][b.base()+:3]=3'b111;
  if(b.word_calls!=1||b.base_calls!=1||b.values[0]!==8'hbd)$fatal(1,"indexed up write %h",b.values[0]);
  b.values[0][6-:3]=3'b001;
  if(b.values[0]!==8'h9d)$fatal(1,"indexed down write %h",b.values[0]);
  b.queue[0][3:1]=3'b101;
  if(b.queue[0]!==8'hab)$fatal(1,"queue write %h",b.queue[0]);
  old=b.values[0][3:0]++;if(old!==8'h0d||b.values[0]!==8'h9e)$fatal(1,"enum part postfix");
  old=--b.queue[0][7:4];if(old!==8'h09||b.queue[0]!==8'h9b)$fatal(1,"enum part prefix");
  b.values[0][3:0]+=2;if(b.values[0]!==8'h90)$fatal(1,"enum part compound %h",b.values[0]);
  $display("PASSED");end
endmodule
