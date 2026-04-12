interface counter_if;
  logic rst_n;
endinterface

virtual class base_imp #(type T = int);
  virtual function bit get();
    return 0;
  endfunction
endclass

class def_imp #(type T = int) extends base_imp #(T);
  static function def_imp #(T) make();
    def_imp #(T) tmp;
    tmp = new;
    return tmp;
  endfunction

  virtual function bit get();
    return 1;
  endfunction
endclass

class holder #(type T = int);
  static base_imp #(T) imp;

  static function base_imp #(T) get_imp();
    if (imp == null)
      imp = def_imp #(T)::make();
    return imp;
  endfunction
endclass

module test;
  initial begin
    base_imp #(virtual counter_if) imp;

    imp = holder #(virtual counter_if)::get_imp();
    $display("GET=%0d", imp.get());
    if (!imp.get()) begin
      $display("FAIL");
      $finish(1);
    end

    $display("PASS");
  end
endmodule
