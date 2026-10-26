class C;
  protected int value = 0;
  protected function int secret(); return value; endfunction
endclass
module sv_protected_external_access_fail;
  C c;
  initial begin
    c = new;
    c.value = 1;
    $display("outside write=%0d", c.value);
    $display("outside method=%0d", c.secret());
  end
endmodule
