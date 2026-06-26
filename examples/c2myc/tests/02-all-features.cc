int add(int a, int b) {
  return a + b;
}

int main() {
  int x = 10;
  int y = 20;
  int z;

  z = x + y;
  printf("add: %d\n", z);

  int s = add(x, y);
  printf("call: %d\n", s);

  printf("mul: %d\n", x * y);
  printf("div: %d\n", y / x);
  printf("sub: %d\n", y - x);
  printf("rem: %d\n", 25 % 4);

  if (x < y) {
    printf("lt\n");
  }
  if (x == 10) {
    printf("eq\n");
  }
  if (x != y) {
    printf("neq\n");
  }

  int i = 0;
  while (i < 3) {
    printf("loop: %d\n", i);
    i = i + 1;
  }

  if (x > y) printf("no\n");
  else {
    printf("yes\n");
  }

  return 0;
}