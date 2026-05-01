#include "boot.h"

static const char *const kMessages[] = {
    "SYSINIT: entered",
    "SYSINIT: relocating DOS",
    "BOOT COMPLETE",
    "SYSINIT: memory scan/setup",
    "SYSINIT: self-relocation copy",
    "SYSINIT: entering SYSIN",
    "SYSINIT: stack switched",
    "SYSINIT: calling MSDOS",
    "SYSINIT: returned from MSDOS",
    "SYSINIT: running RE_INIT",
    "SYSINIT: setting INT 24",
    "SYSINIT: running DOCONF",
    "SYSINIT: opening console devices",
    "SYSINIT: preparing COMMAND"
};

static const char *const kErrors[] = {
    "SYSINIT FATAL: invalid DOS handoff segment",
    "SYSINIT FATAL: DOS returned bad info pointer"
};

const char *const *sysinit_messages(size_t *count) {
    if (count) {
        *count = sizeof(kMessages) / sizeof(kMessages[0]);
    }

    return kMessages;
}

const char *const *sysinit_errors(size_t *count) {
    if (count) {
        *count = sizeof(kErrors) / sizeof(kErrors[0]);
    }

    return kErrors;
}
