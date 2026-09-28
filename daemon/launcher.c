/* vigild — named launcher so macOS lists the background item as "vigild"
   (attributed to Vigil) instead of an anonymous /usr/bin/python3. */
#include <unistd.h>
int main(void) {
    char *argv[] = {"/usr/bin/python3", "/usr/local/libexec/vigil/vigild.py", 0};
    execv(argv[0], argv);
    return 127;
}
