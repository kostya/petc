void test_strings() {
  char *s = "Hello";
  char *t = "World";

  printf("strings: %s %s\n", s, t);
  printf("char: %c\n", s[0]);
}

int main() {
  test_strings();

  return 0;
}
