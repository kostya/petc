union Mixed {
  char c;
  int i;
  long long l;
  double d;
};

struct Data {
  int tag;
  union Mixed value;
};

void test_mixed() {
  struct Data d;

  d.value.i = 0x12345678;
  printf("as int: %x\n", d.value.i);
  printf("as char: %x\n", d.value.c);

  d.value.d = 3.14159;
  printf("as double: %f\n", d.value.d);
}

int main() {
  test_mixed();
  return 0;
}
