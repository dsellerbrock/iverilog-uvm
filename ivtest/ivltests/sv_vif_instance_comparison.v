// IEEE 1800-2017/2023 25.9: logical equality and inequality may compare a
// virtual interface with null, another same-type virtual interface, or a
// same-type concrete interface instance.  Every result is poisoned first so
// an elaboration path that silently drops the comparison cannot false-pass.
interface sv_vif_instance_comparison_if;
  logic value;
endinterface

interface sv_vif_same_spelling_if;
  logic value;
endinterface

module sv_vif_instance_comparison;
  sv_vif_instance_comparison_if first();
  sv_vif_instance_comparison_if second();

  // The instance deliberately has the same spelling as its interface type.
  // This exercises the type/instance namespace ambiguity in expression
  // binding when the virtual-interface operand supplies the expected type.
  sv_vif_same_spelling_if sv_vif_same_spelling_if();

  virtual sv_vif_instance_comparison_if left_vif;
  virtual sv_vif_instance_comparison_if right_vif;
  virtual sv_vif_same_spelling_if same_spelling_vif;
  logic select_second;
  logic observed;

  initial begin
    left_vif = null;
    right_vif = null;

    observed = 1'bx;
    observed = (left_vif == null);
    if (observed !== 1'b1)
      $fatal(1, "null virtual interface did not equal null");

    observed = 1'bx;
    observed = (null == right_vif);
    if (observed !== 1'b1)
      $fatal(1, "null did not equal null virtual interface");

    observed = 1'bx;
    observed = (left_vif != null);
    if (observed !== 1'b0)
      $fatal(1, "null virtual interface compared unequal to null");

    observed = 1'bx;
    observed = (null != right_vif);
    if (observed !== 1'b0)
      $fatal(1, "null compared unequal to null virtual interface");

    left_vif = first;
    right_vif = first;

    observed = 1'bx;
    observed = (left_vif == right_vif);
    if (observed !== 1'b1)
      $fatal(1, "independent handles to one instance compared unequal");

    observed = 1'bx;
    observed = (left_vif != right_vif);
    if (observed !== 1'b0)
      $fatal(1, "independent handles to one instance compared different");

    observed = 1'bx;
    observed = (left_vif == first);
    if (observed !== 1'b1)
      $fatal(1, "virtual interface did not equal its concrete instance");

    observed = 1'bx;
    observed = (first == left_vif);
    if (observed !== 1'b1)
      $fatal(1, "concrete instance did not equal its virtual interface");

    observed = 1'bx;
    observed = (left_vif != first);
    if (observed !== 1'b0)
      $fatal(1, "virtual interface compared unequal to its instance");

    observed = 1'bx;
    observed = (first != left_vif);
    if (observed !== 1'b0)
      $fatal(1, "instance compared unequal to its virtual interface");

    observed = 1'bx;
    observed = (left_vif != second);
    if (observed !== 1'b1)
      $fatal(1, "virtual interface did not differ from another instance");

    observed = 1'bx;
    observed = (second != left_vif);
    if (observed !== 1'b1)
      $fatal(1, "another instance did not differ from virtual interface");

    right_vif = second;

    observed = 1'bx;
    observed = (left_vif == right_vif);
    if (observed !== 1'b0)
      $fatal(1, "handles to different interface instances compared equal");

    observed = 1'bx;
    observed = (right_vif != left_vif);
    if (observed !== 1'b1)
      $fatal(1, "handles to different interface instances did not differ");

    left_vif = second;

    observed = 1'bx;
    observed = (left_vif == right_vif);
    if (observed !== 1'b1)
      $fatal(1, "rebound handle did not match the second handle");

    observed = 1'bx;
    observed = (left_vif == second);
    if (observed !== 1'b1)
      $fatal(1, "rebound handle did not equal its concrete instance");

    observed = 1'bx;
    observed = (second == left_vif);
    if (observed !== 1'b1)
      $fatal(1, "concrete instance did not equal the rebound handle");

    observed = 1'bx;
    observed = (left_vif != first);
    if (observed !== 1'b1)
      $fatal(1, "rebound handle did not differ from its old instance");

    observed = 1'bx;
    observed = (first != left_vif);
    if (observed !== 1'b1)
      $fatal(1, "old instance did not differ from the rebound handle");

    left_vif = first;
    right_vif = second;
    select_second = 1'b0;

    observed = 1'bx;
    observed = ((select_second ? right_vif : left_vif) == first);
    if (observed !== 1'b1)
      $fatal(1, "first conditional branch did not equal concrete instance");

    observed = 1'bx;
    observed = (first == (select_second ? right_vif : left_vif));
    if (observed !== 1'b1)
      $fatal(1, "concrete instance did not equal first conditional branch");

    observed = 1'bx;
    observed = ((select_second ? right_vif : left_vif) != second);
    if (observed !== 1'b1)
      $fatal(1, "first conditional branch did not differ from other instance");

    observed = 1'bx;
    observed = (second != (select_second ? right_vif : left_vif));
    if (observed !== 1'b1)
      $fatal(1, "other instance did not differ from first conditional branch");

    select_second = 1'b1;

    observed = 1'bx;
    observed = ((select_second ? right_vif : left_vif) == second);
    if (observed !== 1'b1)
      $fatal(1, "second conditional branch did not equal concrete instance");

    observed = 1'bx;
    observed = (second == (select_second ? right_vif : left_vif));
    if (observed !== 1'b1)
      $fatal(1, "concrete instance did not equal second conditional branch");

    observed = 1'bx;
    observed = ((select_second ? right_vif : left_vif) != first);
    if (observed !== 1'b1)
      $fatal(1, "second conditional branch did not differ from other instance");

    observed = 1'bx;
    observed = (first != (select_second ? right_vif : left_vif));
    if (observed !== 1'b1)
      $fatal(1, "other instance did not differ from second conditional branch");

    same_spelling_vif = sv_vif_same_spelling_if;

    observed = 1'bx;
    observed = (same_spelling_vif == sv_vif_same_spelling_if);
    if (observed !== 1'b1)
      $fatal(1, "same-spelling instance failed right-operand binding");

    observed = 1'bx;
    observed = (sv_vif_same_spelling_if == same_spelling_vif);
    if (observed !== 1'b1)
      $fatal(1, "same-spelling instance failed left-operand binding");

    $display("PASSED");
  end
endmodule
