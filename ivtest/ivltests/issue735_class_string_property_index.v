module issue735_class_string_property_index;
  class C;
    string name = "obj";
    string words[1:0];
  endclass

  initial begin
    C o;
    byte ch;
    o = new;
    o.words[0] = "first";
    o.words[1] = "second";
    ch = o.name[1];
    if (ch != 8'd98)
      $fatal(1, "string property character index returned %0d", ch);
    if (o.words[0] != "first" || o.words[1] != "second")
      $fatal(1, "fixed string-array property element indexing failed");
    $display("ISSUE735_CLASS_STRING_PROPERTY_INDEX_PASSED");
    $display("PASSED");
  end
endmodule
