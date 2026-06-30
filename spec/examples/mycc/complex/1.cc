int main() {
  int x;

  x = 1;
  for (x = 10; x; x = x - 1)
    printf("x = %d\n", x);

  if (x)
    return 1;

  x = 10;
  for (; x;) {
    x = x - 1;
    printf("x = %d\n", x);
  }
  return x;
}
