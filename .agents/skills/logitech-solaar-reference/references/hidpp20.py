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
from __future__ import annotations

import logging
import socket
import struct
import threading

from collections import UserDict
from enum import Flag
from enum import IntEnum
from random import getrandbits
from typing import Any
from typing import Dict
from typing import Generator
from typing import Optional
from typing import Tuple

import yaml

from solaar.i18n import _
from typing_extensions import Protocol

from . import centurion as _centurion
from . import common
from . import exceptions
from . import hidpp10_constants
from . import special_keys
from .centurion_constants import CenturionCoreFeature
from .centurion_constants import resolve_feature
from .common import Battery
from .common import BatteryLevelApproximation
from .common import BatteryStatus
from .common import FirmwareKind
from .common import NamedInt
from .hidpp20_constants import DEVICE_KIND
from .hidpp20_constants import ChargeLevel
from .hidpp20_constants import ChargeType
from .hidpp20_constants import ErrorCode
from .hidpp20_constants import FeatureFlag
from .hidpp20_constants import GestureId
from .hidpp20_constants import ParamId
from .hidpp20_constants import SupportedFeature

logger = logging.getLogger(__name__)

FixedBytes5 = bytes

KIND_MAP = {kind: hidpp10_constants.DEVICE_KIND[str(kind)] for kind in DEVICE_KIND}


class Device(Protocol):
    def feature_request(self, feature, function=0x00, *params, no_reply=False) -> Any:
        ...

    @property
    def features(self) -> Any:
        ...

    @property
    def _gestures(self) -> Any:
        ...

    @property
    def _backlight(self) -> Any:
        ...

    @property
    def _profiles(self) -> Any:
        ...


# pfps: Consider adding a class method that sanitizes inputs by removing unknown bits.


class KeyFlag(Flag):
    """Capabilities and desired software handling for a control.

    Ref: https://drive.google.com/file/d/10imcbmoxTJ1N510poGdsviEhoFfB_Ua4/view
    We treat bytes 4 and 8 of `getCidInfo` as a single bitfield.
    """

    UNUSED_8000 = 0x8000
    UNUSED_4000 = 0x4000
    UNUSED_2000 = 0x2000
    UNUSED_1000 = 0x1000
    RAW_WHEEL = 0x800
    ANALYTICS_KEY_EVENTS = 0x400
    FORCE_RAW_XY = 0x200
    RAW_XY = 0x100
    VIRTUAL = 0x80
    PERSISTENTLY_DIVERTABLE = 0x40
    DIVERTABLE = 0x20
    REPROGRAMMABLE = 0x10
    FN_SENSITIVE = 0x08
    NONSTANDARD = 0x04
    IS_FN = 0x02
    MSE = 0x01


class MappingFlag(Flag):
    """Flags describing the reporting method of a control.

    We treat bytes 2 and 5 of `get/setCidReporting` as a single bitfield
    """

    UNUSED_4000 = 0x4000
    UNUSED_1000 = 0x1000
    RAW_WHEEL = 0x400
    UNKNOWN_200 = 0x200  # seen on a Wireless Mouse M510 WPID 4004
    ANALYTICS_KEY_EVENTS_REPORTING = 0x100
    FORCE_RAW_XY_DIVERTED = 0x40
    RAW_XY_DIVERTED = 0x10
    PERSISTENTLY_DIVERTED = 0x04
    DIVERTED = 0x01


class ChargeStatus(Flag):
    CHARGING = 0x00
    FULL = 0x01
    NOT_CHARGING = 0x02
    ERROR = 0x07


class FeaturesArray(dict):
    def __init__(self, device):
        assert device is not None
        self.supported = True  # Actually don't know whether it is supported yet
        self.device = device
        self.inverse = {}
        self.sub_inverse = {}
        self.version = {}
        self.flags = {}
        self.count = 0

    def _check(self) -> bool:
        if not self.device.online:
            return False
        if self.supported is False:
            return False
        if self.device.protocol and self.device.protocol < 2.0:
            self.supported = False
            return False
        if self.count > 0:
            return True
        reply = self.device.request(0x0000, struct.pack("!H", SupportedFeature.FEATURE_SET))
        if reply is not None:
            fs_index = reply[0]
            if fs_index:
                count = self.device.request(fs_index << 8)
                if count is None:
                    logger.warning("FEATURE_SET found, but failed to read features count")
                    return False
                else:
                    self[SupportedFeature.ROOT] = 0
                    self[SupportedFeature.FEATURE_SET] = fs_index
                    if getattr(self.device, "centurion", False):
                        self._check_centurion(fs_index, count)
                    else:
                        self.count = count[0] + 1  # ROOT feature not included in count
                    return True
            else:
                self.supported = False
        return False

    def _check_centurion(self, fs_index, count_response):
        """Enumerate features on a Centurion device (parent + sub-device via CentPPBridge).

        Phase A: Enumerate parent device features via CenturionFeatureSet.
                 Find the CentPPBridge index (feature ID 0x0003 on Centurion = CentPPBridge).
        Phase B: Route through CentPPBridge to discover sub-device features.
                 Use CenturionFeatureSet bulk query to get all sub-device features.
                 Store sub-device features keyed by SupportedFeature enum.
        """
        # Phase A: Parent features
        feature_count = count_response[0]  # includes ROOT on Centurion
        self.count = feature_count
        bridge_index = None
        for index in range(feature_count):
            if self.inverse.get(index) is not None:
                continue  # already registered (ROOT=0, FEATURE_SET=fs_index)
            response = self.device.request((fs_index << 8) | 0x10, index)
            if response is None or len(response) < 3:
                continue
            # Centurion FeatureSet response: [remaining_count, feat_hi, feat_lo, type, version]
            feat_id = struct.unpack("!H", response[1:3])[0]
            feat_type = response[3] if len(response) > 3 else 0
            feat_version = response[4] if len(response) > 4 else 0
            feature = resolve_feature(feat_id, centurion=True)
            if feature is None:
                feature = f"unknown:{feat_id:04X}"
            self[feature] = index
            self.inverse[index] = feature
            # Record version/flags so version-gated settings (sidetone, auto-sleep)
            # use the correct payload format on direct USB Centurion devices too.
            self.version[feature] = feat_version
            self.flags[feature] = feat_type
            if logger.isEnabledFor(logging.DEBUG):
                logger.debug(
                    "Centurion parent feature: %s at index %d, version=%d, flags=0x%02X",
                    feature,
                    index,
                    feat_version,
                    feat_type,
                )
            if feature is CenturionCoreFeature.CENT_PP_BRIDGE:
                bridge_index = index

        if bridge_index is not None:
            self.device._centurion_bridge_index = bridge_index
            self.device._centurion_sub_features = set()
            self.device._centurion_sub_indices = {}
            self._discover_sub_device_features(bridge_index)

    def _discover_sub_device_features(self, bridge_index):
        """Phase B: Discover sub-device features via CentPPBridge.

        Uses per-index queries: GetCount (func 0) returns total count, then
        GetFeatureId (func 1) returns one feature per call. Avoids the
        single-frame truncation of bulk queries — a Centurion frame is 64
        bytes so a bulk reply can only fit ~13 features regardless of how
        many the sub-device actually has.
        """
        # First, find the sub-device's FeatureSet index via CenturionRoot (sub_feat_idx=0)
        # Query: CenturionRoot.GetFeature(0x0001) to find FeatureSet index on sub-device
        fs_id_hi = (SupportedFeature.FEATURE_SET >> 8) & 0xFF
        fs_id_lo = SupportedFeature.FEATURE_SET & 0xFF
        response = self.device.centurion_bridge_request(0x00, 0x00, fs_id_hi, fs_id_lo)
        if response is None or len(response) < 1:
            logger.warning("Failed to find FeatureSet on Centurion sub-device")
            return
        sub_fs_index = response[0]
        if sub_fs_index == 0:
            logger.warning("Sub-device FeatureSet not found (index=0)")
            return

        # Query feature count (function 0 = GetCount). Response: [count, ...].
        count_resp = self.device.centurion_bridge_request(sub_fs_index, 0x00)
        if count_resp is None or len(count_resp) < 1:
            logger.warning("Failed to read Centurion sub-device feature count")
            return
        total_count = count_resp[0]
        if logger.isEnabledFor(logging.DEBUG):
            logger.debug("Centurion sub-device: FeatureSet reports %d features", total_count)

        # Per-index query: GetFeatureId (function 1 = 0x10).
        # Response: [remaining, feat_hi, feat_lo, type, version].
        # We now also record `type` (flags) and `version` for each feature so
        # version-gated settings (sidetone, auto-sleep, etc.) can use the
        # correct payload format instead of defaulting to V0.
        sub_feat_idx = 0
        for idx in range(total_count):
            response = self.device.centurion_bridge_request(sub_fs_index, 0x10, idx)
            if response is None or len(response) < 3:
                logger.debug("Centurion sub-device: no response at index %d", idx)
                continue
            feat_id = struct.unpack("!H", response[1:3])[0]
            feat_type = response[3] if len(response) > 3 else 0
            feat_version = response[4] if len(response) > 4 else 0
            try:
                feature = SupportedFeature(feat_id)
            except ValueError:
                feature = f"unknown:{feat_id:04X}"
            self.device._centurion_sub_indices[feature] = sub_feat_idx
            if dict.get(self, feature) is None:
                dict.__setitem__(self, feature, sub_feat_idx)
                self.device._centurion_sub_features.add(feature)
            self.sub_inverse[sub_feat_idx] = feature
            # Record version/flags so downstream settings can version-gate their
            # payload format. get_feature_version(feature) reads self.version[feature].
            self.version[feature] = feat_version
            self.flags[feature] = feat_type
            if logger.isEnabledFor(logging.DEBUG):
                logger.debug(
                    "Centurion sub-device feature: %s at sub-index %d, version=%d, flags=0x%02X",
                    feature,
                    sub_feat_idx,
                    feat_version,
                    feat_type,
                )
            sub_feat_idx += 1
        self._sub_feature_count = sub_feat_idx
        if logger.isEnabledFor(logging.DEBUG):
            logger.debug("Centurion sub-device: discovered %d features total", sub_feat_idx)

    def get_feature(self, index: int) -> SupportedFeature | None:
        feature = self.inverse.get(index)
        if feature is not None:
            return feature
        # Sub-device index; bridge unwrap offsets by 0x100 (see listener).
        if index >= 0x100:
            return self.sub_inverse.get(index - 0x100)
        elif self._check():
            feature = self.inverse.get(index)
            if feature is not None:
                return feature
            # On Centurion devices, all features are discovered upfront (parent + sub-device)
            if getattr(self.device, "centurion", False):
                return None
            try:
                response = self.device.feature_request(SupportedFeature.FEATURE_SET, 0x10, index)
            except exceptions.FeatureCallError:
                logger.warning("failed to retrieve feature at index %d", index)
                return None
            if response:
                data = struct.unpack("!H", response[:2])[0]
                try:
                    feature = SupportedFeature(data)
                except ValueError:
                    feature = f"unknown:{data:04X}"
                self[feature] = index
                self.version[feature] = response[3]
                self.flags[feature] = response[2]
                return feature

    def enumerate(self):  # return all features and their index, ordered by index
        if self._check():
            for index in range(self.count):
                feature = self.get_feature(index)
                if feature is not None:
                    yield feature, index
            # Also yield sub-device features for Centurion devices
            sub_count = getattr(self, "_sub_feature_count", 0)
            for sub_idx in range(sub_count):
                feature = self.sub_inverse.get(sub_idx)
                if feature is not None:
                    yield feature, sub_idx

    def get_feature_version(self, feature: NamedInt) -> Optional[int]:
        if self[feature]:
            return self.version.get(feature, 0)

    def get_flags(self, feature: NamedInt) -> Optional[int]:
        if self[feature]:
            return self.flags.get(feature, 0)

    def get_hidden(self, feature: NamedInt) -> Optional[bool]:
        if self[feature]:
            return self.flags.get(feature, 0) & FeatureFlag.INTERNAL
        return True

    def __contains__(self, feature: NamedInt) -> bool:
        try:
            index = self.__getitem__(feature)
            return index is not None and index is not False
        except exceptions.FeatureCallError:
            return False

    def __getitem__(self, feature: NamedInt) -> Optional[int]:
        index = super().get(feature)
        if index is not None:
            return index
        elif self._check():
            index = super().get(feature)
            if index is not None:
                return index
            # Centurion devices enumerate all features upfront in _check_centurion().
            # If the feature isn't in the dict after _check(), it genuinely doesn't
            # exist — skip the raw ROOT.GetFeature query that the dongle rejects
            # with LOGITECH_ERROR and that creates cycling log spam during settings init.
            if getattr(self.device, "centurion", False):
                return None
            try:
                response = self.device.request(0x0000, struct.pack("!H", feature))
            except exceptions.FeatureCallError:
                return None
            if response:
                index = response[0]
                self[feature] = index if index else False
                self.version[feature] = response[2]
                self.flags[feature] = response[1]
                return index if index else False

    def __setitem__(self, feature, index):
        if isinstance(super().get(feature), int):
            self.inverse.pop(super().get(feature))
        super().__setitem__(feature, index)
        if index is not False:
            self.inverse[index] = feature

    def __delitem__(self, feature):
        raise ValueError("Don't delete features from FeatureArray")

    def __len__(self) -> int:
        return self.count + getattr(self, "_sub_feature_count", 0)

    __bool__ = __nonzero__ = _check


