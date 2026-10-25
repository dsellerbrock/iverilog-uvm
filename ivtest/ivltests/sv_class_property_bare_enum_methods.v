// Bare enum methods on a class property follow IEEE 1800-2017/2023 6.19.5.7.
typedef enum { red, green, blue, yellow } Colors;

class holder;
  Colors color = green;
endclass

module sv_class_property_bare_enum_methods;
  initial begin
    automatic holder h = new;
    $display("%0d %0d %0d %0d %0d %s", h.color.first, h.color.last,
             h.color.next, h.color.prev, h.color.num, h.color.name);
    if (h.color.first !== red) $fatal(1, "first");
    if (h.color.last !== yellow) $fatal(1, "last");
    if (h.color.next !== blue) $fatal(1, "next");
    if (h.color.prev !== red) $fatal(1, "prev");
    if (h.color.num !== 4) $fatal(1, "num");
    if (h.color.name != "green") $fatal(1, "name");
    if (h.color.first() !== red || h.color.next() !== blue)
      $fatal(1, "explicit calls");
    $display("PASSED");
  end
endmodule
