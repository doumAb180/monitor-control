#include "DDCBridge.h"
#include <IOKit/IOKitLib.h>
#include <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>
#include <pthread.h>

// IOAVService is a private Apple Silicon API. Resolve it at runtime so an
// unavailable symbol produces an unsupported device, not a launch failure.
typedef CFTypeRef (*CreateService)(CFAllocatorRef, io_service_t);
typedef IOReturn (*Transfer)(CFTypeRef, uint32_t, uint32_t, void *, uint32_t);
static CreateService createService;
static Transfer sendBytes, receiveBytes;
static pthread_once_t once = PTHREAD_ONCE_INIT;
static void resolve(void) {
    void *library = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY);
    if (!library) return;
    createService = (CreateService)dlsym(library, "IOAVServiceCreateWithService");
    sendBytes = (Transfer)dlsym(library, "IOAVServiceWriteI2C");
    receiveBytes = (Transfer)dlsym(library, "IOAVServiceReadI2C");
}
void *monitor_ddc_open(uint64_t registry_id) {
    pthread_once(&once, resolve);
    if (!createService || !sendBytes || !receiveBytes) return NULL;
    io_service_t entry = IOServiceGetMatchingService(kIOMainPortDefault, IORegistryEntryIDMatching(registry_id));
    if (!entry) return NULL;
    CFTypeRef service = createService(kCFAllocatorDefault, entry);
    IOObjectRelease(entry);
    return (void *)service;
}
void monitor_ddc_close(void *service) { if (service) CFRelease(service); }
bool monitor_ddc_send(void *service, const uint8_t *bytes, uint32_t length) {
    return service && sendBytes && sendBytes(service, 0x37, 0x51, (void *)bytes, length) == kIOReturnSuccess;
}
bool monitor_ddc_receive(void *service, uint8_t *bytes, uint32_t length) {
    return service && receiveBytes && receiveBytes(service, 0x37, 0, bytes, length) == kIOReturnSuccess;
}