class ReprogrammableKey:
    """Information about a control present on a device with the `REPROG_CONTROLS` feature.

    Read-only properties:
    - index -- index in the control ID table
    - key -- the name of this control
    - default_task -- the native function of this control
    - flags -- capabilities and desired software handling of the control

    Ref: https://drive.google.com/file/d/0BxbRzx7vEV7eU3VfMnRuRXktZ3M/view
    """

    def __init__(self, device: Device, index: int, cid: int, task_id: int, flags: int):
        self._device = device
        self.index = index
        self._cid = cid
        self._tid = task_id
        self._flags = flags

    @property
    def key(self) -> NamedInt:
        return special_keys.CONTROL[self._cid]

    @property
    def default_task(self) -> NamedInt:
        """NOTE: This NamedInt is a bit mixed up, because its value is the Control ID
        while the name is the Control ID's native task. But this makes more sense
        than presenting details of controls vs tasks in the interface. The same
        convention applies to `mapped_to`, `remappable_to`, `remap` in `ReprogrammableKeyV4`."""
        try:
            task = str(special_keys.Task(self._tid))
        except ValueError:
            task = f"unknown:{self._tid:04X}"
        return NamedInt(self._cid, task)

    @property
    def flags(self) -> KeyFlag:
        return KeyFlag(self._flags)


class ReprogrammableKeyV4(ReprogrammableKey):
    """Information about a control present on a device with the `REPROG_CONTROLS_V4` feature.
    Ref (v2): https://lekensteyn.nl/files/logitech/x1b04_specialkeysmsebuttons.html
    Ref (v4): https://drive.google.com/file/d/10imcbmoxTJ1N510poGdsviEhoFfB_Ua4/view
    Contains all the functionality of `ReprogrammableKey` plus remapping keys and /diverting/ them
    in order to handle keypresses in a custom way.

    Additional read-only properties:
    - pos {int} -- position of this control on the device; 1-16 for FN-keys, otherwise 0
    - group {int} -- the group this control belongs to; other controls with this group in their
    `group_mask` can be remapped to this control
    - group_mask {List[str]} -- this control can be remapped to any control ID in these groups
    - mapped_to {NamedInt} -- which action this control is mapped to; usually itself
    - remappable_to {List[NamedInt]} -- list of actions which this control can be remapped to
    - mapping_flags {List[str]} -- mapping flags set on the control
    """

    def __init__(self, device: Device, index, cid, task_id, flags, pos, group, gmask):
        ReprogrammableKey.__init__(self, device, index, cid, task_id, flags)
        self.pos = pos
        self.group = group
        self._gmask = gmask
        self._mapping_flags = None
        self._mapped_to = None

    @property
    def group_mask(self) -> Generator[str]:
        return common.flag_names(special_keys.CIDGroupBit, self._gmask)

    @property
    def mapped_to(self) -> NamedInt:
        if self._mapped_to is None:
            self._getCidReporting()
        self._device.keys._ensure_all_keys_queried()
        try:
            task = str(special_keys.Task(self._device.keys.cid_to_tid[self._mapped_to]))
        except ValueError:
            task = f"Unknown_{self._mapped_to:x}"
        return NamedInt(self._mapped_to, task)

    @property
    def remappable_to(self):
        self._device.keys._ensure_all_keys_queried()
        ret = common.UnsortedNamedInts()
        if self.group_mask:  # only keys with a non-zero gmask are remappable
            ret[self.default_task] = self.default_task  # it should always be possible to map the key to itself
            for g in self.group_mask:
                g = special_keys.CidGroup[str(g)]
                for tgt_cid in self._device.keys.group_cids[g]:
                    cid = self._device.keys.cid_to_tid[tgt_cid]
                    try:
                        tgt_task = str(special_keys.Task(cid))
                    except ValueError:
                        tgt_task = f"unknown:{cid:04X}"
                    tgt_task = NamedInt(tgt_cid, tgt_task)
                    if tgt_task != self.default_task:  # don't put itself in twice
                        ret[tgt_task] = tgt_task
        return ret

    @property
    def mapping_flags(self) -> MappingFlag:
        if self._mapping_flags is None:
            self._getCidReporting()
        return MappingFlag(self._mapping_flags)

    def set_diverted(self, value: bool) -> None:
        """If set, the control is diverted temporarily and reports presses as HID++ events."""
        flags = {MappingFlag.DIVERTED: value}
        self._setCidReporting(flags=flags)

    def set_persistently_diverted(self, value: bool) -> None:
        """If set, the control is diverted permanently and reports presses as HID++ events."""
        flags = {MappingFlag.PERSISTENTLY_DIVERTED: value}
        self._setCidReporting(flags=flags)

    def set_rawXY_reporting(self, value: bool) -> None:
        """If set, the mouse temporarily reports all its raw XY events while this control is pressed as HID++ events."""
        flags = {MappingFlag.RAW_XY_DIVERTED: value}
        self._setCidReporting(flags=flags)

    def remap(self, to: NamedInt):
        """Temporarily remaps this control to another action."""
        self._setCidReporting(remap=int(to))

    def _getCidReporting(self):
        try:
            mapped_data = self._device.feature_request(
                SupportedFeature.REPROG_CONTROLS_V4,
                0x20,
                *tuple(struct.pack("!H", self._cid)),
            )
            if mapped_data:
                cid, mapping_flags_1, mapped_to = struct.unpack("!HBH", mapped_data[:5])
                if cid != self._cid and logger.isEnabledFor(logging.WARNING):
                    logger.warning(
                        f"REPROG_CONTROLS_V4 endpoint getCidReporting on device {self._device} replied "
                        + f"with a different control ID ({cid}) than requested ({self._cid})."
                    )
                self._mapped_to = mapped_to if mapped_to != 0 else self._cid
                if len(mapped_data) > 5:
                    (mapping_flags_2,) = struct.unpack("!B", mapped_data[5:6])
                else:
                    mapping_flags_2 = 0
                self._mapping_flags = mapping_flags_1 | (mapping_flags_2 << 8)
            else:
                raise exceptions.FeatureCallError(msg="No reply from device.")
        except exceptions.FeatureCallError:  # if the key hasn't ever been configured only produce a warning
            if logger.isEnabledFor(logging.WARNING):
                logger.warning(
                    f"Feature Call Error in _getCidReporting on device {self._device} for cid {self._cid} - use defaults"
                )
            # Clear flags and set mapping target to self
            self._mapping_flags = 0
            self._mapped_to = self._cid

    def _setCidReporting(self, flags: Dict[NamedInt, bool] = None, remap: int = 0):
        """Sends a `setCidReporting` request with the given parameters.

        Raises an exception if the parameters are invalid.

        Parameters
        ----------
        flags
            A dictionary of which mapping flags to set/unset.
        remap
            Which control ID to remap to; or 0 to keep current mapping.
        """
        flags = flags if flags else {}  # See flake8 B006

        # The capability required to set a given reporting flag.
        FLAG_TO_CAPABILITY = {
            MappingFlag.DIVERTED: KeyFlag.DIVERTABLE,
            MappingFlag.PERSISTENTLY_DIVERTED: KeyFlag.PERSISTENTLY_DIVERTABLE,
            MappingFlag.ANALYTICS_KEY_EVENTS_REPORTING: KeyFlag.ANALYTICS_KEY_EVENTS,
            MappingFlag.FORCE_RAW_XY_DIVERTED: KeyFlag.FORCE_RAW_XY,
            MappingFlag.RAW_XY_DIVERTED: KeyFlag.RAW_XY,
        }

        bfield = 0
        for mapping_flag, activated in flags.items():
            key_flag = FLAG_TO_CAPABILITY[mapping_flag]
            if activated and key_flag not in self.flags:
                raise exceptions.FeatureNotSupported(
                    msg=f'Tried to set mapping flag "{mapping_flag}" on control "{self.key}" '
                    + f'which does not support "{key_flag}" on device {self._device}.'
                )
            bfield |= mapping_flag.value if activated else 0
            bfield |= mapping_flag.value << 1  # The 'Xvalid' bit
            if self._mapping_flags:  # update flags if already read
                if activated:
                    self._mapping_flags |= mapping_flag.value
                else:
                    self._mapping_flags &= ~mapping_flag.value

        if remap != 0 and remap not in self.remappable_to:
            raise exceptions.FeatureNotSupported(
                msg=f'Tried to remap control "{self.key}" to a control ID {remap} which it is not remappable to '
                + f"on device {self._device}."
            )
        if remap != 0:  # update mapping if changing (even if not already read)
            self._mapped_to = remap

        pkt = tuple(struct.pack("!HBH", self._cid, bfield & 0xFF, remap))
        # TODO: to fully support version 4 of REPROG_CONTROLS_V4, append `(bfield >> 8) & 0xff` here.
        # But older devices might behave oddly given that byte, so we don't send it.
        ret = self._device.feature_request(SupportedFeature.REPROG_CONTROLS_V4, 0x30, *pkt)
        if ret is None or struct.unpack("!BBBBB", ret[:5]) != pkt and logger.isEnabledFor(logging.DEBUG):
            logger.debug(f"REPROG_CONTROLS_v4 setCidReporting on device {self._device} didn't echo request packet.")


