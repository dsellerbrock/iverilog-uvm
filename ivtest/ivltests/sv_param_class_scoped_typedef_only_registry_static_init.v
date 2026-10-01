package scoped_registry_pkg;
  int calls[3];
  function automatic int record(int id);
    calls[id]++;
    return id;
  endfunction
  class Registry #(int ID = 0);
    static int marker = record(ID);
  endclass
  class Holder #(int ID = 1);
    static int marker = record(2);
    typedef Registry#(ID) type_id;
  endclass
endpackage
module test;
  import scoped_registry_pkg::*;
  typedef Holder::type_id alias_t;
  typedef Holder::type_id second_alias_t;
  initial begin
    #1;
    if (calls[1] != 1 || calls[0] != 0 || calls[2] != 1)
      $fatal(1, "scoped=%0d generic=%0d holder=%0d",
             calls[1], calls[0], calls[2]);
    $display("PASSED");
  end
endmodule
