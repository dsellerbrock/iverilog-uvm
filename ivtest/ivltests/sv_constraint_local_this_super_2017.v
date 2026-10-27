module sv_constraint_local_this_super_2017;
  class target;
    rand bit [7:0] x;
  endclass

  class caller_base;
    bit [7:0] y = 8'd7;
  endclass

  class caller extends caller_base;
    bit [7:0] y = 8'd5;

    function bit constrain_this(target obj);
      return obj.randomize() with { x == local::this.y; };
    endfunction

    function bit constrain_super(target obj);
      return obj.randomize() with { x == local::super.y; };
    endfunction
  endclass

  target obj;
  caller c;
  initial begin
    obj = new;
    c = new;

    if (!c.constrain_this(obj) || obj.x != c.y)
      $fatal(1, "local::this did not bind to caller this");
    if (!c.constrain_super(obj) || obj.x != 8'd7)
      $fatal(1, "local::super did not bind to caller super");

    $display("PASS local::this and local::super");
    $display("PASSED");
  end
endmodule
