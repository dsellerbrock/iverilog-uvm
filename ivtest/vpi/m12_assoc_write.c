/* M12-4: write associative-array elements through VPI (positional
 * handles in key order, mirroring the read path). */
# include  <vpi_user.h>
# include  <string.h>

static PLI_INT32 probe_calltf(PLI_BYTE8*ud)
{
      s_vpi_value val;
      vpiHandle h, el;
      (void)ud;

      /* int-valued, string keys: "a" is position 0, "b" position 1.
       * Read both, then overwrite both. */
      h = vpi_handle_by_name((char*)"top.aa_i", 0);
      el = vpi_handle_by_index(h, 0);
      val.format = vpiIntVal;
      vpi_get_value(el, &val);
      vpi_printf("aa_i[0](a)=%d\n", (int)val.value.integer);
      val.format = vpiIntVal;
      val.value.integer = 40;
      vpi_put_value(el, &val, 0, vpiNoDelay);
      el = vpi_handle_by_index(h, 1);
      val.format = vpiIntVal;
      val.value.integer = 50;
      vpi_put_value(el, &val, 0, vpiNoDelay);

      /* real-valued */
      h = vpi_handle_by_name((char*)"top.aa_r", 0);
      el = vpi_handle_by_index(h, 0);
      val.format = vpiRealVal;
      val.value.real = 6.25;
      vpi_put_value(el, &val, 0, vpiNoDelay);

      /* string-valued */
      h = vpi_handle_by_name((char*)"top.aa_s", 0);
      el = vpi_handle_by_index(h, 0);
      val.format = vpiStringVal;
      val.value.str = (char*)"after";
      vpi_put_value(el, &val, 0, vpiNoDelay);

      /* byte-valued with int keys: key order is 1 then 3. A 32-bit
       * vpiIntVal put must land resized to the 8-bit element. */
      h = vpi_handle_by_name((char*)"top.aa_b", 0);
      el = vpi_handle_by_index(h, 0);
      val.format = vpiIntVal;
      val.value.integer = 0x1AB;   /* truncates to 8'hAB */
      vpi_put_value(el, &val, 0, vpiNoDelay);

      /* loud rejections: wrong format for the value kind, and an
       * object-valued element. Neither may crash or store. */
      h = vpi_handle_by_name((char*)"top.aa_r", 0);
      el = vpi_handle_by_index(h, 0);
      val.format = vpiStringVal;
      val.value.str = (char*)"nope";
      vpi_put_value(el, &val, 0, vpiNoDelay);
      h = vpi_handle_by_name((char*)"top.aa_o", 0);
      el = vpi_handle_by_index(h, 0);
      val.format = vpiIntVal;
      val.value.integer = 9;
      vpi_put_value(el, &val, 0, vpiNoDelay);

      /* out-of-range position */
      h = vpi_handle_by_name((char*)"top.aa_i", 0);
      el = vpi_handle_by_index(h, 7);
      if (el) {
	    val.format = vpiIntVal;
	    val.value.integer = 1;
	    vpi_put_value(el, &val, 0, vpiNoDelay);
      } else {
	    vpi_printf("aa_i[7]: no handle\n");
      }

      return 0;
}

static void register_probe(void)
{
      s_vpi_systf_data tf;
      memset(&tf, 0, sizeof tf);
      tf.type = vpiSysTask;
      tf.tfname = "$m12aw_probe";
      tf.calltf = probe_calltf;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
