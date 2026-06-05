## Copyright (C) 2012-2013  Daniel Pavel
## Copyright (C) 2014-2024  Solaar Contributors https://pwr-solaar.github.io/Solaar/
##
## This program is free software; you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation; either version 2 of the License, or
## (at your option) any later version.
##
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License along
## with this program; if not, write to the Free Software Foundation, Inc.,
## 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
from enum import IntEnum
from enum import IntFlag

from .common import NamedInts

# <FeaturesSupported.xml sed '/LD_FID_/{s/.*LD_FID_/\t/;s/"[ \t]*Id="/=/;s/" \/>/,/p}' | sort -t= -k2
# additional features names taken from https://github.com/cvuchener/hidpp and
# https://github.com/Logitech/cpg-docs/tree/master/hidpp20
"""Possible features available on a Logitech device.

A particular device might not support all these features, and may support other
unknown features as well.
"""


class SupportedFeature(IntEnum):
    ROOT = 0x0000
    FEATURE_SET = 0x0001
    FEATURE_INFO = 0x0002
    # Common
    DEVICE_FW_VERSION = 0x0003
    DEVICE_UNIT_ID = 0x0004
    DEVICE_NAME = 0x0005
    DEVICE_GROUPS = 0x0006
    DEVICE_FRIENDLY_NAME = 0x0007
    KEEP_ALIVE = 0x0008
    PROPERTY_ACCESS = 0x0011
    CONFIG_CHANGE = 0x0020
    CRYPTO_ID = 0x0021
    TARGET_SOFTWARE = 0x0030
    WIRELESS_SIGNAL_STRENGTH = 0x0080
    DFUCONTROL_LEGACY = 0x00C0
    DFUCONTROL_UNSIGNED = 0x00C1
    DFUCONTROL_SIGNED = 0x00C2
    DFUCONTROL = 0x00C3
    DFU = 0x00D0
    BATTERY_STATUS = 0x1000
    BATTERY_VOLTAGE = 0x1001
    UNIFIED_BATTERY = 0x1004
    CHARGING_CONTROL = 0x1010
    LED_CONTROL = 0x1300
    FORCE_PAIRING = 0x1500
    GENERIC_TEST = 0x1800
    DEVICE_RESET = 0x1802
    OOBSTATE = 0x1805
    CONFIG_DEVICE_PROPS = 0x1806
    CHANGE_HOST = 0x1814
    HOSTS_INFO = 0x1815
    BLE_PRO_PRE_PAIRING = 0x1816
    BACKLIGHT = 0x1981
    BACKLIGHT2 = 0x1982
    BACKLIGHT3 = 0x1983
    ILLUMINATION = 0x1990
    FORCE_SENSING_BUTTON = 0x19C0
    HAPTIC = 0x19B0
    PRESENTER_CONTROL = 0x1A00
    SENSOR_3D = 0x1A01
    REPROG_CONTROLS = 0x1B00
    REPROG_CONTROLS_V2 = 0x1B01
    REPROG_CONTROLS_V2_2 = 0x1B02  # LogiOptions 2.10.73 features.xml
    REPROG_CONTROLS_V3 = 0x1B03
    REPROG_CONTROLS_V4 = 0x1B04
    ANALOG_BUTTONS = 0x1B0C  # Analog button tuning (actuation point, rapid trigger, haptics)
    FULL_KEY_CUSTOMIZATION = 0x1B05
    CONTROL_LIST = 0x1B10
    SWITCH_SWAPABILITY = 0x1B20
    DEVICE_MODE = 0x1B30
    REPORT_HID_USAGE = 0x1BC0
    PERSISTENT_REMAPPABLE_ACTION = 0x1C00
    WIRELESS_DEVICE_STATUS = 0x1D4B
    REMAINING_PAIRING = 0x1DF0
    ENABLE_HIDDEN_FEATURES = 0x1E00
    FIRMWARE_PROPERTIES = 0x1F1F
    ADC_MEASUREMENT = 0x1F20
    # Mouse
    LEFT_RIGHT_SWAP = 0x2001
    SWAP_BUTTON_CANCEL = 0x2005
    POINTER_AXIS_ORIENTATION = 0x2006
    VERTICAL_SCROLLING = 0x2100
    SMART_SHIFT = 0x2110
    SMART_SHIFT_ENHANCED = 0x2111
    HI_RES_SCROLLING = 0x2120
    HIRES_WHEEL = 0x2121
    LOWRES_WHEEL = 0x2130
    THUMB_WHEEL = 0x2150
    MOUSE_POINTER = 0x2200
    ADJUSTABLE_DPI = 0x2201
    EXTENDED_ADJUSTABLE_DPI = 0x2202
    POINTER_SPEED = 0x2205
    ANGLE_SNAPPING = 0x2230
    SURFACE_TUNING = 0x2240
    XY_STATS = 0x2250
    WHEEL_STATS = 0x2251
    HYBRID_TRACKING = 0x2400
    # Keyboard
    FN_INVERSION = 0x40A0
    NEW_FN_INVERSION = 0x40A2
    K375S_FN_INVERSION = 0x40A3
    ENCRYPTION = 0x4100
    LOCK_KEY_STATE = 0x4220
    SOLAR_DASHBOARD = 0x4301
    KEYBOARD_LAYOUT = 0x4520
    KEYBOARD_DISABLE_KEYS = 0x4521
    KEYBOARD_DISABLE_BY_USAGE = 0x4522
    KEYBOARD_DISABLE_CONTROLS = 0x4523
    DUALPLATFORM = 0x4530
    MULTIPLATFORM = 0x4531
    KEYBOARD_LAYOUT_2 = 0x4540
    CROWN = 0x4600
    # Touchpad
    TOUCHPAD_FW_ITEMS = 0x6010
    TOUCHPAD_SW_ITEMS = 0x6011
    TOUCHPAD_WIN8_FW_ITEMS = 0x6012
    TAP_ENABLE = 0x6020
    TAP_ENABLE_EXTENDED = 0x6021
    CURSOR_BALLISTIC = 0x6030
    TOUCHPAD_RESOLUTION = 0x6040
    TOUCHPAD_RAW_XY = 0x6100
    TOUCHMOUSE_RAW_POINTS = 0x6110
    TOUCHMOUSE_6120 = 0x6120
    GESTURE = 0x6500
    GESTURE_2 = 0x6501
    # Gaming Devices
    GKEY = 0x8010
    MKEYS = 0x8020
    MR = 0x8030
    BRIGHTNESS_CONTROL = 0x8040
    LOGI_MODIFIERS = 0x8051
    REPORT_RATE = 0x8060
    EXTENDED_ADJUSTABLE_REPORT_RATE = 0x8061
    COLOR_LED_EFFECTS = 0x8070
    RGB_EFFECTS = 0x8071
    RPM_INDICATOR = 0x807A
    RPM_LED_PATTERN = 0x807B
    PER_KEY_LIGHTING = 0x8080
    PER_KEY_LIGHTING_V2 = 0x8081
    MODE_STATUS = 0x8090
    LEGACY_AXIS_RESPONSE_CURVE = 0x80A3
    AXIS_RESPONSE_CURVE = 0x80A4
    BANDED_AXIS = 0x80B1
    COMBINED_PEDALS = 0x80D0
    BUNNY_HOPPING = 0x80E0
    ONBOARD_PROFILES = 0x8100
    PROFILE_MANAGEMENT = 0x8101
    MOUSE_BUTTON_SPY = 0x8110
    LATENCY_MONITORING = 0x8111
    GAMING_ATTACHMENTS = 0x8120
    FORCE_FEEDBACK = 0x8123
    DUAL_CLUTCH = 0x8127
    WHEEL_CENTER_POSITION = 0x812C
    DISPLAY_GAME_DATA = 0x8130
    CENTER_SPRING = 0x8131
    AXIS_MAPPING = 0x8132
    GLOBAL_DAMPING = 0x8133
    BRAKE_FORCE = 0x8134
    PEDAL_STATUS = 0x8135
    TORQUE_LIMIT = 0x8136
    CONFIGURATION_PROFILES = 0x8137
    OPERATING_RANGE = 0x8138
    TRUE_FORCE = 0x8139
    FFB_FILTER = 0x8140
    # Headsets
    SIDETONE = 0x8300
    EQUALIZER = 0x8310
    HEADSET_OUT = 0x8320
    # Centurion core
    CENTURION_DEVICE_INFO = 0x0100
    CENTURION_DEVICE_NAME = 0x0101
    CENTURION_ROOT = 0x0102
    CENTURION_MEMFAULT = 0x0103
    CENTURION_BATTERY_SOC = 0x0104
    CENTURION_AUTO_SLEEP = 0x0108
    CENTURION_GENERIC_DFU = 0x010A
    CENTURION_LED_BRIGHTNESS = 0x0110
    CENTURION_EU_POWER_MODE = 0x0115
    CENTURION_DEVICE_BOOL_STATE = 0x0116
    # Headsets (Centurion-era)
    HEADSET_VOLUME = 0x0200
    HEADSET_EQ = 0x0201
    HEADSET_ADVANCED_PARA_EQ = 0x020D
    HEADSET_MIC_TEST = 0x020E
    HEADSET_EQ_STYLES = 0x0213
    BT_HOST_INFO = 0x0305
    LIGHTSPEED_PAIRING = 0x0309
    BT_GAMING_MODE = 0x030A
    HEADSET_RGB_EFFECTS = 0x0600
    HEADSET_MIC_MUTE = 0x0601
    HEADSET_MIC_SNR = 0x0602
    HEADSET_AUDIO_SIDETONE = 0x0604
    HEADSET_HOST_SWITCH = 0x0607
    HEADSET_MIX = 0x0609
    HEADSET_TONES = 0x060B
    HEADSET_NOISE_EXPOSURE = 0x060D
    HEADSET_AI_NOISE_REDUCTION = 0x060E
    HEADSET_MIC_GAIN = 0x0611
    HEADSET_USAGE_TRACKING = 0x0617
    HEADSET_BATTERY_SAVER = 0x0618
    HEADSET_RGB_HOSTMODE = 0x0620
    HEADSET_RGB_ONBOARD_EFFECTS = 0x0621
    HEADSET_RGB_SIGNATURE_EFFECTS = 0x0622
    HEADSET_DO_NOT_DISTURB = 0x0631
    CENTURION_ONBOARD_PROFILES = 0x0634
    HEADSET_RGB_STREAMING = 0x0635
    HEADSET_ONBOARD_EQ = 0x0636
    # Audio mixing / LogiVoice
    MIXER_AUDIO = 0x0800
    MIXER_MIC = 0x0801
    LOGIVOICE = 0x0900
    LOGIVOICE_NOISE_REDUCTION = 0x0901
    LOGIVOICE_NOISE_GATE = 0x0902
    LOGIVOICE_COMPRESSOR = 0x0903
    LOGIVOICE_DE_ESSER = 0x0904
    LOGIVOICE_DE_POPPER = 0x0905
    LOGIVOICE_LIMITER = 0x0906
    LOGIVOICE_HIGH_PASS_FILTER = 0x0907
    LOGIVOICE_EQUALIZER = 0x0908
    LOGIVOICE_AINR = 0x0909
    METERING = 0x0B01
    MIC_GAIN_AUTO_MODE = 0x0B02
    # Fake features for Solaar internal use
    MOUSE_GESTURE = 0xFE00

    def __str__(self):
        return self.name.replace("_", " ")


