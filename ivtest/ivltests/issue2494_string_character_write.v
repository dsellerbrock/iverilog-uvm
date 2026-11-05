module issue2494_string_character_write;
  string s, a[1];
  logic [127:0] w, x, m;
  function automatic logic [127:0] f(input logic [127:0] v); return v; endfunction

  initial begin
    w = 0; w[100] = 1; x = 'x; m = 0; m[1:0] = 2'b1x;
    s = "ABC"; s[x] = "X"; $write("var  %s ", s);
    s = "ABC"; s[w] = "Y"; $write("%s ", s);
    s = "ABC"; s[m] = "Z"; $display("%s", s);
    s = "ABC"; s[f(x)] = "X"; $write("call %s ", s);
    s = "ABC"; s[f(w)] = "Y"; $write("%s ", s);
    s = "ABC"; s[f(m)] = "Z"; $display("%s", s);
    a[0] = "ABC"; a[0][x] = "X"; $write("elem %s ", a[0]);
    a[0] = "ABC"; a[0][w] = "Y"; $write("%s ", a[0]);
    a[0] = "ABC"; a[0][m] = "Z"; $display("%s", a[0]);
    a[0] = "ABC"; a[0][f(x)] = "X"; $write("elcl %s ", a[0]);
    a[0] = "ABC"; a[0][f(w)] = "Y"; $write("%s ", a[0]);
    a[0] = "ABC"; a[0][f(m)] = "Z"; $display("%s", a[0]);
  end
endmodule
