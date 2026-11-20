module issue3897_assign_select;
  logic [7:0] source;
  logic [2:0] base;
  logic [1:0] amount;
  logic [3:0] result;

  task automatic activate;
    assign result = source[base +: 4] << amount;
  endtask

  task automatic check(input logic [3:0] expected);
    if (result !== expected)
      $fatal(1, "result = %h, expected %h", result, expected);
  endtask

  initial begin
    source = 8'h93;
    base = 0;
    amount = 0;
    activate();
    check(4'h3);
    base = 4;
    #0 check(4'h9);
    amount = 1;
    #0 check(4'h2);
    source = 8'hb3;
    #0 check(4'h6);
    base = 'x;
    #0 check(4'bxxx0);

    base = 0;
    deassign result;
    result = 4'h7;
    #0 check(4'h7);

    activate();
    check(4'h6);
    amount = 0;
    assign result = ~source[3:0];
    check(4'hc);
    #0 check(4'hc);
    source = 8'hb2;
    #0 check(4'hd);
    deassign result;
    $display("PASSED");
  end
endmodule
