module top;
  logic [7:0] q[$];
  bit [7:0] b[$];
  logic [7:0] bounded[$:1];
  integer idx;
  integer bitidx;
  initial begin
    q[0][3:0] = 4'h3;
    if (q.size() != 1 || q[0] !== 8'bxxxx0011) $fatal(1, "empty queue append");
    q[q.size()][7:4] = 4'ha;
    if (q.size() != 2 || q[1] !== 8'b1010xxxx) $fatal(1, "queue append");
    idx = 2;
    q[idx][2 +: 3] = 3'b101;
    if (q.size() != 3 || q[2] !== 8'bxxx101xx) $fatal(1, "indexed append");
    q[0][7:4] = 4'hc;
    if (q.size() != 3 || q[0] !== 8'hc3) $fatal(1, "existing element");
    bitidx = -2;
    q[q.size()][bitidx +: 4] = 4'b1011;
    bitidx = 6;
    q[q.size()][bitidx +: 4] = 4'b1011;
    if (q.size() != 5 || q[3] !== 8'bxxxxxx10 || q[4] !== 8'b11xxxxxx)
      $fatal(1, "partially out-of-range selects");
    bitidx = 'x;
    q[q.size()][bitidx +: 4] = 4'hf;
    q[7][bitidx +: 4] = 4'hf;
    bitidx = 9;
    q[q.size()][bitidx +: 4] = 4'hf;
    if (q.size() != 5) $fatal(1, "invalid part select appended");
    b[0][3:0] = 4'b1x01;
    if (b.size() != 1 || b[0] !== 8'h09) $fatal(1, "two-state append");
    bounded[0][3:0] = 4'h5;
    bounded[1][7:4] = 4'h6;
    if (bounded.size() != 2 || bounded[0] !== 8'bxxxx0101 ||
        bounded[1] !== 8'b0110xxxx) $fatal(1, "bounded queue append");
    bounded[2][3:0] = 4'hf;
    q[7][3:0] = 4'hf;
    if (bounded.size() != 2 || q.size() != 5 || q[0] !== 8'hc3)
      $fatal(1, "invalid queue index changed queue");
    $display("PASSED");
  end
endmodule
