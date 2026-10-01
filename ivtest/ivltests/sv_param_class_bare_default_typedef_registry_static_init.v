package defaults_pkg;
  int calls[7];
  function automatic int seen(int id);
    calls[id]++;
    return id;
  endfunction
  class AliasOnly #(int ID = 1);
    static int marker = seen(ID);
  endclass
  class AliasAndUse #(int ID = 2);
    static int marker = seen(ID);
  endclass
  class GenericOnly #(int ID = 3);
    static int marker = seen(ID);
  endclass
  class Ordinary;
    static int marker = seen(4);
  endclass
  typedef AliasOnly bare_t;
  typedef AliasOnly second_bare_t;
  typedef bare_t chained_bare_t;
  typedef AliasAndUse used_t;
  typedef Ordinary ordinary_t;
endpackage
module test;
  import defaults_pkg::*;
  used_t handle;
  if (0) begin : disabled
    typedef AliasOnly#(6) disabled_t;
  end
  initial begin
    #1;
    if (calls[1] != 1 || calls[2] != 1 || calls[3] != 0 ||
        calls[4] != 1 || calls[6] != 0)
      $fatal(1, "before new: bare=%0d used=%0d generic=%0d ordinary=%0d disabled=%0d",
             calls[1], calls[2], calls[3], calls[4], calls[6]);
    handle = new;
    #1;
    if (calls[1] != 1 || calls[2] != 1)
      $fatal(1, "after new: bare=%0d used=%0d", calls[1], calls[2]);
    $display("PASSED");
  end
endmodule
