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
    $display("arr0='%s' len0=%0d arr1='%s' len1=%0d arr2='%s' len2=%0d", arr[0], arr[0].len(), arr[1], arr[1].len(), arr[2], arr[2].len());
    n = "stale"; n.hextoa(32'hdeadbeef);
    $display("hextoa='%s' len=%0d lower='%s' lower_len=%0d eq=%b", n, n.len(), n.tolower(), n.tolower().len(), n.tolower() == "deadbeef");
    n = "deadbeef";
    $display("atohex_decimal=%0d hex=%08x equal=%b", n.atohex(), n.atohex(), n.atohex() == 32'hdeadbeef);
  end
endmodule
