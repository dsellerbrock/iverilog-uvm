module s3_module_function_assign;
  function automatic bit f(input bit a); return ~a; endfunction
  bit x;
  wire y;
  assign y = f(x);
  initial begin
    x = 0; #1; $display("S3 x=%0b y=%0b", x, y);
    x = 1; #1; $display("S3 x=%0b y=%0b", x, y);
    $finish;
  end
endmodule
