// IEEE 1800-2017 18.4, 18.5.8.1; IEEE 1800-2023 18.4, 18.5.7.1.
typedef struct {
  rand logic signed [63:0] descending[4:2];
  rand logic signed [63:0] negative[-2:0];
} member_arrays_t;

class bounds_sign_identity;
  rand member_arrays_t primary;
  rand member_arrays_t backup;

  constraint member_values {
    foreach (primary.descending[i]) primary.descending[i] == -64'sd100 - i;
    foreach (primary.negative[i]) primary.negative[i] == 64'sd200 + i;
    foreach (backup.descending[i]) backup.descending[i] == 64'sd300 + i;
    foreach (backup.negative[i]) backup.negative[i] == -64'sd400 - i;
  }
endclass

module bounds_sign_identity_test;
  initial begin
    static bounds_sign_identity item = new;
    if (!item.randomize()) $fatal(1, "member-array randomize failed");
    foreach (item.primary.descending[i])
      if (item.primary.descending[i] !== (-64'sd100 - i))
        $fatal(1, "primary descending[%0d] lost signed 64-bit identity", i);
    foreach (item.primary.negative[i])
      if (item.primary.negative[i] !== (64'sd200 + i))
        $fatal(1, "primary negative[%0d] lost declared index", i);
    foreach (item.backup.descending[i])
      if (item.backup.descending[i] !== (64'sd300 + i)
          || item.backup.descending[i] === item.primary.descending[i])
        $fatal(1, "backup descending[%0d] aliases primary", i);
    foreach (item.backup.negative[i])
      if (item.backup.negative[i] !== (-64'sd400 - i)
          || item.backup.negative[i] === item.primary.negative[i])
        $fatal(1, "backup negative[%0d] aliases primary", i);
    $display("PASS bounds-sign-identity");
  end
endmodule
