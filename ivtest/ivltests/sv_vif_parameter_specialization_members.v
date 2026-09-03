// IEEE 1800-2017/2023 25.8 and 25.9: effective interface parameter
// values and types are part of a virtual-interface type. Equivalent default,
// empty, ordered, and named spellings must share one specialization while
// nondefault widths survive typedefs, class properties, and modport views.
interface param_vif_member_if #(parameter WIDTH = 8);
  logic [WIDTH-1:0] data;
  modport drive(output data);
endinterface

typedef virtual interface param_vif_member_if #(13) vif13_t;
typedef virtual interface param_vif_member_if #(.WIDTH(21)).drive
    vif21_drive_t;

class specialization_holder;
  virtual interface param_vif_member_if default_vif;
  virtual interface param_vif_member_if #() empty_vif;
  virtual interface param_vif_member_if #(.WIDTH(8)) named8_vif;
  virtual interface param_vif_member_if #(13) ordered13_vif;
  vif13_t typedef13_vif;
  vif21_drive_t drive21_vif;
endclass

module sv_vif_parameter_specialization_members;
  param_vif_member_if implicit8();
  param_vif_member_if #() empty8();
  param_vif_member_if #(.WIDTH(8)) named8();
  param_vif_member_if #(13) ordered13();
  param_vif_member_if #(.WIDTH(13)) named13();
  param_vif_member_if #(.WIDTH(21)) named21();
  specialization_holder holder;

  initial begin
    holder = new;

    // All four spellings below have the same effective default specialization.
    holder.default_vif = named8;
    holder.empty_vif = implicit8;
    holder.named8_vif = empty8;

    holder.ordered13_vif = ordered13;
    holder.typedef13_vif = named13;
    holder.drive21_vif = named21;

    holder.default_vif.data = 8'ha5;
    if (named8.data !== 8'ha5)
      $fatal(1, "implicit/named default specialization failed");

    holder.empty_vif.data = 8'h3c;
    if (implicit8.data !== 8'h3c)
      $fatal(1, "empty/default specialization failed");

    holder.named8_vif.data = 8'h5a;
    if (empty8.data !== 8'h5a)
      $fatal(1, "named/empty default specialization failed");

    // Distinct instances of the same W13 specialization are legal operands.
    if (holder.ordered13_vif == holder.typedef13_vif)
      $fatal(1, "distinct W13 instances compared equal");

    ordered13.data = 13'h0fed;
    if (holder.ordered13_vif.data !== 13'h0fed)
      $fatal(1, "ordered W13 member read failed");

    holder.ordered13_vif.data = 13'h1abc;
    if (ordered13.data !== 13'h1abc)
      $fatal(1, "ordered W13 member write failed");

    holder.typedef13_vif.data = 13'h1234;
    if (named13.data !== 13'h1234)
      $fatal(1, "named W13 member write failed");

    holder.typedef13_vif = ordered13;
    if (holder.ordered13_vif != holder.typedef13_vif)
      $fatal(1, "equivalent W13 handles compared unequal");

    // An unqualified interface source may initialize a selected-modport VIF.
    holder.drive21_vif.data = 21'h1abcde;
    if (named21.data !== 21'h1abcde)
      $fatal(1, "selected W21 member write failed");

    $display("PASSED");
  end
endmodule
