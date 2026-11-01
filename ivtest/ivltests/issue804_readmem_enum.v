module top;
  typedef enum logic [3:0] {A = 0, B = 1, C = 2} et;
  et mem [0:2];

  initial begin
    mem[0] = A;
    mem[1] = A;
    mem[2] = A;
    $readmemh("ivltests/issue804_readmem_enum.mem", mem);
    if (mem[0] !== B || mem[1] !== A || mem[2] !== A)
      $fatal(1, "enum readmem result was %0d,%0d,%0d",
             mem[0], mem[1], mem[2]);
    $display("PASS: enum readmem stopped at the invalid value");
    $finish;
  end
endmodule
