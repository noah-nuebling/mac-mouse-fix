## Copyright (C) 2012-2013  Daniel Pavel
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
from __future__ import annotations

import enum
import logging
import socket
import struct
import traceback

from time import sleep
from time import time
from typing import Callable
from typing import Protocol

import yaml

from solaar.i18n import _

from . import base
from . import common
from . import descriptors
from . import desktop_notifications
from . import device_quirks
from . import diversion
from . import exceptions
from . import headset_rgb
from . import hidpp10_constants
from . import hidpp20
from . import hidpp20_constants
from . import logivoice
from . import rgb_effects_probe
from . import rgb_power
from . import settings
from . import settings_new
from . import settings_validator
from . import special_keys
from .hidpp10_constants import Registers
from .hidpp20 import KeyFlag
from .hidpp20 import MappingFlag
from .hidpp20_constants import GestureId
from .hidpp20_constants import ParamId

logger = logging.getLogger(__name__)

_hidpp20 = hidpp20.Hidpp20()
_F = hidpp20_constants.SupportedFeature


def halving_marks(max_value, step_count):
    """Halving series from max_value down by powers of two, plus 0.

    For max=100, count=5 → [0, 13, 25, 50, 100], matching the G515 FN-F8 cycle.
    """
    if step_count < 2 or max_value <= 0:
        return []
    levels = [-(-max_value // (1 << i)) for i in range(step_count - 1)]
    return sorted({0, *levels})


def auto_step_count(max_value, low_pct=10):
    """Step count for halving_marks that stops before dropping below low_pct of max."""
    if max_value <= 0:
        return 0
    threshold = max(1, max_value * low_pct // 100)
    n = 0
    while -(-max_value // (1 << n)) >= threshold:
        n += 1
    return n + 1


def _possible_fields_with_direction_filter(device, possible_fields, direction_field):
    """Filter direction_field's choices against the per-device blocklist for
    Wave directions the firmware accepts but doesn't render."""
    blocked = hidpp20.LedDirectionBlocklist.get(device.wpid)
    if not blocked:
        return possible_fields
    filtered = common.NamedInts()
    for v in hidpp20.LedDirectionChoices:
        if int(v) not in blocked:
            filtered[int(v)] = str(v)
    device_direction_field = dict(direction_field, choices=filtered)
    return [device_direction_field if f is direction_field else f for f in possible_fields]


class State(enum.Enum):
    IDLE = "idle"
    PRESSED = "pressed"
    MOVED = "moved"


# Setting classes are used to control the settings that the Solaar GUI shows and manipulates.
# Each setting class has to several class variables:
# name, which is used as a key when storing information about the setting,
#   setting classes can have the same name, as long as devices only have one setting with the same name;
# label, which is shown in the Solaar main window;
# description, which is shown when the mouse hovers over the setting in the main window;
# either register or feature, the register or feature that the setting uses;
# rw_class, the class of the reader/writer (if it is not the standard one),
# rw_options, a dictionary of options for the reader/writer.
# validator_class, the class of the validator (default settings.BooleanValidator)
# validator_options, a dictionary of options for the validator
# persist (inherited True), which is whether to store the value and apply it when setting up the device.
#
# The different setting classes imported from settings.py are for different numbers and kinds of arguments.
# Setting is for settings with a single value (boolean, number in a range, and symbolic choice).
# Settings is for settings that are maps from keys to values
#    and permit reading or writing the entire map or just one key/value pair.
# The BitFieldSetting class is for settings that have multiple boolean values packed into a bit field.
# BitFieldWithOffsetAndMaskSetting is similar.
# The RangeFieldSetting class is for settings that have multiple ranges packed into a byte string.
# LongSettings is for settings that have an even more complex structure.
#
# When settings are created a reader/writer and a validator are created.

# If the setting class has a value for rw_class then an instance of that class is created.
# Otherwise if the setting has a register then an instance of RegisterRW is created.
# and if the setting has a feature then an instance of FeatureRW is created.
# The instance is created with the register or feature as the first argument and rw_options as keyword arguments.
# RegisterRW doesn't use any options.
# FeatureRW options include
#   read_fnid - the feature function (times 16) to read the value (default 0x00),
#   write_fnid - the feature function (times 16) to write the value (default 0x10),
#   prefix - a prefix to add to the data being written and the read request (default b''), used for features
#     that provide and set multiple settings (e.g., to read and write function key inversion for current host)
#   no_reply - whether to wait for a reply (default false) (USE WITH EXTREME CAUTION).
#
# There are three simple validator classes - BooleanV, RangeValidator, and ChoicesValidator
# BooleanV is for boolean values and is the default.  It takes
#   true_value is the raw value for true (default 0x01), this can be an integer or a byte string,
#   false_value is the raw value for false (default 0x00), this can be an integer or a byte string,
#   mask is used to keep only some bits from a sequence of bits, this can be an integer or a byte string,
#   read_skip_byte_count is the number of bytes to ignore at the beginning of the read value (default 0),
#   write_prefix_bytes is a byte string to write before the value (default empty).

# RangeValidator is for an integer in a range.  It takes
#   byte_count is number of bytes that the value is stored in (defaults to size of max_value).
#   read_skip_byte_count is as for BooleanV
#   write_prefix_bytes is as for BooleanV
# RangeValidator uses min_value and max_value from the setting class as minimum and maximum.

# ChoicesValidator is for symbolic choices.  It takes one positional and three keyword arguments:
#   choices is a list of named integers that are the valid choices,
#   byte_count is the number of bytes for the integer (default size of largest choice integer),
#   read_skip_byte_count is as for BooleanV,
#   write_prefix_bytes is as for BooleanV.
# Settings that use ChoicesValidator should have a choices_universe class variable of the potential choices,
# or None for no limitation and optionally a choices_extra class variable with an extra choice.
# The choices_extra is so that there is no need to specially extend a large existing NamedInts.
# ChoicesMapValidator validator is for map settings that map onto symbolic choices.   It takes
#   choices_map is a map from keys to possible values
#   byte_count is as for ChoicesValidator,
#   read_skip_byte_count is as for ChoicesValidator,
#   write_prefix_bytes is as for ChoicesValidator,
#   key_byte_count is the number of bytes for the key integer (default size of largest key),
#   extra_default is an extra raw value that is used as a default value (default None).
# Settings that use ChoicesValidator should have keys_universe and choices_universe class variable of
# the potential keys and potential choices or None for no limitation.

# BitFieldValidator validator is for bit field settings.  It takes one positional and one keyword argument
#   the positional argument is the number of bits in the bit field
#   byte_count is the size of the bit field (default size of the bit field)
#
# A few settings work very differently.  They divert a key, which is then used to start and stop some special action.
# These settings have reader/writer classes that perform special processing instead of sending commands to the device.


class FnSwapVirtual(settings.Setting):  # virtual setting to hold fn swap strings
    name = "fn-swap"
    label = _("Swap Fx function")
    description = (
        _(
            "When set, the F1..F12 keys will activate their special function,\n"
            "and you must hold the FN key to activate their standard function."
        )
        + "\n\n"
        + _(
            "When unset, the F1..F12 keys will activate their standard function,\n"
            "and you must hold the FN key to activate their special function."
        )
    )


class RegisterHandDetection(settings.Setting):
    name = "hand-detection"
    label = _("Hand Detection")
    description = _("Turn on illumination when the hands hover over the keyboard.")
    register = Registers.KEYBOARD_HAND_DETECTION
    validator_options = {"true_value": b"\x00\x00\x00", "false_value": b"\x00\x00\x30", "mask": b"\x00\x00\xff"}


class RegisterSmoothScroll(settings.Setting):
    name = "smooth-scroll"
    label = _("Scroll Wheel Smooth Scrolling")
    description = _("High-sensitivity mode for vertical scroll with the wheel.")
    register = Registers.MOUSE_BUTTON_FLAGS
    validator_options = {"true_value": 0x40, "mask": 0x40}


class RegisterSideScroll(settings.Setting):
    name = "side-scroll"
    label = _("Side Scrolling")
    description = _(
        "When disabled, pushing the wheel sideways sends custom button events\n"
        "instead of the standard side-scrolling events."
    )
    register = Registers.MOUSE_BUTTON_FLAGS
    validator_options = {"true_value": 0x02, "mask": 0x02}


# different devices have different sets of permissible dpis, so this should be subclassed
class RegisterDpi(settings.Setting):
    name = "dpi-old"
    label = _("Sensitivity (DPI - older mice)")
    description = _("Mouse movement sensitivity")
    register = Registers.MOUSE_DPI
    choices_universe = common.NamedInts.range(0x81, 0x8F, lambda x: str((x - 0x80) * 100))
    validator_class = settings_validator.ChoicesValidator
    validator_options = {"choices": choices_universe}


class RegisterFnSwap(FnSwapVirtual):
    register = Registers.KEYBOARD_FN_SWAP
    validator_options = {"true_value": b"\x00\x01", "mask": b"\x00\x01"}


class _PerformanceMXDpi(RegisterDpi):
    choices_universe = common.NamedInts.range(0x81, 0x8F, lambda x: str((x - 0x80) * 100))
    validator_options = {"choices": choices_universe}


# set up register settings for devices - this is done here to break up an import loop
descriptors.get_wpid("0060").settings = [RegisterFnSwap]
descriptors.get_wpid("2008").settings = [RegisterFnSwap]
descriptors.get_wpid("2010").settings = [RegisterFnSwap, RegisterHandDetection]
descriptors.get_wpid("2011").settings = [RegisterFnSwap]
descriptors.get_usbid(0xC318).settings = [RegisterFnSwap]
descriptors.get_wpid("C714").settings = [RegisterFnSwap]
descriptors.get_wpid("100B").settings = [RegisterSmoothScroll, RegisterSideScroll]
descriptors.get_wpid("100F").settings = [RegisterSmoothScroll, RegisterSideScroll]
descriptors.get_wpid("1013").settings = [RegisterSmoothScroll, RegisterSideScroll]
descriptors.get_wpid("1014").settings = [RegisterSmoothScroll, RegisterSideScroll]
descriptors.get_wpid("1017").settings = [RegisterSmoothScroll, RegisterSideScroll]
descriptors.get_wpid("1023").settings = [RegisterSmoothScroll, RegisterSideScroll]
# somehow messed up ? descriptors.get_wpid("4004").settings = [_PerformanceMXDpi, RegisterSmoothScroll, RegisterSideScroll]
descriptors.get_wpid("101A").settings = [_PerformanceMXDpi, RegisterSmoothScroll, RegisterSideScroll]
descriptors.get_wpid("101B").settings = [RegisterSmoothScroll, RegisterSideScroll]
descriptors.get_wpid("101D").settings = [RegisterSmoothScroll, RegisterSideScroll]
descriptors.get_wpid("101F").settings = [RegisterSideScroll]
descriptors.get_usbid(0xC06B).settings = [RegisterSmoothScroll, RegisterSideScroll]
descriptors.get_wpid("1025").settings = [RegisterSideScroll]
descriptors.get_wpid("102A").settings = [RegisterSmoothScroll, RegisterSideScroll]
descriptors.get_usbid(0xC048).settings = [_PerformanceMXDpi, RegisterSmoothScroll, RegisterSideScroll]
descriptors.get_usbid(0xC066).settings = [_PerformanceMXDpi, RegisterSmoothScroll, RegisterSideScroll]


# ignore the capabilities part of the feature - all devices should be able to swap Fn state
# can't just use the first byte = 0xFF (for current host) because of a bug in the firmware of the MX Keys S
class K375sFnSwap(FnSwapVirtual):
    feature = _F.K375S_FN_INVERSION
    validator_options = {"true_value": b"\x01", "false_value": b"\x00", "read_skip_byte_count": 1}

    class rw_class(settings.FeatureRW):
        def find_current_host(self, device):
            if not self.prefix:
                response = device.feature_request(_F.HOSTS_INFO, 0x00)
                self.prefix = response[3:4] if response else b"\xff"

        def read(self, device, data_bytes=b""):
            self.find_current_host(device)
            return super().read(device, data_bytes)

        def write(self, device, data_bytes):
            self.find_current_host(device)
            return super().write(device, data_bytes)


class FnSwap(FnSwapVirtual):
    feature = _F.FN_INVERSION


class NewFnSwap(FnSwapVirtual):
    feature = _F.NEW_FN_INVERSION


class Backlight(settings.Setting):
    name = "backlight-qualitative"
    label = _("Backlight Timed")
    description = _("Set illumination time for keyboard.")
    feature = _F.BACKLIGHT
    choices_universe = common.NamedInts(Off=0, Varying=2, VeryShort=5, Short=10, Medium=20, Long=60, VeryLong=180)
    validator_class = settings_validator.ChoicesValidator
    validator_options = {"choices": choices_universe}


# MX Keys S requires some extra values, as in 11 02 0c1a 000dff000b000b003c00000000000000
# on/off options (from current) effect (FF-no change) level (from current) durations[6] (from current)
class Backlight2(settings.Setting):
    name = "backlight"
    label = _("Backlight")
    description = _("Illumination level on keyboard.  Changes made are only applied in Manual mode.")
    feature = _F.BACKLIGHT2
    choices_universe = common.NamedInts(Disabled=0xFF, Enabled=0x00, Automatic=0x01, Manual=0x02)
    min_version = 0

    class rw_class:
        def __init__(self, feature):
            self.feature = feature
            self.kind = settings.FeatureRW.kind

        def read(self, device):
            backlight = device.backlight
            if not backlight.enabled:
                return b"\xff"
            else:
                return common.int2bytes(backlight.mode, 1)

        def write(self, device, data_bytes):
            backlight = device.backlight
            backlight.enabled = data_bytes[0] != 0xFF
            if data_bytes[0] != 0xFF:
                backlight.mode = data_bytes[0]
            backlight.write()
            return True

    class validator_class(settings_validator.ChoicesValidator):
        @classmethod
        def build(cls, setting_class, device):
            backlight = device.backlight
            choices = common.NamedInts()
            choices[0xFF] = _("Disabled")
            if backlight.auto_supported:
                choices[0x1] = _("Automatic")
            if backlight.perm_supported:
                choices[0x3] = _("Manual")
            if not (backlight.auto_supported or backlight.temp_supported or backlight.perm_supported):
                choices[0x0] = _("Enabled")
            return cls(choices=choices, byte_count=1)


class Backlight2Level(settings.Setting):
    name = "backlight_level"
    label = _("Backlight Level")
    description = _("Illumination level on keyboard when in Manual mode.")
    feature = _F.BACKLIGHT2
    min_version = 3

    class rw_class:
        def __init__(self, feature):
            self.feature = feature
            self.kind = settings.FeatureRW.kind

        def read(self, device):
            backlight = device.backlight
            return common.int2bytes(backlight.level, 1)

        def write(self, device, data_bytes):
            if device.backlight.level != common.bytes2int(data_bytes):
                device.backlight.level = common.bytes2int(data_bytes)
                device.backlight.write()
            return True

    class validator_class(settings_validator.RangeValidator):
        @classmethod
        def build(cls, setting_class, device):
            reply = device.feature_request(_F.BACKLIGHT2, 0x20)
            assert reply, "Oops, backlight range cannot be retrieved!"
            if reply[0] > 1:
                return cls(min_value=0, max_value=reply[0] - 1, byte_count=1)


class Backlight2Duration(settings.Setting):
    feature = _F.BACKLIGHT2
    min_version = 3
    validator_class = settings_validator.RangeValidator
    min_value = 1
    max_value = 600  # 10 minutes - actual maximum is 2 hours
    validator_options = {"byte_count": 2}

    class rw_class:
        def __init__(self, feature, field):
            self.feature = feature
            self.kind = settings.FeatureRW.kind
            self.field = field

        def read(self, device):
            backlight = device.backlight
            return common.int2bytes(getattr(backlight, self.field) * 5, 2)  # use seconds instead of 5-second units

        def write(self, device, data_bytes):
            backlight = device.backlight
            new_duration = (int.from_bytes(data_bytes, byteorder="big") + 4) // 5  # use ceiling in 5-second units
            if new_duration != getattr(backlight, self.field):
                setattr(backlight, self.field, new_duration)
                backlight.write()
            return True


class Backlight2DurationHandsOut(Backlight2Duration):
    name = "backlight_duration_hands_out"
    label = _("Backlight Delay Hands Out")
    description = _("Delay in seconds until backlight fades out with hands away from keyboard.")
    feature = _F.BACKLIGHT2
    validator_class = settings_validator.RangeValidator
    rw_options = {"field": "dho"}


class Backlight2DurationHandsIn(Backlight2Duration):
    name = "backlight_duration_hands_in"
    label = _("Backlight Delay Hands In")
    description = _("Delay in seconds until backlight fades out with hands near keyboard.")
    feature = _F.BACKLIGHT2
    validator_class = settings_validator.RangeValidator
    rw_options = {"field": "dhi"}


class Backlight2DurationPowered(Backlight2Duration):
    name = "backlight_duration_powered"
    label = _("Backlight Delay Powered")
    description = _("Delay in seconds until backlight fades out with external power.")
    feature = _F.BACKLIGHT2
    validator_class = settings_validator.RangeValidator
    rw_options = {"field": "dpow"}


class Backlight3(settings.Setting):
    name = "backlight-timed"
    label = _("Backlight (Seconds)")
    description = _("Set illumination time for keyboard.")
    feature = _F.BACKLIGHT3
    rw_options = {"read_fnid": 0x10, "write_fnid": 0x20, "suffix": b"\x09"}
    validator_class = settings_validator.RangeValidator
    min_value = 0
    max_value = 1000
    validator_options = {"byte_count": 2}


class HiResScroll(settings.Setting):
    name = "hi-res-scroll"
    label = _("Scroll Wheel High Resolution")
    description = (
        _("High-sensitivity mode for vertical scroll with the wheel.")
        + "\n"
        + _("Set to ignore if scrolling is abnormally fast or slow")
    )
    feature = _F.HI_RES_SCROLLING


class LowresMode(settings.Setting):
    name = "lowres-scroll-mode"
    label = _("Scroll Wheel Diversion")
    description = _(
        "Make scroll wheel send LOWRES_WHEEL HID++ notifications (which trigger Solaar rules but are otherwise ignored)."
    )
    feature = _F.LOWRES_WHEEL


class HiresSmoothInvert(settings.Setting):
    name = "hires-smooth-invert"
    label = _("Scroll Wheel Direction")
    description = _("Invert direction for vertical scroll with wheel.")
    feature = _F.HIRES_WHEEL
    rw_options = {"read_fnid": 0x10, "write_fnid": 0x20}
    validator_options = {"true_value": 0x04, "mask": 0x04}


class HiresSmoothResolution(settings.Setting):
    name = "hires-smooth-resolution"
    label = _("Scroll Wheel Resolution")
    description = (
        _("High-sensitivity mode for vertical scroll with the wheel.")
        + "\n"
        + _("Set to ignore if scrolling is abnormally fast or slow")
    )
    feature = _F.HIRES_WHEEL
    rw_options = {"read_fnid": 0x10, "write_fnid": 0x20}
    validator_options = {"true_value": 0x02, "mask": 0x02}


class HiresMode(settings.Setting):
    name = "hires-scroll-mode"
    label = _("Scroll Wheel Diversion")
    description = _(
        "Make scroll wheel send HIRES_WHEEL HID++ notifications (which trigger Solaar rules but are otherwise ignored)."
    )
    feature = _F.HIRES_WHEEL
    rw_options = {"read_fnid": 0x10, "write_fnid": 0x20}
    validator_options = {"true_value": 0x01, "mask": 0x01}


class PointerSpeed(settings.Setting):
    name = "pointer_speed"
    label = _("Sensitivity (Pointer Speed)")
    description = _("Speed multiplier for mouse (256 is normal multiplier).")
    feature = _F.POINTER_SPEED
    validator_class = settings_validator.RangeValidator
    min_value = 0x002E
    max_value = 0x01FF
    validator_options = {"byte_count": 2}


class ThumbMode(settings.Setting):
    name = "thumb-scroll-mode"
    label = _("Thumb Wheel Diversion")
    description = _(
        "Make thumb wheel send THUMB_WHEEL HID++ notifications (which trigger Solaar rules but are otherwise ignored)."
    )
    feature = _F.THUMB_WHEEL
    rw_options = {"read_fnid": 0x10, "write_fnid": 0x20}
    validator_options = {"true_value": b"\x01\x00", "false_value": b"\x00\x00", "mask": b"\x01\x00"}


class ThumbInvert(settings.Setting):
    name = "thumb-scroll-invert"
    label = _("Thumb Wheel Direction")
    description = _("Invert thumb wheel scroll direction.")
    feature = _F.THUMB_WHEEL
    rw_options = {"read_fnid": 0x10, "write_fnid": 0x20}
    validator_options = {"true_value": b"\x00\x01", "false_value": b"\x00\x00", "mask": b"\x00\x01"}


# change UI to show result of onboard profile change
def profile_change(device, profile_sector):
    if device.setting_callback:
        device.setting_callback(device, OnboardProfiles, [profile_sector])
        for profile in device.profiles.profiles.values() if device.profiles else []:
            if profile.sector == profile_sector:
                resolution_index = profile.resolution_default_index
                device.setting_callback(device, AdjustableDpi, [profile.resolutions[resolution_index]])
                device.setting_callback(device, ReportRate, [profile.report_rate])
                break


class OnboardProfiles(settings.Setting):
    name = "onboard_profiles"
    label = _("Onboard Profiles")
    description = _("Enable an onboard profile, which controls report rate, sensitivity, and button actions")
    feature = _F.ONBOARD_PROFILES
    choices_universe = common.NamedInts(Disabled=0)
    for i in range(1, 16):
        choices_universe[i] = f"Profile {i}"
        choices_universe[i + 0x100] = f"Read-Only Profile {i}"
    validator_class = settings_validator.ChoicesValidator

    class rw_class:
        def __init__(self, feature):
            self.feature = feature
            self.kind = settings.FeatureRW.kind

        def read(self, device):
            enabled = device.feature_request(_F.ONBOARD_PROFILES, 0x20)[0]
            if enabled == 0x01:
                active = device.feature_request(_F.ONBOARD_PROFILES, 0x40)
                return active[:2]
            else:
                return b"\x00\x00"

        def write(self, device, data_bytes):
            if data_bytes == b"\x00\x00":
                result = device.feature_request(_F.ONBOARD_PROFILES, 0x10, b"\x02")
            else:
                device.feature_request(_F.ONBOARD_PROFILES, 0x10, b"\x01")
                result = device.feature_request(_F.ONBOARD_PROFILES, 0x30, data_bytes)
                profile_change(device, common.bytes2int(data_bytes))
            return result

    class validator_class(settings_validator.ChoicesValidator):
        @classmethod
        def build(cls, setting_class, device):
            headers = hidpp20.OnboardProfiles.get_profile_headers(device)
            profiles_list = [setting_class.choices_universe[0]]
            if headers:
                for sector, enabled in headers:
                    if enabled and setting_class.choices_universe[sector]:
                        profiles_list.append(setting_class.choices_universe[sector])
            return cls(choices=common.NamedInts.list(profiles_list), byte_count=2) if len(profiles_list) > 1 else None


class ReportRate(settings.Setting):
    name = "report_rate"
    label = _("Report Rate")
    description = (
        _("Frequency of device movement reports") + "\n" + _("May need Onboard Profiles set to Disable to be effective.")
    )
    feature = _F.REPORT_RATE
    rw_options = {"read_fnid": 0x10, "write_fnid": 0x20}
    choices_universe = common.NamedInts()
    choices_universe[1] = "1ms"
    choices_universe[2] = "2ms"
    choices_universe[3] = "3ms"
    choices_universe[4] = "4ms"
    choices_universe[5] = "5ms"
    choices_universe[6] = "6ms"
    choices_universe[7] = "7ms"
    choices_universe[8] = "8ms"

    class validator_class(settings_validator.ChoicesValidator):
        @classmethod
        def build(cls, setting_class, device):
            # if device.wpid == '408E':
            #    return None  # host mode borks the function keys on the G915 TKL keyboard
            reply = device.feature_request(_F.REPORT_RATE, 0x00)
            assert reply, "Oops, report rate choices cannot be retrieved!"
            rate_list = []
            rate_flags = common.bytes2int(reply[0:1])
            for i in range(0, 8):
                if (rate_flags >> i) & 0x01:
                    rate_list.append(setting_class.choices_universe[i + 1])
            return cls(choices=common.NamedInts.list(rate_list), byte_count=1) if rate_list else None


class ExtendedReportRate(settings.Setting):
    name = "report_rate_extended"
    label = _("Report Rate")
    description = (
        _("Frequency of device movement reports") + "\n" + _("May need Onboard Profiles set to Disable to be effective.")
    )
    feature = _F.EXTENDED_ADJUSTABLE_REPORT_RATE
    rw_options = {"read_fnid": 0x20, "write_fnid": 0x30}
    choices_universe = common.NamedInts()
    choices_universe[0] = "8ms"
    choices_universe[1] = "4ms"
    choices_universe[2] = "2ms"
    choices_universe[3] = "1ms"
    choices_universe[4] = "500us"
    choices_universe[5] = "250us"
    choices_universe[6] = "125us"

    class validator_class(settings_validator.ChoicesValidator):
        @classmethod
        def build(cls, setting_class, device):
            reply = device.feature_request(_F.EXTENDED_ADJUSTABLE_REPORT_RATE, 0x10)
            assert reply, "Oops, report rate choices cannot be retrieved!"
            rate_list = []
            rate_flags = common.bytes2int(reply[0:2])
            for i in range(0, 7):
                if rate_flags & (0x01 << i):
                    rate_list.append(setting_class.choices_universe[i])
            return cls(choices=common.NamedInts.list(rate_list), byte_count=1) if rate_list else None


class DivertCrown(settings.Setting):
    name = "divert-crown"
    label = _("Divert crown events")
    description = _("Make crown send CROWN HID++ notifications (which trigger Solaar rules but are otherwise ignored).")
    feature = _F.CROWN
    rw_options = {"read_fnid": 0x10, "write_fnid": 0x20}
    validator_options = {"true_value": 0x02, "false_value": 0x01, "mask": 0xFF}


class CrownSmooth(settings.Setting):
    name = "crown-smooth"
    label = _("Crown smooth scroll")
    description = _("Set crown smooth scroll")
    feature = _F.CROWN
    rw_options = {"read_fnid": 0x10, "write_fnid": 0x20}
    validator_options = {"true_value": 0x01, "false_value": 0x02, "read_skip_byte_count": 1, "write_prefix_bytes": b"\x00"}


class DivertGkeys(settings.Setting):
    name = "divert-gkeys"
    label = _("Divert G and M Keys")
    description = _("Make G and M keys send HID++ notifications (which trigger Solaar rules but are otherwise ignored).")
    feature = _F.GKEY
    validator_options = {"true_value": 0x01, "false_value": 0x00, "mask": 0xFF}

    class rw_class(settings.FeatureRW):
        def __init__(self, feature):
            super().__init__(feature, write_fnid=0x20)

        def read(self, device):  # no way to read, so just assume not diverted
            return b"\x00"


class ScrollRatchet(settings.Setting):
    name = "scroll-ratchet"
    label = _("Scroll Wheel Ratcheted")
    description = _("Switch the mouse wheel between speed-controlled ratcheting and always freespin.")
    feature = _F.SMART_SHIFT
    choices_universe = common.NamedInts(**{_("Freespinning"): 1, _("Ratcheted"): 2})
    validator_class = settings_validator.ChoicesValidator
    validator_options = {"choices": choices_universe}


class SmartShift(settings.Setting):
    name = "smart-shift"
    label = _("Scroll Wheel Ratchet Speed")
    description = _(
        "Use the mouse wheel speed to switch between ratcheted and freespinning.\n"
        "The mouse wheel is always ratcheted at 50."
    )
    feature = _F.SMART_SHIFT
    rw_options = {"read_fnid": 0x00, "write_fnid": 0x10}

    class rw_class(settings.FeatureRW):
        MIN_VALUE = 1
        MAX_VALUE = 50

        def __init__(self, feature, read_fnid, write_fnid):
            super().__init__(feature, read_fnid, write_fnid)

        def read(self, device):
            value = super().read(device)
            if common.bytes2int(value[0:1]) == 1:
                # Mode = Freespin, map to minimum
                return common.int2bytes(self.MIN_VALUE, count=1)
            else:
                # Mode = smart shift, map to the value, capped at maximum
                threshold = min(common.bytes2int(value[1:2]), self.MAX_VALUE)
                return common.int2bytes(threshold, count=1)

        def write(self, device, data_bytes):
            threshold = common.bytes2int(data_bytes)
            # Freespin at minimum
            mode = 0  # 1 if threshold <= self.MIN_VALUE else 2
            # Ratchet at maximum
            if threshold >= self.MAX_VALUE:
                threshold = 255
            data = common.int2bytes(mode, count=1) + common.int2bytes(max(0, threshold), count=1)
            return super().write(device, data)

    min_value = rw_class.MIN_VALUE
    max_value = rw_class.MAX_VALUE
    validator_class = settings_validator.RangeValidator


class SmartShiftEnhanced(SmartShift):
    feature = _F.SMART_SHIFT_ENHANCED
    rw_options = {"read_fnid": 0x10, "write_fnid": 0x20}


class ScrollRatchetEnhanced(ScrollRatchet):
    feature = _F.SMART_SHIFT_ENHANCED
    rw_options = {"read_fnid": 0x10, "write_fnid": 0x20}


class ScrollRatchetTorque(settings.Setting):
    name = "scroll-ratchet-torque"
    label = _("Scroll Wheel Ratchet Torque")
    description = _("Change the torque needed to overcome the ratchet.")
    feature = _F.SMART_SHIFT_ENHANCED
    min_value = 1
    max_value = 100
    rw_options = {"read_fnid": 0x10, "write_fnid": 0x20}

    class rw_class(settings.FeatureRW):
        def write(self, device, data_bytes):
            ratchetSetting = next(filter(lambda s: s.name == "scroll-ratchet", device.settings), None)
            if ratchetSetting:  # for MX Master 4, the ratchet setting needs to be written for changes to take effect
                ratchet_value = ratchetSetting.read(True)
                data_bytes = ratchet_value.to_bytes(1, "big") + data_bytes[1:]
            result = super().write(device, data_bytes)
            return result

    class validator_class(settings_validator.RangeValidator):
        @classmethod
        def build(cls, setting_class, device):
            reply = device.feature_request(_F.SMART_SHIFT_ENHANCED, 0x00)
            if reply[0] & 0x01:  # device supports tunable torque
                return cls(
                    min_value=setting_class.min_value,
                    max_value=setting_class.max_value,
                    byte_count=1,
                    write_prefix_bytes=b"\x00\x00",  # don't change mode or disengage, but see above
                    read_skip_byte_count=2,
                )


# the keys for the choice map are Logitech controls (from special_keys)
# each choice value is a NamedInt with the string from a task (to be shown to the user)
# and the integer being the control number for that task (to be written to the device)
# Solaar only remaps keys (controlled by key gmask and group), not other key reprogramming
class ReprogrammableKeys(settings.Settings):
    name = "reprogrammable-keys"
    label = _("Key/Button Actions")
    description = (
        _("Change the action for the key or button.")
        + "  "
        + _("Overridden by diversion.")
        + "\n"
        + _("Changing important actions (such as for the left mouse button) can result in an unusable system.")
    )
    feature = _F.REPROG_CONTROLS_V4
    keys_universe = special_keys.CONTROL
    choices_universe = special_keys.CONTROL

    class rw_class:
        def __init__(self, feature):
            self.feature = feature
            self.kind = settings.FeatureRW.kind

        def read(self, device, key):
            key_index = device.keys.index(key)
            key_struct = device.keys[key_index]
            return b"\x00\x00" + common.int2bytes(int(key_struct.mapped_to), 2)

        def write(self, device, key, data_bytes):
            key_index = device.keys.index(key)
            key_struct = device.keys[key_index]
            key_struct.remap(special_keys.CONTROL[common.bytes2int(data_bytes)])
            return True

    class validator_class(settings_validator.ChoicesMapValidator):
        @classmethod
        def build(cls, setting_class, device):
            choices = {}
            if device.keys:
                for k in device.keys:
                    tgts = k.remappable_to
                    if len(tgts) > 1:
                        choices[k.key] = tgts
            return cls(choices, key_byte_count=2, byte_count=2, extra_default=0) if choices else None


class DpiSlidingXY(settings.RawXYProcessing):
    def __init__(
        self,
        *args,
        show_notification: Callable[[str, str], bool],
        **kwargs,
    ):
        super().__init__(*args, **kwargs)
        self.fsmState = None
        self._show_notification = show_notification

    def activate_action(self):
        self.dpiSetting = next(filter(lambda s: s.name == "dpi" or s.name == "dpi_extended", self.device.settings), None)
        self.dpiChoices = list(self.dpiSetting.choices)
        self.otherDpiIdx = self.device.persister.get("_dpi-sliding", -1) if self.device.persister else -1
        if not isinstance(self.otherDpiIdx, int) or self.otherDpiIdx < 0 or self.otherDpiIdx >= len(self.dpiChoices):
            self.otherDpiIdx = self.dpiChoices.index(self.dpiSetting.read())
        self.fsmState = State.IDLE
        self.dx = 0.0
        self.movingDpiIdx = None

    def setNewDpi(self, newDpiIdx):
        newDpi = self.dpiChoices[newDpiIdx]
        self.dpiSetting.write(newDpi)
        if self.device.setting_callback:
            self.device.setting_callback(self.device, type(self.dpiSetting), [newDpi])

    def displayNewDpi(self, newDpiIdx):
        selected_dpi = self.dpiChoices[newDpiIdx]
        min_dpi = self.dpiChoices[0]
        max_dpi = self.dpiChoices[-1]
        reason = f"DPI {selected_dpi} [min {min_dpi}, max {max_dpi}]"
        self._show_notification(self.device, reason)

    def press_action(self, key):  # start tracking
        self.starting = True
        if self.fsmState == State.IDLE:
            self.fsmState = State.PRESSED
            self.dx = 0.0
            # While in 'moved' state, the index into 'dpiChoices' of the currently selected DPI setting
            self.movingDpiIdx = None

    def release_action(self):  # adjust DPI and stop tracking
        if self.fsmState == State.PRESSED:  # Swap with other DPI
            thisIdx = self.dpiChoices.index(self.dpiSetting.read())
            newDpiIdx, self.otherDpiIdx = self.otherDpiIdx, thisIdx
            if self.device.persister:
                self.device.persister["_dpi-sliding"] = self.otherDpiIdx
            self.setNewDpi(newDpiIdx)
            self.displayNewDpi(newDpiIdx)
        elif self.fsmState == State.MOVED:  # Set DPI according to displacement
            self.setNewDpi(self.movingDpiIdx)
        self.fsmState = State.IDLE

    def move_action(self, dx, dy):
        if self.device.features.get_feature_version(_F.REPROG_CONTROLS_V4) >= 5 and self.starting:
            self.starting = False  # hack to ignore strange first movement report from MX Master 3S
            return
        currDpi = self.dpiSetting.read()
        self.dx += float(dx) / float(currDpi) * 15.0  # yields a more-or-less DPI-independent dx of about 5/cm
        if self.fsmState == State.PRESSED:
            if abs(self.dx) >= 1.0:
                self.fsmState = State.MOVED
                self.movingDpiIdx = self.dpiChoices.index(currDpi)
        elif self.fsmState == State.MOVED:
            currIdx = self.dpiChoices.index(self.dpiSetting.read())
            newMovingDpiIdx = min(max(currIdx + int(self.dx), 0), len(self.dpiChoices) - 1)
            if newMovingDpiIdx != self.movingDpiIdx:
                self.movingDpiIdx = newMovingDpiIdx
                self.displayNewDpi(newMovingDpiIdx)


class MouseGesturesXY(settings.RawXYProcessing):
    def activate_action(self):
        self.dpiSetting = next(filter(lambda s: s.name == "dpi" or s.name == "dpi_extended", self.device.settings), None)
        self.fsmState = State.IDLE
        self.initialize_data()

    def initialize_data(self):
        self.dx = 0.0
        self.dy = 0.0
        self.lastEv = None
        self.data = []

    def press_action(self, key):
        self.starting = True
        if self.fsmState == State.IDLE:
            self.fsmState = State.PRESSED
            self.initialize_data()
            self.data = [key.key]

    def release_action(self):
        if self.fsmState == State.PRESSED:
            # emit mouse gesture notification
            self.push_mouse_event()
            if logger.isEnabledFor(logging.INFO):
                logger.info("mouse gesture notification %s", self.data)
            payload = struct.pack("!" + (len(self.data) * "h"), *self.data)
            notification = base.HIDPPNotification(0, 0, 0, 0, payload)
            diversion.process_notification(self.device, notification, _F.MOUSE_GESTURE)
            self.fsmState = State.IDLE

    def move_action(self, dx, dy):
        if self.fsmState == State.PRESSED:
            now = time() * 1000  # time_ns() / 1e6
            if self.device.features.get_feature_version(_F.REPROG_CONTROLS_V4) >= 5 and self.starting:
                self.starting = False  # hack to ignore strange first movement report from MX Master 3S
                return
            if self.lastEv is not None and now - self.lastEv > 200.0:
                self.push_mouse_event()
            dpi = self.dpiSetting.read() if self.dpiSetting else 1000
            dx = float(dx) / float(dpi) * 15.0  # This multiplier yields a more-or-less DPI-independent dx of about 5/cm
            self.dx += dx
            dy = float(dy) / float(dpi) * 15.0  # This multiplier yields a more-or-less DPI-independent dx of about 5/cm
            self.dy += dy
            self.lastEv = now

    def key_action(self, key):
        self.push_mouse_event()
        self.data.append(1)
        self.data.append(key)
        self.lastEv = time() * 1000  # time_ns() / 1e6
        if logger.isEnabledFor(logging.DEBUG):
            logger.debug("mouse gesture key event %d %s", key, self.data)

    def push_mouse_event(self):
        x = int(self.dx)
        y = int(self.dy)
        if x == 0 and y == 0:
            return
        self.data.append(0)
        self.data.append(x)
        self.data.append(y)
        self.dx = 0.0
        self.dy = 0.0
        if logger.isEnabledFor(logging.DEBUG):
            logger.debug("mouse gesture move event %d %d %s", x, y, self.data)


class DivertKeys(settings.Settings):
    name = "divert-keys"
    label = _("Key/Button Diversion")
    description = _("Make the key or button send HID++ notifications (Diverted) or initiate Mouse Gestures or Sliding DPI")
    feature = _F.REPROG_CONTROLS_V4
    keys_universe = special_keys.CONTROL
    choices_universe = common.NamedInts(**{_("Regular"): 0, _("Diverted"): 1, _("Mouse Gestures"): 2, _("Sliding DPI"): 3})
    choices_gesture = common.NamedInts(**{_("Regular"): 0, _("Diverted"): 1, _("Mouse Gestures"): 2})
    choices_divert = common.NamedInts(**{_("Regular"): 0, _("Diverted"): 1})

    class rw_class:
        def __init__(self, feature):
            self.feature = feature
            self.kind = settings.FeatureRW.kind

        def read(self, device, key):
            key_index = device.keys.index(key)
            key_struct = device.keys[key_index]
            return b"\x00\x00\x01" if MappingFlag.DIVERTED in key_struct.mapping_flags else b"\x00\x00\x00"

        def write(self, device, key, data_bytes):
            key_index = device.keys.index(key)
            key_struct = device.keys[key_index]
            key_struct.set_diverted(common.bytes2int(data_bytes) != 0)  # not regular
            return True

    class validator_class(settings_validator.ChoicesMapValidator):
        def __init__(self, choices, key_byte_count=2, byte_count=1, mask=0x01):
            super().__init__(choices, key_byte_count, byte_count, mask)

        def prepare_write(self, key, new_value):
            if self.gestures and new_value != 2:  # mouse gestures
                self.gestures.stop(key)
            if self.sliding and new_value != 3:  # sliding DPI
                self.sliding.stop(key)
            if self.gestures and new_value == 2:  # mouse gestures
                self.gestures.start(key)
            if self.sliding and new_value == 3:  # sliding DPI
                self.sliding.start(key)
            return super().prepare_write(key, new_value)

        @classmethod
        def build(cls, setting_class, device):
            sliding = gestures = None
            choices = {}
            if device.keys:
                for key in device.keys:
                    if KeyFlag.DIVERTABLE in key.flags and KeyFlag.VIRTUAL not in key.flags:
                        if KeyFlag.RAW_XY in key.flags:
                            choices[key.key] = setting_class.choices_gesture
                            if gestures is None:
                                gestures = MouseGesturesXY(device, name="MouseGestures")
                            if _F.ADJUSTABLE_DPI in device.features:
                                choices[key.key] = setting_class.choices_universe
                                if sliding is None:
                                    sliding = DpiSlidingXY(
                                        device, name="DpiSliding", show_notification=desktop_notifications.show
                                    )
                        else:
                            choices[key.key] = setting_class.choices_divert
            if not choices:
                return None
            validator = cls(choices, key_byte_count=2, byte_count=1, mask=0x01)
            validator.sliding = sliding
            validator.gestures = gestures
            return validator


def produce_dpi_list(feature, function, ignore, device, direction):
    dpi_bytes = b""
    for i in range(0, 0x100):  # there will be only a very few iterations performed
        reply = device.feature_request(feature, function, 0x00, direction, i)
        assert reply, "Oops, DPI list cannot be retrieved!"
        dpi_bytes += reply[ignore:]
        if dpi_bytes[-2:] == b"\x00\x00":
            break
    dpi_list = []
    i = 0
    while i < len(dpi_bytes):
        val = common.bytes2int(dpi_bytes[i : i + 2])
        if val == 0:
            break
        if val >> 13 == 0b111:
            step = val & 0x1FFF
            last = common.bytes2int(dpi_bytes[i + 2 : i + 4])
            assert len(dpi_list) > 0 and last > dpi_list[-1], f"Invalid DPI list item: {val!r}"
            dpi_list += range(dpi_list[-1] + step, last + 1, step)
            i += 4
        else:
            dpi_list.append(val)
            i += 2
    return dpi_list


class AdjustableDpi(settings.Setting):
    name = "dpi"
    label = _("Sensitivity (DPI)")
    description = _("Mouse movement sensitivity") + "\n" + _("May need Onboard Profiles set to Disable to be effective.")
    feature = _F.ADJUSTABLE_DPI
    rw_options = {"read_fnid": 0x20, "write_fnid": 0x30}
    choices_universe = common.NamedInts.range(100, 4000, str, 50)

    class validator_class(settings_validator.ChoicesValidator):
        @classmethod
        def build(cls, setting_class, device):
            dpilist = produce_dpi_list(setting_class.feature, 0x10, 1, device, 0)
            setting = (
                cls(choices=common.NamedInts.list(dpilist), byte_count=2, write_prefix_bytes=b"\x00") if dpilist else None
            )
            setting.dpilist = dpilist
            return setting

        def validate_read(self, reply_bytes):  # special validator to use default DPI if needed
            reply_value = common.bytes2int(reply_bytes[1:3])
            if reply_value == 0:  # use default value instead
                reply_value = common.bytes2int(reply_bytes[3:5])
            valid_value = self.choices[reply_value]
            assert valid_value is not None, f"{self.__class__.__name__}: failed to validate read value {reply_value:02X}"
            return valid_value


class ExtendedAdjustableDpi(settings.Setting):
    # the extended version allows for two dimensions, longer dpi descriptions, but still assume only one sensor
    name = "dpi_extended"
    label = _("Sensitivity (DPI)")
    description = _("Mouse movement sensitivity") + "\n" + _("May need Onboard Profiles set to Disable to be effective.")
    feature = _F.EXTENDED_ADJUSTABLE_DPI
    rw_options = {"read_fnid": 0x50, "write_fnid": 0x60}
    keys_universe = common.NamedInts(X=0, Y=1, LOD=2)
    choices_universe = common.NamedInts.range(100, 4000, str, 50)
    choices_universe[1] = "LOW"
    choices_universe[2] = "MEDIUM"
    choices_universe[3] = "HIGH"
    keys = common.NamedInts(X=0, Y=1, LOD=2)

    def write_key_value(self, key, value, save=True):
        # Force a read to populate the full X/Y/LOD dictionary if it's missing (fixes CLI)
        if not isinstance(self._value, dict):
            self.read()

        if isinstance(self._value, dict):
            self._value[key] = value
        else:
            self._value = {key: value}

        result = self.write(self._value, save)
        return result[key] if isinstance(result, dict) else result

    class validator_class(settings_validator.ChoicesMapValidator):
        @classmethod
        def build(cls, setting_class, device):
            reply = device.feature_request(setting_class.feature, 0x10, 0x00)
            y = bool(reply[2] & 0x01)
            lod = bool(reply[2] & 0x02)
            choices_map = {}
            dpilist_x = produce_dpi_list(setting_class.feature, 0x20, 3, device, 0)
            choices_map[setting_class.keys["X"]] = common.NamedInts.list(dpilist_x)
            if y:
                dpilist_y = produce_dpi_list(setting_class.feature, 0x20, 3, device, 1)
                choices_map[setting_class.keys["Y"]] = common.NamedInts.list(dpilist_y)
            if lod:
                choices_map[setting_class.keys["LOD"]] = common.NamedInts(LOW=0, MEDIUM=1, HIGH=2)
            validator = cls(choices_map=choices_map, byte_count=2, write_prefix_bytes=b"\x00")
            validator.y = y
            validator.lod = lod
            validator.keys = setting_class.keys
            return validator

        def validate_read(self, reply_bytes):  # special validator to read entire setting
            dpi_x = common.bytes2int(reply_bytes[3:5]) if reply_bytes[1:3] == 0 else common.bytes2int(reply_bytes[1:3])
            assert dpi_x in self.choices[0], f"{self.__class__.__name__}: failed to validate dpi_x value {dpi_x:04X}"
            value = {self.keys["X"]: dpi_x}
            if self.y:
                dpi_y = common.bytes2int(reply_bytes[7:9]) if reply_bytes[5:7] == 0 else common.bytes2int(reply_bytes[5:7])
                assert dpi_y in self.choices[1], f"{self.__class__.__name__}: failed to validate dpi_y value {dpi_y:04X}"
                value[self.keys["Y"]] = dpi_y
            if self.lod:
                lod = reply_bytes[9]
                assert lod in self.choices[2], f"{self.__class__.__name__}: failed to validate lod value {lod:02X}"
                value[self.keys["LOD"]] = lod
            return value

        def prepare_write(self, new_value, current_value=None):  # special preparer to write entire setting
            data_bytes = self._write_prefix_bytes
            if new_value[self.keys["X"]] not in self.choices[self.keys["X"]]:
                raise ValueError(f"invalid value {new_value!r}")
            data_bytes += common.int2bytes(new_value[0], 2)
            if self.y:
                if new_value[self.keys["Y"]] not in self.choices[self.keys["Y"]]:
                    raise ValueError(f"invalid value {new_value!r}")
                data_bytes += common.int2bytes(new_value[self.keys["Y"]], 2)
            else:
                data_bytes += b"\x00\x00"
            if self.lod:
                if new_value[self.keys["LOD"]] not in self.choices[self.keys["LOD"]]:
                    raise ValueError(f"invalid value {new_value!r}")
                data_bytes += common.int2bytes(new_value[self.keys["LOD"]], 1)
            else:
                data_bytes += b"\x00"
            return data_bytes


class SpeedChange(settings.Setting):
    """Implements the ability to switch Sensitivity by clicking on the DPI_Change button."""

    name = "speed-change"
    label = _("Sensitivity Switching")
    description = _(
        "Switch the current sensitivity and the remembered sensitivity when the key or button is pressed.\n"
        "If there is no remembered sensitivity, just remember the current sensitivity"
    )
    choices_universe = special_keys.CONTROL
    choices_extra = common.NamedInt(0, _("Off"))
    feature = _F.POINTER_SPEED
    rw_options = {"name": "speed change"}

    class rw_class(settings.ActionSettingRW):
        def press_action(self):  # switch sensitivity
            currentSpeed = self.device.persister.get("pointer_speed", None) if self.device.persister else None
            newSpeed = self.device.persister.get("_speed-change", None) if self.device.persister else None
            speed_setting = next(filter(lambda s: s.name == "pointer_speed", self.device.settings), None)
            if newSpeed is not None:
                if speed_setting:
                    speed_setting.write(newSpeed)
                    if self.device.setting_callback:
                        self.device.setting_callback(self.device, type(speed_setting), [newSpeed])
                else:
                    logger.error("cannot save sensitivity setting on %s", self.device)
            if self.device.persister:
                self.device.persister["_speed-change"] = currentSpeed

    class validator_class(settings_validator.ChoicesValidator):
        @classmethod
        def build(cls, setting_class, device):
            key_index = device.keys.index(special_keys.CONTROL.DPI_Change)
            key = device.keys[key_index] if key_index is not None else None
            if key is not None and KeyFlag.DIVERTABLE in key.flags:
                keys = [setting_class.choices_extra, key.key]
                return cls(choices=common.NamedInts.list(keys), byte_count=2)


class DisableKeyboardKeys(settings.BitFieldSetting):
    name = "disable-keyboard-keys"
    label = _("Disable keys")
    description = _("Disable specific keyboard keys.")
    feature = _F.KEYBOARD_DISABLE_KEYS
    rw_options = {"read_fnid": 0x10, "write_fnid": 0x20}
    _labels = {k: (None, _("Disables the %s key.") % k) for k in special_keys.DISABLE}
    choices_universe = special_keys.DISABLE

    class validator_class(settings_validator.BitFieldValidator):
        @classmethod
        def build(cls, setting_class, device):
            mask = device.feature_request(_F.KEYBOARD_DISABLE_KEYS, 0x00)[0]
            options = [special_keys.DISABLE[1 << i] for i in range(8) if mask & (1 << i)]
            return cls(options) if options else None


class Multiplatform(settings.Setting):
    name = "multiplatform"
    label = _("Set OS")
    description = _("Change keys to match OS.")
    feature = _F.MULTIPLATFORM
    rw_options = {"read_fnid": 0x00, "write_fnid": 0x30}
    choices_universe = common.NamedInts(**{"OS " + str(i + 1): i for i in range(8)})

    # multiplatform OS bits
    OSS = [
        ("Linux", 0x0400),
        ("MacOS", 0x2000),
        ("Windows", 0x0100),
        ("iOS", 0x4000),
        ("Android", 0x1000),
        ("WebOS", 0x8000),
        ("Chrome", 0x0800),
        ("WinEmb", 0x0200),
        ("Tizen", 0x0001),
    ]

    # the problem here is how to construct the right values for the rules Set GUI,
    # as, for example, the integer value for 'Windows' can be different on different devices

    class validator_class(settings_validator.ChoicesValidator):
        @classmethod
        def build(cls, setting_class, device):
            def _str_os_versions(low, high):
                def _str_os_version(version):
                    if version == 0:
                        return ""
                    elif version & 0xFF:
                        return f"{str(version >> 8)}.{str(version & 0xFF)}"
                    else:
                        return str(version >> 8)

                return "" if low == 0 and high == 0 else f" {_str_os_version(low)}-{_str_os_version(high)}"

            infos = device.feature_request(_F.MULTIPLATFORM)
            assert infos, "Oops, multiplatform count cannot be retrieved!"
            flags, _ignore, num_descriptors = struct.unpack("!BBB", infos[:3])
            if not (flags & 0x02):  # can't set platform so don't create setting
                return []
            descriptors = []
            for index in range(0, num_descriptors):
                descriptor = device.feature_request(_F.MULTIPLATFORM, 0x10, index)
                platform, _ignore, os_flags, low, high = struct.unpack("!BBHHH", descriptor[:8])
                descriptors.append((platform, os_flags, low, high))
            choices = common.NamedInts()
            for os_name, os_bit in setting_class.OSS:
                for platform, os_flags, low, high in descriptors:
                    os = os_name + _str_os_versions(low, high)
                    if os_bit & os_flags and platform not in choices and os not in choices:
                        choices[platform] = os
            return cls(choices=choices, read_skip_byte_count=6, write_prefix_bytes=b"\xff") if choices else None


class DualPlatform(settings.Setting):
    name = "multiplatform"
    label = _("Set OS")
    description = _("Change keys to match OS.")
    choices_universe = common.NamedInts()
    choices_universe[0x00] = "iOS, MacOS"
    choices_universe[0x01] = "Android, Windows"
    feature = _F.DUALPLATFORM
    rw_options = {"read_fnid": 0x00, "write_fnid": 0x20}
    validator_class = settings_validator.ChoicesValidator
    validator_options = {"choices": choices_universe}


class ChangeHost(settings.Setting):
    name = "change-host"
    label = _("Change Host")
    description = _("Switch connection to a different host")
    persist = False  # persisting this setting is harmful
    feature = _F.CHANGE_HOST
    rw_options = {"read_fnid": 0x00, "write_fnid": 0x10, "no_reply": True}
    choices_universe = common.NamedInts(**{"Host " + str(i + 1): i for i in range(3)})

    class validator_class(settings_validator.ChoicesValidator):
        @classmethod
        def build(cls, setting_class, device):
            infos = device.feature_request(_F.CHANGE_HOST)
            assert infos, "Oops, host count cannot be retrieved!"
            numHosts, currentHost = struct.unpack("!BB", infos[:2])
            hostNames = _hidpp20.get_host_names(device)
            hostNames = hostNames if hostNames is not None else {}
            if currentHost not in hostNames or hostNames[currentHost][1] == "":
                hostNames[currentHost] = (True, socket.gethostname().partition(".")[0])
            choices = common.NamedInts()
            for host in range(0, numHosts):
                paired, hostName = hostNames.get(host, (True, ""))
                choices[host] = f"{str(host + 1)}:{hostName}" if hostName else str(host + 1)
            return cls(choices=choices, read_skip_byte_count=1) if choices and len(choices) > 1 else None


_GESTURE2_GESTURES_LABELS = {
    GestureId.TAP_1_FINGER: (_("Single tap"), _("Performs a left click.")),
    GestureId.TAP_2_FINGER: (_("Single tap with two fingers"), _("Performs a right click.")),
    GestureId.TAP_3_FINGER: (_("Single tap with three fingers"), None),
    GestureId.CLICK_1_FINGER: (None, None),
    GestureId.CLICK_2_FINGER: (None, None),
    GestureId.CLICK_3_FINGER: (None, None),
    GestureId.DOUBLE_TAP_1_FINGER: (_("Double tap"), _("Performs a double click.")),
    GestureId.DOUBLE_TAP_2_FINGER: (_("Double tap with two fingers"), None),
    GestureId.DOUBLE_TAP_3_FINGER: (_("Double tap with three fingers"), None),
    GestureId.TRACK_1_FINGER: (None, None),
    GestureId.TRACKING_ACCELERATION: (None, None),
    GestureId.TAP_DRAG_1_FINGER: (_("Tap and drag"), _("Drags items by dragging the finger after double tapping.")),
    GestureId.TAP_DRAG_2_FINGER: (
        _("Tap and drag with two fingers"),
        _("Drags items by dragging the fingers after double tapping."),
    ),
    GestureId.DRAG_3_FINGER: (_("Tap and drag with three fingers"), None),
    GestureId.TAP_GESTURES: (None, None),
    GestureId.FN_CLICK_GESTURE_SUPPRESSION: (
        _("Suppress tap and edge gestures"),
        _("Disables tap and edge gestures (equivalent to pressing Fn+LeftClick)."),
    ),
    GestureId.SCROLL_1_FINGER: (_("Scroll with one finger"), _("Scrolls.")),
    GestureId.SCROLL_2_FINGER: (_("Scroll with two fingers"), _("Scrolls.")),
    GestureId.SCROLL_2_FINGER_HORIZONTAL: (_("Scroll horizontally with two fingers"), _("Scrolls horizontally.")),
    GestureId.SCROLL_2_FINGER_VERTICAL: (_("Scroll vertically with two fingers"), _("Scrolls vertically.")),
    GestureId.SCROLL_2_FINGER_STATELESS: (_("Scroll with two fingers"), _("Scrolls.")),
    GestureId.NATURAL_SCROLLING: (_("Natural scrolling"), _("Inverts the scrolling direction.")),
    GestureId.THUMBWHEEL: (_("Thumbwheel"), _("Enables the thumbwheel.")),
    GestureId.V_SCROLL_INTERTIA: (None, None),
    GestureId.V_SCROLL_BALLISTICS: (None, None),
    GestureId.SWIPE_2_FINGER_HORIZONTAL: (None, None),
    GestureId.SWIPE_3_FINGER_HORIZONTAL: (None, None),
    GestureId.SWIPE_4_FINGER_HORIZONTAL: (None, None),
    GestureId.SWIPE_3_FINGER_VERTICAL: (None, None),
    GestureId.SWIPE_4_FINGER_VERTICAL: (None, None),
    GestureId.LEFT_EDGE_SWIPE_1_FINGER: (None, None),
    GestureId.RIGHT_EDGE_SWIPE_1_FINGER: (None, None),
    GestureId.BOTTOM_EDGE_SWIPE_1_FINGER: (None, None),
    GestureId.TOP_EDGE_SWIPE_1_FINGER: (_("Swipe from the top edge"), None),
    GestureId.LEFT_EDGE_SWIPE_1_FINGER_2: (_("Swipe from the left edge"), None),
    GestureId.RIGHT_EDGE_SWIPE_1_FINGER_2: (_("Swipe from the right edge"), None),
    GestureId.BOTTOM_EDGE_SWIPE_1_FINGER_2: (_("Swipe from the bottom edge"), None),
    GestureId.TOP_EDGE_SWIPE_1_FINGER_2: (_("Swipe from the top edge"), None),
    GestureId.LEFT_EDGE_SWIPE_2_FINGER: (_("Swipe two fingers from the left edge"), None),
    GestureId.RIGHT_EDGE_SWIPE_2_FINGER: (_("Swipe two fingers from the right edge"), None),
    GestureId.BOTTOM_EDGE_SWIPE_2_FINGER: (_("Swipe two fingers from the bottom edge"), None),
    GestureId.TOP_EDGE_SWIPE_2_FINGER: (_("Swipe two fingers from the top edge"), None),
    GestureId.ZOOM_2_FINGER: (_("Zoom with two fingers."), _("Pinch to zoom out; spread to zoom in.")),
    GestureId.ZOOM_2_FINGER_PINCH: (_("Pinch to zoom out."), _("Pinch to zoom out.")),
    GestureId.ZOOM_2_FINGER_SPREAD: (_("Spread to zoom in."), _("Spread to zoom in.")),
    GestureId.ZOOM_3_FINGER: (_("Zoom with three fingers."), None),
    GestureId.ZOOM_2_FINGER_STATELESS: (_("Zoom with two fingers"), _("Pinch to zoom out; spread to zoom in.")),
    GestureId.TWO_FINGERS_PRESENT: (None, None),
    GestureId.ROTATE_2_FINGER: (None, None),
    GestureId.FINGER_1: (None, None),
    GestureId.FINGER_2: (None, None),
    GestureId.FINGER_3: (None, None),
    GestureId.FINGER_4: (None, None),
    GestureId.FINGER_5: (None, None),
    GestureId.FINGER_6: (None, None),
    GestureId.FINGER_7: (None, None),
    GestureId.FINGER_8: (None, None),
    GestureId.FINGER_9: (None, None),
    GestureId.FINGER_10: (None, None),
    GestureId.DEVICE_SPECIFIC_RAW_DATA: (None, None),
}

_GESTURE2_PARAMS_LABELS = {
    ParamId.EXTRA_CAPABILITIES: (None, None),  # not supported
    ParamId.PIXEL_ZONE: (_("Pixel zone"), None),  # TO DO: replace None with a short description
    ParamId.RATIO_ZONE: (_("Ratio zone"), None),  # TO DO: replace None with a short description
    ParamId.SCALE_FACTOR: (_("Scale factor"), _("Sets the cursor speed.")),
}

_GESTURE2_PARAMS_LABELS_SUB = {
    "left": (_("Left"), _("Left-most coordinate.")),
    "bottom": (_("Bottom"), _("Bottom coordinate.")),
    "width": (_("Width"), _("Width.")),
    "height": (_("Height"), _("Height.")),
    "scale": (_("Scale"), _("Cursor speed.")),
}


class Gesture2Gestures(settings.BitFieldWithOffsetAndMaskSetting):
    name = "gesture2-gestures"
    label = _("Gestures")
    description = _("Tweak the mouse/touchpad behaviour.")
    feature = _F.GESTURE_2
    rw_options = {"read_fnid": 0x10, "write_fnid": 0x20}
    validator_options = {"om_method": hidpp20.Gesture.enable_offset_mask}
    choices_universe = hidpp20_constants.GestureId
    _labels = _GESTURE2_GESTURES_LABELS

    class validator_class(settings_validator.BitFieldWithOffsetAndMaskValidator):
        @classmethod
        def build(cls, setting_class, device, om_method=None):
            options = [g for g in device.gestures.gestures.values() if g.can_be_enabled or g.default_enabled]
            return cls(options, om_method=om_method) if options else None


class Gesture2Divert(settings.BitFieldWithOffsetAndMaskSetting):
    name = "gesture2-divert"
    label = _("Gestures Diversion")
    description = _("Divert mouse/touchpad gestures.")
    feature = _F.GESTURE_2
    rw_options = {"read_fnid": 0x30, "write_fnid": 0x40}
    validator_options = {"om_method": hidpp20.Gesture.diversion_offset_mask}
    choices_universe = hidpp20_constants.GestureId
    _labels = _GESTURE2_GESTURES_LABELS

    class validator_class(settings_validator.BitFieldWithOffsetAndMaskValidator):
        @classmethod
        def build(cls, setting_class, device, om_method=None):
            options = [g for g in device.gestures.gestures.values() if g.can_be_diverted]
            return cls(options, om_method=om_method) if options else None


class Gesture2Params(settings.LongSettings):
    name = "gesture2-params"
    label = _("Gesture params")
    description = _("Change numerical parameters of a mouse/touchpad.")
    feature = _F.GESTURE_2
    rw_options = {"read_fnid": 0x70, "write_fnid": 0x80}
    choices_universe = hidpp20_constants.ParamId
    sub_items_universe = hidpp20.SUB_PARAM
    # item (NamedInt) -> list/tuple of objects that have the following attributes
    # .id (sub-item text), .length (in bytes), .minimum and .maximum

    _labels = _GESTURE2_PARAMS_LABELS
    _labels_sub = _GESTURE2_PARAMS_LABELS_SUB

    class validator_class(settings_validator.MultipleRangeValidator):
        @classmethod
        def build(cls, setting_class, device):
            params = _hidpp20.get_gestures(device).params.values()
            items = [i for i in params if i.sub_params]
            if not items:
                return None
            sub_items = {i: i.sub_params for i in items}
            return cls(items, sub_items)


class MKeyLEDs(settings.BitFieldSetting):
    name = "m-key-leds"
    label = _("M-Key LEDs")
    description = (
        _("Control the M-Key LEDs.")
        + "\n"
        + _("May need Onboard Profiles set to Disable to be effective.")
        + "\n"
        + _("May need G Keys diverted to be effective.")
    )
    feature = _F.MKEYS
    choices_universe = common.NamedInts()
    for i in range(8):
        choices_universe[1 << i] = "M" + str(i + 1)
    _labels = {k: (None, _("Lights up the %s key.") % k) for k in choices_universe}

    class rw_class(settings.FeatureRW):
        def __init__(self, feature):
            super().__init__(feature, write_fnid=0x10)

        def read(self, device):  # no way to read, so just assume off
            return b"\x00"

    class validator_class(settings_validator.BitFieldValidator):
        @classmethod
        def build(cls, setting_class, device):
            number = device.feature_request(setting_class.feature, 0x00)[0]
            options = [setting_class.choices_universe[1 << i] for i in range(number)]
            return cls(options) if options else None


class MRKeyLED(settings.Setting):
    name = "mr-key-led"
    label = _("MR-Key LED")
    description = (
        _("Control the MR-Key LED.")
        + "\n"
        + _("May need Onboard Profiles set to Disable to be effective.")
        + "\n"
        + _("May need G Keys diverted to be effective.")
    )
    feature = _F.MR

    class rw_class(settings.FeatureRW):
        def __init__(self, feature):
            super().__init__(feature, write_fnid=0x00)

        def read(self, device):  # no way to read, so just assume off
            return b"\x00"


## Only implemented for devices that can produce Key and Consumer Codes (e.g., Craft)
## and devices that can produce Key, Mouse, and Horizontal Scroll (e.g., M720)
## Only interested in current host, so use 0xFF for it
class PersistentRemappableAction(settings.Settings):
    name = "persistent-remappable-keys"
    label = _("Persistent Key/Button Mapping")
    description = (
        _("Permanently change the mapping for the key or button.")
        + "\n"
        + _("Changing important keys or buttons (such as for the left mouse button) can result in an unusable system.")
    )
    persist = False  # This setting is persistent in the device so no need to persist it here
    feature = _F.PERSISTENT_REMAPPABLE_ACTION
    keys_universe = special_keys.CONTROL
    choices_universe = special_keys.KEYS

    class rw_class:
        def __init__(self, feature):
            self.feature = feature
            self.kind = settings.FeatureRW.kind

        def read(self, device, key):
            ks = device.remap_keys[device.remap_keys.index(key)]
            return b"\x00\x00" + ks.data_bytes

        def write(self, device, key, data_bytes):
            ks = device.remap_keys[device.remap_keys.index(key)]
            v = ks.remap(data_bytes)
            return v

    class validator_class(settings_validator.ChoicesMapValidator):
        @classmethod
        def build(cls, setting_class, device):
            remap_keys = device.remap_keys
            if not remap_keys:
                return None
            capabilities = device.remap_keys.capabilities
            if capabilities & 0x0041 == 0x0041:  # Key and Consumer Codes
                keys = special_keys.KEYS_KEYS_CONSUMER
            elif capabilities & 0x0023 == 0x0023:  # Key, Mouse, and HScroll Codes
                keys = special_keys.KEYS_KEYS_MOUSE_HSCROLL
            else:
                if logger.isEnabledFor(logging.WARNING):
                    logger.warning("%s: unimplemented Persistent Remappable capability %s", device.name, hex(capabilities))
                return None
            choices = {}
            for k in remap_keys:
                if k is not None:
                    key = special_keys.CONTROL[k.key]
                    choices[key] = keys  # TO RECOVER FROM BAD VALUES use special_keys.KEYS
            return cls(choices, key_byte_count=2, byte_count=4) if choices else None

        def validate_read(self, reply_bytes, key):
            start = self._key_byte_count + self._read_skip_byte_count
            end = start + self._byte_count
            reply_value = common.bytes2int(reply_bytes[start:end]) & self.mask
            # Craft keyboard has a value that isn't valid so fudge these values
            if reply_value not in self.choices[key]:
                if logger.isEnabledFor(logging.WARNING):
                    logger.warning("unusual persistent remappable action mapping %x: use Default", reply_value)
                reply_value = special_keys.KEYS_Default
            return reply_value


class Sidetone(settings.Setting):
    name = "sidetone"
    label = _("Sidetone")
    description = _("Set sidetone level.")
    feature = _F.SIDETONE
    validator_class = settings_validator.RangeValidator
    min_value = 0
    max_value = 100


class Equalizer(settings.RangeFieldSetting):
    name = "equalizer"
    label = _("Equalizer")
    description = _("Set equalizer levels.")
    feature = _F.EQUALIZER
    rw_options = {"read_fnid": 0x20, "write_fnid": 0x30, "read_prefix": b"\x00"}
    keys_universe = []

    class validator_class(settings_validator.PackedRangeValidator):
        @classmethod
        def build(cls, setting_class, device):
            data = device.feature_request(_F.EQUALIZER, 0x00)
            if not data:
                return None
            count, dbRange, _x, dbMin, dbMax = struct.unpack("!BBBBB", data[:5])
            if dbMin == 0:
                dbMin = -dbRange
            if dbMax == 0:
                dbMax = dbRange
            map = common.NamedInts()
            for g in range((count + 6) // 7):
                freqs = device.feature_request(_F.EQUALIZER, 0x10, g * 7)
                for b in range(7):
                    if g * 7 + b >= count:
                        break
                    map[g * 7 + b] = str(int.from_bytes(freqs[2 * b + 1 : 2 * b + 3], "big")) + _("Hz")
            return cls(map, min_value=dbMin, max_value=dbMax, count=count, write_prefix_bytes=b"\x02")


class ADCPower(settings.Setting):
    name = "adc_power_management"
    label = _("Power Management")
    description = _("Power off in minutes (0 for never).")
    feature = _F.ADC_MEASUREMENT
    min_version = 2  # documentation for version 1 does not mention this capability
    rw_options = {"read_fnid": 0x10, "write_fnid": 0x20}
    validator_class = settings_validator.RangeValidator
    min_value = 0x00
    max_value = 0xFF
    validator_options = {"byte_count": 1}


class HeadsetEcoMode(settings.Setting):
    name = "headset-eco-mode"
    label = _("Eco Mode")
    description = _("Battery saver mode.")
    feature = _F.HEADSET_BATTERY_SAVER
    validator_class = settings_validator.BooleanValidator

    @classmethod
    def build(cls, device):
        # G522 firmware rejects no-op writes with device-specific NACK 0x0B.
        # BooleanValidator.prepare_write already skips writes that match the
        # current value when needs_current_value=True; default-mask (0xFF)
        # BooleanValidators get needs_current_value=False, so flip it here.
        rw = settings.FeatureRW(cls.feature)
        validator = settings_validator.BooleanValidator()
        validator.needs_current_value = True
        return cls(device, rw, validator)


class HeadsetDoNotDisturb(settings.Setting):
    name = "headset-do-not-disturb"
    label = _("Do Not Disturb")
    description = _("Suppress notification sounds.")
    feature = _F.HEADSET_DO_NOT_DISTURB
    validator_class = settings_validator.BooleanValidator


class HeadsetMicMute(settings.Setting):
    name = "headset-mic-mute"
    label = _("Mic Mute")
    description = _("Mute the microphone.")
    feature = _F.HEADSET_MIC_MUTE
    validator_class = settings_validator.BooleanValidator
    # HEADSET_MIC_MUTE (0x0601) doesn't follow the typical fn 0 GetState /
    # fn 1 SetState pattern that BooleanValidator defaults to. Function
    # layout (confirmed via G HUB pcap on G522):
    #   fn 0 — physical-mute-switch state-change events from the device
    #   fn 1 — state-change events emitted as the device's echo of a
    #          host-driven SetState; also serves as the host-callable
    #          GetState read
    #   fn 2 — host-callable SetState (single byte: 0=unmuted, 1=muted)
    # The standard fn 0/1 write path returns 0x0A UNSUPPORTED. State-change
    # events from both fn 0 and fn 1 are handled by _process_feature_notification
    # so the toggle reflects physical mute presses too.
    rw_options = {"read_fnid": 0x10, "write_fnid": 0x20}


class HeadsetMicSNR(settings.Setting):
    name = "headset-mic-snr"
    label = _("Mic SNR")
    description = _("Microphone signal-to-noise ratio enhancement.")
    feature = _F.HEADSET_MIC_SNR
    validator_class = settings_validator.BooleanValidator


class HeadsetAINR(settings.Setting):
    name = "headset-ai-nr"
    label = _("AI Noise Reduction")
    description = _("Enable AI noise reduction.")
    feature = _F.HEADSET_AI_NOISE_REDUCTION
    validator_class = settings_validator.BooleanValidator


class HeadsetAINRLevel(settings.Setting):
    name = "headset-ai-nr-level"
    label = _("AI Noise Reduction Level")
    description = _("AI noise reduction intensity.")
    feature = _F.HEADSET_AI_NOISE_REDUCTION
    rw_options = {"read_fnid": 0x20, "write_fnid": 0x30}
    validator_class = settings_validator.ChoicesValidator
    choices_universe = common.NamedInts(Off=0, Low=1, Medium=2, High=3)


class HeadsetSidetone(settings.Setting):
    name = "headset-sidetone"
    label = _("Headset Sidetone")
    description = _("Sidetone level (0 = off, 100 = max).")
    feature = _F.HEADSET_AUDIO_SIDETONE
    rw_options = {"read_fnid": 0x00, "write_fnid": 0x10}
    min_value = 0
    max_value = 100

    class validator_class(settings_validator.RangeValidator):
        """UI value is 0-100 percent; the wire level is a gain-step index
        0..N-1. N (gain_steps) comes from getSidetoneLevelSettings on V2
        devices, or defaults to 101 on V1 — which makes step == percent, so
        V1 round-trips unchanged. The firmware silently ignores out-of-range
        step writes, so writes are clamped to N-1."""

        gain_steps = 101

        def _level_bytes(self, raw):
            return common.bytes2int(raw[self.read_skip_byte_count : self.read_skip_byte_count + self._byte_count])

        def validate_read(self, reply_bytes):
            level = self._level_bytes(reply_bytes)
            steps = self.gain_steps
            return int(round(level * 100 / (steps - 1))) if steps > 1 else level

        def prepare_write(self, new_value, current_value=None):
            steps = self.gain_steps
            level = int(round((steps - 1) * new_value / 100)) if steps > 1 else new_value
            level = max(0, min((steps - 1) if steps > 1 else self.max_value, level))
            to_write = self.write_prefix_bytes + common.int2bytes(level, self._byte_count)
            if current_value is not None and self._level_bytes(current_value) == level:
                return None
            return to_write

    @classmethod
    def build(cls, device):
        # Version <= 1: GetSidetone returns [mic_count, mic_id, level]; SetSidetone takes [mic_id, level]
        # Version > 1: GetSidetone returns [mic_count, mic_id, reserved, level]; SetSidetone takes [mic_id, 0xFF, level]
        version = device.features.get_feature_version(cls.feature) or 0
        if version > 1:
            skip, prefix = 3, b"\x01\xff"
        else:
            skip, prefix = 2, b"\x01"
        # V2 getSidetoneLevelSettings (fn 2) reply byte 2 is the gain-step count N.
        # V1 has no such call — N stays 101 (step == percent). Raw reply still
        # logged at debug so a G HUB setpoint correlation can refine the layout.
        gain_steps = 101
        if version > 1:
            try:
                reply = device.feature_request(cls.feature, 0x20)
            except Exception as e:
                reply = None
                logger.debug("%s: getSidetoneLevelSettings probe raised %s", cls.name, e)
            logger.debug("%s: getSidetoneLevelSettings raw reply: %s", cls.name, reply.hex() if reply else reply)
            if reply is not None and len(reply) >= 3 and reply[2] > 1:
                gain_steps = reply[2]
        rw = settings.FeatureRW(cls.feature, **cls.rw_options)
        validator = cls.validator_class.build(cls, device, read_skip_byte_count=skip, write_prefix_bytes=prefix)
        if validator:
            validator.gain_steps = gain_steps
            return cls(device, rw, validator)


class HeadsetMicGain(settings.Setting):
    name = "headset-mic-gain"
    label = _("Mic Gain")
    description = _("Microphone gain level.")
    feature = _F.HEADSET_MIC_GAIN
    rw_options = {"read_fnid": 0x10, "write_fnid": 0x20}
    validator_class = settings_validator.RangeValidator
    # Fallback range covers int8; build() overrides with device-reported bounds
    # from GetInfo (fn 0) so SetMicGain doesn't get device-specific
    # out-of-range NACK (error 0x0B) on devices that use a small signed range
    # (e.g. G522 reports a narrow window like -12..+12).
    min_value = -128
    max_value = 127
    validator_options = {"byte_count": 1, "signed": True}

    @classmethod
    def build(cls, device):
        # GetInfo (function 0) returns [min_gain (int8), max_gain (int8)].
        # Query once at build time so the slider range reflects the device's
        # actual supported range rather than a generic int8 window.
        try:
            info = device.feature_request(cls.feature, 0x00)
        except Exception as e:
            logger.debug("HeadsetMicGain: GetInfo raised %s, using fallback int8 range", e)
            info = None
        if info and len(info) >= 2:
            min_gain = struct.unpack("b", bytes([info[0]]))[0]
            max_gain = struct.unpack("b", bytes([info[1]]))[0]
            if max_gain <= min_gain:  # sanity — fall back to class defaults
                logger.debug(
                    "HeadsetMicGain: GetInfo returned nonsense range [%d, %d] (hex=%s), using fallback int8 range",
                    min_gain,
                    max_gain,
                    info.hex(),
                )
                min_gain, max_gain = cls.min_value, cls.max_value
            elif logger.isEnabledFor(logging.DEBUG):
                logger.debug(
                    "HeadsetMicGain: device reports gain range [%d, %d]",
                    min_gain,
                    max_gain,
                )
        else:
            logger.debug(
                "HeadsetMicGain: GetInfo returned %s, using fallback int8 range",
                info.hex() if info else info,
            )
            min_gain, max_gain = cls.min_value, cls.max_value
        rw = settings.FeatureRW(cls.feature, **cls.rw_options)
        validator = settings_validator.RangeValidator(min_value=min_gain, max_value=max_gain, byte_count=1, signed=True)
        return cls(device, rw, validator)


class HeadsetMixBalance(settings.Setting):
    name = "headset-mix-balance"
    label = _("Audio Mix Balance")
    description = _("Balance between game and chat audio.")
    feature = _F.HEADSET_MIX
    validator_class = settings_validator.RangeValidator
    min_value = 0
    max_value = 255
    validator_options = {"byte_count": 1}


class _AutoSleepRangeValidator(settings_validator.RangeValidator):
    """Single-slot read-modify-write validator for HID++ 0x0108 AutoSleep.

    0x0108 is not a single timer: V3 has two uint8 bytes, V4+ has three. Each
    byte is an independent timer slot. Solaar exposes only the user-facing slot
    today and preserves the others via RMW; writing zero into the other slots
    causes the firmware to reject the request.

    Wire byte layout per feature version:
      V<3: [timer]
      V3:  [reserved, timer]            — preserve byte[0]
      V4+: [timer_a, timer_b, timer_c]  — preserve byte[1], byte[2]
    """

    def __init__(self, byte_count, **kwargs):
        super().__init__(byte_count=byte_count, **kwargs)
        # V3 sources the user-controllable timer from byte[1] per LGHUB.
        self._slot = 1 if byte_count == 2 else 0

    def validate_read(self, reply_bytes):
        if len(reply_bytes) <= self._slot:
            raise AssertionError(
                f"{self.__class__.__name__}: read returned {len(reply_bytes)} bytes, expected ≥ {self._slot + 1}"
            )
        return reply_bytes[self._slot]

    def prepare_write(self, new_value, current_value=None):
        if new_value < self.min_value or new_value > self.max_value:
            raise ValueError(f"invalid choice {new_value!r}")
        if current_value is None:
            payload = bytearray(self._byte_count)
        else:
            payload = bytearray(current_value[: self._byte_count])
            if len(payload) < self._byte_count:
                payload.extend(b"\x00" * (self._byte_count - len(payload)))
        if payload[self._slot] == new_value:
            return None
        payload[self._slot] = new_value
        return bytes(payload)


class HeadsetAutoSleep(settings.Setting):
    name = "headset-auto-sleep"
    label = _("Auto Sleep Timeout")
    description = _("Idle time in minutes before the headset enters sleep mode (0 = disabled).")
    feature = _F.CENTURION_AUTO_SLEEP
    rw_options = {"read_fnid": 0x00, "write_fnid": 0x10}
    validator_class = _AutoSleepRangeValidator
    min_value = 0
    max_value = 255  # uint8 slot
    validator_options = {"byte_count": 1}

    @classmethod
    def build(cls, device):
        version = device.features.get_feature_version(cls.feature) or 0
        if version >= 4:
            byte_count = 3
        elif version >= 3:
            byte_count = 2
        else:
            byte_count = 1
        rw = settings.FeatureRW(cls.feature, **cls.rw_options)
        validator = _AutoSleepRangeValidator(min_value=0, max_value=cls.max_value, byte_count=byte_count)
        return cls(device, rw, validator)


class HeadsetOnboardEQ(settings.RangeFieldSetting):
    name = "headset-onboard-eq"
    label = _("Headset Equalizer")
    description = _("Set equalizer levels.")
    feature = _F.HEADSET_ONBOARD_EQ
    rw_options = {"read_fnid": 0x10, "write_fnid": 0x20, "read_prefix": b"\x00"}
    keys_universe = []

    class validator_class(settings_validator.PackedRangeValidator):
        kind = settings.Kind.GRAPHIC_EQ

        @classmethod
        def build(cls, setting_class, device):
            info = hidpp20.get_onboard_eq_info(device)
            if not info:
                logger.debug("HeadsetOnboardEQ.build: getEQInfo failed, no panel will be built")
                return None
            _has_hw_eq, num_bands = info
            bands = hidpp20.get_onboard_eq_params(device, slot=0x00)
            if not bands:
                logger.debug("HeadsetOnboardEQ.build: getEQParameters returned no bands, no panel will be built")
                return None
            if len(bands) != num_bands:
                logger.debug(
                    "HeadsetOnboardEQ.build: band count mismatch — EQInfo=%d getEQParameters=%d; skipping",
                    num_bands,
                    len(bands),
                )
                return None
            keys = common.NamedInts()
            for i, (freq, _gain, _q) in enumerate(bands):
                keys[i] = str(freq) + _("Hz")
            v = cls(keys, min_value=-12, max_value=12, count=num_bands, byte_count=1)
            v._band_freqs = [freq for freq, _g, _q in bands]
            v._band_qs = [q for _f, _g, q in bands]
            logger.debug("HeadsetOnboardEQ.build: panel built with %d band(s)", num_bands)
            return v

        def validate_read(self, reply_bytes):
            if reply_bytes is None or len(reply_bytes) < 2:
                return {}
            band_count = reply_bytes[1]
            result = {}
            offset = 2
            for i in range(band_count):
                if offset + 4 > len(reply_bytes):
                    break
                freq = struct.unpack(">H", reply_bytes[offset : offset + 2])[0]
                gain = struct.unpack("b", bytes([reply_bytes[offset + 2]]))[0]
                q = reply_bytes[offset + 3]
                result[i] = gain
                # Update stored freq/Q arrays if they exist
                if hasattr(self, "_band_freqs") and i < len(self._band_freqs):
                    self._band_freqs[i] = freq
                if hasattr(self, "_band_qs") and i < len(self._band_qs):
                    self._band_qs[i] = q
                offset += 4
            return result

        def prepare_write(self, new_values):
            if not hasattr(self, "_band_freqs") or not hasattr(self, "_band_qs"):
                return None
            bands = []
            for i in range(self.count):
                freq = self._band_freqs[i] if i < len(self._band_freqs) else 1000
                q = self._band_qs[i] if i < len(self._band_qs) else 10
                gain = new_values.get(i, 0)
                bands.append((freq, gain, q))
            self._pending_bands = bands  # stash for persist step
            return hidpp20._build_set_eq_payload(0x00, bands)

    def write(self, map, save=True):
        result = super().write(map, save)
        # Also persist to device flash (slot 0x80) so EQ survives power cycle
        if result is not None and hasattr(self._validator, "_pending_bands"):
            bands = self._validator._pending_bands
            del self._validator._pending_bands
            try:
                self._device.feature_request(_F.HEADSET_ONBOARD_EQ, 0x20, hidpp20._build_set_eq_payload(0x80, bands))
            except Exception:
                logger.warning("HeadsetOnboardEQ: failed to persist EQ to slot 0x80")
        return result


class HeadsetAdvancedEQ(settings.RangeFieldSetting):
    """Per-band gain editor for the headset's active AdvancedParaEQ (0x020D) slot.

    V2 wire format (pcap-verified against G522 LIGHTSPEED):
      getCustomEQ  response: [dir_echo] + N × [freq_hi, freq_lo, filter, gain_hi, gain_lo]
      setCustomEQ  request:  [dir, slot, pad=0] + N × [freq_hi, freq_lo, filter, gain_hi, gain_lo]
    Gain is offset-binary against gain_min..gain_max with `gain_steps`
    discrete positions (raw=120 ≈ 0 dB on G522's [-6, +6] / 241-step
    grid). Frequency and filter type are read at build time and not
    user-editable today — UI only exposes per-band gain.
    """

    name = "headset-advanced-eq"
    label = _("Headset Advanced EQ")
    description = _("Per-band gain for the headset's active parametric EQ.")
    feature = _F.HEADSET_ADVANCED_PARA_EQ
    rw_options = {"read_fnid": 0x10, "write_fnid": 0x20}
    keys_universe = []

    class rw_class(settings.FeatureRW):
        """get/setCustomEQ both take [direction, slot]; on writes the
        device additionally expects a single 0x00 padding byte before
        the band payload. The slot is the *active* EQ preset, which the
        device may have switched while we weren't looking — re-query it
        on every read and write instead of caching at build time.
        Direction is hardcoded to 0 (playback); mic-side EQ isn't
        exposed yet.
        """

        def read(self, device, data_bytes=b""):
            active_slot = hidpp20.get_advanced_eq_active_slot(device, direction=0)
            self.read_prefix = bytes([0, active_slot if active_slot is not None else 0])
            return super().read(device, data_bytes)

        def write(self, device, data_bytes):
            active_slot = hidpp20.get_advanced_eq_active_slot(device, direction=0)
            slot = active_slot if active_slot is not None else 0
            write_bytes = bytes([0, slot, 0]) + data_bytes
            return device.feature_request(self.feature, self.write_fnid, write_bytes)

    class validator_class(settings_validator.PackedRangeValidator):
        kind = settings.Kind.GRAPHIC_EQ

        @classmethod
        def build(cls, setting_class, device):
            info = hidpp20.get_advanced_eq_info(device)
            if not info:
                logger.debug("HeadsetAdvancedEQ.build: getEQInfos failed, no panel will be built")
                return None
            device._advanced_eq_info = info
            version = info["version"]
            gain_min = info["gain_min_db"]
            gain_max = info["gain_max_db"]
            step_db = info["step_db"]

            active_slot = hidpp20.get_advanced_eq_active_slot(device, direction=0) or 0
            bands = hidpp20.get_advanced_eq_params(device, direction=0, slot=active_slot)
            if not bands:
                logger.debug("HeadsetAdvancedEQ.build: getCustomEQ returned no bands, no panel will be built")
                return None
            band_count = len(bands)
            expected = info.get("band_count")
            if expected is not None and expected != band_count:
                logger.debug(
                    "HeadsetAdvancedEQ.build: V%d band count mismatch — EQInfos=%d getCustomEQ=%d; trusting getCustomEQ",
                    version,
                    expected,
                    band_count,
                )

            keys = common.NamedInts()
            for i, (filter_type, freq_hz, _gain_db) in enumerate(bands):
                if filter_type == hidpp20.FILTER_TYPE_HP:
                    keys[i] = "HP " + str(freq_hz) + _("Hz")
                else:
                    keys[i] = str(freq_hz) + _("Hz")
            v = cls(
                keys,
                min_value=int(round(gain_min)),
                max_value=int(round(gain_max)),
                count=band_count,
                byte_count=1,
            )
            v._version = version
            v._step_db = step_db
            v._gain_min = gain_min
            v._gain_max = gain_max
            v._gain_steps = info.get("gain_steps", 241)
            v._band_types = [band[0] for band in bands]
            v._band_freqs = [band[1] for band in bands]
            v._active_slot = active_slot
            logger.debug(
                "HeadsetAdvancedEQ.build: panel built V%d with %d band(s), slot=%d, range=[%d,%d], step_db=%.4f",
                version,
                band_count,
                active_slot,
                gain_min,
                gain_max,
                step_db,
            )
            # One-shot per-slot probe — logs band data for each slot the
            # firmware actually honors and caches the working-slot list on
            # `device._advanced_eq_working_slots`. Cheap if HeadsetActiveEQPreset
            # already populated the cache (it usually has at this point);
            # otherwise this is the first-time probe.
            if version >= 2:
                try:
                    hidpp20.probe_advanced_eq_slots(device, direction=0, info=info)
                except Exception as e:
                    logger.debug("HeadsetAdvancedEQ.build: preset corpus probe failed: %s", e)
            return v

        def validate_read(self, reply_bytes):
            if reply_bytes is None:
                return {}
            version = getattr(self, "_version", 0)
            if version >= 2:
                info = {
                    "gain_min_db": getattr(self, "_gain_min", -6),
                    "gain_max_db": getattr(self, "_gain_max", 6),
                    "gain_steps": getattr(self, "_gain_steps", 241),
                    "step_db": getattr(self, "_step_db", 0.05),
                }
                bands = hidpp20.parse_v2_bands(reply_bytes, info)
                if bands is None:
                    return {}
                result = {}
                for i, (filter_type, freq_hz, gain_db) in enumerate(bands):
                    if i >= self.count:
                        break
                    result[i] = int(round(gain_db))
                    if hasattr(self, "_band_types") and i < len(self._band_types):
                        self._band_types[i] = filter_type
                    if hasattr(self, "_band_freqs") and i < len(self._band_freqs):
                        self._band_freqs[i] = freq_hz
                return result
            # V0/V1: 3-byte stride.
            result = {}
            offset = 0
            i = 0
            while offset + 3 <= len(reply_bytes) and i < self.count:
                freq = struct.unpack(">H", reply_bytes[offset : offset + 2])[0]
                if freq == 0:
                    break
                gain = struct.unpack("b", bytes([reply_bytes[offset + 2]]))[0]
                result[i] = gain
                if hasattr(self, "_band_freqs") and i < len(self._band_freqs):
                    self._band_freqs[i] = freq
                offset += 3
                i += 1
            return result

        def prepare_write(self, new_values):
            """Encode N × [freq_hi, freq_lo, filter, gain_hi, gain_lo].

            new_values is {band_idx: int_gain_dB}. freq and filter type
            come from the cache captured at build time; gain is mapped
            from integer dB back to the device's offset-binary raw u16
            against the [_gain_min, _gain_max] / _gain_steps grid.
            """
            version = getattr(self, "_version", 0)
            if version < 2:
                return None
            gain_min = getattr(self, "_gain_min", -6)
            gain_max = getattr(self, "_gain_max", 6)
            steps = getattr(self, "_gain_steps", 241)
            freqs = getattr(self, "_band_freqs", None) or []
            types = getattr(self, "_band_types", None) or []
            if not freqs or not types:
                return None
            span = gain_max - gain_min
            payload = bytearray()
            for i in range(self.count):
                freq = freqs[i] if i < len(freqs) else 0
                filt = types[i] if i < len(types) else hidpp20.FILTER_TYPE_PEAKING_G522
                gain_db = new_values.get(i, 0)
                if steps > 1 and span > 0:
                    raw = int(round((gain_db - gain_min) / span * (steps - 1)))
                else:
                    raw = 0
                raw = max(0, min(steps - 1, raw))
                payload += bytes([(freq >> 8) & 0xFF, freq & 0xFF, filt & 0xFF, (raw >> 8) & 0xFF, raw & 0xFF])
            return bytes(payload)

    def write(self, map, save=True):
        # RangeFieldSetting.write treats an empty-bytes reply (`not reply`)
        # as failure, but setCustomEQ returns an empty ACK on success.
        # Override to treat only `reply is None` (transport error/timeout)
        # as failure.
        assert hasattr(self, "_value")
        assert hasattr(self, "_device")
        assert map is not None
        if self._device.online:
            self.update(map, save)
            data_bytes = self._validator.prepare_write(self._value)
            if data_bytes is not None:
                reply = self._rw.write(self._device, data_bytes)
                if reply is None:
                    return None
            return map

    def _is_valid_persisted_value(self, value):
        """True iff `value` is a well-formed band-gain dict for the current
        validator: a dict with exactly `count` int keys covering [0, count),
        each mapped to an int within [min_value, max_value]. Used to detect
        stale persister entries from older Solaar builds whose V2 parser had
        a different stride/header (commits prior to 7c73c888) and produced
        partial dicts or out-of-range gain values."""
        validator = getattr(self, "_validator", None)
        if not isinstance(value, dict) or validator is None:
            return False
        count = getattr(validator, "count", 0)
        if count == 0 or len(value) != count:
            return False
        mn = getattr(validator, "min_value", None)
        mx = getattr(validator, "max_value", None)
        if mn is None or mx is None:
            return False
        for i in range(count):
            if i not in value:
                return False
            v = value[i]
            if not isinstance(v, int) or v < mn or v > mx:
                return False
        return True

    def apply(self):
        """Validate the persisted EQ against the live device state before
        pushing. Setting.apply uses cached=True so the persister is treated
        as authoritative — that's wrong here because (a) the EQ can be
        changed externally (LGHUB, onboard preset buttons) and (b) older
        Solaar V2 parsers stored partial/out-of-range dicts that
        prepare_write silently fills with 0 dB, overwriting user EQ with
        zeros. Strategy: if the persisted value is well-formed, apply it
        normally (matches existing Solaar semantics). If it's corrupt,
        treat the device's live read as truth and reseed the persister
        from it without writing back. If both are invalid, skip this
        setting only — apply_all_settings keeps going."""
        assert hasattr(self, "_value")
        assert hasattr(self, "_device")
        if not self._device.online:
            return
        persister = getattr(self._device, "persister", None)
        persisted = persister.get(self.name) if persister else None
        persisted_valid = self._is_valid_persisted_value(persisted)
        try:
            live = self.read(cached=False)
        except Exception as e:
            logger.warning("%s: live EQ read failed during apply (%s): %s", self.name, self._device, repr(e))
            live = None
        live_valid = self._is_valid_persisted_value(live)
        if persisted_valid:
            try:
                self.write(persisted, save=False)
            except Exception as e:
                logger.warning("%s: error applying %s (%s): %s", self.name, persisted, self._device, repr(e))
        elif live_valid:
            logger.info(
                "%s: rejecting stale persister value %r; reseeding from device live %r",
                self.name,
                persisted,
                live,
            )
            self._value = live
            if persister is not None:
                persister[self.name] = live
        else:
            logger.warning(
                "%s: both persisted (%r) and live (%r) values invalid; skipping apply",
                self.name,
                persisted,
                live,
            )


class HeadsetActiveEQPreset(settings.Setting):
    """Choose which AdvancedParaEQ slot drives live audio.

    Activation works for any slot — read-only factory presets and
    user-custom slots alike. The "(factory)" tag in the slot label
    distinguishes the read-only ones; that distinction matters for
    band-editing (not supported yet), not for activation today.
    """

    name = "headset-eq-active-preset"
    label = _("EQ Preset")
    description = _("Switch the active EQ preset. Factory presets are read-only.")
    feature = _F.HEADSET_ADVANCED_PARA_EQ
    rw_options = {"read_fnid": 0x30, "write_fnid": 0x40, "prefix": b"\x00"}
    validator_class = settings_validator.ChoicesValidator

    @classmethod
    def build(cls, device):
        info = getattr(device, "_advanced_eq_info", None) or hidpp20.get_advanced_eq_info(device)
        if not info:
            return None
        ro_count = info.get("onboard_ro_preset_count", 0) or 0
        # Probe each advertised slot — getEQInfos may report capacity that
        # the firmware doesn't actually back (G522 advertises 16 slots but
        # only honors slot 0). Only include slots that responded with band
        # data; the result is cached on device._advanced_eq_working_slots
        # so HeadsetAdvancedEQ.build can reuse it without re-probing.
        working = hidpp20.probe_advanced_eq_slots(device, direction=0, info=info)
        if len(working) <= 1:
            # One option (or zero) is meaningless as a selector — there's
            # nothing for the user to choose between. The active EQ is
            # whatever slot 0 has, no preset switching is available.
            return None
        choices = common.NamedInts()
        for slot, slot_name, _bands in working:
            if not slot_name:
                slot_name = _("Slot") + " " + str(slot)
            if slot < ro_count:
                slot_name = slot_name + " " + _("(factory)")
            choices[slot] = slot_name
        rw = settings.FeatureRW(cls.feature, **cls.rw_options)
        validator = settings_validator.ChoicesValidator(choices=choices)
        return cls(device, rw, validator)

    def write(self, value, save=True):
        result = super().write(value, save)
        if result is not None:
            # After setActiveEQ, repopulate the AdvancedParaEQ band-display
            # cache so the panel reflects the newly-active slot. Force a
            # fresh read so _value is a real dict — leaving it as None
            # would let a UI band-click hit `_value[item]` on None and
            # crash (config_panel.py:589 'NoneType' is not subscriptable).
            # The visible widget redraw still waits for a manual refresh /
            # panel reopen — auto-redraw would need UI-side plumbing.
            eq_panel = _headset_setting_by_name(self._device, HeadsetAdvancedEQ.name)
            if eq_panel is not None:
                try:
                    eq_panel._value = None
                    eq_panel.read(cached=False)
                except Exception as e:
                    logger.debug("HeadsetActiveEQPreset: failed to refresh EQ panel: %s", e)
        return result


_NO_CHANGE_COLOR = int(special_keys.COLORSPLUS["No change"])


def _headset_setting_by_name(device, name):
    for s in getattr(device, "settings", None) or []:
        if getattr(s, "name", None) == name:
            return s
    return None


def _headset_primary_color(device, default=0xFFFFFF):
    """The headset's base color — the 0x0621 onboard Fixed-effect color.
    Per-zone 'No change' cells resolve against this. Returns `default` when
    the onboard-effect setting is absent or not currently on Fixed."""
    s = _headset_setting_by_name(device, HeadsetOnboardEffect.name)
    value = getattr(s, "_value", None) if s is not None else None
    if value is not None and int(getattr(value, "ID", -1)) == 0:
        return int(getattr(value, "color1", default))
    return default


def _headset_cluster_effect_is_fixed(device):
    """True when the 0x0621 onboard effect is Fixed (the Static analog), or
    when the device has no onboard-effect setting. A non-Fixed cluster
    animation masks the per-zone buffer, so per-zone writes are suppressed
    while one runs."""
    s = _headset_setting_by_name(device, HeadsetOnboardEffect.name)
    if s is None:
        return True
    value = getattr(s, "_value", None)
    if value is None:
        persister = getattr(device, "persister", None)
        value = persister.get(HeadsetOnboardEffect.name) if persister else None
    if value is None:
        return True
    return int(getattr(value, "ID", 0)) == 0


def _headset_per_zone_overrides(device):
    """Return `{zone_id: color_int}` for zones with explicit (non-'No change')
    colors set via the Per-zone Lighting setting, or `None` if the setting
    isn't built/present."""
    s = _headset_setting_by_name(device, HeadsetPerZoneLighting.name)
    if s is None:
        return None
    value = getattr(s, "_value", None)
    if not isinstance(value, dict):
        return None
    overrides = {}
    for zone, color in value.items():
        try:
            color_int = int(color)
        except (TypeError, ValueError):
            continue
        if color_int != _NO_CHANGE_COLOR:
            overrides[int(zone)] = color_int
    return overrides


def _headset_reassert_zone_layer(device):
    """Re-paint the per-zone layer: every zone to the LEDs Primary color,
    then the explicit per-zone overrides on top.

    The headset firmware drops the host-painted per-zone buffer whenever a
    cluster layer is (re)written — so any path that re-asserts a cluster
    layer (LED Control re-claim, onboard Static color change) must call this
    to restore the per-zone paint. No-op unless the onboard effect is Fixed;
    a non-Static animation owns the LEDs and masks per-zone anyway.
    """
    if not _headset_cluster_effect_is_fixed(device):
        return
    zones = headset_rgb.discover_zones(device)
    if not zones:
        return
    zone_map = {int(z): _headset_primary_color(device) for z in zones}
    zone_map.update(_headset_per_zone_overrides(device) or {})
    headset_rgb.write_zone_map(device, zone_map)


def _headset_led_control_on(device):
    """True when the headset LED Control is on (Solaar drives the LEDs).
    When off, the firmware owns the LEDs and host color writes are
    suppressed — the value is still persisted so it re-applies on switch-on.
    Reads setting._value first, then the persister; accepts a bool or a
    legacy int 0/1 from the old ChoicesValidator era."""
    s = _headset_setting_by_name(device, HeadsetLEDControl.name)
    v = getattr(s, "_value", None) if s is not None else None
    if v is None:
        persister = getattr(device, "persister", None)
        v = persister.get(HeadsetLEDControl.name) if persister else None
    if v is None:
        return True  # unknown — don't suppress
    return bool(v)


class HeadsetLEDControl(settings.Setting):
    """Whether Solaar holds the headset's live-coloring claim.

    Mirrors the `RGBControl` pattern for keyboards and mice. On = Solaar
    may drive the LEDs — the 0x0621 onboard effect and 0x0620 per-zone
    painting are both live LED control; off = Solaar releases the LEDs so
    another app (e.g. OpenRGB) can drive them. The 0x0622 signature
    effects are stored settings (startup/shutdown colors), not live
    coloring, and stay editable either way.
    """

    name = "headset_led_control"
    label = _("LED Control")
    description = _("Allow Solaar to control the headset LED zones.")
    feature = _F.HEADSET_RGB_HOSTMODE
    rw_options = {"read_fnid": 0x70, "write_fnid": 0x80}
    # Two-state — render as a Gtk.Switch. Wire byte: 1 = Solaar (host) control,
    # 0 = Device (firmware) control.
    validator_class = settings_validator.BooleanValidator
    validator_options = {"true_value": 1, "false_value": 0}

    def _pre_read(self, cached, key=None):
        # Migrate legacy int values (0/1 from the old ChoicesValidator) to bool.
        super()._pre_read(cached, key)
        if isinstance(self._value, int) and not isinstance(self._value, bool):
            self._value = self._value != 0

    @classmethod
    def build(cls, device):
        # One-shot read-only probe of 0x0621 / 0x0622 — logs the data the RE
        # pass needs to pin down RGB onboard/signature effect structures.
        # Skip cleanly if neither feature is exposed.
        try:
            rgb_effects_probe.probe(device)
        except Exception as e:
            logger.debug("RGB effects probe raised %r", e)
        return super().build(device)

    def write(self, value, save=True):
        # On re-claim the firmware drops our colors; reassert the dominant
        # layer — per-zone when the onboard effect is Static, else the effect.
        result = super().write(value, save)
        if result is not None and value and self._device.online:
            if _headset_cluster_effect_is_fixed(self._device):
                _headset_reassert_zone_layer(self._device)
            else:
                onboard = next((s for s in self._device.settings if s.name == "headset-onboard-effect"), None)
                if onboard is not None and onboard._value is not None:
                    onboard.write(onboard._value, save=False)
        return result


class HeadsetPerZoneLighting(settings.Settings):
    """Per-zone LED color overrides.

    Mirrors `PerKeyLighting` — keys are firmware zone IDs, values are
    24-bit RGB ints with the `-1` sentinel meaning "inherit the current
    `LEDs Primary` color." Surfaces in the UI via the per-key painter.
    """

    name = "headset_per_zone_lighting"
    label = _("Per-zone Lighting")
    description = _(
        "Override individual zone colors. 'No change' inherits the LEDs Primary color.\n"
        "LED Control needs to be set to Solaar to be effective."
    )
    feature = _F.HEADSET_RGB_HOSTMODE
    persist = True
    editor_class = "solaar.ui.perkey.control:PerKeyControl"

    class rw_class(settings.FeatureRWMap):
        pass

    class validator_class(settings_validator.MapRangeValidator):
        _COLOR_RANGE = settings_validator.Range(min=0, max=0xFFFFFF, byte_count=3)

        @classmethod
        def build(cls, setting_class, device):
            zones = headset_rgb.discover_zones(device)
            if not zones:
                return None
            choices_map = {common.NamedInt(int(z), _("Zone") + " " + str(int(z))): cls._COLOR_RANGE for z in zones}
            return cls(choices_map) if choices_map else None

    def read(self, cached=True):
        self._pre_read(cached)
        if cached and self._value is not None:
            return self._value
        # Device doesn't expose current per-zone state; default every
        # zone to "No change" so the primary color shows through.
        reply_map = {int(key): _NO_CHANGE_COLOR for key in self._validator.choices}
        self._value = reply_map
        return reply_map

    def _resolve_zone_map(self, map_, primary):
        """Substitute 'No change' entries with the primary color."""
        resolved = {}
        for key, value in map_.items():
            try:
                v = int(value)
            except (TypeError, ValueError):
                continue
            resolved[int(key)] = primary if v == _NO_CHANGE_COLOR else v
        return resolved

    def write(self, map_, save=True):
        device = self._device
        if not device.online:
            return None
        self.update(map_, save)
        # Gate the wire on both conditions, like keyboard per-key (needs
        # rgb_control on + zone Static): LED Control on, cluster effect Fixed.
        if not _headset_led_control_on(device) or not _headset_cluster_effect_is_fixed(device):
            return map_  # value stored, skip the wire
        primary = _headset_primary_color(device)
        zone_map = self._resolve_zone_map(map_, primary)
        if not zone_map:
            return map_
        headset_rgb.write_zone_map(device, zone_map)
        return map_

    def write_key_value(self, key, value, save=True):
        result = super().write_key_value(int(key), value, save)
        device = self._device
        if not device.online:
            return result
        if not _headset_led_control_on(device) or not _headset_cluster_effect_is_fixed(device):
            return result  # value stored, skip the wire
        try:
            v = int(value)
        except (TypeError, ValueError):
            return result
        effective = _headset_primary_color(device) if v == _NO_CHANGE_COLOR else v
        headset_rgb.write_zone_map(device, {int(key): int(effective)})
        return result


class _HeadsetSignatureEffect:
    """A 0x0622 signature-effect slot value: an enable byte, two colors and a
    speed. Synthetic 8-byte form [ID, R1,G1,B1, R2,G2,B2, speed] — ID is 0x01
    on / 0x02 off. The rw_class splits it across get/setSignatureEffectParams
    (colors + speed) and get/setSignatureEffectState (the enable byte)."""

    def __init__(self, ID=1, color1=0, color2=0, speed=0):
        self.ID = int(ID)
        self.speed = max(0, min(100, int(speed)))
        for k, v in (("color1", color1), ("color2", color2)):
            setattr(self, k, common.ColorInt(int(v) & 0xFFFFFF))

    @classmethod
    def from_bytes(cls, data, options=None):
        if data is None or len(data) < 8:
            return cls()
        c1 = (data[1] << 16) | (data[2] << 8) | data[3]
        c2 = (data[4] << 16) | (data[5] << 8) | data[6]
        return cls(ID=data[0], color1=c1, color2=c2, speed=data[7])

    def to_bytes(self, options=None):
        return bytes(
            [
                self.ID & 0xFF,
                (self.color1 >> 16) & 0xFF,
                (self.color1 >> 8) & 0xFF,
                self.color1 & 0xFF,
                (self.color2 >> 16) & 0xFF,
                (self.color2 >> 8) & 0xFF,
                self.color2 & 0xFF,
                self.speed & 0xFF,
            ]
        )

    def __eq__(self, other):
        return isinstance(other, self.__class__) and self.to_bytes() == other.to_bytes()

    def __str__(self):
        return yaml.dump(self, width=float("inf")).rstrip("\n")

    @classmethod
    def from_yaml(cls, loader, node):
        return cls(**loader.construct_mapping(node))

    @classmethod
    def to_yaml(cls, dumper, data):
        return dumper.represent_mapping("!HeadsetSignatureEffect", data.__dict__, flow_style=True)


yaml.SafeLoader.add_constructor("!HeadsetSignatureEffect", _HeadsetSignatureEffect.from_yaml)
yaml.add_representer(_HeadsetSignatureEffect, _HeadsetSignatureEffect.to_yaml)


class _HeadsetSignatureEffectSetting(settings.Setting):
    """One firmware signature-effect slot on HEADSET_RGB_SIGNATURE_EFFECTS
    (0x0622). Subclasses set effect_id (0 startup, 1 shutdown, 2 passive).
    Build probes the slot via getSignatureEffectState and suppresses the
    setting if the device doesn't expose it. These run autonomously on the
    device firmware, so — like the keyboard boot animations — they are not
    gated on host LED control."""

    feature = _F.HEADSET_RGB_SIGNATURE_EFFECTS
    effect_id: int = 0

    _ENABLED_CHOICES = common.NamedInts(**{"On": 1, "Off": 2})
    _COLOR1_FIELD = {"name": "color1", "kind": settings.Kind.COLOR, "label": _("Primary")}
    _COLOR2_FIELD = {"name": "color2", "kind": settings.Kind.COLOR, "label": _("Secondary")}
    _SPEED_FIELD = {"name": "speed", "kind": settings.Kind.RANGE, "label": _("Speed"), "min": 0, "max": 100}

    class rw_class:
        kind = settings.FeatureRW.kind

        def __init__(self, feature, effect_id):
            self.feature = feature
            self._eid = bytes([(effect_id >> 8) & 0xFF, effect_id & 0xFF])

        def read(self, device):
            params = device.feature_request(self.feature, 0x10, self._eid)  # getSignatureEffectParams
            state = device.feature_request(self.feature, 0x30, self._eid)  # getSignatureEffectState
            if params is None or len(params) < 9 or state is None or len(state) < 3:
                return None
            # params: [effectId, R1,G1,B1, R2,G2,B2, speed]; state: [effectId, enabled]
            return bytes([state[2]]) + params[2:9]

        def write(self, device, data_bytes):
            # data_bytes: [enabled, R1,G1,B1, R2,G2,B2, speed]
            params = device.feature_request(self.feature, 0x20, self._eid + data_bytes[1:8])
            state = device.feature_request(self.feature, 0x40, self._eid + data_bytes[0:1])
            return data_bytes if params is not None and state is not None else None

    @classmethod
    def build(cls, device):
        eid = bytes([(cls.effect_id >> 8) & 0xFF, cls.effect_id & 0xFF])
        try:
            state = device.feature_request(cls.feature, 0x30, eid)  # probe: is this slot present?
        except exceptions.FeatureCallError:
            return None
        if state is None or len(state) < 3:
            return None
        # NVconfig-saved colors are default-DENY: signature effects persist to
        # device storage, so a slot is shown only on models explicitly known-
        # good. allowed is None on an unlisted model/slot (suppress the whole
        # setting), else the set of fields the firmware honors. The G522
        # passive slot is deliberately unlisted — its behavior is unknown.
        # SOLAAR_EXPERIMENTAL unmasks everything.
        allowed = device_quirks.headset_signature_allowed_fields(device, cls.effect_id)
        if allowed is None:
            return None
        # Log getSignatureEffectsInfo (fn 0) once per device — its byte layout
        # isn't pinned down, so slot discovery uses per-slot probing for now.
        if not getattr(device, "_headset_sig_info_logged", False):
            device._headset_sig_info_logged = True
            try:
                info = device.feature_request(cls.feature, 0x00)
                logger.debug("%s: getSignatureEffectsInfo raw reply: %s", cls.name, info.hex() if info else info)
            except Exception as e:
                logger.debug("%s: getSignatureEffectsInfo probe raised %s", cls.name, e)
        rw = cls.rw_class(cls.feature, cls.effect_id)
        validator = settings_validator.HeteroValidator(data_class=_HeadsetSignatureEffect, options=None)
        setting = cls(device, rw, validator)
        # Enable byte as a right-aligned Gtk.Switch (on=1 / off=2); colors and
        # speed stay visible in both states so toggling Off keeps them.
        id_field = {"name": "ID", "kind": settings.Kind.TOGGLE, "label": None, "on_value": 1, "off_value": 2}
        setting.possible_fields = [id_field, cls._COLOR1_FIELD, cls._COLOR2_FIELD, cls._SPEED_FIELD]
        visible = {f: 1 for f in ("color1", "color2", "speed") if f in allowed}
        setting.fields_map = {
            int(cls._ENABLED_CHOICES["On"]): (cls._ENABLED_CHOICES["On"], visible),
            int(cls._ENABLED_CHOICES["Off"]): (cls._ENABLED_CHOICES["Off"], visible),
        }
        return setting


class HeadsetSignatureStartupEffect(_HeadsetSignatureEffectSetting):
    name = "headset-signature-startup"
    label = _("Startup Effect")
    description = (
        _("Firmware lighting effect played when the headset powers on or wakes.")
        + "\n"
        + _("Device default: Primary #00B8FC, Secondary #FF00AB, Speed 100.")
    )
    effect_id = 0


class HeadsetSignatureShutdownEffect(_HeadsetSignatureEffectSetting):
    name = "headset-signature-shutdown"
    label = _("Shutdown Effect")
    description = (
        _("Firmware lighting effect played when the headset powers off or sleeps.")
        + "\n"
        + _("Device default: Primary #00B8FC, Secondary #FF00AB, Speed 100.")
    )
    effect_id = 1


class HeadsetSignaturePassiveEffect(_HeadsetSignatureEffectSetting):
    name = "headset-signature-passive"
    label = _("Passive Effect")
    description = (
        _("Firmware lighting effect played while the headset is idle.")
        + "\n"
        + _("Device default: Primary #00B8FC, Secondary #FF00AB, Speed 75.")
    )
    effect_id = 2


class _HeadsetOnboardEffect:
    """A 0x0621 onboard RGB effect: an effect ID plus the parameters that
    effect uses. Synthetic form [effectId_u16_BE, 7 param bytes]; to_bytes /
    from_bytes encode the per-effect parameter layout (the rw_class adds the
    leading clusterIndex). intensity is a 0-100 percent; saturation is a raw
    0-255 byte (same as the keyboard RGB effects)."""

    # Per-effect default parameter values, applied only to fields left
    # unset (passed as None). An explicit value is always honored — passing
    # 0 means the caller chose 0, e.g. a black Static color1 turns the LEDs
    # off. Only a genuinely absent field falls back to the default (a fresh
    # effect-pick seeds its RANGE widgets UI-side via _apply_id_defaults).
    # Defaults confirmed against the LGHUB binary decode of 0x0621.
    _DEFAULTS = {
        0: {"color1": 0xFFFFFF},  # Static / Fixed
        1: {"intensity": 100, "saturation": 255, "period": 5000},  # Color Cycle
        2: {"intensity": 100, "saturation": 255, "period": 5000},  # Color Wave
        3: {"color1": 0xFFFFFF, "intensity": 100, "period": 5000},  # Breathing
        4: {"color1": 0xFFFFFF, "color2": 0x0000FF, "intensity": 100},  # Dual Color
    }

    # speed is accepted only to load configs persisted before the 0x0621
    # decode (DualColor byte 6 was mislabelled "speed"; it is intensity).
    def __init__(self, ID=0, color1=None, color2=None, intensity=None, saturation=None, period=None, speed=0, direction=None):
        self.ID = int(ID)
        defaults = self._DEFAULTS.get(self.ID, {})
        color1 = defaults.get("color1", 0) if color1 is None else color1
        color2 = defaults.get("color2", 0) if color2 is None else color2
        intensity = defaults.get("intensity", 0) if intensity is None else intensity
        saturation = defaults.get("saturation", 0) if saturation is None else saturation
        period = defaults.get("period", 0) if period is None else period
        direction = defaults.get("direction", 0) if direction is None else direction
        self.intensity = max(0, min(100, int(intensity)))
        self.saturation = max(0, min(255, int(saturation)))
        self.period = max(0, min(0xFFFF, int(period)))
        self.direction = max(0, min(3, int(direction)))
        for k, v in (("color1", color1), ("color2", color2)):
            setattr(self, k, common.ColorInt(int(v) & 0xFFFFFF))

    @classmethod
    def from_bytes(cls, data, options=None):
        if data is None or len(data) < 9:
            return cls()
        eid = (data[0] << 8) | data[1]
        p = data[2:9]
        kw = {"ID": eid}
        if eid == 0:  # Fixed
            kw["color1"] = (p[0] << 16) | (p[1] << 8) | p[2]
        elif eid in (1, 2):  # ColorCycle / ColorWave
            kw["intensity"] = p[0]
            kw["period"] = (p[1] << 8) | p[2]
            kw["saturation"] = p[3]
            if eid == 2:
                kw["direction"] = p[4]
        elif eid == 3:  # Breathing: R, G, B, intensity, period u16 BE
            kw["color1"] = (p[0] << 16) | (p[1] << 8) | p[2]
            kw["intensity"] = p[3]
            kw["period"] = (p[4] << 8) | p[5]
        elif eid == 4:  # DualColor: R1, G1, B1, R2, G2, B2, intensity
            kw["color1"] = (p[0] << 16) | (p[1] << 8) | p[2]
            kw["color2"] = (p[3] << 16) | (p[4] << 8) | p[5]
            kw["intensity"] = p[6]
        return cls(**kw)

    def to_bytes(self, options=None):
        eid = self.ID
        p = bytearray(7)
        c1, c2 = int(self.color1), int(self.color2)
        if eid == 0:  # Fixed: R, G, B
            p[0], p[1], p[2] = (c1 >> 16) & 0xFF, (c1 >> 8) & 0xFF, c1 & 0xFF
        elif eid in (1, 2):  # ColorCycle / ColorWave
            p[0] = self.intensity
            p[1], p[2] = (self.period >> 8) & 0xFF, self.period & 0xFF
            p[3] = self.saturation
            if eid == 2:
                p[4] = self.direction
        elif eid == 3:  # Breathing: R, G, B, intensity, period u16 BE, pad
            p[0], p[1], p[2] = (c1 >> 16) & 0xFF, (c1 >> 8) & 0xFF, c1 & 0xFF
            p[3] = self.intensity
            p[4], p[5] = (self.period >> 8) & 0xFF, self.period & 0xFF
        elif eid == 4:  # DualColor: R1,G1,B1, R2,G2,B2, intensity
            p[0], p[1], p[2] = (c1 >> 16) & 0xFF, (c1 >> 8) & 0xFF, c1 & 0xFF
            p[3], p[4], p[5] = (c2 >> 16) & 0xFF, (c2 >> 8) & 0xFF, c2 & 0xFF
            p[6] = self.intensity
        return bytes([(eid >> 8) & 0xFF, eid & 0xFF]) + bytes(p)

    def __eq__(self, other):
        return isinstance(other, self.__class__) and self.to_bytes() == other.to_bytes()

    def __str__(self):
        return yaml.dump(self, width=float("inf")).rstrip("\n")

    @classmethod
    def from_yaml(cls, loader, node):
        return cls(**loader.construct_mapping(node))

    @classmethod
    def to_yaml(cls, dumper, data):
        return dumper.represent_mapping("!HeadsetOnboardEffect", data.__dict__, flow_style=True)


yaml.SafeLoader.add_constructor("!HeadsetOnboardEffect", _HeadsetOnboardEffect.from_yaml)
yaml.add_representer(_HeadsetOnboardEffect, _HeadsetOnboardEffect.to_yaml)


class HeadsetOnboardEffect(settings.Setting):
    """The RGB effect the headset shows on its primary lighting cluster
    (HEADSET_RGB_ONBOARD_EFFECTS, 0x0621). Build reads the cluster's
    supported-effect set so the picker offers only those. This is live LED
    control, like per-zone painting — gated on Solaar holding the LED-control
    claim: writes are skipped and the row greys out when the claim is
    released. Multi-cluster devices (none seen yet) drive only cluster 0."""

    name = "headset-onboard-effect"
    label = _("Onboard Effect")
    description = _("Firmware RGB effect the headset plays on its own.")
    feature = _F.HEADSET_RGB_ONBOARD_EFFECTS

    _CLUSTER = 0
    # Custom (5) is intentionally absent — it is a stored card-reference
    # effect, not a parametric one; it cannot be set via setRGBClusterEffect.
    _ALL_EFFECTS = (
        ("Static", 0),
        ("Color Cycle", 1),
        ("Color Wave", 2),
        ("Breathing", 3),
        ("Dual Color", 4),
    )
    _EFFECT_FIELDS = {
        0: ("color1",),
        1: ("intensity", "period", "saturation"),
        2: ("intensity", "period", "saturation", "direction"),
        3: ("color1", "intensity", "period"),
        4: ("color1", "color2", "intensity"),
    }
    _DIRECTIONS = common.NamedInts(**{"Horizontal": 0, "Vertical": 1, "Reverse Horizontal": 2, "Reverse Vertical": 3})

    class rw_class:
        kind = settings.FeatureRW.kind

        def __init__(self, feature, cluster):
            self.feature = feature
            self._cluster = cluster

        def read(self, device):
            reply = device.feature_request(self.feature, 0x20, bytes([self._cluster]))  # getRGBClusterEffect
            if reply is None or len(reply) < 10:
                return None
            return reply[1:10]  # strip clusterIndex -> [effectId_u16, 7 param bytes]

        def write(self, device, data_bytes):
            # data_bytes is [effectId_u16, 7 param bytes]; prepend clusterIndex.
            # The onboard effect is live LED control — skip the wire when Solaar
            # doesn't hold the claim; the value is still persisted.
            if not _headset_led_control_on(device):
                return data_bytes
            reply = device.feature_request(self.feature, 0x30, bytes([self._cluster]) + bytes(data_bytes))
            return data_bytes if reply is not None else None

    @classmethod
    def build(cls, device):
        try:
            info = device.feature_request(cls.feature, 0x10, bytes([cls._CLUSTER]))  # getRGBClusterInfo
        except exceptions.FeatureCallError:
            return None
        if info is None or len(info) < 1:
            return None
        # [count, count x {effectId_u16_BE, caps_u16_BE}] — take effectId of each entry
        supported = []
        for i in range(info[0]):
            off = 1 + i * 4
            if off + 2 > len(info):
                break
            eid = (info[off] << 8) | info[off + 1]
            if 0 <= eid <= 4 and eid not in supported:
                supported.append(eid)
        if not supported:
            # Unparseable reply — offer the five parametric effects; the
            # firmware rejects any it doesn't support. Custom (5) is never
            # offered here. See the 0x0621 fallback note in protocol RE.
            supported = [0, 1, 2, 3, 4]
        rw = cls.rw_class(cls.feature, cls._CLUSTER)
        validator = settings_validator.HeteroValidator(data_class=_HeadsetOnboardEffect, options=None)
        setting = cls(device, rw, validator)
        id_choices = common.NamedInts(**{name: eid for name, eid in cls._ALL_EFFECTS if eid in supported})
        id_field = {"name": "ID", "kind": settings.Kind.CHOICE, "label": None, "choices": id_choices}
        setting.possible_fields = [
            id_field,
            {"name": "color1", "kind": settings.Kind.COLOR, "label": _("Primary")},
            {"name": "color2", "kind": settings.Kind.COLOR, "label": _("Secondary")},
            {"name": "intensity", "kind": settings.Kind.RANGE, "label": _("Intensity"), "min": 0, "max": 100},
            {"name": "saturation", "kind": settings.Kind.RANGE, "label": _("Saturation"), "min": 0, "max": 255},
            {
                "name": "period",
                "kind": settings.Kind.RANGE,
                "label": _("Period"),
                "min": 1000,
                "max": 20000,
                "display_seconds": True,
            },
            {"name": "direction", "kind": settings.Kind.CHOICE, "label": _("Direction"), "choices": cls._DIRECTIONS},
        ]
        setting.fields_map = {eid: (id_choices[eid], {field: 1 for field in cls._EFFECT_FIELDS[eid]}) for eid in supported}
        return setting

    def write(self, value, save=True):
        # Writing the 0x0621 cluster effect re-fills every LED uniformly; the
        # firmware treats that as dropping the host per-zone buffer. After a
        # Static write, re-overlay the per-zone paint so individually-colored
        # zones survive a LEDs Primary change. _headset_reassert_zone_layer is
        # a no-op for non-Static effects (the animation masks per-zone).
        result = super().write(value, save)
        if result is not None and self._device.online and _headset_led_control_on(self._device):
            _headset_reassert_zone_layer(self._device)
        return result


# ----------------------------------------------------------------------------
# LogiVoice (0x0900 + 0x0901..0x0907) — read-only presentation pass.
#
# Per module we auto-generate two settings:
#   1. A flat State toggle — reads GetState (fn 1), renders as a boolean.
#      Top-level so users see a direct on/off indicator at a glance.
#   2. A collapsible "Parameters" panel — one MULTIPLE_RANGE-kind setting
#      that reads GetParameters (fn 3) once and distributes the bytes to
#      per-field sliders. The existing MultipleRangeControl widget is
#      collapsible by default, so the field-level clutter stays folded.
#
# Writes are disabled — the Parameters struct carries fields whose wire
# encodings are still ambiguous (see logivoice.py) and a SetParameters
# write must bundle all fields at once. A write pass can be added once
# each field's encoding is confirmed live.
# ----------------------------------------------------------------------------


class _LogiVoiceStateSetting(settings.Setting):
    """Per-module State toggle. Reads GetState (fn 1) and writes SetState (fn 0).

    State wire format is unambiguous (one byte: 0 = off, 1 = on), so this is
    the one piece of the LogiVoice surface we enable for writes. The per-module
    Parameters struct stays read-only until each field's encoding is confirmed.
    """

    rw_options = {"read_fnid": logivoice.FN_GET_STATE, "write_fnid": logivoice.FN_SET_STATE}
    validator_class = settings_validator.BooleanValidator

    @classmethod
    def build(cls, device):
        # Corpus probe runs here (once per module) so -dd users get a full
        # snapshot of state + raw Parameters + raw Info for future decoding.
        try:
            logivoice.probe_module(device, cls.feature)
        except Exception as e:
            logger.debug("LogiVoice probe_module(%s) raised %s", cls.feature, e)
        return super().build(device)


class _LogiVoiceModuleItem:
    """Top-level MULTIPLE_RANGE item representing one LogiVoice module.

    One `item` per setting — the module itself. `__int__` returns the feature
    id so the Setting's reply dict is keyed predictably.
    """

    def __init__(self, feature: hidpp20_constants.SupportedFeature):
        self._feature = feature
        self.id = logivoice.MODULE_SLUGS.get(feature, f"0x{int(feature):04X}")
        self.index = 0

    def __int__(self):
        return int(self._feature)

    def __str__(self):
        return logivoice.MODULE_NAMES.get(self._feature, f"0x{int(self._feature):04X}")


class _LogiVoiceFieldSubItem:
    """MULTIPLE_RANGE sub-item wrapping one decoded Parameters field.

    MultipleRangeControl reads minimum/maximum/length/widget/str(). We pick
    SpinButton for wide ranges (0..65535) where a 64k-step slider is useless,
    and Scale for small ranges (e.g. signed int8 thresholds).
    """

    def __init__(self, field: logivoice.Field):
        self._field = field
        self.id = field.name
        self.minimum = field.min_value
        self.maximum = field.max_value
        self.length = field.byte_count
        self.widget = "SpinButton" if (field.max_value - field.min_value) > 512 else "Scale"

    def __int__(self):
        return hash(self.id) & 0xFFFFFF

    def __str__(self):
        return self._field.label + (" (raw)" if self._field.opaque else "")


class _LogiVoiceParametersValidator(settings_validator.MultipleRangeValidator):
    """Reads the whole GetParameters struct once and distributes bytes to fields.

    MULTIPLE_RANGE's default read loop fires prepare_read_item once per top-
    level item; we have exactly one item (the module), so this issues a single
    GetParameters call. validate_read_item parses the shared reply into a
    {field_name: value} dict. Writes are blocked.
    """

    def __init__(self, feature: hidpp20_constants.SupportedFeature):
        fields = logivoice.PARAMETERS_FIELDS.get(feature, [])
        self._fields = list(fields)
        item = _LogiVoiceModuleItem(feature)
        sub_items = {item: [_LogiVoiceFieldSubItem(f) for f in fields]}
        super().__init__(items=[item], sub_items=sub_items)

    def prepare_read_item(self, item):
        return b""  # GetParameters takes no wire arguments

    def validate_read(self, reply_bytes):
        # Setting.read() calls validate_read with the raw GetParameters reply.
        # MultipleRangeValidator only defines validate_read_item, so wrap that
        # call — we have a single item (the module) so one call suffices.
        item = self.items[0]
        return {int(item): self.validate_read_item(reply_bytes, item)}

    def validate_read_item(self, reply_bytes, item):
        parsed = {}
        # Key by str(sub_item) so MultipleRangeControl.set_value can look up
        # values via v[str(sub_item)] — the UI uses the label as the dict key.
        for sub in self.sub_items[item]:
            f = sub._field
            end = f.offset + f.byte_count
            if end > len(reply_bytes):
                continue
            chunk = reply_bytes[f.offset : end]
            if f.byte_count == 1:
                v = struct.unpack("b" if f.signed else "B", chunk)[0]
            elif f.byte_count == 2:
                v = struct.unpack(">h" if f.signed else ">H", chunk)[0]
            else:
                v = int.from_bytes(chunk, "big", signed=f.signed)
            parsed[str(sub)] = v
        return parsed

    def prepare_write_item(self, item, value):
        return None

    def prepare_write(self, value):
        return None


class _LogiVoiceParametersSetting(settings.Setting):
    """Collapsible read-only display of one module's GetParameters struct."""

    rw_options = {"read_fnid": logivoice.FN_GET_PARAMETERS}
    persist = False
    kind = settings.Kind.MULTIPLE_RANGE

    @classmethod
    def build(cls, device):
        if not logivoice.PARAMETERS_FIELDS.get(cls.feature):
            return None
        rw = settings.FeatureRW(cls.feature, **cls.rw_options)
        validator = _LogiVoiceParametersValidator(cls.feature)
        return cls(device, rw, validator)

    def write(self, map, save=True):
        return None


def _logivoice_make_state_class(feature: hidpp20_constants.SupportedFeature):
    slug = logivoice.MODULE_SLUGS.get(feature)
    if not slug:
        return None
    module_name = logivoice.MODULE_NAMES.get(feature, f"0x{int(feature):04X}")
    attrs = {
        "name": f"logivoice-{slug}-state",
        "label": f"LogiVoice {module_name}",
        "description": f"Enable the headset {module_name} processing block.",
        "feature": feature,
    }
    return type(f"LogiVoice_{slug}_State", (_LogiVoiceStateSetting,), attrs)


def _logivoice_make_parameters_class(feature: hidpp20_constants.SupportedFeature):
    slug = logivoice.MODULE_SLUGS.get(feature)
    if not slug or not logivoice.PARAMETERS_FIELDS.get(feature):
        return None
    module_name = logivoice.MODULE_NAMES.get(feature, f"0x{int(feature):04X}")
    attrs = {
        "name": f"logivoice-{slug}-parameters",
        "label": f"LogiVoice {module_name}: Parameters (read-only)",
        "description": (
            f"Decoded {module_name} GetParameters fields. "
            "Opaque raw values shown where the wire encoding isn't confirmed yet."
        ),
        "feature": feature,
    }
    return type(f"LogiVoice_{slug}_Parameters", (_LogiVoiceParametersSetting,), attrs)


_LOGIVOICE_SETTINGS: list[type] = []
for _feature in logivoice.PARAMETERS_FIELDS:
    _state_cls = _logivoice_make_state_class(_feature)
    if _state_cls is not None:
        _LOGIVOICE_SETTINGS.append(_state_cls)
    # Parameters panels are read-only and the wire encoding is only
    # partially decoded — hide from the UI until we can write them back.
    # _params_cls = _logivoice_make_parameters_class(_feature)
    # if _params_cls is not None:
    #     _LOGIVOICE_SETTINGS.append(_params_cls)


class BrightnessControl(settings.Setting):
    name = "brightness_control"
    label = _("Brightness Control")
    description = _("Control overall brightness")
    feature = _F.BRIGHTNESS_CONTROL
    rw_options = {"read_fnid": 0x10, "write_fnid": 0x20}
    validator_class = settings_validator.RangeValidator

    def __init__(self, device, rw, validator):
        super().__init__(device, rw, validator)
        rw.on_off = validator.on_off
        rw.min_nonzero_value = validator.min_value
        validator.min_value = 0 if validator.on_off else validator.min_value

    def write(self, value, save=True):
        # Snap to firmware-driven halving levels (off only at exact 0).
        steps = getattr(self._validator, "steps", 0)
        marks = halving_marks(self._validator.max_value, steps)
        if value is not None and marks:
            if value <= 0:
                value = 0
            else:
                nonzero = [m for m in marks if m > 0]
                if nonzero:
                    value = min(reversed(nonzero), key=lambda m: abs(m - value))
        return super().write(value, save)

    class rw_class(settings.FeatureRW):
        def read(self, device, data_bytes=b""):
            if self.on_off:
                reply = device.feature_request(self.feature, 0x30)
                if not reply[0] & 0x01:
                    return b"\x00\x00"
            return super().read(device, data_bytes)

        def write(self, device, data_bytes):
            if self.on_off:
                off = int.from_bytes(data_bytes, byteorder="big") < self.min_nonzero_value
                reply = device.feature_request(self.feature, 0x40, b"\x00" if off else b"\x01", no_reply=False)
                if off:
                    return reply
            return super().write(device, data_bytes)

    class validator_class(settings_validator.RangeValidator):
        @classmethod
        def build(cls, setting_class, device):
            reply = device.feature_request(_F.BRIGHTNESS_CONTROL)
            assert reply, "Oops, brightness range cannot be retrieved!"
            if reply:
                max_value = int.from_bytes(reply[0:2], byteorder="big")
                steps_and_flags = reply[2]
                caps = reply[3]
                min_value = int.from_bytes(reply[4:6], byteorder="big")
                on_off = bool(caps & 0x04)
                if logger.isEnabledFor(logging.DEBUG):
                    logger.debug(
                        "%s BrightnessControl getInfo: %s — max=%d min=%d steps_and_flags=0x%02x caps=0x%02x on_off=%s",
                        device,
                        reply[:8].hex(),
                        max_value,
                        min_value,
                        steps_and_flags,
                        caps,
                        on_off,
                    )
                validator = cls(min_value=min_value, max_value=max_value, byte_count=2)
                validator.on_off = on_off
                validator.steps = steps_and_flags & 0x0F
                device._brightness_steps = validator.steps  # for sibling settings (e.g. idle Dim)
                return validator


class LEDControl(settings.Setting):
    name = "led_control"
    label = _("LED Control")
    description = _("Allow Solaar to control LED zones.")
    feature = _F.COLOR_LED_EFFECTS
    rw_options = {"read_fnid": 0x70, "write_fnid": 0x80}
    # Two-state setting — render as a Gtk.Switch rather than a 2-option combo.
    # true_value=1 / false_value=0 are the wire bytes for Solaar / Device mode.
    validator_class = settings_validator.BooleanValidator
    validator_options = {"true_value": 1, "false_value": 0}

    def _pre_read(self, cached, key=None):
        # Migrate legacy int values (0/1) stored under the old ChoicesValidator
        # to bool so the switch widget gets a value it can set_state() on.
        super()._pre_read(cached, key)
        if isinstance(self._value, int) and not isinstance(self._value, bool):
            self._value = self._value != 0


colors = special_keys.COLORS
_LEDP = hidpp20.LEDParam


# an LED Zone has an index, a set of possible LED effects, and an LED effect setting
class LEDZoneSetting(settings.Setting):
    name = "led_zone_"  # the trailing underscore signals that this setting creates other settings
    label = _("LED Zone Effects")
    description = _("Set effect for LED Zone") + "\n" + _("LED Control needs to be enabled.")
    feature = _F.COLOR_LED_EFFECTS
    color_field = {"name": _LEDP.color, "kind": settings.Kind.COLOR, "label": _("Color")}
    speed_field = {"name": _LEDP.speed, "kind": settings.Kind.RANGE, "label": _("Speed"), "min": 0, "max": 255}
    period_field = {
        "name": _LEDP.period,
        "kind": settings.Kind.RANGE,
        "label": _("Period"),
        "min": 1000,
        "max": 20000,
        "display_seconds": True,
    }
    intensity_field = {"name": _LEDP.intensity, "kind": settings.Kind.RANGE, "label": _("Intensity"), "min": 0, "max": 100}
    ramp_field = {"name": _LEDP.ramp, "kind": settings.Kind.CHOICE, "label": _("Ramp"), "choices": hidpp20.LedRampChoice}
    saturation_field = {"name": _LEDP.saturation, "kind": settings.Kind.RANGE, "label": _("Saturation"), "min": 0, "max": 255}
    form_field = {"name": _LEDP.form, "kind": settings.Kind.CHOICE, "label": _("Waveform"), "choices": hidpp20.LedFormChoices}
    direction_field = {
        "name": _LEDP.direction,
        "kind": settings.Kind.CHOICE,
        "label": _("Direction"),
        "choices": hidpp20.LedDirectionChoices,
    }
    # Per-widget visibility driven by LEDEffects[ID][1]; RGBEffectSetting
    # overrides this list to drop ramp/form on 0x8071.
    possible_fields = [
        color_field,
        speed_field,
        period_field,
        intensity_field,
        ramp_field,
        saturation_field,
        form_field,
        direction_field,
    ]

    @classmethod
    def setup(cls, device, read_fnid, write_fnid, suffix):
        infos = device.led_effects
        possible_fields = cls._device_possible_fields(device)
        settings_ = []
        for zone in infos.zones:
            prefix = common.int2bytes(zone.index, 1)
            rw = settings.FeatureRW(cls.feature, read_fnid, write_fnid, prefix=prefix, suffix=suffix)
            validator = settings_validator.HeteroValidator(
                data_class=hidpp20.LEDEffectSetting, options=zone.effects, readable=infos.readable and read_fnid is not None
            )
            setting = cls(device, rw, validator)
            setting.name = cls.name + str(int(zone.location))
            setting.label = _("LEDs") + " " + str(hidpp20.LEDZoneLocations[zone.location])
            choices = [hidpp20.LEDEffects[e.ID][0] for e in zone.effects if e.ID in hidpp20.LEDEffects]
            ID_field = {"name": "ID", "kind": settings.Kind.CHOICE, "label": None, "choices": choices}
            setting.possible_fields = [ID_field] + possible_fields
            setting.fields_map = hidpp20.LEDEffects
            settings_.append(setting)
        return settings_

    @classmethod
    def _device_possible_fields(cls, device):
        return _possible_fields_with_direction_filter(device, cls.possible_fields, cls.direction_field)

    @classmethod
    def build(cls, device):
        return cls.setup(device, 0xE0, 0x30, b"")


class RGBControl(settings.Setting):
    name = "rgb_control"
    label = _("LED Control")
    description = _("Allow Solaar to control LED zones.")
    feature = _F.RGB_EFFECTS
    rw_options = {"read_fnid": 0x50, "write_fnid": 0x50}
    # Two-state setting — render as a Gtk.Switch rather than a 2-option combo.
    # true_value=3 / false_value=0 are the wire bytes for Solaar / Device mode
    # returned by GetSWControl after the 1-byte sub-fn echo. Mode 3 is the
    # full SW takeover the claim handshake below expects.
    validator_class = settings_validator.BooleanValidator
    validator_options = {"true_value": 3, "false_value": 0, "write_prefix_bytes": b"\x01", "read_skip_byte_count": 1}

    def _pre_read(self, cached, key=None):
        # Migrate legacy int values (0/3) stored under the old ChoicesValidator
        # to bool so the switch widget gets a value it can set_state() on.
        super()._pre_read(cached, key)
        if isinstance(self._value, int) and not isinstance(self._value, bool):
            self._value = self._value != 0

    def write(self, value, save=True):
        assert hasattr(self, "_value")
        assert hasattr(self, "_device")
        assert value is not None
        device = self._device
        if not device.online:
            return None
        if self._value != value:
            self.update(value, save)
        claiming = int(value) != 0  # any non-zero value is a Solaar-side claim
        if claiming:
            self._claim_sw_control(device)
        else:
            self._release_sw_control(device)
        return value

    def _claim_sw_control(self, device):
        # Disable firmware power management via profile management or onboard profiles
        if device.features and _F.PROFILE_MANAGEMENT in device.features:
            device.feature_request(_F.PROFILE_MANAGEMENT, 0x60, b"\x05")
        elif device.features and _F.ONBOARD_PROFILES in device.features:
            device.feature_request(_F.ONBOARD_PROFILES, 0x10, b"\x02")
        # Claim LED pipeline: SetSWControl(mode=3, flags=5)
        device.feature_request(_F.RGB_EFFECTS, 0x50, rgb_power.SW_ACTIVE)
        # Reset per-key one-shot flags so the first write after this claim
        # re-fires the prep + double-send.
        for s in device.settings:
            if s.name == "per-key-lighting":
                s._frame_settled = False
                s._prep_pushed = False
                break
        # Start software power management
        rgb_power.start(device)
        # Register cleanup for graceful release on device close
        if rgb_power.cleanup not in device.cleanups:
            device.cleanups.append(rgb_power.cleanup)
        # Repaint LEDs with Solaar's saved state. Without this the firmware's
        # last-active onboard profile keeps showing until the user changes
        # something — the takeover would look like it did nothing.
        self._repaint_after_claim(device)

    def _repaint_after_claim(self, device):
        """Push saved zone effects and (if opted in) per-key buffer to the
        device after a fresh SW claim. Best-effort: individual failures get
        logged but don't abort the rest of the repaint."""
        for s in device.settings:
            if s.name.startswith("rgb_zone_") and s._value is not None:
                try:
                    s.write(s._value, save=False)
                except Exception as e:
                    logger.warning("%s: post-claim repaint of %s failed: %s", device, s.name, e)
        perkey, has_paint = rgb_power.perkey_has_paint(device)
        if has_paint and perkey._value is not None:
            try:
                perkey.write(perkey._value, save=False)
            except Exception as e:
                logger.warning("%s: post-claim per-key repaint failed: %s", device, e)

    def _release_sw_control(self, device):
        # If we never claimed in this session, don't touch the device at all.
        # The presence of an RGBPowerManager is the canonical "we claimed" signal
        # — _claim_sw_control creates it via rgb_power.start, and stop() pops it.
        had_claim = rgb_power.get_manager(device) is not None
        rgb_power.stop(device)
        if not had_claim:
            return
        # Release LED pipeline: SetSWControl(mode=0, flags=0)
        device.feature_request(_F.RGB_EFFECTS, 0x50, rgb_power.SW_RELEASE)
        # Restore firmware power management
        if device.features and _F.PROFILE_MANAGEMENT in device.features:
            device.feature_request(_F.PROFILE_MANAGEMENT, 0x60, b"\x03")
        elif device.features and _F.ONBOARD_PROFILES in device.features:
            device.feature_request(_F.ONBOARD_PROFILES, 0x10, b"\x01")
        # Keep cleanup registered on devices that support the shutdown effect
        # cap — it also fires the firmware shutdown animation trigger on exit.
        if not getattr(device, "_rgb_has_shutdown_cap", False):
            if rgb_power.cleanup in device.cleanups:
                device.cleanups.remove(rgb_power.cleanup)


class RGBIdleTimeout(settings.Setting):
    name = "rgb_idle_timeout"
    label = _("Idle Timeout")
    description = _("Time without input before LED idle effect starts.") + "\n" + _("LED Control needs to be enabled.")
    feature = _F.RGB_EFFECTS
    choices_universe = common.NamedInts(
        **{
            "Disabled": 0,
            "15 Seconds": 15,
            "30 Seconds": 30,
            "1 Minute": 60,
            "2 Minutes": 120,
            "5 Minutes": 300,
        }
    )
    validator_class = settings_validator.ChoicesValidator
    validator_options = {"choices": choices_universe}

    class rw_class:
        def __init__(self, feature, **kwargs):
            self.feature = feature
            self.kind = settings.FeatureRW.kind

        def read(self, device):
            return common.int2bytes(60, 2)  # default 1 minute

        def write(self, device, data_bytes):
            timeout = int.from_bytes(data_bytes, byteorder="big")
            mgr = rgb_power.get_manager(device)
            if mgr:
                mgr.set_idle_timeout(timeout)
            return True


class RGBIdleEffect(settings.Setting):
    """Idle-effect setting with per-effect sub-widgets. Persisted value is an
    LEDEffectSetting; legacy bare-int values are migrated in `_pre_read`."""

    name = "rgb_idle_effect"
    label = _("Idle Effect")
    description = (
        _("What happens to LEDs when idle — dim to a percentage, change the base color, or play an animation.")
        + "\n"
        + _("LED Control needs to be enabled.")
    )
    feature = _F.RGB_EFFECTS
    # Reuse zone fields so idle controls match the active-zone setup exactly.
    # Idle-specific intensity override carries the halving marks for Dim.
    intensity_field = {**LEDZoneSetting.intensity_field, "halving": True}
    period_field = LEDZoneSetting.period_field
    saturation_field = LEDZoneSetting.saturation_field
    speed_field = LEDZoneSetting.speed_field
    direction_field = LEDZoneSetting.direction_field
    color_field = LEDZoneSetting.color_field
    possible_fields = [color_field, speed_field, period_field, intensity_field, saturation_field, direction_field]

    class rw_class:
        def __init__(self, feature, **kwargs):
            self.feature = feature
            self.kind = settings.FeatureRW.kind

        def read(self, device):
            return hidpp20.LEDEffectSetting(ID=0x80, intensity=50).to_bytes()

        def write(self, device, data_bytes):
            value = hidpp20.LEDEffectSetting.from_bytes(data_bytes)
            mgr = rgb_power.get_manager(device)
            if mgr:
                mgr.set_idle_effect(value)
            return True

    def _pre_read(self, cached, key=None):
        """Migrate legacy bare-int values to LEDEffectSetting on first read."""
        super()._pre_read(cached, key)
        if self._value is None or isinstance(self._value, hidpp20.LEDEffectSetting):
            return
        if not isinstance(self._value, int):
            return
        legacy = self._value
        if legacy == 0:
            migrated = hidpp20.LEDEffectSetting(ID=0x00)
        elif legacy in (25, 50, 75):
            migrated = hidpp20.LEDEffectSetting(ID=0x80, intensity=legacy)
        elif legacy == 0x0A:
            migrated = hidpp20.LEDEffectSetting(ID=0x0A, period=3000, intensity=100)
        elif legacy == 0x0B:
            migrated = hidpp20.LEDEffectSetting(ID=0x0B, period=3000)
        else:
            return  # unrecognized — leave alone, write() will error informatively
        if logger.isEnabledFor(logging.DEBUG):
            logger.debug(
                "%s: migrating legacy bare-int %s to LEDEffectSetting on %s",
                self.name,
                legacy,
                self._device,
            )
        self._value = migrated
        if getattr(self._device, "persister", None) is not None:
            self._device.persister[self.name] = self._value

    # Ripple needs keyboard input to animate so it can't run while idle.
    # Disabled (0x00) and Dim (0x80) are seeded into choice_ids directly.
    # Static (0x01) is also seeded so it appears right below Dim regardless
    # of probe-derived ID ordering.
    _IDLE_EXCLUDED_IDS = frozenset({0x00, 0x0B, 0x17})

    @classmethod
    def build(cls, device):
        rw = cls.rw_class(cls.feature)
        # No change → Dim → Static, then any probed device-specific effects.
        choice_ids = [0x00, 0x80, 0x01]
        probed = set()
        try:
            infos = device.led_effects
            if infos and infos.zones:
                probed = {int(e.ID) for e in infos.zones[0].effects}
        except Exception:
            pass
        for eid in sorted(probed):
            if eid in cls._IDLE_EXCLUDED_IDS or eid in choice_ids:
                continue
            if eid not in hidpp20.LEDEffects:
                continue
            choice_ids.append(eid)
        idle_disabled = common.NamedInt(0x00, _("No change"))
        choices = [idle_disabled if i == 0x00 else hidpp20.LEDEffects[i][0] for i in choice_ids]
        ID_field = {"name": "ID", "kind": settings.Kind.CHOICE, "label": None, "choices": choices}
        fields_map = {
            0x00: [idle_disabled, {}],
            0x80: [
                hidpp20.LEDEffects[0x80][0],
                {hidpp20.LEDParam.intensity: 0},
                {hidpp20.LEDParam.intensity: 50},
            ],
        }
        for eid in choice_ids:
            if eid not in fields_map:
                fields_map[eid] = hidpp20.LEDEffects[eid]
        validator = settings_validator.HeteroValidator(data_class=hidpp20.LEDEffectSetting, options=None, readable=True)
        setting = cls(device, rw, validator)
        setting.possible_fields = [ID_field] + _possible_fields_with_direction_filter(
            device, cls.possible_fields, cls.direction_field
        )
        setting.fields_map = fields_map
        return setting


class RGBSleepTimeout(settings.Setting):
    name = "rgb_sleep_timeout"
    label = _("Sleep Timeout")
    description = _("Time without input before LEDs fade off completely.") + "\n" + _("LED Control needs to be enabled.")
    feature = _F.RGB_EFFECTS
    choices_universe = common.NamedInts(
        **{
            "Disabled": 0,
            "2 Minutes": 120,
            "5 Minutes": 300,
            "10 Minutes": 600,
            "15 Minutes": 900,
            "30 Minutes": 1800,
        }
    )
    validator_class = settings_validator.ChoicesValidator
    validator_options = {"choices": choices_universe}

    class rw_class:
        def __init__(self, feature, **kwargs):
            self.feature = feature
            self.kind = settings.FeatureRW.kind

        def read(self, device):
            return common.int2bytes(300, 2)  # default 5 minutes

        def write(self, device, data_bytes):
            timeout = int.from_bytes(data_bytes, byteorder="big")
            mgr = rgb_power.get_manager(device)
            if mgr:
                mgr.set_sleep_timeout(timeout)
            return True


class _RgbBootEffect:
    """NvConfig persistent boot/shutdown effect payload on RGBEffects (0x8071).

    Wire format (7 bytes, NvConfig cap 0x0001 startup / 0x0040 shutdown):
        [enabled, R1, G1, B1, R2, G2, B2]
    enabled: 0x01 on, 0x02 off. Colors are kept editable in both states so
    toggling Off doesn't lose the user's chosen color.
    """

    _COLOR_ATTRS = ("color1", "color2")

    def __init__(self, ID=1, color1=0, color2=0):
        self.ID = int(ID)
        for k, v in (("color1", color1), ("color2", color2)):
            iv = int(v) & 0xFFFFFF
            setattr(self, k, common.ColorInt(iv))

    @classmethod
    def from_bytes(cls, data, options=None):
        if data is None or len(data) < 7:
            return cls()
        c1 = (data[1] << 16) | (data[2] << 8) | data[3]
        c2 = (data[4] << 16) | (data[5] << 8) | data[6]
        return cls(ID=data[0], color1=c1, color2=c2)

    def to_bytes(self, options=None):
        return bytes(
            [
                self.ID & 0xFF,
                (self.color1 >> 16) & 0xFF,
                (self.color1 >> 8) & 0xFF,
                self.color1 & 0xFF,
                (self.color2 >> 16) & 0xFF,
                (self.color2 >> 8) & 0xFF,
                self.color2 & 0xFF,
            ]
        )

    def __eq__(self, other):
        return isinstance(other, self.__class__) and self.to_bytes() == other.to_bytes()

    def __str__(self):
        return yaml.dump(self, width=float("inf")).rstrip("\n")

    @classmethod
    def from_yaml(cls, loader, node):
        return cls(**loader.construct_mapping(node))

    @classmethod
    def to_yaml(cls, dumper, data):
        return dumper.represent_mapping("!RgbBootEffect", data.__dict__, flow_style=True)


yaml.SafeLoader.add_constructor("!RgbBootEffect", _RgbBootEffect.from_yaml)
yaml.add_representer(_RgbBootEffect, _RgbBootEffect.to_yaml)


class _RgbBootEffectSetting(settings.Setting):
    """Base for NvConfig persistent effect toggles on RGBEffects (0x8071).

    Subclasses set cap_id (0x0001 startup, 0x0040 shutdown). Build probes the
    cap once and suppresses the setting if the device doesn't answer — so the
    setting auto-appears on any 0x8071 device that supports the cap, without
    needing per-model gating.
    """

    feature = _F.RGB_EFFECTS
    cap_id: int = 0

    _ENABLED_CHOICES = common.NamedInts(**{"On": 1, "Off": 2})
    _COLOR1_FIELD = {"name": "color1", "kind": settings.Kind.COLOR, "label": _("Primary")}
    _COLOR2_FIELD = {"name": "color2", "kind": settings.Kind.COLOR, "label": _("Secondary")}

    class rw_class:
        kind = settings.FeatureRW.kind

        def __init__(self, feature, cap_id):
            self.feature = feature
            self.cap_id = cap_id
            self._cap_bytes = bytes([(cap_id >> 8) & 0xFF, cap_id & 0xFF])

        def read(self, device):
            reply = device.feature_request(self.feature, 0x30, b"\x00" + self._cap_bytes)
            if reply is None or len(reply) < 10:
                return None
            return reply[3:10]  # strip [sub-fn, capHi, capLo] echo

        def write(self, device, data_bytes):
            return device.feature_request(self.feature, 0x30, b"\x01" + self._cap_bytes + bytes(data_bytes))

    @classmethod
    def build(cls, device):
        cap_bytes = bytes([(cls.cap_id >> 8) & 0xFF, cls.cap_id & 0xFF])
        try:
            reply = device.feature_request(_F.RGB_EFFECTS, 0x30, b"\x00" + cap_bytes)
        except exceptions.FeatureCallError:
            return None  # device rejects this cap — gate the setting off
        if reply is None or len(reply) < 10:
            return None
        # Register the firmware shutdown trigger on cap 0x0040 devices so the
        # animation plays on Solaar exit. This depends only on the device
        # having the cap (probe above), not on the UI control being shown —
        # so it runs before the allowlist gate below. rgb_power.cleanup fires
        # mode 0 at its end when _rgb_has_shutdown_cap is set. See
        # solaar_shutdown_effect_trigger_spec.md.
        if cls.cap_id == 0x0040:
            device._rgb_has_shutdown_cap = True
            if rgb_power.cleanup not in device.cleanups:
                device.cleanups.append(rgb_power.cleanup)
        # NVconfig-saved colors are default-DENY: the boot-effect setting is
        # shown only on models explicitly known-good. allowed is None on an
        # unlisted model/cap (suppress), or a (possibly empty) set of color
        # fields the firmware honors. SOLAAR_EXPERIMENTAL unmasks everything.
        allowed = device_quirks.rgb_effects_nvconfig_allowed_fields(device, cls.cap_id)
        if allowed is None:
            return None
        rw = cls.rw_class(cls.feature, cls.cap_id)
        validator = settings_validator.HeteroValidator(data_class=_RgbBootEffect, options=None)
        setting = cls(device, rw, validator)
        # Render the enabled byte as a right-aligned Gtk.Switch (like a plain
        # TOGGLE setting) rather than an inline Off/On combo. on_value/off_value
        # carry the wire-format byte (0x01 = on, 0x02 = off) through to the
        # data class without changing the byte semantics.
        id_field = {"name": "ID", "kind": settings.Kind.TOGGLE, "label": None, "on_value": 1, "off_value": 2}
        # Keep all color widgets in possible_fields so reads still populate
        # them and writes still carry their values — the firmware may store
        # bytes it doesn't visibly use. fields_map controls UI visibility.
        setting.possible_fields = [id_field, cls._COLOR1_FIELD, cls._COLOR2_FIELD]
        # An empty allowed set shows the On/Off toggle only (cap works, colors
        # don't); a non-empty set adds the listed color pickers.
        visible = {n: o for n, o in (("color1", 1), ("color2", 4)) if n in allowed}
        # Both On/Off map to the same visible field set so colors stay editable
        # when the effect is Off (pre-stages them for next enable).
        setting.fields_map = {
            int(cls._ENABLED_CHOICES["On"]): (cls._ENABLED_CHOICES["On"], visible),
            int(cls._ENABLED_CHOICES["Off"]): (cls._ENABLED_CHOICES["Off"], visible),
        }
        return setting


class RgbStartupAnimation(_RgbBootEffectSetting):
    name = "rgb_startup_animation"
    label = _("Startup Animation")
    description = (
        _(
            "Firmware-played animation when the keyboard wakes from deep sleep or powers on.\n"
            "Setting persists on the device (non-volatile)."
        )
        + "\n"
        + _("Device default: Primary #FF0081, Secondary #80AAFF.")
    )
    cap_id = 0x0001


class RgbShutdownAnimation(_RgbBootEffectSetting):
    name = "rgb_shutdown_animation"
    label = _("Shutdown Animation")
    description = (
        _("Firmware-played animation when the keyboard powers off.\n" "Setting persists on the device (non-volatile).")
        + "\n"
        + _("Device default: Primary #FF0081, Secondary #80AAFF.")
    )
    cap_id = 0x0040


class RGBEffectSetting(LEDZoneSetting):
    name = "rgb_zone_"  # the trailing underscore signals that this setting creates other settings
    label = _("LED Zone Effects")
    description = _("Set effect for LED Zone") + "\n" + _("LED Control needs to be enabled.")
    feature = _F.RGB_EFFECTS
    # 0x8071 firmware-fixes ramp/form bytes; drop those widgets here.
    possible_fields = [
        LEDZoneSetting.color_field,
        LEDZoneSetting.speed_field,
        LEDZoneSetting.period_field,
        LEDZoneSetting.intensity_field,
        LEDZoneSetting.saturation_field,
        LEDZoneSetting.direction_field,
    ]

    @classmethod
    def build(cls, device):
        return cls.setup(device, None, 0x10, b"\x01")

    def write(self, value, save=True):
        """Push zone effect to wire unless per-key is the dominant layer.

        Per-key acts as a multi-color sub-mode of Static: when zone is Static
        and per-key is opted in with paint, per-key owns the visible layer.
        Non-Static zone effects (animations) always go to the wire — per-key
        defers to the firmware animation. Transitions into Static still push
        the Static wire so any running animation stops.
        """
        assert hasattr(self, "_value")
        assert hasattr(self, "_device")
        assert value is not None
        device = self._device
        if not device.online:
            return None
        perkey, has_paint = rgb_power.perkey_has_paint(device)
        new_is_static = int(getattr(value, "ID", 0) or 0) == rgb_power._EFFECT_STATIC
        old_value = self._value
        old_is_static = old_value is None or int(getattr(old_value, "ID", 0) or 0) == rgb_power._EFFECT_STATIC
        if has_paint and new_is_static and old_is_static:
            if save:
                changed = old_value != value
                self.update(value, save)
                if changed and perkey._fill_unset_zones_with_base_color():
                    perkey._send_with_retry(0x70, b"\x00")  # FrameEnd
                    # Resync the dim ramp's start colors for unset cells.
                    mgr = rgb_power.get_manager(device)
                    if mgr is not None:
                        new_base = int(getattr(value, "color", 0) or 0)
                        unset_zones = perkey._unset_zone_ids()
                        if unset_zones:
                            mgr.notify_perkey_bulk_changed({z: new_base for z in unset_zones})
            return value
        # Persist undimmed value first (single source of truth).
        if self._value != value:
            self.update(value, save)
        # rgb_control gate: skip wire when the user has LED Control off.
        rgb_ctrl = next((s for s in device.settings if s.name == "rgb_control"), None)
        if rgb_ctrl is not None and not rgb_ctrl._value:
            return value
        wire_value = self._translate_for_wire(value)
        if wire_value is None:  # SLEEPING — _wake() will re-push at full brightness.
            return value
        current_value = None
        if self._validator.needs_current_value:
            current_value = self._rw.read(device)
        data_bytes = self._validator.prepare_write(wire_value, current_value)
        if data_bytes is None:
            return None
        reply = self._rw.write(device, data_bytes)
        if not reply:
            return None
        # Animation → Static transition with per-key paint: the Static wire
        # we just pushed stops the animation; now repaint the per-key
        # multi-color overlay on top so the user gets a seamless switch.
        if has_paint and new_is_static and perkey is not None:
            try:
                perkey.write(perkey._value, save=False)
            except Exception as e:
                logger.warning("%s: per-key repaint after Static restore failed: %s", device, e)
        # Resync any in-flight dim ramp to the new color.
        mgr = rgb_power.get_manager(device)
        if mgr is not None and getattr(value, "color", None) is not None and self._rw.prefix:
            mgr.notify_zone_changed(self._rw.prefix[0], int(value.color))
        return value

    def _translate_for_wire(self, value):
        """Clone `value` with `.color` translated through rgb_power state.
        Returns None for SLEEPING."""
        saved_color = getattr(value, "color", None)
        if saved_color is None:
            return value
        wire_color = rgb_power.translate_for_device(self._device, int(saved_color))
        if wire_color is None:
            return None
        if int(wire_color) == int(saved_color):
            return value  # ACTIVE or no-op translation; reuse original
        # Build a shallow clone with translated color so the persister and the
        # in-memory _value keep the undimmed source-of-truth color.
        wire_attrs = dict(value.__dict__)
        wire_attrs["color"] = int(wire_color)
        return hidpp20.LEDEffectSetting(**wire_attrs)


class PerKeyLighting(settings.Settings):
    name = "per-key-lighting"
    label = _("Per-key Lighting")
    description = (
        _("Control per-key lighting.")
        + "\n"
        + _("LED Control needs to be enabled and the zone effect set to Static for per-key paint to be visible.")
    )
    feature = _F.PER_KEY_LIGHTING_V2
    keys_universe = special_keys.KEYCODES
    editor_class = "solaar.ui.perkey.control:PerKeyControl"
    # 0x8081 has no GetIndividualRgbZones — there's no way to ask the device
    # what colors are currently on the per-key buffer. read() returns the
    # canonical in-memory map for callers that need a value, but `solaar show`
    # honors this flag and skips its live-read line to avoid misleading output.
    live_readable = False

    @staticmethod
    def _wrap_color(value):
        # Wrap raw 24-bit-range ints in ColorInt so saved configs render as
        # ``0xrrggbb`` hex literals and `solaar show` prints hex. Sentinels
        # (NamedInt "No change" = -1) and existing ColorInt values pass
        # through untouched.
        # type(value) is int — exact match excludes NamedInt sentinels like
        # COLORSPLUS["No change"] = -1 and avoids re-wrapping ColorInts.
        if type(value) is int and 0 <= value <= 0xFFFFFF:  # noqa: E721
            return common.ColorInt(value)
        return value

    def update(self, value, save=True):
        if isinstance(value, dict):
            value = {k: self._wrap_color(v) for k, v in value.items()}
        super().update(value, save)

    def update_key_value(self, key, value, save=True):
        super().update_key_value(key, self._wrap_color(value), save)

    def _sw_control_held(self):
        """Return True if it's safe to push LED bytes to the wire.

        rgb_control is the gate: when the user has it off, LED writes must be
        silent no-ops at the wire. Never auto-flip it on from here — doing so
        rewrites the persister and turns the user-facing toggle into a lie."""
        if getattr(self, "_has_rgb_effects", None) is None:
            self._has_rgb_effects = bool(self._device.features and _F.RGB_EFFECTS in self._device.features)
        if not self._has_rgb_effects:
            return True  # No autonomous effect engine, no gate needed
        for s in self._device.settings:
            if s.name == "rgb_control":
                # _value may be bool (current) or int 3/0 (legacy persister value
                # before BooleanValidator migration); both coerce cleanly.
                return bool(s._value)
        return True  # rgb_control not on this device → no gate to enforce

    # BUSY-retry backoff (ms).
    _BUSY_BACKOFF_MS = (30, 60, 90)

    def _send_with_retry(self, function, data, retries=3):
        # Retry on BUSY and timeout (both transient). Other FeatureCallError
        # codes abort — they're real bugs we shouldn't paper over.
        busy_attempt = 0
        max_busy = len(self._BUSY_BACKOFF_MS)
        for attempt in range(retries + 1):
            try:
                reply = self._device.feature_request(self.feature, function, data)
            except exceptions.FeatureCallError as e:
                if getattr(e, "error", None) == hidpp20_constants.ErrorCode.BUSY and busy_attempt < max_busy:
                    delay_ms = self._BUSY_BACKOFF_MS[busy_attempt]
                    busy_attempt += 1
                    if logger.isEnabledFor(logging.DEBUG):
                        logger.debug(
                            "%s: per-key 0x%02x BUSY, retry %d/%d after %dms",
                            self._device,
                            function,
                            busy_attempt,
                            max_busy,
                            delay_ms,
                        )
                    sleep(delay_ms / 1000.0)
                    continue
                logger.warning("%s: per-key 0x%02x rejected by device", self._device, function)
                return False
            if reply is not None:
                if (attempt > 0 or busy_attempt > 0) and logger.isEnabledFor(logging.DEBUG):
                    logger.debug(
                        "%s: per-key 0x%02x succeeded after %d timeout retries, %d BUSY retries",
                        self._device,
                        function,
                        attempt,
                        busy_attempt,
                    )
                return True
            if logger.isEnabledFor(logging.DEBUG):
                logger.debug(
                    "%s: per-key 0x%02x timed out (attempt %d/%d)",
                    self._device,
                    function,
                    attempt + 1,
                    retries + 1,
                )
        return False

    def _zone_base_color(self):
        """Color used to fill per-key unset cells. Defers to
        rgb_power.effective_zone_base_color which returns black when the
        zone effect is ignored, otherwise the saved zone color."""
        return rgb_power.effective_zone_base_color(self._device)

    def _send_zone_color(self, zone_id, wire_color):
        """Emit a single-zone color update (fn 0x10). `wire_color` is the
        already-translated color that should appear on the device."""
        r = (wire_color >> 16) & 0xFF
        g = (wire_color >> 8) & 0xFF
        b = wire_color & 0xFF
        return self._send_with_retry(0x10, bytes([zone_id, r, g, b]))

    def _unset_zone_ids(self):
        """Per-key zone IDs that don't have a user-painted color."""
        no_change = special_keys.COLORSPLUS["No change"]
        user_set = set()
        if self._value:
            for key, color in self._value.items():
                if color != no_change and isinstance(color, int) and color >= 0:
                    user_set.add(int(key))
        return [int(k) for k in self._validator.choices if int(k) not in user_set]

    def _fill_unset_zones_with_base_color(self):
        """Push the zone base color (translated for current power state) to
        any per-key cell the user hasn't painted. Caller commits FrameEnd."""
        if not self._has_rgb_effects:
            return True
        zone_base = self._zone_base_color()
        wire_base = rgb_power.translate_for_device(self._device, zone_base)
        if wire_base is None:
            return True  # SLEEPING — caller defers wire entirely
        r = (wire_base >> 16) & 0xFF
        g = (wire_base >> 8) & 0xFF
        b = wire_base & 0xFF
        unset_zones = self._unset_zone_ids()
        if not unset_zones:
            return True
        remaining = list(unset_zones)
        ok = True
        while remaining:
            batch = remaining[:13]
            remaining = remaining[13:]
            if not self._send_with_retry(0x60, bytes([r, g, b]) + bytes(batch)):
                ok = False
        return ok

    def read(self, cached=True):
        # The 0x8081 protocol has no GetIndividualRgbZones — the device cannot
        # report its current per-key buffer back. So a "live" read is fictional:
        # we either return what we last wrote (the persisted/in-memory map,
        # which is the canonical truth for this setting) or, on a fresh device
        # with no persisted state, fabricate an all-"No change" sentinel map
        # as the starting point. Returning the cached value unconditionally
        # also fixes `solaar show` showing every key as "No change" on the
        # live line — it now matches what's actually on the keyboard.
        self._pre_read(cached)
        if self._value is not None:
            return self._value
        reply_map = {}
        for key in self._validator.choices:
            reply_map[int(key)] = special_keys.COLORSPLUS["No change"]  # starting state, no per-key write yet
        self._value = reply_map
        return reply_map

    def _send_perkey_frame(self, map, no_change):
        """Send all per-key sub-packets for `map`, fill unset cells with the
        zone base color, and commit with FrameEnd. Returns True on success."""
        # Bucket by color; single-bucket allows the range-update fast path.
        table = {}
        for key, value in map.items():
            if value in table:
                table[value].append(key)
            else:
                table[value] = [key]
        ok = True
        if len(table) == 1:  # use range update
            for value, keys in table.items():  # only one, of course
                if value != no_change:  # this signals no change, so don't update at all
                    wire = rgb_power.translate_for_device(self._device, int(value))
                    data_bytes = keys[0].to_bytes(1, "big") + keys[-1].to_bytes(1, "big") + wire.to_bytes(3, "big")
                    if not self._send_with_retry(0x50, data_bytes):  # range update command to update all keys
                        ok = False
        else:
            data_bytes = b""
            for value, keys in table.items():
                if value != no_change:  # this signals no change, so ignore it
                    wire = rgb_power.translate_for_device(self._device, int(value))
                    while len(keys) > 3:  # use an optimized update command that can update up to 13 keys
                        data = wire.to_bytes(3, "big") + b"".join([key.to_bytes(1, "big") for key in keys[0:13]])
                        if not self._send_with_retry(0x60, data):  # single-value multiple-keys update
                            ok = False
                        keys = keys[13:]
                    for key in keys:
                        data_bytes += key.to_bytes(1, "big") + wire.to_bytes(3, "big")
                        if len(data_bytes) >= 16:  # up to four values are packed into a regular update
                            if not self._send_with_retry(0x10, data_bytes):
                                ok = False
                            data_bytes = b""
            if len(data_bytes) > 0:  # update any remaining keys
                if not self._send_with_retry(0x10, data_bytes):
                    ok = False
        # Fill unset zones before FrameEnd so the frame commits atomically.
        if not self._fill_unset_zones_with_base_color():
            ok = False
        # Suppress FrameEnd on partial failure to avoid a visibly wrong commit.
        if ok:
            if not self._send_with_retry(0x70, b"\x00"):
                logger.warning("%s: per-key FrameEnd failed; frame not committed", self._device)
                ok = False
        else:
            logger.warning(
                "%s: per-key frame had failed sub-packets; suppressing FrameEnd to avoid partial commit",
                self._device,
            )
        return ok

    def write(self, map, save=True):
        if self._device.online:
            # Persist undimmed (single source of truth).
            self.update(map, save)
            if not self._sw_control_held():
                return map  # gate is off — keep state in memory, skip the wire
            # Per-key is a sub-mode of Static — when zone is animating, the
            # firmware engine owns the visible layer.
            if not rgb_power.zone_effect_is_static(self._device):
                return map
            no_change = special_keys.COLORSPLUS["No change"]
            # SLEEPING — defer wire to wake.
            for value in map.values():
                if value != no_change and rgb_power.translate_for_device(self._device, int(value)) is None:
                    return map
            # Mouse-only prep, one-shot per claim — keyboards don't need it.
            if (
                getattr(self, "_has_rgb_effects", False)
                and not getattr(self, "_prep_pushed", False)
                and int(getattr(self._device, "kind", -1) or -1) == int(hidpp10_constants.DEVICE_KIND.mouse)
            ):
                if rgb_power.push_artanis_perkey_prep(self._device):
                    self._prep_pushed = True
            ok = self._send_perkey_frame(map, no_change)
            # First frame after a claim sometimes lands before the firmware
            # has fully transitioned out of onboard mode — replay it once.
            if ok and not getattr(self, "_frame_settled", False):
                self._send_perkey_frame(map, no_change)
                self._frame_settled = True
            if ok:
                mgr = rgb_power.get_manager(self._device)
                if mgr is not None:
                    mgr.notify_perkey_bulk_changed(map)
        return map

    def write_key_value(self, key, value, save=True):
        no_change = special_keys.COLORSPLUS["No change"]
        zone_id = int(key)
        if value != no_change:
            self.update_key_value(zone_id, value, save)
            if not self._device.online:
                return value
            if not self._sw_control_held():
                return value  # gate is off — state stored, no wire push
            # Per-key is a sub-mode of Static — defer to firmware animation.
            if not rgb_power.zone_effect_is_static(self._device):
                return value
            wire = rgb_power.translate_for_device(self._device, int(value))
            if wire is None:
                return value  # SLEEPING — wake re-pushes
            ok = True
            # Fill unset zones once so they don't show white-default.
            if not getattr(self, "_base_filled", False):
                if self._fill_unset_zones_with_base_color():
                    self._base_filled = True
                else:
                    ok = False
            if ok and not self._send_zone_color(zone_id, wire):
                ok = False
            if ok:
                mgr = rgb_power.get_manager(self._device)
                if mgr is not None:
                    mgr.notify_perkey_changed(zone_id, int(value))
                if not self._send_with_retry(0x70, b"\x00"):
                    logger.warning("%s: per-key FrameEnd failed; frame not committed", self._device)
            else:
                logger.warning("%s: per-key write failed; suppressing FrameEnd", self._device)
            return value
        else:
            # Un-set: store "No change", push the zone base color to that cell.
            self.update_key_value(zone_id, no_change, save)
            if not self._device.online:
                return no_change
            if not self._sw_control_held():
                return no_change  # gate is off — state stored, no wire push
            if not rgb_power.zone_effect_is_static(self._device):
                return no_change
            zone_base = self._zone_base_color()
            wire_base = rgb_power.translate_for_device(self._device, zone_base)
            if wire_base is None:
                return no_change
            if self._send_zone_color(zone_id, wire_base):
                mgr = rgb_power.get_manager(self._device)
                if mgr is not None:
                    mgr.notify_perkey_changed(zone_id, zone_base)
                if not self._send_with_retry(0x70, b"\x00"):
                    logger.warning("%s: per-key FrameEnd failed; frame not committed", self._device)
            else:
                logger.warning("%s: per-key un-set write failed; suppressing FrameEnd", self._device)
            return no_change

    class rw_class(settings.FeatureRWMap):
        pass

    class validator_class(settings_validator.MapRangeValidator):
        _COLOR_RANGE = settings_validator.Range(min=0, max=0xFFFFFF, byte_count=3, value_type=common.ColorInt)

        @classmethod
        def build(cls, setting_class, device):
            choices_map = {}
            key_bitmap = device.feature_request(setting_class.feature, 0x00, 0x00, 0x00)[2:]
            key_bitmap += device.feature_request(setting_class.feature, 0x00, 0x00, 0x01)[2:]
            key_bitmap += device.feature_request(setting_class.feature, 0x00, 0x00, 0x02)[2:]
            for i in range(1, 255):
                if (key_bitmap[i // 8] >> i % 8) & 0x01:
                    key = (
                        setting_class.keys_universe[i]
                        if i in setting_class.keys_universe
                        else common.NamedInt(i, f"KEY {str(i)}")
                    )
                    choices_map[key] = cls._COLOR_RANGE
            return cls(choices_map) if choices_map else None


# Allow changes to force sensing buttons
class ForceSensing(settings_new.Settings):
    name = "force-sensing"
    label = _("Force Sensing Buttons")
    description = _("Change the force required to activate button.")
    feature = _F.FORCE_SENSING_BUTTON
    setup = "force_buttons"
    get = "get_current"
    set = "set_current"
    acceptable = "acceptable_current_key"
    choices_universe = list(range(0, 256))
    kind = settings.Kind.MAP_RANGE

    @classmethod
    def build(cls, device):
        cls.check_properties(cls)
        device_object = getattr(device, cls.setup)()
        if device_object:
            setting = cls(device, device_object)
            if setting and len(device_object) == 1:
                ## If there is only one force button a simpler interface can be used
                setting.label = _("Force Sensing Button")
                setting.acceptable = "acceptable_current"
                setting.min_value = device_object[0].min_value
                setting.max_value = device_object[0].max_value
                setting.kind = settings.Kind.RANGE
            return setting


# Analog button tuning settings (actuation point, rapid trigger, haptics)
#
# Bytes 1 (actuation), 2 (rapid trigger), 3 (haptics) of the 0x1B0C config struct
# pack a logical value in bits 7..2 (i.e. wire = logical << 2). Byte 2 bit 0 is a
# firmware-managed sensitivityFlag that must be preserved across writes; all other
# low-order bits are reserved and must be zero. Sending a wire byte that doesn't
# match this layout produces INVALID_ARGUMENT — see issue #3202.


class _AnalogButtonActuationRW(settings.FeatureRW):
    """RW for analog button actuation point per button."""

    def __init__(self, feature, button_index):
        super().__init__(feature, read_fnid=0x20, write_fnid=0x10)
        self.button_index = button_index

    def read(self, device, data_bytes=b""):
        res = device.feature_request(self.feature, 0x20, self.button_index)
        if not res:
            return b"\x05"  # default mid-point (logical)
        return bytes([res[1] >> 2])

    def write(self, device, data_bytes):
        current = device.feature_request(self.feature, 0x20, self.button_index)
        if not current:
            return None
        wire_act = (data_bytes[0] & 0x3F) << 2
        return device.feature_request(self.feature, 0x10, self.button_index, wire_act, current[2], current[3])


class _AnalogButtonRapidTriggerRW(settings.FeatureRW):
    """RW for analog button rapid trigger sensitivity per button."""

    def __init__(self, feature, button_index):
        super().__init__(feature, read_fnid=0x20, write_fnid=0x10)
        self.button_index = button_index

    def read(self, device, data_bytes=b""):
        res = device.feature_request(self.feature, 0x20, self.button_index)
        if not res:
            return b"\x03"  # default mid-point (logical)
        return bytes([res[2] >> 2])

    def write(self, device, data_bytes):
        current = device.feature_request(self.feature, 0x20, self.button_index)
        if not current:
            return None
        # Preserve the firmware-managed sensitivityFlag (byte 2 bit 0).
        wire_rt = ((data_bytes[0] & 0x3F) << 2) | (current[2] & 0x01)
        return device.feature_request(self.feature, 0x10, self.button_index, current[1], wire_rt, current[3])


class _AnalogButtonHapticsRW(settings.FeatureRW):
    """RW for analog button click haptics per button."""

    def __init__(self, feature, button_index):
        super().__init__(feature, read_fnid=0x20, write_fnid=0x10)
        self.button_index = button_index

    def read(self, device, data_bytes=b""):
        res = device.feature_request(self.feature, 0x20, self.button_index)
        if not res:
            return b"\x03"  # default mid-point (logical)
        return bytes([res[3] >> 2])

    def write(self, device, data_bytes):
        current = device.feature_request(self.feature, 0x20, self.button_index)
        if not current:
            return None
        wire_haptics = (data_bytes[0] & 0x3F) << 2
        return device.feature_request(self.feature, 0x10, self.button_index, current[1], current[2], wire_haptics)


class _AnalogButtonSetting(settings.Setting):
    """Setting subclass that migrates legacy raw-byte persisted values.

    Solaar 1.1.19 stored the wire byte (logical value × 4) under these names. After
    the encoding fix, the same key holds the logical value. If a stored value is
    above the new max but a divide-by-4 lands inside the valid range, treat it as
    legacy raw and migrate in place — this prevents apply() from raising
    INVALID_ARGUMENT/ValueError on first run after upgrade.
    """

    def _pre_read(self, cached, key=None):
        super()._pre_read(cached, key)
        if self._value is None or not isinstance(self._value, int):
            return
        validator = self._validator
        if self._value > validator.max_value and (self._value & 0x03) == 0:
            migrated = self._value >> 2
            if validator.min_value <= migrated <= validator.max_value:
                if logger.isEnabledFor(logging.INFO):
                    logger.info(
                        "%s: migrating legacy raw value %d to logical %d on %s",
                        self.name,
                        self._value,
                        migrated,
                        self._device,
                    )
                self._value = migrated
                if getattr(self._device, "persister", None) is not None:
                    self._device.persister[self.name] = self._value


class AnalogButtonTuning(settings.Setting):
    """Analog button tuning: actuation point, rapid trigger, and haptics configuration."""

    name = "analog-button-tuning"
    label = _("Analog Button Tuning")
    description = _("Configure analog button settings including actuation point, rapid trigger, and haptics.")
    feature = _F.ANALOG_BUTTONS

    @classmethod
    def build(cls, device):
        if cls.feature not in device.features:
            return None
        # Capabilities: [flags, button_count, max_act<<2, max_rt<<2, max_haptics<<2, ...]
        caps = device.feature_request(cls.feature, 0x00)
        if not caps or len(caps) < 5:
            return None
        button_count = min(caps[1], 2)  # firmware reports 3; only L/R are user-accessible
        max_actuation = (caps[2] >> 2) if caps[2] > 0 else 10
        max_rt_level = (caps[3] >> 2) if caps[3] > 0 else 5
        max_haptics = (caps[4] >> 2) if caps[4] > 0 else 5

        if button_count == 0:
            return None

        button_names = [_("Left Button"), _("Right Button")]
        all_settings = []

        for i in range(button_count):
            btn_name = button_names[i] if i < len(button_names) else f"Button {i}"

            rw_act = _AnalogButtonActuationRW(cls.feature, i)
            val_act = settings_validator.RangeValidator(min_value=1, max_value=max_actuation)
            s_act = _AnalogButtonSetting(device, rw_act, val_act)
            s_act.name = f"analog-button-tuning_actuation-{i}"
            s_act.label = f"{btn_name} Actuation Point"
            s_act.description = _("Actuation point depth (1=shallow, %d=deep).") % max_actuation
            all_settings.append(s_act)

            rw_rt = _AnalogButtonRapidTriggerRW(cls.feature, i)
            val_rt = settings_validator.RangeValidator(min_value=1, max_value=max_rt_level)
            s_rt = _AnalogButtonSetting(device, rw_rt, val_rt)
            s_rt.name = f"analog-button-tuning_rapid-trigger-{i}"
            s_rt.label = f"{btn_name} Rapid Trigger"
            s_rt.description = _("Rapid trigger sensitivity (1..%d).") % max_rt_level
            all_settings.append(s_rt)

            rw_haptics = _AnalogButtonHapticsRW(cls.feature, i)
            val_haptics = settings_validator.RangeValidator(min_value=0, max_value=max_haptics)
            s_haptics = _AnalogButtonSetting(device, rw_haptics, val_haptics)
            s_haptics.name = f"analog-button-tuning_haptics-{i}"
            s_haptics.label = f"{btn_name} Click Haptics"
            s_haptics.description = _("Click haptic feedback intensity (0=off, %d=max).") % max_haptics
            all_settings.append(s_haptics)

        return all_settings if all_settings else None


class HapticLevel(settings.Setting):
    name = "haptic-level"
    label = _("Haptic Feedback Level")
    description = _("Change power of haptic feedback.  (Zero to turn off.)")
    feature = _F.HAPTIC
    choices_universe = common.NamedInts(Off=0, Low=25, Medium=50, High=75, Maximum=100)
    min_value = 0
    max_value = 100

    class rw_class(settings.FeatureRW):
        def __init__(self, feature):
            super().__init__(feature, read_fnid=0x10, write_fnid=0x20)

        def read(self, device, data_bytes=b""):
            result = device.feature_request(self.feature, 0x10)
            if result[0] & 0x01 == 0:  # disabled, return 0
                return b"\x00"
            else:  # enabled, return second byte
                return result[1:2]

        def write(self, device, data_bytes):
            if data_bytes == b"\x00":
                write_bytes = b"\x00\x32"  # disable, at 50 percent
            else:
                write_bytes = b"\x01" + data_bytes
            reply = device.feature_request(self.feature, 0x20, write_bytes)
            return reply

    @classmethod
    def build(cls, device):
        response = device.feature_request(cls.feature, 0x10)
        if response:
            rw = cls.rw_class(cls.feature)
            levels = response[2] & 0x01
            if levels:  # device only has four levels
                validator = settings_validator.ChoicesValidator(choices=cls.choices_universe)
            else:  # device has all levels
                validator = settings_validator.RangeValidator(min_value=cls.min_value, max_value=cls.max_value)
            return cls(device, rw, validator)


# This setting is not displayed in the UI
# Use `solaar config <device> haptic-play <form>` to play a haptic form
class PlayHapticWaveForm(settings.Setting):
    name = "haptic-play"
    label = _("Play Haptic Waveform")
    description = _("Tell device to play a haptic waveform.")
    feature = _F.HAPTIC
    choices_universe = hidpp20_constants.HapticWaveForms
    rw_options = {"read_fnid": None, "write_fnid": 0x40}  # nothing to read
    persist = False  # persisting this setting is useless
    display = False  # don't display in UI, interact using `solaar config ...`

    class validator_class(settings_validator.ChoicesValidator):
        @classmethod
        def build(cls, setting_class, device):
            response = device.feature_request(_F.HAPTIC, 0x00)
            if response:
                waves = common.NamedInts()
                waveforms = int.from_bytes(response[4:8])
                for waveform in hidpp20_constants.HapticWaveForms:
                    if (1 << int(waveform)) & waveforms:
                        waves[int(waveform)] = str(waveform)
            return cls(choices=waves, byte_count=1)


SETTINGS: list[settings.Setting] = [
    RegisterHandDetection,  # simple
    RegisterSmoothScroll,  # simple
    RegisterSideScroll,  # simple
    RegisterDpi,
    RegisterFnSwap,  # working
    HiResScroll,  # simple
    LowresMode,  # simple
    HiresSmoothInvert,  # working
    HiresSmoothResolution,  # working
    HiresMode,  # simple
    ScrollRatchet,  # simple
    ScrollRatchetTorque,
    SmartShift,  # working
    ScrollRatchetEnhanced,
    SmartShiftEnhanced,  # simple
    ThumbInvert,  # working
    ThumbMode,  # working
    OnboardProfiles,
    ReportRate,  # working
    ExtendedReportRate,
    PointerSpeed,  # simple
    AdjustableDpi,  # working
    ExtendedAdjustableDpi,
    SpeedChange,
    #    Backlight,  # not working - disabled temporarily
    Backlight2,  # working
    Backlight2Level,
    Backlight2DurationHandsOut,
    Backlight2DurationHandsIn,
    Backlight2DurationPowered,
    Backlight3,
    LEDControl,
    LEDZoneSetting,
    RGBControl,
    RGBEffectSetting,
    PerKeyLighting,
    BrightnessControl,
    RGBIdleEffect,
    RGBIdleTimeout,
    RGBSleepTimeout,
    RgbStartupAnimation,
    RgbShutdownAnimation,
    FnSwap,  # simple
    NewFnSwap,  # simple
    K375sFnSwap,  # working
    ReprogrammableKeys,  # working
    PersistentRemappableAction,
    DivertKeys,  # working
    DisableKeyboardKeys,  # working
    ForceSensing,
    CrownSmooth,  # working
    DivertCrown,  # working
    DivertGkeys,  # working
    MKeyLEDs,  # working
    MRKeyLED,  # working
    Multiplatform,  # working
    DualPlatform,  # simple
    ChangeHost,  # working
    Gesture2Gestures,  # working
    Gesture2Divert,
    Gesture2Params,  # working
    AnalogButtonTuning,
    HapticLevel,
    PlayHapticWaveForm,
    Sidetone,
    Equalizer,
    ADCPower,
    HeadsetEcoMode,
    HeadsetDoNotDisturb,
    HeadsetMicMute,
    HeadsetMicSNR,
    HeadsetAINR,
    HeadsetAINRLevel,
    HeadsetSidetone,
    HeadsetMicGain,
    HeadsetMixBalance,
    HeadsetAutoSleep,
    HeadsetOnboardEQ,
    HeadsetActiveEQPreset,
    HeadsetAdvancedEQ,
    HeadsetLEDControl,
    HeadsetOnboardEffect,
    HeadsetPerZoneLighting,
    HeadsetSignatureStartupEffect,
    HeadsetSignatureShutdownEffect,
    HeadsetSignaturePassiveEffect,
    *_LOGIVOICE_SETTINGS,
]


class SettingsProtocol(Protocol):
    @property
    def name(self):
        ...

    @property
    def label(self):
        ...

    @property
    def description(self):
        ...

    @property
    def feature(self):
        ...

    @property
    def register(self):
        ...

    @property
    def kind(self):
        ...

    @property
    def min_version(self):
        ...

    @property
    def persist(self):
        ...

    @property
    def rw_options(self):
        ...

    @property
    def validator_class(self):
        ...

    @property
    def validator_options(self):
        ...

    @classmethod
    def build(cls, device):
        ...

    def val_to_string(self, value):
        ...

    @property
    def choices(self):
        ...

    @property
    def range(self):
        ...

    def _pre_read(self, cached, key=None):
        ...

    def read(self, cached=True):
        ...

    def _pre_write(self, save=True):
        ...

    def update(self, value, save=True):
        ...

    def write(self, value, save=True):
        ...

    def acceptable(self, args, current):
        ...

    def compare(self, args, current):
        ...

    def apply(self):
        ...

    def __str__(self):
        ...


def check_feature(device, settings_class: SettingsProtocol) -> None | bool | SettingsProtocol:
    if settings_class.feature not in device.features:
        return
    if settings_class.min_version > device.features.get_feature_version(settings_class.feature):
        logger.debug(
            "check_feature %s [%s]: min_version=%d > device feature version=%d; skipping",
            settings_class.name,
            settings_class.feature,
            settings_class.min_version,
            device.features.get_feature_version(settings_class.feature) or 0,
        )
        return
    if device.features.get_hidden(settings_class.feature):
        flags = device.features.flags.get(settings_class.feature, 0)
        logger.debug(
            "check_feature %s [%s]: feature has INTERNAL flag set (flags=0x%02X); skipping",
            settings_class.name,
            settings_class.feature,
            flags,
        )
        return
    try:
        detected = settings_class.build(device)
        if logger.isEnabledFor(logging.DEBUG):
            logger.debug("check_feature %s [%s] detected", settings_class.name, settings_class.feature)
        return detected
    except Exception as e:
        logger.error(
            "check_feature %s [%s] error %s\n%s", settings_class.name, settings_class.feature, e, traceback.format_exc()
        )
        raise e  # differentiate from an error-free determination that the setting is not supported


def check_feature_settings(device, already_known) -> bool:
    """Auto-detect device settings by the HID++ 2.0 features they have.

    Returns
    -------
    bool
        True, if device was fully queried to find features, False otherwise.
    """
    if not device.features or not device.online:
        return False
    if device.protocol and device.protocol < 2.0:
        return False
    absent = device.persister.get("_absent", []) if device.persister else []
    new_absent = []
    for sclass in SETTINGS:
        if sclass.feature:
            if device.persister:
                if sclass.name.endswith("_"):
                    # Multi-setting prototype (e.g. rgb_zone_); persister stores child keys
                    # like rgb_zone_1, never the prototype name itself.
                    known_present = any(k.startswith(sclass.name) for k in device.persister)
                else:
                    known_present = sclass.name in device.persister
            else:
                known_present = False
            already = any(s.name == sclass.name for s in already_known)
            if already:
                continue
            if not known_present and sclass.name in absent:
                # Silent-skip cache from an earlier run's failed build(). If the
                # feature is actually present on this device now, the cache is
                # stale (e.g. from a prior build that returned None for a
                # feature that currently works) — drop it and retry the probe.
                if sclass.feature in device.features:
                    logger.debug(
                        "check_feature_settings: retrying %s — cached in _absent but feature %s is present now",
                        sclass.name,
                        sclass.feature,
                    )
                    absent.remove(sclass.name)
                    if device.persister:
                        device.persister["_absent"] = absent
                else:
                    continue
            try:
                setting = check_feature(device, sclass)
            except Exception as err:
                # on an internal HID++ error, assume offline and stop further checking
                if isinstance(err, exceptions.FeatureCallError) and err.error == hidpp20_constants.ErrorCode.LOGITECH_ERROR:
                    logger.warning(f"HID++ internal error checking feature {sclass.name}: make device not present")
                    device.online = False
                    device.present = False
                    return False
                else:
                    logger.warning(f"ignore feature {sclass.name} because of error {err}")

            if isinstance(setting, list):
                for s in setting:
                    already_known.append(s)
                if sclass.name in new_absent:
                    new_absent.remove(sclass.name)
            elif setting:
                already_known.append(setting)
                if sclass.name in new_absent:
                    new_absent.remove(sclass.name)
            elif setting is None:
                if sclass.name not in new_absent and sclass.name not in absent and sclass.name not in device.persister:
                    new_absent.append(sclass.name)
    if device.persister and new_absent:
        absent.extend(new_absent)
        device.persister["_absent"] = absent
    return True


def check_feature_setting(device, setting_name: str) -> settings.Setting | None:
    for sclass in SETTINGS:
        if (
            sclass.feature
            and device.features
            and (sclass.name == setting_name or sclass.name.endswith("_") and setting_name.startswith(sclass.name))
        ):
            try:
                setting = check_feature(device, sclass)
            except Exception:
                return None
            if isinstance(setting, list):
                for s in setting:
                    if s.name == setting_name:
                        return s
            elif setting:
                return setting
