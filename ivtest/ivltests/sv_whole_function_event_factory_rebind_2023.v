module sv_whole_function_event_factory_rebind;
 class item_t;
  int value;
  function int read_value();return value;endfunction
 endclass
 item_t item,old_item,replacement;
 bit woke;
 function automatic item_t receiver();return item;endfunction
 initial begin
  old_item=new;replacement=new;item=old_item;
  fork begin @(receiver().read_value());woke=1;end join_none
  #1 item=replacement;
  #1 if(woke)$fatal(1,"equal receiver rebind woke");
  old_item.value=1;
  #1 if(woke)$fatal(1,"old receiver mutation woke");
  replacement.value=1;
  #1 if(!woke)$fatal(1,"new receiver mutation missed");
  $display("PASS factory rebind");$finish;
 end
endmodule
