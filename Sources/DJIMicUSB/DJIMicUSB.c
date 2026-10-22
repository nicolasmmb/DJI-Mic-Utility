#include "DJIMicUSB.h"

#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/usb/IOUSBLib.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

struct dji_usb_device {
    io_service_t service;
    IOUSBInterfaceInterface **interface;
    UInt8 pipe_in;
    UInt8 pipe_out;
};

static char g_error[256];
static int g_error_code;

static void set_error(const char *message, IOReturn result)
{
    snprintf(g_error, sizeof(g_error), "%s (0x%08x)", message, (unsigned)result);
}

static int read_number(io_service_t service, CFStringRef key, int *value)
{
    CFTypeRef property = IORegistryEntryCreateCFProperty(service, key, kCFAllocatorDefault, 0);
    if (property == NULL) {
        return 0;
    }

    int result = 0;
    if (CFGetTypeID(property) == CFNumberGetTypeID()) {
        int number = 0;
        if (CFNumberGetValue((CFNumberRef)property, kCFNumberIntType, &number)) {
            *value = number;
            result = 1;
        }
    }

    CFRelease(property);
    return result;
}

static io_service_t find_interface(uint16_t vendor_id, uint16_t product_id, uint8_t interface_number)
{
    CFMutableDictionaryRef matching = IOServiceMatching("IOUSBHostInterface");
    if (matching == NULL) {
        return 0;
    }

    io_iterator_t iterator = 0;
    if (IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) != kIOReturnSuccess) {
        return 0;
    }

    io_service_t service = 0;
    while ((service = IOIteratorNext(iterator)) != 0) {
        int vendor = -1;
        int product = -1;
        int number = -1;

        if (read_number(service, CFSTR("idVendor"), &vendor) &&
            read_number(service, CFSTR("idProduct"), &product) &&
            read_number(service, CFSTR("bInterfaceNumber"), &number) &&
            vendor == vendor_id && product == product_id && number == interface_number) {
            break;
        }

        IOObjectRelease(service);
        service = 0;
    }

    IOObjectRelease(iterator);
    return service;
}

static IOUSBInterfaceInterface **create_interface(io_service_t service, IOCFPlugInInterface ***plugin_out)
{
    IOCFPlugInInterface **plugin = NULL;
    IOUSBInterfaceInterface **interface = NULL;
    SInt32 score = 0;
    IOReturn result = kIOReturnError;

    /* IOCreatePlugInInterfaceForService can return "out of resources" on the
     * first attempt while the interface is still starting. libusb retries the
     * same call for the same reason. */
    for (int attempt = 0; attempt < 8; attempt++) {
        result = IOCreatePlugInInterfaceForService(
            service,
            kIOUSBInterfaceUserClientTypeID,
            kIOCFPlugInInterfaceID,
            &plugin,
            &score
        );

        if (result == kIOReturnSuccess && plugin != NULL) {
            break;
        }

        plugin = NULL;
        usleep(1000);
    }

    if (result != kIOReturnSuccess || plugin == NULL) {
        set_error("IOCreatePlugInInterfaceForService", result);
        return NULL;
    }

    HRESULT hr = (*plugin)->QueryInterface(
        plugin,
        CFUUIDGetUUIDBytes(kIOUSBInterfaceInterfaceID),
        (LPVOID *)&interface
    );

    if (hr != S_OK || interface == NULL) {
        set_error("QueryInterface(IOUSBInterfaceInterface)", (IOReturn)hr);
        (*plugin)->Release(plugin);
        return NULL;
    }

    *plugin_out = plugin;
    return interface;
}

