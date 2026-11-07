// IEEE 1800-2017/2023 21.2.1.7: %p of a class object prints each property
// as name:value, including associative-array properties.
module issue2592_p_class_assoc_label;
  class c;
    int ids[int];
    int n = 2;
    string tags[string];
  endclass
  c h = new;
  string s;

  initial begin
    h.ids[5] = 50; h.ids[1] = 10;
    h.tags["b"] = "x"; h.tags["a"] = "y";
    s = $sformatf("%p", h);
    if (s == "'{ids:'{1:10, 5:50}, n:2, tags:'{a:\"y\", b:\"x\"}}")
      $display("PASSED");
    else
      $display("FAILED: %s", s);
  end
endmodule
