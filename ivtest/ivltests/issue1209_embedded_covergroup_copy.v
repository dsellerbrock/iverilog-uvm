covergroup external_cg_t with function sample(bit value);
  cp: coverpoint value;
endgroup

class C;
  covergroup cg with function sample(bit value);
    cp: coverpoint value;
  endgroup
  external_cg_t external_cg;
  function new();
    cg = new;
    external_cg = new;
  endfunction
endclass

module test;
  C a, b;
  initial begin
    a = new;
    b = new a;
    if (b.cg != null)
      $fatal(1, "embedded covergroup handle was copied");
    if (b.external_cg != a.external_cg)
      $fatal(1, "separate covergroup handle was not shared");
    $display("PASSED");
  end
endmodule
