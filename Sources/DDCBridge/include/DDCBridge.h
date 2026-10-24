#include <stdint.h>
#include <stdbool.h>
void *monitor_ddc_open(uint64_t registry_id);
void monitor_ddc_close(void *service);
bool monitor_ddc_send(void *service, const uint8_t *bytes, uint32_t length);
bool monitor_ddc_receive(void *service, uint8_t *bytes, uint32_t length);
