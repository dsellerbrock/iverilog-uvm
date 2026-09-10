package p;
  class resource;
    int value;
  endclass
  class queue_type #(type T=int);
    T value;
  endclass
  class types;
    typedef queue_type#(resource) rsrc_q_t;
  endclass
  class checker_type #(type T=int);
    static function T identity(input T value); return value; endfunction
  endclass
  class pool;
    function int probe();
      types::rsrc_q_t original, result_handle;
      resource item;
      original=new;
      item=new;
      item.value=73;
      original.value=item;
      result_handle=checker_type#(types::rsrc_q_t)::identity(original);
      return result_handle==original && result_handle.value.value==73;
    endfunction
  endclass
endpackage
module main;
  import p::*;
  pool object_handle;
  initial begin
    object_handle=new;
    if (!object_handle.probe()) $fatal(1,"specialization or handle identity lost");
    $display("PASSED"); $finish(0);
  end
endmodule
