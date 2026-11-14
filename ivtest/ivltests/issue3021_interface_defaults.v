interface class api;
  pure virtual function int f(int x = 4, logic [3:0] y = 4'b10xz);
  pure virtual function real g(real x = 1.5);
endclass
class impl implements api;
  virtual function int f(int x = 2 + 2, logic [3:0] y = 4'b10xz);
    if (y !== 4'b10xz) $fatal(1, "wrong four-state default");
    return x;
  endfunction
  virtual function real g(real x = 1.5); return x; endfunction
endclass
module issue3021_interface_defaults;
  impl obj;
  api handle;
  initial begin
    obj = new; handle = obj;
    if (handle.f() != 4 || handle.g() != 1.5) $fatal(1, "wrong default");
    if (obj.f() != 4 || obj.g() != 1.5) $fatal(1, "wrong implementation default");
    $display("PASS");
  end
endmodule
