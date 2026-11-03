class issue736_name;
  string name;
endclass

typedef struct {
  string text;
} issue736_record_t;

module issue736_string_property_index;
  issue736_name object;
  issue736_record_t record;
  string direct;
  string fixed [2];
  int index;

  initial begin
    object = new;
    object.name = "obj";
    record.text = "xyz";
    direct = "abc";
    fixed[1] = "arr";

    index = 0;
    object.name[index] = "O";
    record.text[0] = "X";
    direct[0] = "A";
    fixed[1][0] = "B";
    if (object.name != "Obj")
      $fatal(1, "class string character write: %s", object.name);
    if (record.text != "Xyz")
      $fatal(1, "struct string character write: %s", record.text);
    if (direct != "Abc")
      $fatal(1, "plain string control: %s", direct);
    if (fixed[1] != "Brr")
      $fatal(1, "fixed-array string control: %s", fixed[1]);

    object.name[1] += 1;
    record.text[1] += 1;
    if (object.name != "Ocj" || record.text != "Xzz")
      $fatal(1, "compound property character write: %s / %s",
             object.name, record.text);

    object.name[2] = 8'h00;
    record.text[2] = 8'h00;
    object.name[7] = "!";
    record.text[7] = "!";
    if (object.name != "Ocj" || record.text != "Xzz")
      $fatal(1, "zero or out-of-range character write changed string");

    $display("PASS indexed class and struct string writes");
  end
endmodule