class PersistentRemappableAction:
    def __init__(self, device, index, cid, actionId, remapped, modifierMask, cidStatus):
        self._device = device
        self.index = index
        self._cid = cid
        self.actionId = actionId
        self.remapped = remapped
        self._modifierMask = modifierMask
        self.cidStatus = cidStatus

    @property
    def key(self) -> NamedInt:
        return special_keys.CONTROL[self._cid]

    @property
    def actionType(self) -> NamedInt:
        return special_keys.ACTIONID[self.actionId]

    @property
    def action(self):
        if self.actionId == special_keys.ACTIONID.Empty:
            return None
        elif self.actionId == special_keys.ACTIONID.Key:
            return f"Key: {str(self.modifiers)}{str(self.remapped)}"
        elif self.actionId == special_keys.ACTIONID.Mouse:
            return f"Mouse Button: {str(self.remapped)}"
        elif self.actionId == special_keys.ACTIONID.Xdisp:
            return f"X Displacement {str(self.remapped)}"
        elif self.actionId == special_keys.ACTIONID.Ydisp:
            return f"Y Displacement {str(self.remapped)}"
        elif self.actionId == special_keys.ACTIONID.Vscroll:
            return f"Vertical Scroll {str(self.remapped)}"
        elif self.actionId == special_keys.ACTIONID.Hscroll:
            return f"Horizontal Scroll: {str(self.remapped)}"
        elif self.actionId == special_keys.ACTIONID.Consumer:
            return f"Consumer: {str(self.remapped)}"
        elif self.actionId == special_keys.ACTIONID.Internal:
            return f"Internal Action {str(self.remapped)}"
        elif self.actionId == special_keys.ACTIONID.Internal:
            return f"Power {str(self.remapped)}"
        else:
            return "Unknown"

    @property
    def modifiers(self):
        return special_keys.modifiers[self._modifierMask]

    @property
    def data_bytes(self):
        return (
            common.int2bytes(self.actionId, 1) + common.int2bytes(self.remapped, 2) + common.int2bytes(self._modifierMask, 1)
        )

    def remap(self, data_bytes):
        cid = common.int2bytes(self._cid, 2)
        if common.bytes2int(data_bytes) == special_keys.KEYS_Default:  # map back to default
            self._device.feature_request(SupportedFeature.PERSISTENT_REMAPPABLE_ACTION, 0x50, cid, 0xFF)
            self._device.remap_keys._query_key(self.index)
            return self._device.remap_keys.keys[self.index].data_bytes
        else:
            self.actionId, self.remapped, self._modifierMask = struct.unpack("!BHB", data_bytes)
            self.cidStatus = 0x01
            self._device.feature_request(SupportedFeature.PERSISTENT_REMAPPABLE_ACTION, 0x40, cid, 0xFF, data_bytes)
            return True


class KeysArray:
    """A sequence of key mappings supported by a HID++ 2.0 device."""

    def __init__(self, device, count, version):
        assert device is not None
        self.device = device
        self.lock = threading.Lock()
        if SupportedFeature.REPROG_CONTROLS_V4 in self.device.features:
            self.keyversion = SupportedFeature.REPROG_CONTROLS_V4
        elif SupportedFeature.REPROG_CONTROLS_V2 in self.device.features:
            self.keyversion = SupportedFeature.REPROG_CONTROLS_V2
        else:
            if logger.isEnabledFor(logging.ERROR):
                logger.error(f"Trying to read keys on device {device} which has no REPROG_CONTROLS(_VX) support.")
            self.keyversion = None
        self.keys = [None] * count

    def _ensure_all_keys_queried(self):
        """The retrieval of key information is lazy, but for certain functionality
        we need to know all keys. This function makes sure that's the case."""
        with self.lock:  # don't want two threads doing this
            for i, k in enumerate(self.keys):
                if k is None:
                    self._query_key(i)

    def __getitem__(self, index):
        if isinstance(index, int):
            if index < 0 or index >= len(self.keys):
                raise IndexError(index)

            if self.keys[index] is None:
                self._query_key(index)

            return self.keys[index]

        elif isinstance(index, slice):
            indices = index.indices(len(self.keys))
            return [self.__getitem__(i) for i in range(*indices)]

    def index(self, value):
        self._ensure_all_keys_queried()
        for index, k in enumerate(self.keys):
            if k is not None and int(value) == int(k.key):
                return index

    def __iter__(self):
        for k in range(0, len(self.keys)):
            yield self.__getitem__(k)

    def __len__(self):
        return len(self.keys)


class KeysArrayV2(KeysArray):
    def __init__(self, device: Device, count, version=1):
        super().__init__(device, count, version)
        """The mapping from Control IDs to their native Task IDs.
        For example, Control "Left Button" is mapped to Task "Left Click".
        When remapping controls, we point the control we want to remap
        at a target Control ID rather than a target Task ID. This has the
        effect of performing the native task of the target control,
        even if the target itself is also remapped. So remapping
        is not recursive."""
        self.cid_to_tid = {}
        """The mapping from Control ID groups to Controls IDs that belong to it.
        A key k can only be remapped to targets in groups within k.group_mask."""
        self.group_cids = {g: [] for g in special_keys.CidGroup}

    def _query_key(self, index: int):
        if index < 0 or index >= len(self.keys):
            raise IndexError(index)
        keydata = self.device.feature_request(SupportedFeature.REPROG_CONTROLS, 0x10, index)
        if keydata:
            cid, task_id, flags = struct.unpack("!HHB", keydata[:5])
            self.keys[index] = ReprogrammableKey(self.device, index, cid, task_id, flags)
            self.cid_to_tid[cid] = task_id
        elif logger.isEnabledFor(logging.WARNING):
            logger.warning(f"Key with index {index} was expected to exist but device doesn't report it.")


class KeysArrayV4(KeysArrayV2):
    def __init__(self, device, count):
        super().__init__(device, count, 4)

    def _query_key(self, index: int):
        if index < 0 or index >= len(self.keys):
            raise IndexError(index)
        keydata = self.device.feature_request(SupportedFeature.REPROG_CONTROLS_V4, 0x10, index)
        if keydata:
            cid, task_id, flags1, pos, group, gmask, flags2 = struct.unpack("!HHBBBBB", keydata[:9])
            flags = flags1 | (flags2 << 8)
            self.keys[index] = ReprogrammableKeyV4(self.device, index, cid, task_id, flags, pos, group, gmask)
            self.cid_to_tid[cid] = task_id
            if group != 0:  # 0 = does not belong to a group
                self.group_cids[special_keys.CidGroup(group)].append(cid)
        elif logger.isEnabledFor(logging.WARNING):
            logger.warning(f"Key with index {index} was expected to exist but device doesn't report it.")


# we are only interested in the current host, so use 0xFF for the host throughout
class KeysArrayPersistent(KeysArray):
    def __init__(self, device, count):
        super().__init__(device, count, 5)
        self._capabilities = None

    @property
    def capabilities(self):
        if self._capabilities is None and self.device.online:
            capabilities = self.device.feature_request(SupportedFeature.PERSISTENT_REMAPPABLE_ACTION, 0x00)
            assert capabilities, "Oops, persistent remappable key capabilities cannot be retrieved!"
            self._capabilities = struct.unpack("!H", capabilities[:2])[0]  # flags saying what the mappings are possible
        return self._capabilities

    def _query_key(self, index: int):
        if index < 0 or index >= len(self.keys):
            raise IndexError(index)
        keydata = self.device.feature_request(SupportedFeature.PERSISTENT_REMAPPABLE_ACTION, 0x20, index, 0xFF)
        if keydata:
            key = struct.unpack("!H", keydata[:2])[0]
            mapped_data = self.device.feature_request(
                SupportedFeature.PERSISTENT_REMAPPABLE_ACTION,
                0x30,
                key >> 8,
                key & 0xFF,
                0xFF,
            )
            if mapped_data:
                _ignore, _ignore, actionId, remapped, modifiers, status = struct.unpack("!HBBHBB", mapped_data[:8])
            else:
                actionId = remapped = modifiers = status = 0
            actionId = special_keys.ACTIONID[actionId]
            if actionId == special_keys.ACTIONID.Key:
                remapped = special_keys.USB_HID_KEYCODES[remapped]
            elif actionId == special_keys.ACTIONID.Mouse:
                remapped = special_keys.MOUSE_BUTTONS[remapped]
            elif actionId == special_keys.ACTIONID.Hscroll:
                try:
                    remapped = special_keys.HorizontalScroll(remapped)
                except ValueError:
                    remapped = f"unknown horizontal scroll:{remapped:04X}"
            elif actionId == special_keys.ACTIONID.Consumer:
                remapped = special_keys.HID_CONSUMERCODES[remapped]
            elif actionId == special_keys.ACTIONID.Empty:  # purge data from empty value
                remapped = modifiers = 0
            self.keys[index] = PersistentRemappableAction(
                self.device,
                index,
                key,
                actionId,
                remapped,
                modifiers,
                status,
            )
        elif logger.isEnabledFor(logging.WARNING):
            logger.warning(f"Key with index {index} was expected to exist but device doesn't report it.")


class SubParam:
    __slots__ = ("id", "length", "minimum", "maximum", "widget")

    def __init__(self, id, length, minimum=None, maximum=None, widget=None):
        self.id = id
        self.length = length
        self.minimum = minimum if minimum is not None else 0
        self.maximum = maximum if maximum is not None else ((1 << 8 * length) - 1)
        self.widget = widget if widget is not None else "Scale"

    def __str__(self):
        return self.id

    def __repr__(self):
        return self.id


SUB_PARAM = {  # (byte count, minimum, maximum)
    ParamId.EXTRA_CAPABILITIES: None,  # ignore
    ParamId.PIXEL_ZONE: (  # TODO: replace min and max with the correct values
        SubParam("left", 2, 0x0000, 0xFFFF, "SpinButton"),
        SubParam("bottom", 2, 0x0000, 0xFFFF, "SpinButton"),
        SubParam("width", 2, 0x0000, 0xFFFF, "SpinButton"),
        SubParam("height", 2, 0x0000, 0xFFFF, "SpinButton"),
    ),
    ParamId.RATIO_ZONE: (  # TODO: replace min and max with the correct values
        SubParam("left", 1, 0x00, 0xFF, "SpinButton"),
        SubParam("bottom", 1, 0x00, 0xFF, "SpinButton"),
        SubParam("width", 1, 0x00, 0xFF, "SpinButton"),
        SubParam("height", 1, 0x00, 0xFF, "SpinButton"),
    ),
    ParamId.SCALE_FACTOR: (SubParam("scale", 2, 0x002E, 0x01FF, "Scale"),),
}


class SpecGesture(IntEnum):
    """Spec IDs for feature GESTURE_2."""

    DVI_FIELD_WIDTH = 1
    FIELD_WIDTHS = 2
    PERIOD_UNIT = 3
    RESOLUTION = 4
    MULTIPLIER = 5
    SENSOR_SIZE = 6
    FINGER_WIDTH_AND_HEIGHT = 7
    FINGER_MAJOR_MINOR_AXIS = 8
    FINGER_FORCE = 9
    ZONE = 10

    def __str__(self):
        return f"{self.name.replace('_', ' ').lower()}"


class ActionId(IntEnum):
    """Action IDs for feature GESTURE_2."""

    MOVE_POINTER = 1
    SCROLL_HORIZONTAL = 2
    WHEEL_SCROLLING = 3
    SCROLL_VERTICAL = 4
    SCROLL_OR_PAGE_XY = 5
    SCROLL_OR_PAGE_HORIZONTAL = 6
    PAGE_SCREEN = 7
    DRAG = 8
    SECONDARY_DRAG = 9
    ZOOM = 10
    SCROLL_HORIZONTAL_ONLY = 11
    SCROLL_VERTICAL_ONLY = 12


class Gesture:
    def __init__(self, device, low, high, next_index, next_diversion_index):
        self._device = device
        self.id = low
        self.gesture = GestureId(low)
        self.can_be_enabled = high & 0x01
        self.can_be_diverted = high & 0x02
        self.show_in_ui = high & 0x04
        self.desired_software_default = high & 0x08
        self.persistent = high & 0x10
        self.default_enabled = high & 0x20
        self.index = next_index if self.can_be_enabled or self.default_enabled else None
        self.diversion_index = next_diversion_index if self.can_be_diverted else None
        self._enabled = None
        self._diverted = None

    def _offset_mask(self, index):  # offset and mask
        if index is not None:
            offset = index >> 3  # 8 gestures per byte
            mask = 0x1 << (index % 8)
            return offset, mask
        else:
            return None, None

    def enable_offset_mask(self):
        return self._offset_mask(self.index)

    def diversion_offset_mask(self):
        return self._offset_mask(self.diversion_index)

    def enabled(self):  # is the gesture enabled?
        if self._enabled is None and self.index is not None:
            offset, mask = self.enable_offset_mask()
            result = self._device.feature_request(SupportedFeature.GESTURE_2, 0x10, offset, 0x01, mask)
            self._enabled = bool(result[0] & mask) if result else None
        return self._enabled

    def set(self, enable):  # enable or disable the gesture
        if not self.can_be_enabled:
            return None
        if self.index is not None:
            offset, mask = self.enable_offset_mask()
            reply = self._device.feature_request(
                SupportedFeature.GESTURE_2, 0x20, offset, 0x01, mask, mask if enable else 0x00
            )
            return reply

    def diverted(self):  # is the gesture diverted?
        if self._diverted is None and self.diversion_index is not None:
            offset, mask = self.diversion_offset_mask()
            result = self._device.feature_request(SupportedFeature.GESTURE_2, 0x30, offset, 0x01, mask)
            self._diverted = bool(result[0] & mask) if result else None
        return self._diverted

    def divert(self, diverted):  # divert or undivert the gesture
        if not self.can_be_diverted:
            return None
        if self.diversion_index is not None:
            offset, mask = self.diversion_offset_mask()
            reply = self._device.feature_request(
                SupportedFeature.GESTURE_2,
                0x40,
                offset,
                0x01,
                mask,
                mask if diverted else 0x00,
            )
            return reply

    def as_int(self):
        return self.gesture

    def __int__(self):
        return self.id

    def __repr__(self):
        return f"<Gesture {self.gesture} index={self.index} diversion_index={self.diversion_index}>"

    # allow a gesture to be used as a settings reader/writer to enable and disable the gesture
    read = enabled
    write = set


