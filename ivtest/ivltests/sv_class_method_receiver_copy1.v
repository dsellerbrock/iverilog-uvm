package p;
  class producer;
    int x;

    function new(int v = 11);
      x = v;
    endfunction

    function int get();
      return x;
    endfunction
  endclass

  class consumer;
    int x;
    producer other;

    function new();
      x = 22;
      other = new(11);
    endfunction

    function int probe();
      return other.get();
    endfunction
  endclass
endpackage

module test;
  import p::*;

  initial begin
    consumer c;
    int got;

    c = new;
    got = c.probe();
    if (got !== 11) begin
      $display("FAIL got=%0d", got);
      $finish(1);
    end

    $display("PASS");
  end
endmodule
