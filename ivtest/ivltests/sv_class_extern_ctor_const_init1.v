package p;
  class worker;
    const int id = 7;
    string tag = "ok";

    extern function new();

    function int get_id();
      return id;
    endfunction

    function string get_tag();
      return tag;
    endfunction
  endclass

  function worker::new();
  endfunction
endpackage

module test;
  import p::*;

  initial begin
    worker w;

    w = new;
    if (w.get_id() != 7) begin
      $display("FAIL id=%0d", w.get_id());
      $finish(1);
    end

    if (w.get_tag() != "ok") begin
      $display("FAIL tag=%s", w.get_tag());
      $finish(1);
    end

    $display("PASS");
  end
endmodule
