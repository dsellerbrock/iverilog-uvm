module issue2122_child(input logic [3:0] id);
endmodule

module issue2122_instance_array_packed_port;
  issue2122_child u[3:0](.id(16'h3210));
  issue2122_child repeated[3:0](.id(4'hA));
  issue2122_child zero[3:0](.id('0));

  initial begin
    #1 $display("%0d %0d %0d %0d",
                u[3].id, u[2].id, u[1].id, u[0].id);
    $display("%0d %0d %0d %0d",
             repeated[3].id, repeated[2].id, repeated[1].id, repeated[0].id);
    $display("%0d %0d %0d %0d",
             zero[3].id, zero[2].id, zero[1].id, zero[0].id);
  end
endmodule
