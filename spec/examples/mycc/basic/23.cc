void test_pointers() {
  int arr[5] = {10, 20, 30, 40, 50};
  int *q = arr;
  printf("arr[2]: %d\n", *(q + 2));
}

int main() {
  test_pointers();
  return 0;
}
