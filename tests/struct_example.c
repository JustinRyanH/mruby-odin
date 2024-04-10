struct test_example {};

typedef struct test_struct {
  int field_a;
  _Bool field_b;
  float *field_c;
  void *field_d;
  float *const field_e;
  struct test_example field_f;
} test_struct;

typedef struct string_struct {
  char *cstring; // Char is CString
} string_struct;

typedef struct byte_struct {
  char *byte; // This is a pointer to a single byte
} byte_struct;

typedef struct bytes_struct {
  char *bytes; // This is an array of bytes
} bytes_struct;