class Param:
    def __init__(self, device, low: int, high, next_param_index):
        self._device = device
        self.id = low
        self.param = ParamId(low)
        self.size = high & 0x0F
        self.show_in_ui = bool(high & 0x1F)
        self._value = None
        self._default_value = None
        self.index = next_param_index

    @property
    def sub_params(self):
        return SUB_PARAM.get(self.id, None)

    @property
    def value(self):
        return self._value if self._value is not None else self.read()

    def read(self):  # returns the bytes for the parameter
        result = self._device.feature_request(SupportedFeature.GESTURE_2, 0x70, self.index, 0xFF)
        if result:
            self._value = common.bytes2int(result[: self.size])
            return self._value

    @property
    def default_value(self):
        if self._default_value is None:
            self._default_value = self._read_default()
        return self._default_value

    def _read_default(self):
        result = self._device.feature_request(SupportedFeature.GESTURE_2, 0x60, self.index, 0xFF)
        if result:
            self._default_value = common.bytes2int(result[: self.size])
            return self._default_value

    def write(self, bytes):
        self._value = bytes
        return self._device.feature_request(SupportedFeature.GESTURE_2, 0x80, self.index, bytes, 0xFF)

    def __str__(self):
        return str(self.param)

    def __int__(self):
        return self.id


class Spec:
    def __init__(self, device, low: int, high):
        self._device = device
        self.id = low
        try:
            self.spec = SpecGesture(low)
        except ValueError:
            self.spec = f"unknown:{low:04X}"
        self.byte_count = high & 0x0F
        self._value = None

    @property
    def value(self):
        if self._value is None:
            self._value = self.read()
        return self._value

    def read(self):
        try:
            value = self._device.feature_request(SupportedFeature.GESTURE_2, 0x50, self.id, 0xFF)
        except exceptions.FeatureCallError:  # some calls produce an error (notably spec 5 multiplier on K400Plus)
            if logger.isEnabledFor(logging.WARNING):
                logger.warning(
                    f"Feature Call Error reading Gesture Spec on device {self._device} for spec {self.id} - use None"
                )
            return None
        return common.bytes2int(value[: self.byte_count])

    def __repr__(self):
        return f"[{self.spec}={self.value}]"


class Gestures:
    """Information about the gestures that a device supports.
    Right now only some information fields are supported.
    WARNING: Assumes that parameters are always global, which is not the case.
    """

    def __init__(self, device):
        self.device = device
        self.gestures = {}
        self.params = {}
        self.specs = {}
        index = 0
        next_gesture_index = next_divsn_index = next_param_index = 0
        field_high = 0x00
        while field_high != 0x01:  # end of fields
            # retrieve the next eight fields
            fields = device.feature_request(SupportedFeature.GESTURE_2, 0x00, index >> 8, index & 0xFF)
            if not fields:
                break
            for offset in range(8):
                field_high = fields[offset * 2]
                field_low = fields[offset * 2 + 1]
                if field_high == 0x1:  # end of fields
                    break
                elif field_high & 0x80:
                    gesture = Gesture(device, field_low, field_high, next_gesture_index, next_divsn_index)
                    next_gesture_index = next_gesture_index if gesture.index is None else next_gesture_index + 1
                    next_divsn_index = next_divsn_index if gesture.diversion_index is None else next_divsn_index + 1
                    self.gestures[gesture.gesture] = gesture
                elif field_high & 0xF0 == 0x30 or field_high & 0xF0 == 0x20:
                    param = Param(device, field_low, field_high, next_param_index)
                    next_param_index = next_param_index + 1
                    self.params[param.param] = param
                elif field_high == 0x04:
                    if field_low != 0x00:
                        logger.error(f"Unimplemented GESTURE_2 grouping {field_low} {field_high} found.")
                elif field_high & 0xF0 == 0x40:
                    spec = Spec(device, field_low, field_high)
                    self.specs[spec.spec] = spec
                else:
                    logger.warning(f"Unimplemented GESTURE_2 field {field_low} {field_high} found.")
                index += 1

    def gesture(self, gesture):
        return self.gestures.get(gesture, None)

    def gesture_enabled(self, gesture):  # is the gesture enabled?
        g = self.gestures.get(gesture, None)
        return g.enabled() if g else None

    def enable_gesture(self, gesture):
        g = self.gestures.get(gesture, None)
        return g.set(True) if g else None

    def disable_gesture(self, gesture):
        g = self.gestures.get(gesture, None)
        return g.set(False) if g else None

    def param(self, param):
        return self.params.get(param, None)

    def get_param(self, param):
        g = self.params.get(param, None)
        return g.read() if g else None

    def set_param(self, param, value):
        g = self.params.get(param, None)
        return g.write(value) if g else None


class Backlight:
    """Information about the current settings of x1982 Backlight2 v3, but also works for previous versions"""

    def __init__(self, device):
        response = device.feature_request(SupportedFeature.BACKLIGHT2, 0x00)
        if not response:
            raise exceptions.FeatureCallError(msg="No reply from device.")
        self.device = device
        self.enabled, self.options, supported, effects, self.level, self.dho, self.dhi, self.dpow = struct.unpack(
            "<BBBHBHHH", response[:12]
        )
        self.auto_supported = supported & 0x08
        self.temp_supported = supported & 0x10
        self.perm_supported = supported & 0x20
        self.mode = (self.options >> 3) & 0x03

    def write(self):
        self.options = (self.options & 0x07) | (self.mode << 3)
        level = self.level if self.mode == 0x3 else 0
        data_bytes = struct.pack("<BBBBHHH", self.enabled, self.options, 0xFF, level, self.dho, self.dhi, self.dpow)
        return self.device.feature_request(SupportedFeature.BACKLIGHT2, 0x10, data_bytes)


class LEDParam:
    color = "color"
    speed = "speed"
    period = "period"
    intensity = "intensity"
    ramp = "ramp"
    form = "form"
    saturation = "saturation"
    direction = "direction"


# NamedInts (not IntEnum) so the GTK ComboBoxText shows readable labels.
LedRampChoice = common.NamedInts(Default=0, Yes=1, No=2)

LedFormChoices = common.NamedInts(
    Default=0,
    Sine=1,
    Square=2,
    Triangle=3,
    Sawtooth=4,
    Shark_fin=5,
    Exponential=6,
)

LedDirectionChoices = common.NamedInts()
LedDirectionChoices[0] = _("Cycle")
LedDirectionChoices[1] = _("Right")
LedDirectionChoices[2] = _("Down")
LedDirectionChoices[3] = _("Center Out")
LedDirectionChoices[4] = _("In")
LedDirectionChoices[5] = _("Out")
LedDirectionChoices[6] = _("Left")
LedDirectionChoices[7] = _("Up")
LedDirectionChoices[8] = _("Center In")

# Direction values to hide on devices whose LED grid can't render them.
LedDirectionBlocklist = {
    "40B4": {4, 5},  # G515 LS TKL — no edge-radiating wave geometry
}


LEDParamSize = {
    LEDParam.color: 3,
    LEDParam.speed: 1,
    LEDParam.period: 2,
    LEDParam.intensity: 1,
    LEDParam.ramp: 1,
    LEDParam.form: 1,
    LEDParam.saturation: 1,
    LEDParam.direction: 1,
}
# Entry: [NamedInt, params, defaults, ranges] — trailing dicts optional.
# ranges overrides a field's global min/max, e.g. period: (2, 200).
LEDEffects = {
    0x00: [NamedInt(0x00, _("Disabled")), {}],
    0x01: [NamedInt(0x01, _("Static")), {LEDParam.color: 0, LEDParam.ramp: 3}],
    0x02: [NamedInt(0x02, _("Pulse")), {LEDParam.color: 0, LEDParam.speed: 3}],
    0x03: [
        NamedInt(0x03, _("Cycle")),
        {LEDParam.period: 5, LEDParam.intensity: 7},
        {LEDParam.period: 5000, LEDParam.intensity: 100},
    ],
    # No probe device enumerates base Wave; assume the 0x16 layout so the
    # UI matches what 0x16-capable hardware shows.
    0x04: [
        NamedInt(0x04, _("Wave")),
        {LEDParam.period: 6, LEDParam.direction: 9},
        {LEDParam.period: 5000},
    ],
    0x08: [NamedInt(0x08, _("Boot")), {}],
    0x09: [NamedInt(0x09, _("Demo")), {}],
    0x0A: [
        NamedInt(0x0A, _("Breathe")),
        {LEDParam.color: 0, LEDParam.period: 3, LEDParam.form: 5, LEDParam.intensity: 6},
        {LEDParam.period: 5000, LEDParam.intensity: 100},
    ],
    0x0B: [
        NamedInt(0x0B, _("Ripple")),
        {LEDParam.color: 0, LEDParam.period: 4},
        {LEDParam.period: 20},
        {LEDParam.period: (2, 200)},
    ],
    0x0E: [NamedInt(0x0E, _("Decomposition")), {LEDParam.period: 6, LEDParam.intensity: 8}],
    0x0F: [NamedInt(0x0F, _("Signature1")), {LEDParam.period: 5, LEDParam.intensity: 7}],
    0x10: [NamedInt(0x10, _("Signature2")), {LEDParam.period: 5, LEDParam.intensity: 7}],
    0x15: [
        NamedInt(0x15, _("Cycle")),
        {LEDParam.saturation: 1, LEDParam.period: 6, LEDParam.intensity: 8},
        {LEDParam.saturation: 255, LEDParam.period: 5000, LEDParam.intensity: 100},
    ],
    0x16: [
        NamedInt(0x16, _("Wave")),
        {LEDParam.saturation: 1, LEDParam.period: 6, LEDParam.intensity: 8, LEDParam.direction: 9},
        {LEDParam.saturation: 255, LEDParam.period: 5000, LEDParam.intensity: 100},
    ],
    # Saturation derivative of Ripple 0x0B; pcap layout: color @ 0-2,
    # saturation @ 3, period @ 6-7.
    0x17: [
        NamedInt(0x17, _("Ripple")),
        {LEDParam.color: 0, LEDParam.saturation: 3, LEDParam.period: 6},
        {LEDParam.saturation: 255, LEDParam.period: 20},
        {LEDParam.period: (2, 200)},
    ],
    # Synthetic — host-side dim ramp, no wire effect.
    0x80: [NamedInt(0x80, _("Dim")), {LEDParam.intensity: 0}],
}


