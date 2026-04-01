module test;
  class child;
    int id;

    function new(int value);
      id = value;
    endfunction
  endclass

  class holder;
    child kids[string];

    function void add(string name, int id);
      kids[name] = new(id);
    endfunction

    function int first(ref string name);
      return kids.first(name);
    endfunction

    function int next(ref string name);
      return kids.next(name);
    endfunction

    function child get(string name);
      if (kids.exists(name))
        return kids[name];
      return null;
    endfunction
  endclass

  initial begin
    holder h;
    child c;
    int first_id;
    string key;

    h = new;
    key = "";
    first_id = -1;

    h.add("alpha", 11);
    h.add("beta", 22);

    if (!h.first(key)) begin
      $display("FAILED: missing first key");
      $finish;
    end

    c = h.get(key);
    if (c == null) begin
      $display("FAILED: null child for first key '%s'", key);
      $finish;
    end
    first_id = c.id;

    if (!h.next(key)) begin
      $display("FAILED: missing next key");
      $finish;
    end

    c = h.get(key);
    if (c == null) begin
      $display("FAILED: null child for next key '%s'", key);
      $finish;
    end

    if (c.id == first_id) begin
      $display("FAILED: next() did not advance to a different child");
      $finish;
    end

    if (h.next(key)) begin
      $display("FAILED: unexpected third key '%s'", key);
      $finish;
    end

    $display("PASSED");
  end
endmodule
