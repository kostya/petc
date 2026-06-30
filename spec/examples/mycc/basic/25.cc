int add(int a, int b) { return a + b; }

int apply(int (*fp)(int, int), int x, int y) { return fp(x, y); }

int main() {
  int (*my_add)(int, int) = &add;
  printf("%d\n", my_add(10, 20));
  printf("%d\n", apply(add, 5, 7));
  return 0;
}
