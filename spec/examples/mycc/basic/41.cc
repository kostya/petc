int main() {
  int x[] = {1, 2, 3, 4, 5};
  printf("%d\n", (&x[4]) - (x + 1));

  int *p = &x[4];
  unsigned long long len = p - x;
  printf("%d\n", len);

  return 0;
}
