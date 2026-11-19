module issue3753;
  reg signed [3:0] data;
  reg signed [2:0] distance;
  wire signed [3:0] vl = data << distance, val = data <<< distance;
  wire signed [3:0] vr = data >> distance, var_ = data >>> distance;
  wire signed [3:0] fl = data << 1, fal = data <<< 1;
  wire signed [3:0] fr = data >> 1, far = data >>> 1;
  wire signed [3:0] zl = data << 0, zal = data <<< 0;
  wire signed [3:0] zr = data >> 0, zar = data >>> 0;
  wire signed [3:0] ol = data << 4, oal = data <<< 4;
  wire signed [3:0] or_ = data >> 4, oar = data >>> 4;
  wire signed [3:0] wide = data >>> 65'h1_0000_0000_0000_0000;
  wire signed [3:0] rx = data << 3'b0x1, rz = data >>> 3'b0z1;
  wire signed [3:0] folded = 4'sb000z >>> 1;

  wire [3:0] udata = data;
  wire [3:0] ul = udata << 1, ur = udata >>> distance;
  // The unsigned OR operand makes the shift's left operand effectively unsigned.
  wire [3:0] mixed = (data >>> distance) | 4'd0;

  wire [3:0] concat_ref = {data[2:0], 1'b0};
  reg observe = 0;
  integer left_events = 0, fixed_right_events = 0, variable_events = 0;
  always @(fl) if (observe) begin
    left_events = left_events + 1;
    if ((^data !== 1'bx) && fl !== concat_ref)
      $fatal(1, "Fixed left event preceded concat reference");
  end
  always @(far) if (observe) fixed_right_events = fixed_right_events + 1;
  always @(var_) if (observe) variable_events = variable_events + 1;

  task check_x_data;
    begin
      if ({vl, val, vr, var_} !== 16'hxxxx)
        $fatal(1, "Variable signed shifts of %b gave %b %b %b %b", data, vl, val, vr, var_);
      if ({fl, fal, fr, far} !== 16'hxxxx)
        $fatal(1, "Fixed signed shifts of %b gave %b %b %b %b", data, fl, fal, fr, far);
      if ({zl, zal, zr, zar} !== 16'hxxxx)
        $fatal(1, "Zero shifts of %b gave %b %b %b %b", data, zl, zal, zr, zar);
      if ({ol, oal, or_, oar, wide} !== 20'hxxxxx)
        $fatal(1, "Overshifts of %b gave %b %b %b %b %b", data, ol, oal, or_, oar, wide);
    end
  endtask

  initial begin
    if ({vl, val, vr, var_} !== 16'hxxxx)
      $fatal(1, "Variable signed shifts did not start at X");
    data = 4'b000x;
    distance = 1;
    #1;
    check_x_data;
    if ({ul, ur, mixed} !== 12'b00x0_0000_0000)
      $fatal(1, "Unsigned shifts of %b gave %b %b %b", udata, ul, ur, mixed);
    if (folded !== 4'bxxxx)
      $fatal(1, "Folded signed shift gave %b", folded);

    data = 4'bz001;
    #1;
    check_x_data;
    if ({ul, ur, mixed} !== 12'b0010_0z00_0x00)
      $fatal(1, "Unsigned shifts of %b gave %b %b %b", udata, ul, ur, mixed);

    observe = 1;
    data = 4'b1001;
    if (var_ !== 4'b1100)
      $fatal(1, "Variable signed shift recovery was not immediate");
    #1;
    if ({vl, val, vr, var_} !== 16'h224c || {fl, fal, fr, far} !== 16'h224c)
      $fatal(1, "Known shifts gave %h and %h", {vl, val, vr, var_}, {fl, fal, fr, far});
    if ({zl, zal, zr, zar} !== 16'h9999 || {ol, oal, or_, oar, wide} !== 20'h000ff)
      $fatal(1, "Known zero shifts or overshifts are incorrect");
    if ({ul, ur, mixed} !== 12'h244 || {rx, rz} !== 8'hxx)
      $fatal(1, "Known unsigned data or fixed unknown distance is incorrect");

    // A fixed concat-style shift must coalesce these two writes.
    data = 4'b1011;
    if (fl !== 4'b0010)
      $fatal(1, "Fixed left shift bypassed coalescing");
    data = 4'b1001;
    #1;
    if (left_events != 1)
      $fatal(1, "Fixed left shift produced %0d events before coalescing check", left_events);
    observe = 0;

    distance = -1;
    #1;
    if ({vl, val, vr, var_} !== 16'h000f)
      $fatal(1, "Shift distance was treated as signed");
    distance = 0;
    #1;
    if ({vl, val, vr, var_} !== 16'h9999)
      $fatal(1, "Variable shift by zero changed known data");
    distance = 3'b0x1;
    #1;
    if ({vl, val, vr, var_} !== 16'hxxxx)
      $fatal(1, "Variable X distance did not produce X");
    distance = 3'b0z1;
    #1;
    if ({vl, val, vr, var_} !== 16'hxxxx)
      $fatal(1, "Variable Z distance did not produce X");
    distance = 1;
    #1;

    left_events = 0;
    fixed_right_events = 0;
    variable_events = 0;
    observe = 1;
    data = 4'b100x;
    #1;
    check_x_data;
    data = 4'b100z;
    #1;
    check_x_data;
    data = 4'b1001;
    #1;
    if (left_events != 2 || fixed_right_events != 2 || variable_events != 2)
      $fatal(1, "Wrong event counts for X/Z and recovery: %0d %0d %0d",
             left_events, fixed_right_events, variable_events);
    $display("PASSED");
  end
endmodule
