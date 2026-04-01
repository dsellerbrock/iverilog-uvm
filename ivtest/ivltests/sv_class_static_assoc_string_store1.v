module test;

  class item;
    static item by_name[string];
    string name;

    function new(string s);
      name = s;
      by_name[s] = this;
    endfunction

    static function item lookup(string s);
      if (by_name.exists(s))
        return by_name[s];
      return null;
    endfunction
  endclass

  initial begin
    item a;
    item b;
    item c;

    a = new("alpha");
    b = item::lookup("alpha");
    if (b == null || b !== a) begin
      $display("FAILED: alpha lookup");
      $finish(1);
    end

    c = new("beta");
    if (item::lookup("beta") !== c) begin
      $display("FAILED: beta lookup");
      $finish(1);
    end

    if (item::lookup("missing") != null) begin
      $display("FAILED: missing lookup");
      $finish(1);
    end

    $display("PASSED");
  end
endmodule