class LEDEffectSetting:  # an effect plus its parameters
    # Params whose value space is an RGB color; wrapped in ColorInt so the
    # value self-formats as ``0xrrggbb`` in solaar show and the YAML config.
    _COLOR_PARAMS = (str(LEDParam.color),)

    def __init__(self, **kwargs):
        self.ID = None
        for key, val in kwargs.items():
            # type(val) is int — exact match excludes NamedInt/ColorInt and
            # any other int subclass; only "raw" ints get wrapped here.
            if key in self._COLOR_PARAMS and type(val) is int and 0 <= val <= 0xFFFFFF:  # noqa: E721
                val = common.ColorInt(val)
            setattr(self, key, val)

    @classmethod
    def from_bytes(cls, bytes, options=None):
        ID = next((ze.ID for ze in options if ze.index == bytes[0]), None) if options is not None else bytes[0]
        effect = LEDEffects[ID] if ID in LEDEffects else None
        args = {"ID": effect[0] if effect else None}
        if effect:
            for p, b in effect[1].items():
                args[str(p)] = common.bytes2int(bytes[1 + b : 1 + b + LEDParamSize[p]])
        else:
            args["bytes"] = bytes
        return cls(**args)

    def to_bytes(self, options=None):
        ID = self.ID
        if ID is None:
            return self.bytes if hasattr(self, "bytes") else b"\xff" * 11
        else:
            bs = [0] * 10
            for p, b in LEDEffects[ID][1].items():
                bs[b : b + LEDParamSize[p]] = common.int2bytes(getattr(self, str(p), 0), LEDParamSize[p])
            if options is not None:
                ID = next((ze.index for ze in options if ze.ID == ID), None)
            result = common.int2bytes(ID, 1) + bytes(bs)
            return result

    @classmethod
    def from_yaml(cls, loader, node):
        return cls(**loader.construct_mapping(node))

    @classmethod
    def to_yaml(cls, dumper, data):
        return dumper.represent_mapping("!LEDEffectSetting", data.__dict__, flow_style=True)

    def __eq__(self, other):
        return isinstance(other, self.__class__) and self.to_bytes() == other.to_bytes()

    def __str__(self):
        return yaml.dump(self, width=float("inf")).rstrip("\n")


yaml.SafeLoader.add_constructor("!LEDEffectSetting", LEDEffectSetting.from_yaml)
yaml.add_representer(LEDEffectSetting, LEDEffectSetting.to_yaml)


class LEDEffectInfo:  # an effect that a zone can do
    def __init__(self, feature, function, device, zindex, eindex):
        info = device.feature_request(feature, function, zindex, eindex, 0x00)
        self.zindex, self.index, self.ID, self.capabilities, self.period = struct.unpack("!BBHHH", info[0:8])

    def __str__(self):
        return f"LEDEffectInfo({self.zindex}, {self.index}, {self.ID}, {self.capabilities: x}, {self.period})"


LEDZoneLocations = common.NamedInts()
LEDZoneLocations[0x00] = _("Unknown Location")
LEDZoneLocations[0x01] = _("Primary")
LEDZoneLocations[0x02] = _("Logo")
LEDZoneLocations[0x03] = _("Left Side")
LEDZoneLocations[0x04] = _("Right Side")
LEDZoneLocations[0x05] = _("Combined")
LEDZoneLocations[0x06] = _("Primary 1")
LEDZoneLocations[0x07] = _("Primary 2")
LEDZoneLocations[0x08] = _("Primary 3")
LEDZoneLocations[0x09] = _("Primary 4")
LEDZoneLocations[0x0A] = _("Primary 5")
LEDZoneLocations[0x0B] = _("Primary 6")


class LEDZoneInfo:  # effects that a zone can do
    def __init__(self, feature, function, offset, effect_function, device, index):
        info = device.feature_request(feature, function, index, 0xFF, 0x00)
        self.location, self.count = struct.unpack("!HB", info[1 + offset : 4 + offset])
        self.index = index
        self.location = LEDZoneLocations[self.location] if LEDZoneLocations[self.location] else self.location
        self.effects = []
        for i in range(0, self.count):
            self.effects.append(LEDEffectInfo(feature, effect_function, device, index, i))

    def to_command(self, setting):
        for i in range(0, len(self.effects)):
            e = self.effects[i]
            if e.ID == setting.ID:
                return common.int2bytes(self.index, 1) + common.int2bytes(i, 1) + setting.to_bytes()[1:]
        return None

    def __str__(self):
        return f"LEDZoneInfo({self.index}, {self.location}, {[str(z) for z in self.effects]}"


class LEDEffectsInfo:  # effects that the LEDs can do, using COLOR_LED_EFFECTS
    def __init__(self, device):
        self.device = device
        info = device.feature_request(SupportedFeature.COLOR_LED_EFFECTS, 0x00)
        self.count, _, capabilities = struct.unpack("!BHH", info[0:5])
        self.readable = capabilities & 0x1
        self.zones = []
        for i in range(0, self.count):
            self.zones.append(LEDZoneInfo(SupportedFeature.COLOR_LED_EFFECTS, 0x10, 0, 0x20, device, i))

    def to_command(self, index, setting):
        return self.zones[index].to_command(setting)

    def __str__(self):
        zones = "\n".join([str(z) for z in self.zones])
        return f"LEDEffectsInfo({self.device}, readable {self.readable}\n{zones})"


class RGBEffectsInfo(LEDEffectsInfo):  # effects that the LEDs can do using RGB_EFFECTS
    def __init__(self, device):
        self.device = device
        info = device.feature_request(SupportedFeature.RGB_EFFECTS, 0x00, 0xFF, 0xFF, 0x00)
        _, _, self.count, _, capabilities = struct.unpack("!BBBHH", info[0:7])
        self.readable = capabilities & 0x1
        self.zones = []
        for i in range(0, self.count):
            self.zones.append(LEDZoneInfo(SupportedFeature.RGB_EFFECTS, 0x00, 1, 0x00, device, i))


class ButtonBehavior(IntEnum):
    MACRO_EXECUTE = 0x0
    MACRO_STOP = 0x1
    MACRO_STOP_ALL = 0x2
    SEND = 0x8
    FUNCTION = 0x9


class ButtonMappingType(IntEnum):
    NO_ACTION = 0x0
    BUTTON = 0x1
    MODIFIER_AND_KEY = 0x2
    CONSUMER_KEY = 0x3


class ButtonFunctions(IntEnum):
    NO_ACTION = 0x0
    TILT_LEFT = 0x1
    TILT_RIGHT = 0x2
    NEXT_DPI = 0x3
    PREVIOUS_DPI = 0x4
    CYCLE_DPI = 0x5
    DEFAULT_DPI = 0x6
    SHIFT_DPI = 0x7
    NEXT_PROFILE = 0x8
    PREVIOUS_PROFILE = 0x9
    CYCLE_PROFILE = 0xA
    G_SHIFT = 0xB
    BATTERY_STATUS = 0xC
    PROFILE_SELECT = 0xD
    MODE_SWITCH = 0xE
    HOST_BUTTON = 0xF
    SCROLL_DOWN = 0x10
    SCROLL_UP = 0x11


ButtonButtons = special_keys.MOUSE_BUTTONS
ButtonModifiers = special_keys.modifiers
ButtonKeys = special_keys.USB_HID_KEYCODES
ButtonConsumerKeys = special_keys.HID_CONSUMERCODES


class Button:
    """A button mapping"""

    def __init__(self, **kwargs):
        self.behavior = None
        for key, val in kwargs.items():
            setattr(self, key, val)

    @classmethod
    def from_yaml(cls, loader, node):
        args = loader.construct_mapping(node)
        return cls(**args)

    @classmethod
    def to_yaml(cls, dumper, data):
        return dumper.represent_mapping("!Button", data.__dict__, flow_style=True)

    @classmethod
    def from_bytes(cls, bytes_) -> Button:
        behavior = bytes_[0] >> 4
        if behavior == ButtonBehavior.MACRO_EXECUTE or behavior == ButtonBehavior.MACRO_STOP:
            sector = ((bytes_[0] & 0x0F) << 8) + bytes_[1]
            address = (bytes_[2] << 8) + bytes_[3]
            result = cls(behavior=behavior, sector=sector, address=address)
        elif behavior == ButtonBehavior.SEND:
            try:
                mapping_type = ButtonMappingType(bytes_[1]).value
                if mapping_type == ButtonMappingType.BUTTON:
                    value = ButtonButtons[(bytes_[2] << 8) + bytes_[3]]
                    result = cls(behavior=behavior, type=mapping_type, value=value)
                elif mapping_type == ButtonMappingType.MODIFIER_AND_KEY:
                    modifiers = bytes_[2]
                    value = ButtonKeys[bytes_[3]]
                    result = cls(behavior=behavior, type=mapping_type, modifiers=modifiers, value=value)
                elif mapping_type == ButtonMappingType.CONSUMER_KEY:
                    value = ButtonConsumerKeys[(bytes_[2] << 8) + bytes_[3]]
                    result = cls(behavior=behavior, type=mapping_type, value=value)
                elif mapping_type == ButtonMappingType.NO_ACTION:
                    result = cls(behavior=behavior, type=mapping_type)
            except Exception:
                pass
        elif behavior == ButtonBehavior.FUNCTION:
            second_byte = bytes_[1]
            try:
                btn_func = ButtonFunctions(second_byte).value
            except ValueError:
                btn_func = second_byte
            data = bytes_[3]
            result = cls(behavior=behavior, value=btn_func, data=data)
        else:
            result = cls(behavior=bytes_[0] >> 4, bytes=bytes_)
        return result

    def to_bytes(self):
        bytes = common.int2bytes(self.behavior << 4, 1) if self.behavior is not None else None
        if self.behavior == ButtonBehavior.MACRO_EXECUTE.value or self.behavior == ButtonBehavior.MACRO_STOP.value:
            bytes = common.int2bytes((self.behavior << 12) + self.sector, 2) + common.int2bytes(self.address, 2)
        elif self.behavior == ButtonBehavior.SEND.value:
            bytes += common.int2bytes(self.type, 1)
            if self.type == ButtonMappingType.BUTTON:
                bytes += common.int2bytes(self.value, 2)
            elif self.type == ButtonMappingType.MODIFIER_AND_KEY:
                bytes += common.int2bytes(self.modifiers, 1)
                bytes += common.int2bytes(self.value, 1)
            elif self.type == ButtonMappingType.CONSUMER_KEY:
                bytes += common.int2bytes(self.value, 2)
            elif self.type == ButtonMappingType.NO_ACTION:
                bytes += b"\xff\xff"
        elif self.behavior == ButtonBehavior.FUNCTION:
            data = common.int2bytes(self.data, 1) if self.data else b"\x00"
            bytes += common.int2bytes(self.value, 1) + b"\xff" + data
        else:
            bytes = self.bytes if self.bytes else b"\xff\xff\xff\xff"
        return bytes

    def __repr__(self):
        return "%s{%s}" % (
            self.__class__.__name__,
            ", ".join([f"{str(key)}:{str(val)}" for key, val in self.__dict__.items()]),
        )


yaml.SafeLoader.add_constructor("!Button", Button.from_yaml)
yaml.add_representer(Button, Button.to_yaml)


