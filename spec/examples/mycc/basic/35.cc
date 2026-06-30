typedef signed long long int64_t;

void test() {
  double *u = malloc(10 * sizeof(double));

  for (int64_t i = 0; i < 10; i++) {
    u[i] = 1.0;
  }

  printf("ok\n");
}

int main() {
  test();
  return 0;
}