class FeatureFlag(IntFlag):
    """Single bit flags."""

    INTERNAL = 0x20
    HIDDEN = 0x40
    OBSOLETE = 0x80


DEVICE_KIND = NamedInts(
    keyboard=0x00,
    remote_control=0x01,
    numpad=0x02,
    mouse=0x03,
    touchpad=0x04,
    trackball=0x05,
    presenter=0x06,
    receiver=0x07,
)


class OnboardMode(IntEnum):
    MODE_NO_CHANGE = 0x00
    MODE_ONBOARD = 0x01
    MODE_HOST = 0x02


class ChargeLevel(IntEnum):
    AVERAGE = 50
    FULL = 90
    CRITICAL = 5


class ChargeType(IntEnum):
    STANDARD = 0x00
    FAST = 0x01
    SLOW = 0x02


class ErrorCode(IntEnum):
    UNKNOWN = 0x01
    INVALID_ARGUMENT = 0x02
    OUT_OF_RANGE = 0x03
    HARDWARE_ERROR = 0x04
    LOGITECH_ERROR = 0x05
    INVALID_FEATURE_INDEX = 0x06
    INVALID_FUNCTION = 0x07
    BUSY = 0x08
    UNSUPPORTED = 0x09


class GestureId(IntEnum):
    """Gesture IDs for feature GESTURE_2."""

    TAP_1_FINGER = 1  # task Left_Click
    TAP_2_FINGER = 2  # task Right_Click
    TAP_3_FINGER = 3
    CLICK_1_FINGER = 4  # task Left_Click
    CLICK_2_FINGER = 5  # task Right_Click
    CLICK_3_FINGER = 6
    DOUBLE_TAP_1_FINGER = 10
    DOUBLE_TAP_2_FINGER = 11
    DOUBLE_TAP_3_FINGER = 12
    TRACK_1_FINGER = 20  # action MovePointer
    TRACKING_ACCELERATION = 21
    TAP_DRAG_1_FINGER = 30  # action Drag
    TAP_DRAG_2_FINGER = 31  # action SecondaryDrag
    DRAG_3_FINGER = 32
    TAP_GESTURES = 33  # group all tap gestures under a single UI setting
    FN_CLICK_GESTURE_SUPPRESSION = 34  # suppresses Tap and Edge gestures, toggled by Fn+Click
    SCROLL_1_FINGER = 40  # action ScrollOrPageXY / ScrollHorizontal
    SCROLL_2_FINGER = 41  # action ScrollOrPageXY / ScrollHorizontal
    SCROLL_2_FINGER_HORIZONTAL = 42  # action ScrollHorizontal
    SCROLL_2_FINGER_VERTICAL = 43  # action WheelScrolling
    SCROLL_2_FINGER_STATELESS = 44
    NATURAL_SCROLLING = 45  # affects native HID wheel reporting by gestures, not when diverted
    THUMBWHEEL = (46,)  # action WheelScrolling
    V_SCROLL_INTERTIA = 48
    V_SCROLL_BALLISTICS = 49
    SWIPE_2_FINGER_HORIZONTAL = 50  # action PageScreen
    SWIPE_3_FINGER_HORIZONTAL = 51  # action PageScreen
    SWIPE_4_FINGER_HORIZONTAL = 52  # action PageScreen
    SWIPE_3_FINGER_VERTICAL = 53
    SWIPE_4_FINGER_VERTICAL = 54
    LEFT_EDGE_SWIPE_1_FINGER = 60
    RIGHT_EDGE_SWIPE_1_FINGER = 61
    BOTTOM_EDGE_SWIPE_1_FINGER = 62
    TOP_EDGE_SWIPE_1_FINGER = 63
    LEFT_EDGE_SWIPE_1_FINGER_2 = 64  # task HorzScrollNoRepeatSet
    RIGHT_EDGE_SWIPE_1_FINGER_2 = 65
    BOTTOM_EDGE_SWIPE_1_FINGER_2 = 66
    TOP_EDGE_SWIPE_1_FINGER_2 = 67
    LEFT_EDGE_SWIPE_2_FINGER = 70
    RIGHT_EDGE_SWIPE_2_FINGER = 71
    BottomEdgeSwipe2Finger = 72
    BOTTOM_EDGE_SWIPE_2_FINGER = 72
    TOP_EDGE_SWIPE_2_FINGER = 73
    ZOOM_2_FINGER = 80  # action Zoom
    ZOOM_2_FINGER_PINCH = 81  # ZoomBtnInSet
    ZOOM_2_FINGER_SPREAD = 82  # ZoomBtnOutSet
    ZOOM_3_FINGER = 83
    ZOOM_2_FINGER_STATELESS = 84
    TWO_FINGERS_PRESENT = 85
    ROTATE_2_FINGER = 87
    FINGER_1 = 90
    FINGER_2 = 91
    FINGER_3 = 92
    FINGER_4 = 93
    FINGER_5 = 94
    FINGER_6 = 95
    FINGER_7 = 96
    FINGER_8 = 97
    FINGER_9 = 98
    FINGER_10 = 99
    DEVICE_SPECIFIC_RAW_DATA = 100


class ParamId(IntEnum):
    """Param Ids for feature GESTURE_2"""

    EXTRA_CAPABILITIES = 1  # not suitable for use
    PIXEL_ZONE = 2  # 4 2-byte integers, left, bottom, width, height; pixels
    RATIO_ZONE = 3  # 4 bytes, left, bottom, width, height; unit 1/240 pad size
    SCALE_FACTOR = 4  # 2-byte integer, with 256 as normal scale


HapticWaveForms = NamedInts(
    SHARP_STATE_CHANGE=0x00,
    DAMP_STATE_CHANGE=0x01,
    SHARP_COLLISION=0x02,
    DAMP_COLLISION=0x03,
    SUBTLE_COLLISION=0x04,
    HAPPY_ALERT=0x05,
    ANGRY_ALERT=0x06,
    COMPLETED=0x07,
    SQUARE=0x08,
    WAVE=0x09,
    FIREWORK=0x0A,
    MAD=0x0B,
    KNOCK=0x0C,
    JINGLE=0x0D,
    RINGING=0xE,
    WHISPER_COLLISION=0x1B,
)
