double sqrt(double);

int sieve_count(int limit) {
  if (limit < 2) {
    return 0;
  }

  char *primes = (char*)malloc((limit + 1) * sizeof(char));
  if (!primes)
    return 0;

  memset(primes, 1, (limit + 1) * sizeof(char));
  primes[0] = 0;
  primes[1] = 0;

  int sqrt_limit = (int)sqrt((double)limit);

  for (int p = 2; p <= sqrt_limit; p++) {
    if (primes[p] == 1) {

      for (int multiple = p * p; multiple <= limit; multiple += p) {
        primes[multiple] = 0;
      }
    }
  }

  int last_prime = 2;
  int count_primes = 1;

  for (int n = 3; n <= limit; n += 2) {
    if (primes[n] == 1) {
      last_prime = n;
      count_primes++;
    }
  }

  free(primes);
  return count_primes;
}

int main() {
  int res = sieve_count(50000000);
  printf("sieve = %d\n", res);
  return 0;
}
