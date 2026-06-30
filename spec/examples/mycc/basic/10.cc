void test_bitwise() {
  int a = 0b1010, b = 0b1100;

  printf("and: %d\n", a & b);
  printf("or: %d\n", a | b);
  printf("xor: %d\n", a ^ b);
  printf("not: %d\n", ~a);
  printf("shl: %d\n", a << 2);
  printf("shr: %d\n", a >> 1);
}

int main() {
  test_bitwise();
  return 0;
}
