static const char LUT[6] = {'.', '-', '+', '*', 'X', 'M'};

void test_lut(void) {
  printf("LUT[0] = %c\n", LUT[0]);
  printf("LUT[5] = %c\n", LUT[5]);
}

int main() {
  test_lut();
  return 0;
}
