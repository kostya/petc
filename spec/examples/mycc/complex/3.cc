void bla(unsigned int x) { printf("bla = %d\n", x); }

void blaf(float x) { printf("blaf = %d\n", (int)x); }

void blai(int x) { printf("blai = %d\n", x); }

unsigned int bla2() { return 42; }

unsigned int bla3() {
  int x = 43;
  return x;
}

int bla4() { return 3.14f; }

float bla5() { return 7; }

struct Data {
  unsigned int x;
  float y;
};

int main() {
  bla(43);
  bla('A');
  blaf(42);
  blaf(3.14f);
  blai(5.99f);
  blai(-10);

  printf("bla2 = %d\n", bla2());
  printf("bla3 = %d\n", bla3());
  printf("bla4 = %d\n", bla4());
  printf("bla5 = %d\n", (int)bla5());

  unsigned int y = 44;
  printf("y = %d\n", y);

  float f = 5;
  printf("f = %d\n", (int)f);

  int i = 6.5f;
  printf("i = %d\n", i);

  struct Data data;
  data.x = 45;
  data.y = 46;
  printf("data.x = %d\n", data.x);
  printf("data.y = %d\n", (int)data.y);

  unsigned int z = y + 1;
  printf("z = %d\n", z);

  if (y == 44) {
    printf("y == 44\n");
  }

  unsigned int result = 0;
  return result;
}