class OnboardProfile:
    """A single onboard profile"""

    def __init__(self, **kwargs):
        for key, val in kwargs.items():
            setattr(self, key, val)

    @classmethod
    def from_yaml(cls, loader, node):
        args = loader.construct_mapping(node)
        return cls(**args)

    @classmethod
    def to_yaml(cls, dumper, data):
        return dumper.represent_mapping("!OnboardProfile", data.__dict__)

    @classmethod
    def from_bytes(cls, sector, enabled, buttons, gbuttons, bytes):
        return cls(
            sector=sector,
            enabled=enabled,
            report_rate=bytes[0],
            resolution_default_index=bytes[1],
            resolution_shift_index=bytes[2],
            resolutions=[struct.unpack("<H", bytes[i * 2 + 3 : i * 2 + 5])[0] for i in range(0, 5)],
            red=bytes[13],
            green=bytes[14],
            blue=bytes[15],
            power_mode=bytes[16],
            angle_snap=bytes[17],
            write_count=struct.unpack("<H", bytes[18:20])[0],
            reserved=bytes[20:28],
            ps_timeout=struct.unpack("<H", bytes[28:30])[0],
            po_timeout=struct.unpack("<H", bytes[30:32])[0],
            buttons=[Button.from_bytes(bytes[32 + i * 4 : 32 + i * 4 + 4]) for i in range(0, buttons)],
            gbuttons=[Button.from_bytes(bytes[96 + i * 4 : 96 + i * 4 + 4]) for i in range(0, gbuttons)],
            name=bytes[160:208].decode("utf-16le").rstrip("\x00").rstrip("\uffff"),
            lighting=[LEDEffectSetting.from_bytes(bytes[208 + i * 11 : 219 + i * 11]) for i in range(0, 4)],
        )

    @classmethod
    def from_dev(cls, dev, i, sector, s, enabled, buttons, gbuttons):
        bytes = OnboardProfiles.read_sector(dev, sector, s)
        return cls.from_bytes(sector, enabled, buttons, gbuttons, bytes)

    def to_bytes(self, length):
        bytes = common.int2bytes(self.report_rate, 1)
        bytes += common.int2bytes(self.resolution_default_index, 1) + common.int2bytes(self.resolution_shift_index, 1)
        bytes += b"".join([self.resolutions[i].to_bytes(2, "little") for i in range(0, 5)])
        bytes += common.int2bytes(self.red, 1) + common.int2bytes(self.green, 1) + common.int2bytes(self.blue, 1)
        bytes += common.int2bytes(self.power_mode, 1) + common.int2bytes(self.angle_snap, 1)
        bytes += self.write_count.to_bytes(2, "little") + self.reserved
        bytes += self.ps_timeout.to_bytes(2, "little") + self.po_timeout.to_bytes(2, "little")
        for i in range(0, 16):
            bytes += self.buttons[i].to_bytes() if i < len(self.buttons) else b"\xff\xff\xff\xff"
        for i in range(0, 16):
            bytes += self.gbuttons[i].to_bytes() if i < len(self.gbuttons) else b"\xff\xff\xff\xff"
        if self.name == "":
            bytes += b"\xff" * 48
        else:
            bytes += self.name[0:24].ljust(24, "\x00").encode("utf-16le")
        for i in range(0, 4):
            bytes += self.lighting[i].to_bytes()
        while len(bytes) < length - 2:
            bytes += b"\xff"
        bytes += common.int2bytes(common.crc16(bytes), 2)
        return bytes

    def dump(self):
        print(f"     Onboard Profile: {self.name}")
        print(f"       Report Rate {self.report_rate} ms")
        print(f"       DPI Resolutions {self.resolutions}")
        print(f"       Default Resolution Index {self.res_index}, Shift Resolution Index {self.res_shift_index}")
        print(f"       Colors {self.red} {self.green} {self.blue}")
        print(f"       Power {self.power_mode}, Angle Snapping {self.angle_snap}")
        for i in range(0, len(self.buttons)):
            if self.buttons[i].behavior is not None:
                print("       BUTTON", i + 1, self.buttons[i])
        for i in range(0, len(self.gbuttons)):
            if self.gbuttons[i].behavior is not None:
                print("       G-BUTTON", i + 1, self.gbuttons[i])


yaml.SafeLoader.add_constructor("!OnboardProfile", OnboardProfile.from_yaml)
yaml.add_representer(OnboardProfile, OnboardProfile.to_yaml)

OnboardProfilesVersion = 3


# Doesn't handle macros
class OnboardProfiles:
    """The entire onboard profiles information"""

    def __init__(self, **kwargs):
        for key, val in kwargs.items():
            setattr(self, key, val)

    @classmethod
    def from_yaml(cls, loader, node):
        args = loader.construct_mapping(node)
        return cls(**args)

    @classmethod
    def to_yaml(cls, dumper, data):
        return dumper.represent_mapping("!OnboardProfiles", data.__dict__)

    @classmethod
    def get_profile_headers(cls, device) -> list[tuple[int, int]]:
        """Returns profile headers.

        Returns
        -------
        list[tuple[int, int]]
            Tuples contain (sector, enabled).
        """
        i = 0
        headers = []
        chunk = device.feature_request(SupportedFeature.ONBOARD_PROFILES, 0x50, 0, 0, 0, i)
        s = 0x00
        if chunk[0:4] == b"\x00\x00\x00\x00" or chunk[0:4] == b"\xff\xff\xff\xff":  # look in ROM instead
            chunk = device.feature_request(SupportedFeature.ONBOARD_PROFILES, 0x50, 0x01, 0, 0, i)
            s = 0x01
        while chunk[0:2] != b"\xff\xff":
            sector, enabled = struct.unpack("!HB", chunk[0:3])
            headers.append((sector, enabled))
            i += 1
            chunk = device.feature_request(SupportedFeature.ONBOARD_PROFILES, 0x50, s, 0, 0, i * 4)
        return headers

    @classmethod
    def from_device(cls, device):
        if not device.online:  # wake the device up if necessary
            device.ping()
        response = device.feature_request(SupportedFeature.ONBOARD_PROFILES, 0x00)
        memory, profile, _macro = struct.unpack("!BBB", response[0:3])
        if memory != 0x01 or profile > 0x05:
            return
        count, oob, buttons, sectors, size, shift = struct.unpack("!BBBBHB", response[3:10])
        gbuttons = buttons if (shift & 0x3 == 0x2) else 0
        headers = OnboardProfiles.get_profile_headers(device)
        profiles = {}
        for i, (sector, enabled) in enumerate(headers, start=1):
            profiles[i] = OnboardProfile.from_dev(device, i, sector, size, enabled, buttons, gbuttons)
        return cls(
            version=OnboardProfilesVersion,
            name=device.name,
            count=count,
            buttons=buttons,
            gbuttons=gbuttons,
            sectors=sectors,
            size=size,
            profiles=profiles,
        )

    def to_bytes(self):
        bytes = b""
        for i in range(1, len(self.profiles) + 1):
            profiles_sector = common.int2bytes(self.profiles[i].sector, 2)
            profiles_enabled = common.int2bytes(self.profiles[i].enabled, 1)
            bytes += profiles_sector + profiles_enabled + b"\x00"
        bytes += b"\xff\xff\x00\x00"  # marker after last profile
        while len(bytes) < self.size - 2:  # leave room for CRC
            bytes += b"\xff"
        bytes += common.int2bytes(common.crc16(bytes), 2)
        return bytes

    @classmethod
    def read_sector(cls, dev, sector, s):  # doesn't check for valid sector or size
        bytes = b""
        o = 0
        while o < s - 15:
            chunk = dev.feature_request(SupportedFeature.ONBOARD_PROFILES, 0x50, sector >> 8, sector & 0xFF, o >> 8, o & 0xFF)
            bytes += chunk
            o += 16
        chunk = dev.feature_request(
            SupportedFeature.ONBOARD_PROFILES,
            0x50,
            sector >> 8,
            sector & 0xFF,
            (s - 16) >> 8,
            (s - 16) & 0xFF,
        )
        bytes += chunk[16 + o - s :]  # the last chunk has to be read in an awkward way
        return bytes

    @classmethod
    def write_sector(cls, device, s, bs):  # doesn't check for valid sector or size
        rbs = OnboardProfiles.read_sector(device, s, len(bs))
        if rbs[:-2] == bs[:-2]:
            return False
        device.feature_request(SupportedFeature.ONBOARD_PROFILES, 0x60, s >> 8, s & 0xFF, 0, 0, len(bs) >> 8, len(bs) & 0xFF)
        o = 0
        while o < len(bs) - 1:
            device.feature_request(SupportedFeature.ONBOARD_PROFILES, 0x70, bs[o : o + 16])
            o += 16
        device.feature_request(SupportedFeature.ONBOARD_PROFILES, 0x80)
        return True

    def write(self, device):
        try:
            written = 1 if OnboardProfiles.write_sector(device, 0, self.to_bytes()) else 0
        except Exception as e:
            logger.warning("Exception writing onboard profile control sector")
            raise e
        for p in self.profiles.values():
            try:
                if p.sector >= self.sectors:
                    raise Exception(f"Sector {p.sector} not a writable sector")
                written += 1 if OnboardProfiles.write_sector(device, p.sector, p.to_bytes(self.size)) else 0
            except Exception as e:
                logger.warning(f"Exception writing onboard profile sector {p.sector}")
                raise e
        return written

    def show(self):
        print(yaml.dump(self))


yaml.SafeLoader.add_constructor("!OnboardProfiles", OnboardProfiles.from_yaml)
yaml.add_representer(OnboardProfiles, OnboardProfiles.to_yaml)


def feature_request(device, feature, function=0x00, *params, no_reply=False):
    if device.online and device.features:
        if feature in device.features:
            feature_index = device.features[feature]
            return device.request((feature_index << 8) + (function & 0xFF), *params, no_reply=no_reply)


