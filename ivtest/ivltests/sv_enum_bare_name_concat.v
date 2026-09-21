typedef enum int { Red = 0, Blue = 1 } color_t;
class palette;
  color_t value;
  function string label();
    color_t local_value;
    local_value = Blue;
    return {value.name, ":", local_value.name};
  endfunction
endclass
module test;
  color_t value;
  palette p;
  string label;
  initial begin
    p = new;
    value = Blue;
    p.value = Red;
    label = {value.name, "_bin"};
    if (label != "Blue_bin" || label != {value.name(), "_bin"})
      $fatal(1, "bare enum name concatenation: %s", label);
    label = {p.value.name, "_class"};
    if (label != "Red_class" || p.label() != "Red:Blue")
      $fatal(1, "class/local enum name: %s", label);
    value = color_t'(3);
    label = {"<", value.name, ">"};
    if (label != "<>") $fatal(1, "invalid enum value name: %s", label);
    value = Red;
    if (value.num != 2 || value.first != Red || value.last != Blue
        || value.next != Blue || value.prev != Blue)
      $fatal(1, "integral enum methods changed");
    $display("PASSED");
  end
endmodule
