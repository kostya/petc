void test_logic() {
  int a = 1, b = 0;

  printf("and: %d\n", a && b);
  printf("or: %d\n", a || b);
  printf("not: %d\n", !a);
  printf("not not: %d\n", !!a);
  printf("complex: %d\n", (a && !b) || (!a && b));
}

int main() {
  test_logic();
  return 0;
}
