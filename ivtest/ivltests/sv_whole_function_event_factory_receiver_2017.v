module sv_whole_function_event_factory_receiver;
 class item_t;
  int value;
  function int read_value();return value;endfunction
 endclass
 item_t item;
 int calls;
 bit woke;
 function automatic item_t receiver();calls++; return item;endfunction
 initial begin
  item=new;item.value=0;
  fork begin @(receiver().read_value());woke=1;end join_none
  #1 if(calls!=1)$fatal(1,"receiver evaluated more than once");
  item.value=1;
  #1 if(!woke)$fatal(1,"factory receiver member mutation missed");
  $display("PASS factory receiver");$finish;
 end
endmodule
