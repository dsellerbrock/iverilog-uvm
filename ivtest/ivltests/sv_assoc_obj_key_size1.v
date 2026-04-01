module test;
  class key_t;
    int id;
    function new(int i);
      id = i;
    endfunction
  endclass

  typedef bit aa_t[key_t];

  aa_t aa;
  key_t k1, k2, k;
  int count;

  initial begin
    k1 = new(1);
    k2 = new(2);

    aa[k1] = 1'b1;
    aa[k2] = 1'b1;

    foreach (aa[k]) count += 1;

    $display("SIZE=%0d COUNT=%0d", aa.size(), count);
    if (aa.size() !== 2 || count !== 2) begin
      $display("FAIL");
      $finish(1);
    end

    $display("PASS");
  end
endmodule
