module test;
  class base_obj;
    int id;
    function new(int v = 0);
      id = v;
    endfunction
  endclass

  class derived_obj extends base_obj;
    function new();
      super.new(123);
    endfunction
  endclass

  class creator;
    static function base_obj create_by_type();
      derived_obj tmp;
      tmp = new();
      return tmp;
    endfunction

    static function string base_type_name();
      return "base_obj";
    endfunction
  endclass

  class registry_common #(type Tcreator = creator, type Tcreated = int);
    static function Tcreated create();
      base_obj obj;
      obj = Tcreator::create_by_type();
      if (!$cast(create, obj)) begin
        $display("FAIL cast");
        $finish(1);
      end
    endfunction
  endclass

  class reg_special extends registry_common#(creator, derived_obj);
  endclass

  initial begin
    derived_obj d;

    d = reg_special::create();
    if (d == null) begin
      $display("FAIL null");
      $finish(1);
    end

    if (d.id != 123) begin
      $display("FAIL bad %0d", d.id);
      $finish(1);
    end

    $display("PASSED");
  end
endmodule
