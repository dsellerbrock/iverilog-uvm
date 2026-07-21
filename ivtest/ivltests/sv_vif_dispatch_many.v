// Dynamic virtual-interface method dispatch across MORE than 64 interface
// instances. The dispatch-table builder used a fixed VIF_DISPATCH_MAX=64
// cap and SILENTLY dropped instances beyond it, so calls through handles
// bound to instances 65+ quietly did nothing. The collection is now
// dynamically sized; every instance must dispatch.

interface tick_if;
  int hits = 0;
  task bump(); hits++; endtask
endinterface

module sv_vif_dispatch_many;

  localparam int N = 72;

  tick_if t0();
  tick_if t1();
  tick_if t2();
  tick_if t3();
  tick_if t4();
  tick_if t5();
  tick_if t6();
  tick_if t7();
  tick_if t8();
  tick_if t9();
  tick_if t10();
  tick_if t11();
  tick_if t12();
  tick_if t13();
  tick_if t14();
  tick_if t15();
  tick_if t16();
  tick_if t17();
  tick_if t18();
  tick_if t19();
  tick_if t20();
  tick_if t21();
  tick_if t22();
  tick_if t23();
  tick_if t24();
  tick_if t25();
  tick_if t26();
  tick_if t27();
  tick_if t28();
  tick_if t29();
  tick_if t30();
  tick_if t31();
  tick_if t32();
  tick_if t33();
  tick_if t34();
  tick_if t35();
  tick_if t36();
  tick_if t37();
  tick_if t38();
  tick_if t39();
  tick_if t40();
  tick_if t41();
  tick_if t42();
  tick_if t43();
  tick_if t44();
  tick_if t45();
  tick_if t46();
  tick_if t47();
  tick_if t48();
  tick_if t49();
  tick_if t50();
  tick_if t51();
  tick_if t52();
  tick_if t53();
  tick_if t54();
  tick_if t55();
  tick_if t56();
  tick_if t57();
  tick_if t58();
  tick_if t59();
  tick_if t60();
  tick_if t61();
  tick_if t62();
  tick_if t63();
  tick_if t64();
  tick_if t65();
  tick_if t66();
  tick_if t67();
  tick_if t68();
  tick_if t69();
  tick_if t70();
  tick_if t71();

  virtual tick_if vifs[72];
  int errors = 0;

  initial begin
    vifs[0] = t0;
    vifs[1] = t1;
    vifs[2] = t2;
    vifs[3] = t3;
    vifs[4] = t4;
    vifs[5] = t5;
    vifs[6] = t6;
    vifs[7] = t7;
    vifs[8] = t8;
    vifs[9] = t9;
    vifs[10] = t10;
    vifs[11] = t11;
    vifs[12] = t12;
    vifs[13] = t13;
    vifs[14] = t14;
    vifs[15] = t15;
    vifs[16] = t16;
    vifs[17] = t17;
    vifs[18] = t18;
    vifs[19] = t19;
    vifs[20] = t20;
    vifs[21] = t21;
    vifs[22] = t22;
    vifs[23] = t23;
    vifs[24] = t24;
    vifs[25] = t25;
    vifs[26] = t26;
    vifs[27] = t27;
    vifs[28] = t28;
    vifs[29] = t29;
    vifs[30] = t30;
    vifs[31] = t31;
    vifs[32] = t32;
    vifs[33] = t33;
    vifs[34] = t34;
    vifs[35] = t35;
    vifs[36] = t36;
    vifs[37] = t37;
    vifs[38] = t38;
    vifs[39] = t39;
    vifs[40] = t40;
    vifs[41] = t41;
    vifs[42] = t42;
    vifs[43] = t43;
    vifs[44] = t44;
    vifs[45] = t45;
    vifs[46] = t46;
    vifs[47] = t47;
    vifs[48] = t48;
    vifs[49] = t49;
    vifs[50] = t50;
    vifs[51] = t51;
    vifs[52] = t52;
    vifs[53] = t53;
    vifs[54] = t54;
    vifs[55] = t55;
    vifs[56] = t56;
    vifs[57] = t57;
    vifs[58] = t58;
    vifs[59] = t59;
    vifs[60] = t60;
    vifs[61] = t61;
    vifs[62] = t62;
    vifs[63] = t63;
    vifs[64] = t64;
    vifs[65] = t65;
    vifs[66] = t66;
    vifs[67] = t67;
    vifs[68] = t68;
    vifs[69] = t69;
    vifs[70] = t70;
    vifs[71] = t71;

    // Call through every handle; each must reach ITS OWN instance.
    foreach (vifs[i]) vifs[i].bump();

    // The last instances (beyond the old 64 cap) are the regression core.
    if (t70.hits !== 1) begin $display("FAIL t70 hits=%0d", t70.hits); errors++; end
    if (t71.hits !== 1) begin $display("FAIL t71 hits=%0d", t71.hits); errors++; end
    if (t0.hits  !== 1) begin $display("FAIL t0 hits=%0d",  t0.hits);  errors++; end
    if (t63.hits !== 1) begin $display("FAIL t63 hits=%0d", t63.hits); errors++; end
    if (t64.hits !== 1) begin $display("FAIL t64 hits=%0d", t64.hits); errors++; end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish(0);
  end

endmodule
