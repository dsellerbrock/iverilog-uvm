// IEEE 1800-2017 11.4.13: an unpacked array in an inside list contributes
// its singular elements, compared with wildcard equality.
module sv_inside_const_array_parameter;
  parameter logic [3:0] codes [0:2] = '{4'h1, 4'h7, 4'he};
  parameter logic [3:0] wildcard_codes [0:1] = '{4'b10x1, 4'b011z};
  parameter logic [3:0] singleton [2:2] = '{4'ha};
  parameter logic [3:0] grid [0:1][0:1] = '{'{4'h2, 4'h4}, '{4'h6, 4'h8}};
  int empty_q[$];

  task automatic check(input string label, input logic got,
                       input logic expected);
    if (got !== expected) begin
      $display("FAILED -- %s: got %b expected %b", label, got, expected);
      $finish(1);
    end
  endtask

  initial begin
    check("first", 4'h1 inside {codes}, 1);
    check("middle", 4'h7 inside {codes}, 1);
    check("last", 4'he inside {codes}, 1);
    check("nonmember", 4'h2 inside {codes}, 0);
    check("wildcard x", 4'b1001 inside {wildcard_codes}, 1);
    check("wildcard z", 4'b0111 inside {wildcard_codes}, 1);
    check("wildcard nonmember", 4'b1101 inside {wildcard_codes}, 0);
    check("singleton", 4'ha inside {singleton}, 1);
    check("multidimensional leaf", 4'h8 inside {grid}, 1);
    check("multidimensional nonmember", 4'h9 inside {grid}, 0);
    check("empty queue", 4'h1 inside {empty_q}, 0);
    $display("PASSED");
  end
endmodule
