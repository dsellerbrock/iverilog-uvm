// Behavioral/testbench style: functions, loops, arrays, integer math.
module top;
  function automatic int hash(int x);
    int h = x;
    for (int k=0;k<8;k++) h = (h * 31) ^ (h >>> 7) + k;
    return h;
  endfunction
  int mem [0:1023];
  int sum = 0;
  initial begin
    for (int it=0; it<300; it++) begin
      for (int j=0;j<1024;j++) mem[j] = hash(j + it);
      for (int j=0;j<1024;j++) sum += mem[j] & 255;
      #1;
    end
    $display("sum=%0d", sum);
  end
endmodule
