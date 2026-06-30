int global_var = 42;

void test_globals() {
  printf("global: %d\n", global_var);
  global_var = 100;
  printf("global modified: %d\n", global_var);
}

int main() {
  test_globals();

  return 0;
}
