covergroup shared_cg_t with function sample(bit value);
  cp: coverpoint value;
endgroup

class C;
  covergroup cg with function sample(bit value);
    cp: coverpoint value;
  endgroup
  shared_cg_t shared_cg;

  function new();
    cg = new;
    shared_cg = new;
  endfunction
endclass

module test;
  C a, b;
  initial begin
    a = new;
    b = new a;
    if (b.cg != null)
      $fatal(1, "embedded covergroup handle was copied");
    if (b.shared_cg != a.shared_cg)
      $fatal(1, "separately declared covergroup handle was not shared");
    $display("PASS embedded covergroup shallow copy");
  end
endmodule
