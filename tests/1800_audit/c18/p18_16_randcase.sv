module p18c;
 int pass=0, fail=0; task automatic ck(input string id, input bit c); if (c) pass++; else begin fail++; $display("FAIL %s", id); end endtask
 int c1=0, c2=0, c3=0, z=0, x, evals=0, hit=0; byte a=3, b=1;
 function int w(int v); evals++; return v; endfunction
 initial begin
  repeat (800) randcase 3 : c1++; 1 : c2++; 4 : c3++; endcase
  $display("INFO 3:1:4 -> %0d %0d %0d of 800", c1, c2, c3);
  ck("ratio", c1 >= 240 && c1 <= 360 && c2 >= 60 && c2 <= 140 && c3 >= 340 && c3 <= 460 && c1+c2+c3 == 800);
  repeat (200) randcase 0 : z++; 1 : ; endcase
  ck("zero_weight_never", z == 0);
  x = 7; randcase 0 : x = 1; 0 : x = 2; endcase
  ck("all_zero_no_branch", x == 7);
  repeat (100) randcase a + b : hit++; a - b : hit++; 12'h800 : ; endcase
  $display("INFO mixed-width hit=%0d of 100", hit);
  ck("expr_weights_run", hit >= 0 && hit <= 100);
  evals = 0; randcase w(1) : ; w(2) : ; endcase
  ck("weights_evaluated_once", evals == 2);
  $display("RESULT pass=%0d fail=%0d", pass, fail); if (fail != 0) $fatal(1, "randcase probe failed");
 end
endmodule
