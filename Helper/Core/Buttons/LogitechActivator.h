#import <Foundation/Foundation.h>
#import <IOKit/hid/IOHIDLib.h>

typedef struct {
    uint8_t  wheelMode;    // 0 = Freespin, 1 = Ratchet
    uint8_t  autoShift;    // 0 = off, 1 = on
    uint8_t  threshold;    // 1 ~ 100
    uint8_t  torque;       // 1 ~ 100
    BOOL     supportsTunableTorque;
} LogitechSmartShiftState;

typedef struct {
    uint16_t currentDpi;
    uint16_t defaultDpi;
    uint16_t minDpi;
    uint16_t maxDpi;
    uint16_t step;
} LogitechDPICapabilities;

typedef struct {
    BOOL    supported;        // Device supports HiRes wheel
    BOOL    hiResEnabled;     // Current HiRes mode state
    uint8_t multiplier;       // Resolution multiplier (typically 8)
    BOOL    hasRatchetSwitch; // Has physical ratchet/free switch
} LogitechHiResWheelState;

typedef struct {
    uint8_t  currentRate;    // Current report rate index
    uint8_t  rateCount;      // Number of supported rates
    uint16_t rates[8];       // Supported rate values in Hz (e.g. 125, 250, 500, 1000)
} LogitechReportRateInfo;
