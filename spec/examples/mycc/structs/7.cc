typedef struct Bla Bla;

struct Bla {
  Bla *(*create)(void);
};

Bla *crea(void) {
  printf("create \n");
  return (Bla *)malloc(sizeof(Bla));
};

int main() {
  Bla bla;
  bla.create = crea;

  Bla *bla2 = bla.create();
  free(bla2);
  return 0;
}
