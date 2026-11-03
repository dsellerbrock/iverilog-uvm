module top;
  int fa[0:2];
  int src[0:3] = '{10, 20, 30, 40};

  initial begin
    fa = {src[1:2], 99};
    if (fa[0] !== 20 || fa[1] !== 30 || fa[2] !== 99)
      $fatal(1, "ascending slice item failed: %p", fa);

    fa = {src[2:1], 99};
    if (fa[0] !== 30 || fa[1] !== 20 || fa[2] !== 99)
      $fatal(1, "descending slice item failed: %p", fa);

    $display("PASS");
  end
endmodule
