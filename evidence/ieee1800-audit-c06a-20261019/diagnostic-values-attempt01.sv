module diagnostic_values;
  class C; string name = "obj"; endclass
  string arr[3] = '{"a", "bb", "ccc"};
  string n;
  C o;
  initial begin
    o = new;
    $display("member='%s' len=%0d upper='%s'", o.name, o.name.len(), o.name.toupper());
    o.name[0] = "O";
    $display("member_after_write='%s' len=%0d", o.name, o.name.len());
    $display("arr0='%s' arr1='%s' arr2='%s'", arr[0], arr[1], arr[2]);
    n = "deadbeef";
    $display("atohex_decimal=%0d hex=%08x equal=%b", n.atohex(), n.atohex(), n.atohex() == 32'hdeadbeef);
  end
endmodule