class Hidpp20:
    # Host-side counter for SetComplete cookies (see set_configuration_complete).
    # Seeded to a non-zero random 16-bit value at import so successive sessions
    # don't trivially collide; we just need to never send 0x0000.
    _session_cookie = getrandbits(16) or 1

    def get_firmware(self, device) -> tuple[common.FirmwareInfo] | None:
        """Reads a device's firmware info.

        :returns: a list of FirmwareInfo tuples, ordered by firmware layer.
        """
        count = device.feature_request(SupportedFeature.DEVICE_FW_VERSION)
        if count:
            count = ord(count[:1])

            fw = []
            for index in range(0, count):
                fw_info = device.feature_request(SupportedFeature.DEVICE_FW_VERSION, 0x10, index)
                if fw_info:
                    level = ord(fw_info[:1]) & 0x0F
                    if level == 0 or level == 1:
                        name, version_major, version_minor, build = struct.unpack("!3sBBH", fw_info[1:8])
                        version = f"{version_major:02X}.{version_minor:02X}"
                        if build:
                            version += f".B{build:04X}"
                        extras = fw_info[9:].rstrip(b"\x00") or None
                        fw_info = common.FirmwareInfo(FirmwareKind(level), name.decode("ascii"), version, extras)
                    elif level == FirmwareKind.Hardware:
                        fw_info = common.FirmwareInfo(FirmwareKind.Hardware, "", str(ord(fw_info[1:2])), None)
                    else:
                        fw_info = common.FirmwareInfo(FirmwareKind.Other, "", "", None)

                    fw.append(fw_info)
            return tuple(fw)

    def get_firmware_centurion(self, device):
        return _centurion.get_firmware_centurion(device)

    def get_serial_centurion(self, device):
        return _centurion.get_serial_centurion(device)

    def get_hardware_info_centurion(self, device):
        return _centurion.get_hardware_info_centurion(device)

    def _centurion_sub_device_info_request(self, device, function=0x00, *params):
        return _centurion._centurion_sub_device_info_request(device, function, *params)

    def get_firmware_centurion_sub(self, device):
        return _centurion.get_firmware_centurion_sub(device)

    def get_serial_centurion_sub(self, device):
        return _centurion.get_serial_centurion_sub(device)

    def get_hardware_info_centurion_sub(self, device):
        return _centurion.get_hardware_info_centurion_sub(device)

    def get_ids(self, device):
        """Reads a device's ids (unit and model numbers)"""
        ids = device.feature_request(SupportedFeature.DEVICE_FW_VERSION)
        if ids:
            unitId = ids[1:5]
            modelId = ids[7:13]
            transport_bits = ord(ids[6:7])
            offset = 0
            tid_map = {}
            for transport, flag in [("btid", 0x1), ("btleid", 0x02), ("wpid", 0x04), ("usbid", 0x08)]:
                if transport_bits & flag:
                    tid_map[transport] = modelId[offset : offset + 2].hex().upper()
                    offset = offset + 2
            return unitId.hex().upper(), modelId.hex().upper(), tid_map

    def get_kind(self, device: Device):
        """Reads a device's type.

        :see DEVICE_KIND:
        :returns: a string describing the device type, or ``None`` if the device is
        not available or does not support the ``DEVICE_NAME`` feature.
        """
        kind = device.feature_request(SupportedFeature.DEVICE_NAME, 0x20)
        if kind:
            kind = ord(kind[:1])
            try:
                return KIND_MAP[DEVICE_KIND[kind]]
            except Exception:
                return None

    def get_name(self, device: Device):
        """Reads a device's name.

        :returns: a string with the device name, or ``None`` if the device is not
        available or does not support the ``DEVICE_NAME`` feature.
        """
        name_length = device.feature_request(SupportedFeature.DEVICE_NAME)
        if name_length:
            name_length = ord(name_length[:1])

            name = b""
            while len(name) < name_length:
                fragment = device.feature_request(SupportedFeature.DEVICE_NAME, 0x10, len(name))
                if fragment:
                    name += fragment[: name_length - len(name)]
                else:
                    logger.error("failed to read whole name of %s (expected %d chars)", device, name_length)
                    return None

            return name.decode("utf-8")

    def get_name_centurion(self, device):
        return _centurion.get_name_centurion(device)

    def get_friendly_name(self, device: Device):
        """Reads a device's friendly name.

        :returns: a string with the device name, or ``None`` if the device is not
        available or does not support the ``DEVICE_NAME`` feature.
        """
        name_length = device.feature_request(SupportedFeature.DEVICE_FRIENDLY_NAME)
        if name_length:
            name_length = ord(name_length[:1])

            name = b""
            while len(name) < name_length:
                fragment = device.feature_request(SupportedFeature.DEVICE_FRIENDLY_NAME, 0x10, len(name))
                if fragment:
                    name += fragment[1 : name_length - len(name) + 1]
                else:
                    logger.error("failed to read whole name of %s (expected %d chars)", device, name_length)
                    return None

            return name.decode("utf-8")

    def get_battery_status(self, device: Device):
        report = device.feature_request(SupportedFeature.BATTERY_STATUS)
        if report:
            return decipher_battery_status(report)

    def get_battery_unified(self, device: Device):
        report = device.feature_request(SupportedFeature.UNIFIED_BATTERY, 0x10)
        if report is not None:
            return decipher_battery_unified(report)

    def get_battery_voltage(self, device: Device):
        report = device.feature_request(SupportedFeature.BATTERY_VOLTAGE)
        if report is not None:
            return decipher_battery_voltage(report)

    def get_adc_measurement(self, device: Device):
        try:  # this feature call produces an error for headsets that are connected but inactive
            report = device.feature_request(SupportedFeature.ADC_MEASUREMENT)
            if report is not None:
                return decipher_adc_measurement(report)
        except exceptions.FeatureCallError:
            return SupportedFeature.ADC_MEASUREMENT if SupportedFeature.ADC_MEASUREMENT in device.features else None

    def get_battery_centurion(self, device: Device):
        return _centurion.get_battery_centurion(device)

    def get_battery(self, device, feature):
        """Return battery information - feature, approximate level, next, charging, voltage
        or battery feature if there is one but it is not responding or None for no battery feature"""

        if feature is not None:
            battery_function = battery_functions.get(feature, None)
            if battery_function:
                result = battery_function(self, device)
                if result:
                    return result
        else:
            for battery_function in battery_functions.values():
                result = battery_function(self, device)
                if result:
                    return result
        return 0

    def get_keys(self, device: Device):
        # TODO: add here additional variants for other REPROG_CONTROLS
        count = None
        if device.features and SupportedFeature.REPROG_CONTROLS_V2 in device.features:
            count = device.feature_request(SupportedFeature.REPROG_CONTROLS_V2)
            return KeysArrayV2(device, ord(count[:1]))
        elif device.features and SupportedFeature.REPROG_CONTROLS_V4 in device.features:
            count = device.feature_request(SupportedFeature.REPROG_CONTROLS_V4)
            return KeysArrayV4(device, ord(count[:1]))
        return None

    def get_remap_keys(self, device: Device):
        count = device.feature_request(SupportedFeature.PERSISTENT_REMAPPABLE_ACTION, 0x10)
        if count:
            return KeysArrayPersistent(device, ord(count[:1]))

    def get_gestures(self, device: Device):
        if getattr(device, "_gestures", None) is not None:
            return device._gestures
        if SupportedFeature.GESTURE_2 in device.features:
            return Gestures(device)

    def get_backlight(self, device: Device):
        if getattr(device, "_backlight", None) is not None:
            return device._backlight
        if SupportedFeature.BACKLIGHT2 in device.features:
            return Backlight(device)

    def get_force_buttons(self, device: Device):
        if getattr(device, "_force_buttons", None) is not None:
            return device._force_buttons
        if SupportedFeature.FORCE_SENSING_BUTTON in device.features:
            return ForceSensingButtonArray(device)

    def get_profiles(self, device: Device):
        if getattr(device, "_profiles", None) is not None:
            return device._profiles
        if SupportedFeature.ONBOARD_PROFILES in device.features:
            return OnboardProfiles.from_device(device)

    def get_mouse_pointer_info(self, device: Device):
        pointer_info = device.feature_request(SupportedFeature.MOUSE_POINTER)
        if pointer_info:
            dpi, flags = struct.unpack("!HB", pointer_info[:3])
            acceleration = ("none", "low", "med", "high")[flags & 0x3]
            suggest_os_ballistics = (flags & 0x04) != 0
            suggest_vertical_orientation = (flags & 0x08) != 0
            return {
                "dpi": dpi,
                "acceleration": acceleration,
                "suggest_os_ballistics": suggest_os_ballistics,
                "suggest_vertical_orientation": suggest_vertical_orientation,
            }

    def get_vertical_scrolling_info(self, device: Device):
        vertical_scrolling_info = device.feature_request(SupportedFeature.VERTICAL_SCROLLING)
        if vertical_scrolling_info:
            roller, ratchet, lines = struct.unpack("!BBB", vertical_scrolling_info[:3])
            roller_type = (
                "reserved",
                "standard",
                "reserved",
                "3G",
                "micro",
                "normal touch pad",
                "inverted touch pad",
                "reserved",
            )[roller]
            return {"roller": roller_type, "ratchet": ratchet, "lines": lines}

    def get_hi_res_scrolling_info(self, device: Device):
        hi_res_scrolling_info = device.feature_request(SupportedFeature.HI_RES_SCROLLING)
        if hi_res_scrolling_info:
            mode, resolution = struct.unpack("!BB", hi_res_scrolling_info[:2])
            return mode, resolution

    def get_pointer_speed_info(self, device: Device):
        pointer_speed_info = device.feature_request(SupportedFeature.POINTER_SPEED)
        if pointer_speed_info:
            pointer_speed_hi, pointer_speed_lo = struct.unpack("!BB", pointer_speed_info[:2])
            # if pointer_speed_lo > 0:
            #     pointer_speed_lo = pointer_speed_lo
            return pointer_speed_hi + pointer_speed_lo / 256

    def get_lowres_wheel_status(self, device: Device):
        lowres_wheel_status = device.feature_request(SupportedFeature.LOWRES_WHEEL)
        if lowres_wheel_status:
            wheel_flag = struct.unpack("!B", lowres_wheel_status[:1])[0]
            wheel_reporting = ("HID", "HID++")[wheel_flag & 0x01]
            return wheel_reporting

    def get_hires_wheel(self, device: Device):
        caps = device.feature_request(SupportedFeature.HIRES_WHEEL, 0x00)
        mode = device.feature_request(SupportedFeature.HIRES_WHEEL, 0x10)
        ratchet = device.feature_request(SupportedFeature.HIRES_WHEEL, 0x030)

        if caps and mode and ratchet:
            # Parse caps
            multi, flags = struct.unpack("!BB", caps[:2])

            has_invert = (flags & 0x08) != 0
            has_ratchet = (flags & 0x04) != 0

            # Parse mode
            wheel_mode, reserved = struct.unpack("!BB", mode[:2])

            target = (wheel_mode & 0x01) != 0
            res = (wheel_mode & 0x02) != 0
            inv = (wheel_mode & 0x04) != 0

            # Parse Ratchet switch
            ratchet_mode, reserved = struct.unpack("!BB", ratchet[:2])

            ratchet = (ratchet_mode & 0x01) != 0

            return multi, has_invert, has_ratchet, inv, res, target, ratchet

    def get_new_fn_inversion(self, device: Device):
        state = device.feature_request(SupportedFeature.NEW_FN_INVERSION, 0x00)
        if state:
            inverted, default_inverted = struct.unpack("!BB", state[:2])
            inverted = (inverted & 0x01) != 0
            default_inverted = (default_inverted & 0x01) != 0
            return inverted, default_inverted

    def get_host_names(self, device: Device):
        state = device.feature_request(SupportedFeature.HOSTS_INFO, 0x00)
        host_names = {}
        if state:
            capability_flags, _ignore, numHosts, currentHost = struct.unpack("!BBBB", state[:4])
            if capability_flags & 0x01:  # device can get host names
                for host in range(0, numHosts):
                    hostinfo = device.feature_request(SupportedFeature.HOSTS_INFO, 0x10, host)
                    _ignore, status, _ignore, _ignore, nameLen, _ignore = struct.unpack("!BBBBBB", hostinfo[:6])
                    name = ""
                    remaining = nameLen
                    while remaining > 0:
                        name_piece = device.feature_request(SupportedFeature.HOSTS_INFO, 0x30, host, nameLen - remaining)
                        if name_piece:
                            name += name_piece[2 : 2 + min(remaining, 14)].decode()
                            remaining = max(0, remaining - 14)
                        else:
                            remaining = 0
                    host_names[host] = (bool(status), name)
            if host_names:  # update the current host's name if it doesn't match the system name
                hostname = socket.gethostname().partition(".")[0]
                if host_names[currentHost][1] != hostname:
                    self.set_host_name(device, hostname, host_names[currentHost][1])
                    host_names[currentHost] = (host_names[currentHost][0], hostname)
        return host_names

    def set_host_name(self, device: Device, name, currentName=""):
        name = bytearray(name, "utf-8")
        currentName = bytearray(currentName, "utf-8")
        if logger.isEnabledFor(logging.INFO):
            logger.info("Setting host name to %s", name)
        state = device.feature_request(SupportedFeature.HOSTS_INFO, 0x00)
        if state:
            flags, _ignore, _ignore, currentHost = struct.unpack("!BBBB", state[:4])
            if flags & 0x02:
                hostinfo = device.feature_request(SupportedFeature.HOSTS_INFO, 0x10, currentHost)
                _ignore, _ignore, _ignore, _ignore, _ignore, maxNameLen = struct.unpack("!BBBBBB", hostinfo[:6])
                if name[:maxNameLen] == currentName[:maxNameLen] and False:
                    return True
                length = min(maxNameLen, len(name))
                chunk = 0
                while chunk < length:
                    response = device.feature_request(
                        SupportedFeature.HOSTS_INFO, 0x40, currentHost, chunk, name[chunk : chunk + 14]
                    )
                    if not response:
                        return False
                    chunk += 14
            return True

    def get_onboard_mode(self, device: Device):
        state = device.feature_request(SupportedFeature.ONBOARD_PROFILES, 0x20)

        if state:
            mode = struct.unpack("!B", state[:1])[0]
            return mode

    def set_onboard_mode(self, device: Device, mode):
        state = device.feature_request(SupportedFeature.ONBOARD_PROFILES, 0x10, mode)
        return state

    def get_polling_rate(self, device: Device):
        state = device.feature_request(SupportedFeature.REPORT_RATE, 0x10)
        if state:
            rate = struct.unpack("!B", state[:1])[0]
            return f"{str(rate)}ms"
        else:
            rates = ["8ms", "4ms", "2ms", "1ms", "500us", "250us", "125us"]
            state = device.feature_request(SupportedFeature.EXTENDED_ADJUSTABLE_REPORT_RATE, 0x20)
            if state:
                rate = struct.unpack("!B", state[:1])[0]
                return rates[rate]

    def get_remaining_pairing(self, device: Device):
        result = device.feature_request(SupportedFeature.REMAINING_PAIRING, 0x0)
        if result:
            result = struct.unpack("!B", result[:1])[0]
            SupportedFeature._fallback = lambda x: f"unknown:{x:04X}"
            return result

    def get_keyboard_layout(self, device: Device):
        """Return the device's keyboard layout country code, or None.

        Country code semantics match the HID HUT keyboard country codes that
        Logitech's KEYBOARD_LAYOUT_2 (0x4540) feature reports in the first byte.
        Used by the per-key painter to pick the matching regional layout.
        """
        result = device.feature_request(SupportedFeature.KEYBOARD_LAYOUT_2, 0x00)
        if result:
            return struct.unpack("!B", result[:1])[0]
        return None

    def get_configuration_cookie(self, device: Device):
        """ConfigChange (0x0020) GetCookie — read the device's current configuration cookie."""
        response = device.feature_request(SupportedFeature.CONFIG_CHANGE, 0x00)
        return response[:2] if response else None

    def next_session_cookie(self):
        """Bump and return the host-side counter used as the SetComplete cookie."""
        Hidpp20._session_cookie = (Hidpp20._session_cookie + 1) & 0xFFFF or 1
        return bytes([Hidpp20._session_cookie >> 8, Hidpp20._session_cookie & 0xFF])

    def set_configuration_complete(self, device: Device, cookie=None, no_reply=False):
        """ConfigChange (0x0020) SetComplete — acknowledge host has synced with device configuration.

        Sends a host-side monotonic counter, incremented per call and
        always non-zero. Cookie 0x0000 has been observed to release the
        SW effect-engine claim on at least the G515 LS TKL; we avoid it."""
        if cookie is None:
            cookie = self.next_session_cookie()
        if cookie and len(cookie) >= 2:
            return device.feature_request(SupportedFeature.CONFIG_CHANGE, 0x10, cookie[0], cookie[1], no_reply=no_reply)

    def config_change(self, device: Device, configuration, no_reply=False):
        """Deprecated — use set_configuration_complete() instead."""
        return device.feature_request(SupportedFeature.CONFIG_CHANGE, 0x10, configuration, no_reply=no_reply)


