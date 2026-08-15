// IEEE 1800-2017 40.3.2 fixes the arity and argument categories of each
// coverage access function and database task.
module test;
  int value;
  initial begin
    value = $coverage_control(`SV_COV_CHECK, `SV_COV_TOGGLE,
                              `SV_COV_HIER);
    value = $coverage_get(`SV_COV_TOGGLE, `SV_COV_HIER, 1);
    value = $coverage_save(`SV_COV_TOGGLE, 1);
    value = $coverage_get_max(`SV_COV_TOGGLE, `SV_COV_HIER,
                              "test", 1);
    $set_coverage_db_name(1);
    $load_coverage_db();
    $load_coverage_db("first", "second");
  end
endmodule
