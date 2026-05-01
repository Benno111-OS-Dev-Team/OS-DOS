#include "boot.h"

typedef struct OsDosVersion {
    unsigned major;
    unsigned minor;
} OsDosVersion;

static const OsDosVersion kVersion = {2u, 11u};

unsigned osdos_major_version(void) {
    return kVersion.major;
}

unsigned osdos_minor_version(void) {
    return kVersion.minor;
}

int osdos_boot(BootLogFn log_fn, void *user_data) {
    BootState state;

    skelio_bootstrap(&state);
    return sysinit_run(&state, log_fn, user_data);
}