battery_functions = {
    SupportedFeature.BATTERY_STATUS: Hidpp20.get_battery_status,
    SupportedFeature.BATTERY_VOLTAGE: Hidpp20.get_battery_voltage,
    SupportedFeature.UNIFIED_BATTERY: Hidpp20.get_battery_unified,
    SupportedFeature.ADC_MEASUREMENT: Hidpp20.get_adc_measurement,
    SupportedFeature.CENTURION_BATTERY_SOC: Hidpp20.get_battery_centurion,
}


def decipher_battery_status(report: FixedBytes5) -> Tuple[Any, Battery]:
    battery_discharge_level, battery_discharge_next_level, battery_status = struct.unpack("!BBB", report[:3])
    if battery_discharge_level == 0:
        battery_discharge_level = None
    try:
        status = BatteryStatus(battery_status)
    except ValueError:
        status = None
        logger.debug(f"Unknown battery status byte 0x{battery_status:02X}")
    if logger.isEnabledFor(logging.DEBUG):
        logger.debug(
            "battery status %s%% charged, next %s%%, status %s", battery_discharge_level, battery_discharge_next_level, status
        )
    return SupportedFeature.BATTERY_STATUS, Battery(battery_discharge_level, battery_discharge_next_level, status, None)


def decipher_battery_voltage(report: bytes):
    voltage, flags = struct.unpack(">HB", report[:3])
    status = BatteryStatus.DISCHARGING
    charge_sts = ErrorCode.UNKNOWN
    charge_lvl = ChargeLevel.AVERAGE
    charge_type = ChargeType.STANDARD
    if flags & (1 << 7):
        status = BatteryStatus.RECHARGING
        charge_sts = ChargeStatus(flags & 0x03)
    if charge_sts is None:
        charge_sts = ErrorCode.UNKNOWN
    elif isinstance(charge_sts, ChargeStatus) and ChargeStatus.FULL in charge_sts:
        charge_lvl = ChargeLevel.FULL
        status = BatteryStatus.FULL
    if flags & (1 << 3):
        charge_type = ChargeType.FAST
    elif flags & (1 << 4):
        charge_type = ChargeType.SLOW
        status = BatteryStatus.SLOW_RECHARGE
    elif flags & (1 << 5):
        charge_lvl = ChargeLevel.CRITICAL
    charge_level = estimate_battery_level_percentage(voltage)
    if charge_level:
        charge_lvl = charge_level
    if logger.isEnabledFor(logging.DEBUG):
        logger.debug(
            "battery voltage %d mV, charging %s, status %d = %s, level %s, type %s",
            voltage,
            status,
            (flags & 0x03),
            charge_sts,
            charge_lvl,
            charge_type,
        )
    return SupportedFeature.BATTERY_VOLTAGE, Battery(charge_lvl, None, status, voltage)


def decipher_battery_unified(report) -> tuple[SupportedFeature, Battery]:
    discharge, level, status_byte, _ignore = struct.unpack("!BBBB", report[:4])
    try:
        status = BatteryStatus(status_byte)
    except ValueError:
        status = None
        logger.debug(f"Unknown battery status byte 0x{status_byte:02X}")
    if logger.isEnabledFor(logging.DEBUG):
        logger.debug("battery unified %s%% charged, level %s, charging %s", discharge, level, status)

    if level == 8:
        approx_level = BatteryLevelApproximation.FULL
    elif level == 4:
        approx_level = BatteryLevelApproximation.GOOD
    elif level == 2:
        approx_level = BatteryLevelApproximation.LOW
    elif level == 1:
        approx_level = BatteryLevelApproximation.CRITICAL
    else:
        approx_level = BatteryLevelApproximation.EMPTY

    return SupportedFeature.UNIFIED_BATTERY, Battery(discharge if discharge else approx_level, None, status, None)


decipher_battery_centurion = _centurion.decipher_battery_centurion


def decipher_adc_measurement(report) -> tuple[SupportedFeature, Battery]:
    # partial implementation - needs mapping to levels
    adc_voltage, flags = struct.unpack("!HB", report[:3])
    charge_level = estimate_battery_level_percentage(adc_voltage)
    if flags & 0x01:
        status = BatteryStatus.RECHARGING if flags & 0x02 else BatteryStatus.DISCHARGING
        return SupportedFeature.ADC_MEASUREMENT, Battery(charge_level, None, status, adc_voltage)


def estimate_battery_level_percentage(value_millivolt: int) -> int | None:
    """Estimate battery level percentage based on battery voltage.

    Uses linear approximation to estimate the battery level in percent.

    Parameters
    ----------
    value_millivolt
        Measured battery voltage in millivolt.
    """
    battery_voltage_to_percentage = [
        (4186, 100),
        (4067, 90),
        (3989, 80),
        (3922, 70),
        (3859, 60),
        (3811, 50),
        (3778, 40),
        (3751, 30),
        (3717, 20),
        (3671, 10),
        (3646, 5),
        (3579, 2),
        (3500, 0),
    ]

    if value_millivolt >= battery_voltage_to_percentage[0][0]:
        return battery_voltage_to_percentage[0][1]
    if value_millivolt <= battery_voltage_to_percentage[-1][0]:
        return battery_voltage_to_percentage[-1][1]

    for i in range(len(battery_voltage_to_percentage) - 1):
        v_high, p_high = battery_voltage_to_percentage[i]
        v_low, p_low = battery_voltage_to_percentage[i + 1]
        if v_low <= value_millivolt <= v_high:
            # Linear interpolation
            percent = p_low + (p_high - p_low) * (value_millivolt - v_low) / (v_high - v_low)
            return round(percent)
    return 0


class ForceSensingButton:
    """A button that has a force value at which to trigger the button"""

    @classmethod
    def create(cls, device, number: int):
        buttondata = device.feature_request(SupportedFeature.FORCE_SENSING_BUTTON, 0x10, number)
        buttoncurrent = device.feature_request(SupportedFeature.FORCE_SENSING_BUTTON, 0x20, number)
        if buttondata is not None and buttoncurrent is not None:
            changeable, default, max_value, min_value = struct.unpack("!HHHH", buttondata[:8])
            changeable = changeable & 0x01
            current = struct.unpack("!H", buttoncurrent[:2])[0]
            return cls(device, number, changeable, default, max_value, min_value, current)

    def __init__(self, device, number: int, changeable: bool, default: int, max_value: int, min_value: int, current: int):
        self._device = device
        self.number = number
        self.changeable = changeable
        self.default = default
        self.min_value = min_value
        self.max_value = max_value
        self._current = current

    def get_current(self) -> int:
        return self._current

    def set_current(self, current: int) -> None:
        if not self.changeable:
            logger.warning(f"FORCE_SENSING_BUTTON on device {self._device} does not allow changing force.")
        if self.min_value <= current <= self.max_value:
            ret = self._device.feature_request(
                SupportedFeature.FORCE_SENSING_BUTTON, 0x30, struct.pack("!BH", self.number, current)
            )
        if ret is None and logger.isEnabledFor(logging.DEBUG):
            logger.debug(f"FORCE_SENSING_BUTTON setButtonConfig on device {self._device} didn't respond.")

    def acceptable_current(self, value: int) -> bool:
        return self.min_value <= value <= self.max_value


class ForceSensingButtonArray(UserDict):
    """A map of buttons supporting force sensing"""

    def __new__(cls, device: Device):
        assert device is not None
        count = device.feature_request(SupportedFeature.FORCE_SENSING_BUTTON, 0x00)
        if count:
            instance = super().__new__(cls)
            instance._count = ord(count[:1])
            return instance

    def __init__(self, device: Device):
        super().__init__(self)
        self.device = device
        for index in range(0, self._count):
            self[index] = None

    def __getitem__(self, index: int):
        item = super().__getitem__(index)
        if item is None:
            self.query_key(index)
        return super().__getitem__(index)

    def query_key(self, index):
        if index not in self:
            raise IndexError(index)
        button = ForceSensingButton.create(self.device, index)
        if button:
            self[index] = button
            return button

    def query(self):
        for index in self:
            button = ForceSensingButton.create(self.device, index)
            if button:
                self[index] = button
        return self

    # interface for single force button
    def get_current(self):
        return self[0].get_current()

    def set_current(self, current: int) -> None:
        self[0].set_current(current)

    def acceptable(self, value: int) -> bool:
        return self[0].acceptable(value)

    def acceptable_current_key(self, index: int, value: int) -> bool:
        return self[index].acceptable(value)


# --- OnboardEQ (0x0636) — re-exported from onboard_eq.py ---
# --- AdvancedParaEQ (0x020D) — re-exported from advanced_para_eq.py ---
from .advanced_para_eq import FILTER_TYPE_HP  # noqa: E402, F401
from .advanced_para_eq import FILTER_TYPE_PEAKING  # noqa: E402, F401
from .advanced_para_eq import FILTER_TYPE_PEAKING_G522  # noqa: E402, F401
from .advanced_para_eq import get_advanced_eq_active_slot  # noqa: E402, F401
from .advanced_para_eq import get_advanced_eq_defaults  # noqa: E402, F401
from .advanced_para_eq import get_advanced_eq_friendly_name  # noqa: E402, F401
from .advanced_para_eq import get_advanced_eq_info  # noqa: E402, F401
from .advanced_para_eq import get_advanced_eq_params  # noqa: E402, F401
from .advanced_para_eq import parse_v2_bands  # noqa: E402, F401
from .advanced_para_eq import probe_advanced_eq_slots  # noqa: E402, F401
from .advanced_para_eq import probe_all_presets as probe_advanced_eq_presets  # noqa: E402, F401
from .onboard_eq import _build_set_eq_payload  # noqa: E402, F401
from .onboard_eq import get_onboard_eq_info  # noqa: E402, F401
from .onboard_eq import get_onboard_eq_params  # noqa: E402, F401
from .onboard_eq import set_onboard_eq_params  # noqa: E402, F401
