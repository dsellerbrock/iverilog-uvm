module issue3683;
  logic [3:0] a [-2:1];
  logic [3:0] b [1:-2];
  int i;
  logic [11:0] packed_value;
  initial begin
    a = '{1,2,3,4};
    packed_value = {>>{a with [-2 +: 3]}};
    if (packed_value !== 12'h123) $fatal(1, "source");
    {>>{a with [-2 +: 3]}} = 12'h567;
    if (a[-2] !== 5 || a[-1] !== 6 || a[0] !== 7 || a[1] !== 4)
      $fatal(1, "constant ascending");
    a = '{1,2,3,4};
    i = -2;
    {>>{a with [i +: 3]}} = 12'h567;
    if (a[-2] !== 5 || a[-1] !== 6 || a[0] !== 7 || a[1] !== 4)
      $fatal(1, "variable ascending");
    {>>{a with [-1]}} = 4'ha;
    if (a[-1] !== 10) $fatal(1, "single index");
    {>>{a with [-2:0]}} = 12'habc;
    if (a[-2] !== 10 || a[-1] !== 11 || a[0] !== 12 || a[1] !== 4)
      $fatal(1, "explicit range");
    b = '{1,2,3,4};
    i = 0;
    {>>{b with [i -: 3]}} = 12'h567;
    if (b[1] !== 1 || b[0] !== 5 || b[-1] !== 6 || b[-2] !== 7)
      $fatal(1, "descending");
    $display("PASS");
  end
endmodule