dji_usb_device *dji_usb_open(uint16_t vendor_id, uint16_t product_id, uint8_t interface_number)
{
    g_error[0] = '\0';
    g_error_code = DJI_USB_OK;

    io_service_t service = find_interface(vendor_id, product_id, interface_number);
    if (service == 0) {
        g_error_code = DJI_USB_NOT_FOUND;
        snprintf(g_error, sizeof(g_error), "interface %u not found for %04x:%04x", interface_number, vendor_id, product_id);
        return NULL;
    }

    IOCFPlugInInterface **plugin = NULL;
    IOUSBInterfaceInterface **interface = create_interface(service, &plugin);
    if (interface == NULL) {
        g_error_code = DJI_USB_IO;
        IOObjectRelease(service);
        return NULL;
    }

    IOReturn result = (*interface)->USBInterfaceOpenSeize(interface);
    if (result != kIOReturnSuccess) {
        g_error_code = (result == kIOReturnExclusiveAccess) ? DJI_USB_ACCESS : DJI_USB_IO;
        set_error("USBInterfaceOpenSeize", result);
        (*interface)->Release(interface);
        (*plugin)->Release(plugin);
        IOObjectRelease(service);
        return NULL;
    }

    UInt8 endpoint_count = 0;
    result = (*interface)->GetNumEndpoints(interface, &endpoint_count);
    if (result != kIOReturnSuccess) {
        set_error("GetNumEndpoints", result);
        (*interface)->USBInterfaceClose(interface);
        (*interface)->Release(interface);
        (*plugin)->Release(plugin);
        IOObjectRelease(service);
        return NULL;
    }

    UInt8 pipe_in = 0;
    UInt8 pipe_out = 0;
    for (UInt8 pipe = 1; pipe <= endpoint_count; pipe++) {
        UInt8 direction = 0;
        UInt8 number = 0;
        UInt8 transfer_type = 0;
        UInt8 interval = 0;
        UInt16 max_packet_size = 0;

        result = (*interface)->GetPipeProperties(
            interface, pipe, &direction, &number, &transfer_type, &max_packet_size, &interval
        );
        if (result != kIOReturnSuccess) {
            continue;
        }

        if (number == 6 && direction == kUSBIn) {
            pipe_in = pipe;
        } else if (number == 6 && direction == kUSBOut) {
            pipe_out = pipe;
        }
    }

    if (pipe_in == 0 || pipe_out == 0) {
        g_error_code = DJI_USB_NOT_FOUND;
        set_error("bulk endpoints 0x06/0x86 not found", kIOReturnNotFound);
        (*interface)->USBInterfaceClose(interface);
        (*interface)->Release(interface);
        (*plugin)->Release(plugin);
        IOObjectRelease(service);
        return NULL;
    }

    dji_usb_device *device = calloc(1, sizeof(*device));
    if (device == NULL) {
        (*interface)->USBInterfaceClose(interface);
        (*interface)->Release(interface);
        (*plugin)->Release(plugin);
        IOObjectRelease(service);
        return NULL;
    }

    device->service = service;
    device->interface = interface;
    device->pipe_in = pipe_in;
    device->pipe_out = pipe_out;

    /* The plugin interface is no longer needed after QueryInterface.
     * Keep it alive until now to match the documented ownership model. */
    (*plugin)->Release(plugin);
    return device;
}

void dji_usb_close(dji_usb_device *device)
{
    if (device == NULL) {
        return;
    }

    if (device->interface != NULL) {
        (*device->interface)->USBInterfaceClose(device->interface);
        (*device->interface)->Release(device->interface);
    }

    if (device->service != 0) {
        IOObjectRelease(device->service);
    }

    free(device);
}

int dji_usb_write(dji_usb_device *device, const uint8_t *data, uint32_t length, uint32_t timeout_ms)
{
    if (device == NULL || device->interface == NULL || data == NULL || length == 0) {
        return DJI_USB_INVALID;
    }

    IOReturn result = (*device->interface)->WritePipeTO(
        device->interface,
        device->pipe_out,
        (void *)data,
        length,
        0,
        timeout_ms
    );

    if (result == kIOReturnSuccess) {
        return (int)length;
    }

    if (result == kIOReturnTimeout || result == kIOUSBTransactionTimeout) {
        g_error_code = DJI_USB_TIMEOUT;
        return DJI_USB_TIMEOUT;
    }

    g_error_code = DJI_USB_IO;
    set_error("WritePipeTO", result);
    return DJI_USB_IO;
}

int dji_usb_read(dji_usb_device *device, uint8_t *data, uint32_t *length, uint32_t timeout_ms)
{
    if (device == NULL || device->interface == NULL || data == NULL || length == NULL || *length == 0) {
        return DJI_USB_INVALID;
    }

    UInt32 size = *length;
    IOReturn result = (*device->interface)->ReadPipeTO(
        device->interface,
        device->pipe_in,
        data,
        &size,
        0,
        timeout_ms
    );

    if (result == kIOReturnSuccess) {
        *length = size;
        return 0;
    }

    if (result == kIOReturnTimeout || result == kIOUSBTransactionTimeout) {
        g_error_code = DJI_USB_TIMEOUT;
        return DJI_USB_TIMEOUT;
    }

    g_error_code = DJI_USB_IO;
    set_error("ReadPipeTO", result);
    return DJI_USB_IO;
}

const char *dji_usb_last_error(void)
{
    return g_error;
}

int dji_usb_last_error_code(void)
{
    return g_error_code;
}
