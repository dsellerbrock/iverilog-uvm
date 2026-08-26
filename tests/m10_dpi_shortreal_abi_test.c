float c_shortreal_all(float value, float *out_value, float *inout_value)
{
      if (value != 1.25f || out_value == 0 || inout_value == 0)
            return 0.0f;
      *out_value = -2.5f;
      *inout_value += 0.5f;
      return value + 4.0f;
}
