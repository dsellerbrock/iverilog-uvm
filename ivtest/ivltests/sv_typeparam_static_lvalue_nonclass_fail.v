// The generic holder seed must defer T::value, but a concrete holder#(int)
// specialization must reject int as a class-scoped l-value receiver.
module sv_typeparam_static_lvalue_nonclass_fail;
  class holder #(type T = int);
    static function void set();
      begin
        T::value = 1;
        return;
      end
    endfunction
  endclass

  initial holder#(int)::set();
endmodule
