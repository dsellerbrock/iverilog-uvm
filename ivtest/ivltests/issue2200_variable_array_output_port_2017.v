module issue2200_driver(output logic [7:0] data [1:0]);
  always_comb begin
    data[0] = 8'h01;
    data[1] = 8'h02;
  end
endmodule

module test;
  logic [7:0] arr [0:1][1:0];
  logic [7:0] plain [1:0];

  issue2200_driver u(.data(arr[0]));

  initial begin
    #1;
    if (arr[0][0] !== 8'h01 || arr[0][1] !== 8'h02)
      $fatal(1, "selected=%h %h", arr[0][0], arr[0][1]);
    if (arr[1][0] !== 8'hxx || arr[1][1] !== 8'hxx)
      $fatal(1, "unselected=%h %h", arr[1][0], arr[1][1]);
    if (plain[0] !== 8'hxx || plain[1] !== 8'hxx)
      $fatal(1, "never-connected=%h %h", plain[0], plain[1]);
    $display("PASSED");
  end
endmodule
