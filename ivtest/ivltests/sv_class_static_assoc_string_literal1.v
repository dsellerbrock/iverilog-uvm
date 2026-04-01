module test;

  class domain_like;
    static domain_like by_name[string];
    string name;

    function new(string s);
      name = s;
      by_name[s] = this;
    endfunction

    static function bit has_common();
      return by_name.exists("common");
    endfunction

    static function domain_like lookup_common();
      if (by_name.exists("common"))
        return by_name["common"];
      return null;
    endfunction

    static function domain_like get_common();
      domain_like tmp;

      tmp = lookup_common();
      if (tmp == null)
        tmp = new("common");
      return tmp;
    endfunction
  endclass

  initial begin
    domain_like a;
    domain_like b;
    domain_like c;

    a = domain_like::get_common();
    b = domain_like::get_common();
    c = domain_like::lookup_common();

    if (!domain_like::has_common()) begin
      $display("FAILED: literal exists lookup missed stored object");
      $finish(1);
    end

    if (a == null || b == null || c == null) begin
      $display("FAILED: null common instance");
      $finish(1);
    end

    if (a !== b || a !== c) begin
      $display("FAILED: literal lookup created duplicate singleton");
      $finish(1);
    end

    if (a.name != "common") begin
      $display("FAILED: wrong common instance name");
      $finish(1);
    end

    $display("PASSED");
  end
endmodule
