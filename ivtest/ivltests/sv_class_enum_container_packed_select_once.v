class enum_select_once_box;
 typedef enum logic [7:0] {E0=0, E55=8'h55} value_t;
 value_t values[]; value_t queue[$];
 function new(value_t v); values=new[1];values[0]=v;queue.push_back(v);endfunction
endclass
module sv_class_enum_container_packed_select_once;
 enum_select_once_box first,second,current; int receiver_calls,word_calls,base_calls; bit old;
 function automatic int word_index(); receiver_calls++;word_calls++;current=second;return 0;endfunction
 function automatic int packed_base(); base_calls++;first.values[0][7:4]=4'ha;return 0;endfunction
 initial begin
  first=new(enum_select_once_box::E55);second=new(enum_select_once_box::E0);
  repeat(32) begin
   current=first;old=current.values[word_index()][packed_base()]++;
   if(old!==!first.values[0][0])$fatal(1,"postfix result stack");
   current=first;--current.queue[word_index()][0];
  end
  if(receiver_calls!=64||word_calls!=64||base_calls!=32)
   $fatal(1,"selectors repeated receiver=%0d word=%0d base=%0d",receiver_calls,word_calls,base_calls);
  if(first.values[0]!==8'ha5||first.queue[0]!==8'h55||second.values[0]!==8'h00)$fatal(1,"receiver/neighbor preservation");
  first.values[0][7:0]=8'haa;if(first.values[0]!==8'haa)$fatal(1,"full-width selected vector");
  $display("PASSED");
 end
endmodule
