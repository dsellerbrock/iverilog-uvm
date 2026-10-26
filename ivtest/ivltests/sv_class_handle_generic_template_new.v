module sv_class_handle_generic_template_new;
  class payload;
    int value;
    function new(); value = 1; endfunction
  endclass

  class pair #(type T1 = int, type T2 = int);
    T1 first;
    T2 second;
    function new();
      first = new;
      second = new;
    endfunction
  endclass

  pair#(payload, payload) p;
  chandle raw_a, raw_b;
  initial begin
    raw_a = null;
    raw_b = raw_a;
    p = new;
    if (p.first == null || p.second == null)
      $fatal(1, "pair handles were not created");
    $display("PASS");
  end
endmodule
