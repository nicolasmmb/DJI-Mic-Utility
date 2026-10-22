#ifndef DJI_MIC_USB_H
#define DJI_MIC_USB_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct dji_usb_device dji_usb_device;

enum {
    DJI_USB_OK = 0,
    DJI_USB_NOT_FOUND = -1,
    DJI_USB_ACCESS = -2,
    DJI_USB_IO = -3,
    DJI_USB_TIMEOUT = -4,
    DJI_USB_INVALID = -5,
};

dji_usb_device *dji_usb_open(uint16_t vendor_id, uint16_t product_id, uint8_t interface_number);
void dji_usb_close(dji_usb_device *device);

int dji_usb_write(dji_usb_device *device, const uint8_t *data, uint32_t length, uint32_t timeout_ms);
int dji_usb_read(dji_usb_device *device, uint8_t *data, uint32_t *length, uint32_t timeout_ms);

const char *dji_usb_last_error(void);
int dji_usb_last_error_code(void);

#ifdef __cplusplus
}
#endif

#endif
