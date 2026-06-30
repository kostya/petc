int add(int x, int y) { return x + y; }
int sub(int x, int y) { return x - y; }

struct Call {
  int (*method1)(int, int);
  int (*method2)(int, int);
};

void test_call(struct Call *call) {
  printf("method1 %d\n", call->method1(1, 2));
  printf("method2 %d\n", call->method2(1, 2));
}

int main() {
  struct Call call;
  call.method1 = &sub;
  call.method2 = &add;

  test_call(&call);

  return 0;
}
