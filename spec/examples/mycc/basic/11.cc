int add(int a, int b) { return a + b; }
int sub(int a, int b) { return a - b; }
int mul(int a, int b) { return a * b; }

int calc(int a, int b, int op) {
  if (op == 0)
    return add(a, b);
  if (op == 1)
    return sub(a, b);
  return mul(a, b);
}

int main() {
  printf("calc(10,5,0): %d\n", calc(10, 5, 0));
  printf("calc(10,5,1): %d\n", calc(10, 5, 1));
  printf("calc(10,5,2): %d\n", calc(10, 5, 2));

  return 0;
}
