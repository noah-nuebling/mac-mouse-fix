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

# Reprogrammable keys information
# Mostly from Logitech documentation, but with some edits for better Linux compatibility

import os

from enum import IntEnum

import yaml

from .common import NamedInts
from .common import UnsortedNamedInts

_XDG_CONFIG_HOME = os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser(os.path.join("~", ".config"))
_keys_file_path = os.path.join(_XDG_CONFIG_HOME, "solaar", "keys.yaml")


# Original set done as
# <controls.xml awk -F\" '/<Control /{sub(/^LD_FINFO_(CTRLID_)?/, "", $2);printf("\t%s=0x%04X,\n", $2, $4)}' | sort -t= -k2
# Keys added afterwards based on information from Logitech and users
CONTROL = NamedInts(
    {
        "Volume_Up_old": 0x0001,
        "Volume_Down_old": 0x0002,
        "Mute": 0x0003,
        "Play__Pause_old": 0x0004,
        "Next": 0x0005,
        "Previous": 0x0006,
        "Stop": 0x0007,
        "Application_Switcher": 0x0008,
        "Burn": 0x0009,
        "Calculator": 0x000A,  # Craft Keyboard top 4th from right; Logitech
        "Calendar": 0x000B,
        "Close": 0x000C,
        "Eject": 0x000D,
        "Mail": 0x000E,
        "Help_As_HID": 0x000F,
        "Help_As_F1": 0x0010,
        "Launch_Word_Proc": 0x0011,
        "Launch_Spreadsheet": 0x0012,
        "Launch_Presentation": 0x0013,
        "Undo_As_Ctrl_Z": 0x0014,
        "Undo_As_HID": 0x0015,
        "Redo_As_Ctrl_Y": 0x0016,
        "Redo_As_HID": 0x0017,
        "Print_As_Ctrl_P": 0x0018,  # Logitech, modified
        "Print_As_HID": 0x0019,
        "Save_As_Ctrl_S": 0x001A,
        "Save_As_HID": 0x001B,
        "Preset_A": 0x001C,
        "Preset_B": 0x001D,
        "Preset_C": 0x001E,
        "Preset_D": 0x001F,
        "Favorites": 0x0020,
        "Gadgets": 0x0021,
        "My_Home": 0x0022,
        "Gadgets_As_Win_G": 0x0023,
        "Maximize_As_HID": 0x0024,
        "Maximize_As_Win_Shift_M": 0x0025,
        "Minimize_As_HID": 0x0026,
        "Minimize_As_Win_M": 0x0027,
        "Media_Player": 0x0028,
        "Media_Center_Logi": 0x0029,
        "Media_Center_Msft": 0x002A,  # Should not be used as it is not reprogrammable under Windows
        "Custom_Menu": 0x002B,
        "Messenger": 0x002C,
        "My_Documents": 0x002D,
        "My_Music": 0x002E,
        "Webcam": 0x002F,
        "My_Pictures": 0x0030,
        "My_Videos": 0x0031,
        "My_Computer_As_HID": 0x0032,
        "My_Computer_As_Win_E": 0x0033,
        "FN_Key": 0x0034,
        "Launch_Picture_Viewer": 0x0035,
        "One_Touch_Search": 0x0036,
        "Preset_1": 0x0037,
        "Preset_2": 0x0038,
        "Preset_3": 0x0039,
        "Preset_4": 0x003A,
        "Record": 0x003B,
        "Internet_Refresh": 0x003C,
        "Search": 0x003E,  # SEARCH
        "Shuffle": 0x003F,
        "Sleep": 0x0040,
        "Internet_Stop": 0x0041,
        "Synchronize": 0x0042,
        "Zoom": 0x0043,
        "Zoom_In_As_HID": 0x0044,
        "Zoom_In_As_Ctrl_Wheel": 0x0045,
        "Zoom_In_As_Cltr_Plus": 0x0046,
        "Zoom_Out_As_HID": 0x0047,
        "Zoom_Out_As_Ctrl_Wheel": 0x0048,
        "Zoom_Out_As_Ctrl_Minus": 0x0049,
        "Zoom_Reset": 0x004A,
        "Zoom_Full_Screen": 0x004B,
        "Print_Screen": 0x004C,
        "Pause_Break": 0x004D,
        "Scroll_Lock": 0x004E,
        "Contextual_Menu": 0x004F,
        "Left_Button": 0x0050,  # LEFT_CLICK; Logitech
        "Right_Button": 0x0051,  # RIGHT_CLICK; Logitech
        "Middle_Button": 0x0052,  # MIDDLE_BUTTON; Logitech
        "Back_Button": 0x0053,  # from M510v2 was BACK_AS_BUTTON_4; Logitech
        "Back": 0x0054,  # BACK_AS_HID
        "Back_As_Alt_Win_Arrow": 0x0055,
        "Forward_Button": 0x0056,  # from M510v2 was FORWARD_AS_BUTTON_5; Logitech
        "Forward_As_HID": 0x0057,
        "Forward_As_Alt_Win_Arrow": 0x0058,
        "Button_6": 0x0059,
        "Left_Scroll_As_Button_7": 0x005A,
        "Left_Tilt": 0x005B,  # from M510v2 was LEFT_SCROLL_AS_AC_PAN
        "Right_Scroll_As_Button_8": 0x005C,
        "Right_Tilt": 0x005D,  # from M510v2 was RIGHT_SCROLL_AS_AC_PAN
        "Button_9": 0x005E,
        "Button_10": 0x005F,
        "Button_11": 0x0060,
        "Button_12": 0x0061,
        "Button_13": 0x0062,
        "Button_14": 0x0063,
        "Button_15": 0x0064,
        "Button_16": 0x0065,
        "Button_17": 0x0066,
        "Button_18": 0x0067,
        "Button_19": 0x0068,
        "Button_20": 0x0069,
        "Button_21": 0x006A,
        "Button_22": 0x006B,
        "Button_23": 0x006C,
        "Button_24": 0x006D,
        "Show_Desktop": 0x006E,  # Craft Keyboard Fn F5; Logitch
        "Screen_Lock": 0x006F,  # Craft Keyboard top 1st from right; Logitech
        "Fn_F1": 0x0070,
        "Fn_F2": 0x0071,
        "Fn_F3": 0x0072,
        "Fn_F4": 0x0073,
        "Fn_F5": 0x0074,
        "Fn_F6": 0x0075,
        "Fn_F7": 0x0076,
        "Fn_F8": 0x0077,
        "Fn_F9": 0x0078,
        "Fn_F10": 0x0079,
        "Fn_F11": 0x007A,
        "Fn_F12": 0x007B,
        "Fn_F13": 0x007C,
        "Fn_F14": 0x007D,
        "Fn_F15": 0x007E,
        "Fn_F16": 0x007F,
        "Fn_F17": 0x0080,
        "Fn_F18": 0x0081,
        "Fn_F19": 0x0082,
        "IOS_Home": 0x0083,
        "Android_Home": 0x0084,
        "Android_Menu": 0x0085,
        "Android_Search": 0x0086,
        "Android_Back": 0x0087,
        "Home_Combo": 0x0088,
        "Lock_Combo": 0x0089,
        "IOS_Virtual_Keyboard": 0x008A,
        "IOS_Language_Switch": 0x008B,
        "Mac_Expose": 0x008C,
        "Mac_Dashboard": 0x008D,
        "Win7_Snap_Left": 0x008E,
        "Win7_Snap_Right": 0x008F,
        "Minimize_Window": 0x0090,  # WIN7_MINIMIZE_AS_WIN_ARROW
        "Maximize_Window": 0x0091,  # WIN7_MAXIMIZE_AS_WIN_ARROW
        "Win7_Stretch_Up": 0x0092,
        "Win7_Monitor_Switch_As_Win_Shift_LeftArrow": 0x0093,
        "Win7_Monitor_Switch_As_Win_Shift_RightArrow": 0x0094,
        "Switch_Screen": 0x0095,  # WIN7_SHOW_PRESENTATION_MODE
        "Win7_Show_Mobility_Center": 0x0096,
        "Analog_HScroll": 0x0097,
        "Metro_Appswitch": 0x009F,
        "Metro_Appbar": 0x00A0,
        "Metro_Charms": 0x00A1,
        "Calc_Vkeyboard": 0x00A2,
        "Metro_Search": 0x00A3,
        "Combo_Sleep": 0x00A4,
        "Metro_Share": 0x00A5,
        "OS_Settings": 0x00A6,  # Logitech
        "Metro_Devices": 0x00A7,
        "Metro_Start_Screen": 0x00A9,
        "Zoomin": 0x00AA,
        "Zoomout": 0x00AB,
        "Back_Hscroll": 0x00AC,
        "Show_Desktop_HPP": 0x00AE,
        "Fn_Left_Click": 0x00B7,  # from K400 Plus
        # https://docs.google.com/document/u/0/d/1YvXICgSe8BcBAuMr4Xu_TutvAxaa-RnGfyPFWBWzhkc/export?format=docx
        # Extract to csv.  Eliminate extra linefeeds and spaces.
        # awk -F, '/0x/{gsub(" \\+ ","_",$2); gsub("/","__",$2); gsub(" -","_Down",$2);
        # gsub(" \\+","_Up",$2); gsub("[()\"-]","",$2); gsub(" ","_",$2); printf("\t%s=0x%04X,\n", $2, $1)}' < controls.cvs
        "Second_Left_Click": 0x00B8,  # Second_LClick / on K400 Plus
        "Fn_Second_Left_Click": 0x00B9,  # Fn_Second_LClick
        "Multiplatform_App_Switch": 0x00BA,
        "Multiplatform_Home": 0x00BB,
        "Multiplatform_Menu": 0x00BC,
        "Multiplatform_Back": 0x00BD,
        "Multiplatform_Insert": 0x00BE,
        "Screen_Capture__Print_Screen": 0x00BF,  # Craft Keyboard top 3rd from right
        "Fn_Down": 0x00C0,
        "Fn_Up": 0x00C1,
        "Multiplatform_Lock": 0x00C2,
        "Mouse_Gesture_Button": 0x00C3,  # Thumb_Button on MX Master - Logitech name App_Switch_Gesture; Logitech
        "Smart_Shift": 0x00C4,  # Top_Button on MX Master; Logitech
        "Microphone": 0x00C5,
        "Wifi": 0x00C6,
        "Brightness_Down": 0x00C7,  # Craft Keyboard Fn F1, Logitech
        "Brightness_Up": 0x00C8,  # Craft Keyboard Fn F2, Logitech
        "Display_Out__Project_Screen_": 0x00C9,
        "View_Open_Apps": 0x00CA,
        "View_All_Apps": 0x00CB,
        "Switch_App": 0x00CC,
        "Fn_Inversion_Change": 0x00CD,
        "MultiPlatform_Back": 0x00CE,  # Logitech
        "MultiPlatform_Forward": 0x00CF,
        "MultiPlatform_Gesture_Button": 0x00D0,
        "Host_Switch_Channel_1": 0x00D1,  # Craft Keyboard; Logitech
        "Host_Switch_Channel_2": 0x00D2,  # Craft Keyboard; Logitech
        "Host_Switch_Channel_3": 0x00D3,  # Craft Keyboard; Logitech
        "MultiPlatform_Search": 0x00D4,
        "MultiPlatform_Home__Mission_Control": 0x00D5,
        "MultiPlatform_Menu__Show__Hide_Virtual_Keyboard__Launchpad": 0x00D6,
        "Virtual_Gesture_Button": 0x00D7,
        "Cursor_Button_Long_Press": 0x00D8,
        "Next_Button_Shortpress": 0x00D9,  # Next_Button
        "Next_Button_Long_Press": 0x00DA,
        "Back_Button_Short_Press": 0x00DB,  # Back
        "Back_Button_Long_Press": 0x00DC,
        "Multi_Platform_Language_Switch": 0x00DD,
        "F_Lock": 0x00DE,
        "Switch_Highlight": 0x00DF,
        "Mission_Control__Task_View": 0x00E0,  # Craft Keyboard Fn F3 Switch_Workspace; Logitech
        "Dashboard_Launchpad__Action_Center": 0x00E1,  # Craft Keyboard Fn F4 Application_Launcher
        "Backlight_Down": 0x00E2,  # Craft Keyboard Fn F6, Logitech
        "Backlight_Up": 0x00E3,  # Craft Keyboard Fn F7, Logitech
        "Previous_Track": 0x00E4,  # Craft Keyboard Fn F8 Previous_Track; Logitech
        "Play__Pause": 0x00E5,  # Craft Keyboard Fn F9 Play__Pause; Logitech
        "Next_Track": 0x00E6,  # Craft Keyboard Fn F10 Next_Track; Logitech
        "Mute_Sound": 0x00E7,  # Craft Keyboard Fn F11 Mute; Logitech
        "Volume_Down": 0x00E8,  # Craft Keyboard Fn F12 Volume_Down; Logitech
        "Volume_Up": 0x00E9,  # Craft Keyboard next to F12 Volume_Down; Logitech
        "App_Contextual_Menu__Right_Click": 0x00EA,  # Craft Keyboard top 2nd from right
        "Right_Arrow": 0x00EB,
        "Left_Arrow": 0x00EC,
        "DPI_Change": 0x00ED,
        "Open_New_Tab": 0x00EE,  # Logitech
        "F2": 0x00EF,
        "F3": 0x00F0,
        "F4": 0x00F1,
        "F5": 0x00F2,
        "F6": 0x00F3,
        "F7": 0x00F4,
        "F8": 0x00F5,
        "F1": 0x00F6,
        "Next_Color_Effect": 0x00F7,
        "Increase_Color_Effect_Speed": 0x00F8,
        "Decrease_Color_Effect_Speed": 0x00F9,
        "Load_Lighting_Custom_Profile": 0x00FA,
        "Laser_Button_Short_Press": 0x00FB,
        "Laser_Button_Long_Press": 0x00FC,
        "DPI_Switch": 0x00FD,
        "Multiplatform_Home__Show_Desktop": 0x00FE,  # Logitech
        "Multiplatform_App_Switch__Show_Dashboard": 0x00FF,
        "Multiplatform_App_Switch_2": 0x0100,  # Multiplatform_App_Switch
        "Fn_Inversion__Hot_Key": 0x0101,
        "LeftAndRightClick": 0x0102,
        "Dictation": 0x0103,  # MX Keys for Business Fn F5 ; MX Mini Fn F6 Dictation; Logitech
        "Emoji_Smiley_Heart_Eyes": 0x0104,  # Logitech
        "Emoji_Crying_Face": 0x0105,  # Logitech
        "Emoji_Smiley": 0x0106,  # Logitech
        "Emoji_Smilie_With_Tears": 0x0107,  # Logitech
        "Emoji": 0x0108,  # MX Keys for Business Fn F6 ; MX Mini Fn F7 Emoji, Logitech
        "Multiplatform_App_Switch__Launchpad": 0x0109,  # Logitech
        "Screen_Capture": 0x010A,  # MX Keys for Business top 3rd from right; MX Mini Fn F8 Screenshot; Logitech
        "Grave_Accent": 0x010B,  # Logitech
        "Tab_Key": 0x010C,
        "Caps_Lock": 0x010D,
        "Left_Shift": 0x010E,
        "Left_Control": 0x010F,
        "Left_Option__Start": 0x0110,
        "Left_Command__Alt": 0x0111,
        "Right_Command__Alt": 0x0112,
        "Right_Option__Start": 0x0113,
        "Right_Control": 0x0114,
        "Right_Shift": 0x0115,
        "Insert": 0x0116,
        "Delete": 0x0117,  # MX Mini Lock (on delete key in function row)
        "Home": 0x118,  # Logitech
        "End": 0x119,  # Logitech
        "Page_Up": 0x11A,
        "Page_Down": 0x11B,
        "Mute_Microphone": 0x11C,  # MX Keys for Business Fn F7 ; MX Mini Fn F9 Microphone Mute; Logitech
        "Do_Not_Disturb": 0x11D,  # Logitech
        "Backslash": 0x11E,
        "Refresh": 0x11F,  # Logitech
        "Close_Tab": 0x120,
        "Lang_Switch": 0x121,  # Logitech
        "Standard_Key_A": 0x122,
        "Standard_Key_B": 0x123,
        "Standard_Key_C": 0x124,  # There are lots more of these
        "Right_Option__Start__2": 0x013C,  # On MX Mechanical Mini
        "Play__Pause_mini": 0x0141,  # On MX Mechanical Mini
        "Haptic": 0x01A0,  # Logitech
        "Circle": 0x01A3,
        "Triangle": 0x01A4,
        "Diamond": 0x01A5,
        "Star": 0x01A6,
        "Cut": 0x1A9,  # Logitech
        "Copy": 0x1AA,  # Logitech
        "Paste": 0x1AB,  # Logitech
        "Video_On_Off": 0x01AC,  # Logitech
        "AI": 0x1B4,  # Logitech
    }
)

for i in range(1, 33):  # add in G keys - these are not really Logitech Controls
    CONTROL[0x1000 + i] = f"G{str(i)}"
for i in range(1, 9):  # add in M keys - these are not really Logitech Controls
    CONTROL[0x1100 + i] = f"M{str(i)}"
CONTROL[0x1200] = "MR"  # add in MR key - this is not really a Logitech Control

CONTROL._fallback = lambda x: f"unknown:{x:04X}"


class Task(IntEnum):
    """
    <tasks.xml awk -F\" '/<Task /{gsub(/ /, "_", $6); printf("\t%s=0x%04X,\n", $6, $4)}'
    """

    VOLUME_UP = 0x0001
    VOLUME_DOWN = 0x0002
    MUTE = 0x0003
    # Multimedia tasks:
    PLAY_PAUSE = 0x0004
    NEXT = 0x0005
    PREVIOUS = 0x0006
    STOP = 0x0007
    APPLICATION_SWITCHER = 0x0008
    BURN_MEDIA_PLAYER = 0x0009
    CALCULATOR = 0x000A
    CALENDAR = 0x000B
    CLOSE_APPLICATION = 0x000C
    EJECT = 0x000D
    EMAIL = 0x000E
    HELP = 0x000F
    OFF_DOCUMENT = 0x0010
    OFF_SPREADSHEET = 0x0011
    OFF_POWERPNT = 0x0012
    UNDO = 0x0013
    REDO = 0x0014
    PRINT = 0x0015
    SAVE = 0x0016
    SMART_KEY_SET = 0x0017
    FAVORITES = 0x0018
    GADGETS_SET = 0x0019
    HOME_PAGE = 0x001A
    WINDOWS_RESTORE = 0x001B
    WINDOWS_MINIMIZE = 0x001C
    MUSIC = 0x001D  # also known as MediaPlayer
    # Both 0x001E and 0x001F are known as MediaCenterSet
    MEDIA_CENTER_LOGITECH = 0x001E
    MEDIA_CENTER_MICROSOFT = 0x001F
    USER_MENU = 0x0020
    MESSENGER = 0x0021
    PERSONAL_FOLDERS = 0x0022
    MY_MUSIC = 0x0023
    WEBCAM = 0x0024
    PICTURES_FOLDER = 0x0025
    MY_VIDEOS = 0x0026
    MY_COMPUTER = 0x0027
    PICTURE_APP_SET = 0x0028
    SEARCH = 0x0029  # also known as AdvSmartSearch
    RECORD_MEDIA_PLAYER = 0x002A
    BROWSER_REFRESH = 0x002B
    ROTATE_RIGHT = 0x002C
    SEARCH_FILES = 0x002D  # SearchForFiles
    MM_SHUFFLE = 0x002E
    SLEEP = 0x002F  # also known as StandBySet
    BROWSER_STOP = 0x0030
    ONE_TOUCH_SYNC = 0x0031
    ZOOM_SET = 0x0032
    ZOOM_BTN_IN_SET_2 = 0x0033
    ZOOM_BTN_IN_SET = 0x0034
    ZOOM_BTN_OUT_SET_2 = 0x0035
    ZOOM_BTN_OUT_SET = 0x0036
    ZOOM_BTN_RESET_SET = 0x0037
    LEFT_CLICK = 0x0038  # LeftClick
    RIGHT_CLICK = 0x0039  # RightClick
    MOUSE_MIDDLE_BUTTON = 0x003A  # from M510v2 was MiddleMouseButton
    BACK = 0x003B
    MOUSE_BACK_BUTTON = 0x003C  # from M510v2 was BackEx
    BROWSER_FORWARD = 0x003D
    MOUSE_FORWARD_BUTTON = 0x003E  # from M510v2 was BrowserForwardEx
    MOUSE_SCROLL_LEFT_BUTTON = 0x003F  # from M510v2 was HorzScrollLeftSet
    MOUSE_SCROLL_RIGHT_BUTTON = 0x0040  # from M510v2 was HorzScrollRightSet
    QUICK_SWITCH = 0x0041
    BATTERY_STATUS = 0x0042
    SHOW_DESKTOP = 0x0043  # ShowDesktop
    WINDOWS_LOCK = 0x0044
    FILE_LAUNCHER = 0x0045
    FOLDER_LAUNCHER = 0x0046
    GOTO_WEB_ADDRESS = 0x0047
    GENERIC_MOUSE_BUTTON = 0x0048
    KEYSTROKE_ASSIGNMENT = 0x0049
    LAUNCH_PROGRAM = 0x004A
    MIN_MAX_WINDOW = 0x004B
    VOLUME_MUTE_NO_OSD = 0x004C
    NEW = 0x004D
    COPY = 0x004E
    CRUISE_DOWN = 0x004F
    CRUISE_UP = 0x0050
    CUT = 0x0051
    DO_NOTHING = 0x0052
    PAGE_DOWN = 0x0053
    PAGE_UP = 0x0054
    PASTE = 0x0055
    SEARCH_PICTURE = 0x0056
    REPLY = 0x0057
    PHOTO_GALLERY_SET = 0x0058
    MM_REWIND = 0x0059
    MM_FASTFORWARD = 0x005A
    SEND = 0x005B
    CONTROL_PANEL = 0x005C
    UNIVERSAL_SCROLL = 0x005D
    AUTO_SCROLL = 0x005E
    GENERIC_BUTTON = 0x005F
    MM_NEXT = 0x0060
    MM_PREVIOUS = 0x0061
    DO_NOTHING_ONE = 0x0062  # also known as Do_Nothing
    SNAP_LEFT = 0x0063
    SNAP_RIGHT = 0x0064
    WIN_MIN_RESTORE = 0x0065
    WIN_MAX_RESTORE = 0x0066
    WIN_STRETCH = 0x0067
    SWITCH_MONITOR_LEFT = 0x0068
    SWITCH_MONITOR_RIGHT = 0x0069
    SHOW_PRESENTATION = 0x006A
    SHOW_MOBILITY_CENTER = 0x006B
    HORZ_SCROLL_NO_REPEAT_SET = 0x006C
    TOUCH_BACK_FORWARD_HORZ_SCROLL = 0x0077
    METRO_APP_SWITCH = 0x0078
    METRO_APP_BAR = 0x0079
    METRO_CHARMS = 0x007A
    CALCULATOR_VKEY = 0x007B  # also known as Calculator
    METRO_SEARCH = 0x007C
    METRO_START_SCREEN = 0x0080
    METRO_SHARE = 0x007D
    METRO_SETTINGS = 0x007E
    METRO_DEVICES = 0x007F
    METRO_BACK_LEFT_HORZ = 0x0082
    METRO_FORW_RIGHT_HORZ = 0x0083
    WIN8_BACK = 0x0084  # also known as MetroCharms
    WIN8_FORWARD = 0x0085  # also known as AppSwitchBar
    WIN8_CHARM_APPSWITCH_GIF_ANIMATION = 0x0086
    WIN8_BACK_HORZ_LEFT = 0x008B  # also known as Back
    WIN8_FORWARD_HORZ_RIGHT = 0x008C  # also known as BrowserForward
    METRO_SEARCH_2 = 0x0087
    METROA_SHARE_2 = 0x0088
    METRO_SETTINGS_2 = 0x008A
    METRO_DEVICES_2 = 0x0089
    WIN8_METRO_WIN7_FORWARD = 0x008D  # also known as MetroStartScreen
    WIN8_SHOW_DESKTOP_WIN7_BACK = 0x008E  # also known as ShowDesktop
    METRO_APPLICATION_SWITCH = 0x0090  # also known as MetroStartScreen
    SHOW_UI = 0x0092
    # https://docs.google.com/document/d/1Dpx_nWRQAZox_zpZ8SNc9nOkSDE9svjkghOCbzopabc/edit
    # Extract to csv.  Eliminate extra linefeeds and spaces. Turn / into __ and space into _
    # awk -F, '/0x/{gsub(" \\+ ","_",$2);  gsub("_-","_Down",$2); gsub("_\\+","_Up",$2);
    # gsub("[()\"-]","",$2); gsub(" ","_",$2); printf("\t%s=0x%04X,\n", $2, $1)}' < tasks.csv > tasks.py
    SWITCH_PRESENTATION_SWITCH_SCREEN = 0x0093  # on K400 Plus
    MINIMIZE_WINDOW = 0x0094
    MAXIMIZE_WINDOW = 0x0095  # on K400 Plus
    MULTI_PLATFORM_APP_SWITCH = 0x0096
    MULTI_PLATFORM_HOME = 0x0097
    MULTI_PLATFORM_MENU = 0x0098
    MULTI_PLATFORM_BACK = 0x0099
    SWITCH_LANGUAGE = 0x009A  # Mac_switch_language
    SCREEN_CAPTURE = 0x009B  # Mac_screen_Capture, on Craft Keyboard
    GESTURE_BUTTON = 0x009C
    SMART_SHIFT = 0x009D
    APP_EXPOSE = 0x009E
    SMART_ZOOM = 0x009F
    LOOKUP = 0x00A0
    MICROPHEON_ON_OFF = 0x00A1
    WIFI_ON_OFF = 0x00A2
    BRIGHTNESS_DOWN = 0x00A3
    BRIGHTNESS_UP = 0x00A4
    DISPLAY_OUT = 0x00A5
    VIEW_OPEN_APPS = 0x00A6
    VIEW_ALL_OPEN_APPS = 0x00A7
    APP_SWITCH = 0x00A8
    GESTURE_BUTTON_NAVIGATION = 0x00A9  # Mouse_Thumb_Button on MX Master
    FN_INVERSION = 0x00AA
    MULTI_PLATFORM_BACK_2 = 0x00AB  # Alternative
    MULTI_PLATFORM_FORWARD = 0x00AC
    MULTI_PLATFORM_Gesture_Button = 0x00AD
    HostSwitch_Channel_1 = 0x00AE
    HostSwitch_Channel_2 = 0x00AF
    HostSwitch_Channel_3 = 0x00B0
    MULTI_PLATFORM_SEARCH = 0x00B1
    MULTI_PLATFORM_HOME_MISSION_CONTROL = 0x00B2
    MULTI_PLATFORM_MENU_LAUNCHPAD = 0x00B3
    VIRTUAL_GESTURE_BUTTON = 0x00B4
    CURSOR = 0x00B5
    KEYBOARD_RIGHT_ARROW = 0x00B6
    SW_CUSTOM_HIGHLIGHT = 0x00B7
    KEYBOARD_LEFT_ARROW = 0x00B8
    TBD = 0x00B9
    MULTI_PLATFORM_Language_Switch = 0x00BA
    SW_CUSTOM_HIGHLIGHT_2 = 0x00BB
    FAST_FORWARD = 0x00BC
    FAST_BACKWARD = 0x00BD
    SWITCH_HIGHLIGHTING = 0x00BE
    MISSION_CONTROL_TASK_VIEW = 0x00BF  # Switch_Workspace on Craft Keyboard
    DASHBOARD_LAUNCHPAD_ACTION_CENTER = 0x00C0  # Application_Launcher on Craft
    # Keyboard
    BACKLIGHT_DOWN = 0x00C1  # Backlight_Down_FW_internal_function
    BACKLIGHT_UP = 0x00C2  # Backlight_Up_FW_internal_function
    RIGHT_CLICK_APP_CONTEXT_MENU = 0x00C3  # Context_Menu on Craft Keyboard
    DPI_Change = 0x00C4
    NEW_TAB = 0x00C5
    F2 = 0x00C6
    F3 = 0x00C7
    F4 = 0x00C8
    F5 = 0x00C9
    F6 = 0x00CA
    F7 = 0x00CB
    F8 = 0x00CC
    F1 = 0x00CD
    LASER_BUTTON = 0x00CE
    LASER_BUTTON_LONG_PRESS = 0x00CF
    START_PRESENTATION = 0x00D0
    BLANK_SCREEN = 0x00D1
    DPI_Switch = 0x00D2  # AdjustDPI on MX Vertical
    HOME_SHOW_DESKTOP = 0x00D3
    APP_SWITCH_DASHBOARD = 0x00D4
    APP_SWITCH_2 = 0x00D5  # Alternative
    FN_INVERSION_2 = 0x00D6  # Alternative
    LEFT_AND_RIGHT_CLICK = 0x00D7
    VOICE_DICTATION = 0x00D8
    EMOJI_SMILING_FACE_WITH_HEART_SHAPED_EYES = 0x00D9
    EMOJI_LOUDLY_CRYING_FACE = 0x00DA
    EMOJI_SMILEY = 0x00DB
    EMOJI_SMILE_WITH_TEARS = 0x00DC
    OPEN_EMOJI_PANEL = 0x00DD
    MULTI_PLATFORM_APP_SWITCH_LAUNCHPAD = 0x00DE
    SNIPPING_TOOL = 0x00DF
    GRAVE_ACCENT = 0x00E0
    STANDARD_TAB_KEY = 0x00E1
    CAPS_LOCK = 0x00E2
    LEFT_SHIFT = 0x00E3
    LEFT_CONTROL = 0x00E4
    LEFT_OPTION_START = 0x00E5
    LEFT_COMMAND_ALT = 0x00E6
    RIGHT_COMMAND_ALT = 0x00E7
    RIGHT_OPTION_START = 0x00E8
    RIGHT_CONTROL = 0x00E9
    RIGHT_SHIFT = 0x0EA
    INSERT = 0x00EB
    DELETE = 0x00EC
    HOME = 0x00ED
    END = 0x00EE
    PAGE_UP_2 = 0x00EF  # Alternative
    PAGE_DOWN_2 = 0x00F0  # Alternative
    MUTE_MICROPHONE = 0x00F1
    DO_NOT_DISTURB = 0x00F2
    BACKSLASH = 0x00F3
    REFRESH = 0x00F4
    CLOSE_TAB = 0x00F5
    LANG_SWITCH = 0x00F6
    STANDARD_ALPHABETICAL_KEY = 0x00F7
    RRIGH_OPTION_START_2 = 0x00F8
    LEFT_OPTION = 0x00F9
    RIGHT_OPTION = 0x00FA
    LEFT_CMD = 0x00FB
    RIGHT_CMD = 0x00FC

    def __str__(self):
        return self.name.replace("_", " ").title()


class CIDGroupBit(IntEnum):
    g1 = 0x01
    g2 = 0x02
    g3 = 0x04
    g4 = 0x08
    g5 = 0x10
    g6 = 0x20
    g7 = 0x40
    g8 = 0x80


class CidGroup(IntEnum):
    g1 = 1
    g2 = 2
    g3 = 3
    g4 = 4
    g5 = 5
    g6 = 6
    g7 = 7
    g8 = 8


DISABLE = NamedInts(
    Caps_Lock=0x01,
    Num_Lock=0x02,
    Scroll_Lock=0x04,
    Insert=0x08,
    Win=0x10,  # aka Super
)
DISABLE._fallback = lambda x: f"unknown:{x:02X}"

# HID USB Keycodes from https://www.usb.org/sites/default/files/documents/hut1_12v2.pdf
# Modified by information from Linux HID driver linux/drivers/hid/hid-input.c
USB_HID_KEYCODES = NamedInts(
    A=0x04,
    B=0x05,
    C=0x06,
    D=0x07,
    E=0x08,
    F=0x09,
    G=0x0A,
    H=0x0B,
    I=0x0C,
    J=0x0D,
    K=0x0E,
    L=0x0F,
    M=0x10,
    N=0x11,
    O=0x12,
    P=0x13,
    Q=0x14,
    R=0x15,
    S=0x16,
    T=0x17,
    U=0x18,
    V=0x19,
    W=0x1A,
    X=0x1B,
    Y=0x1C,
    Z=0x1D,
    ENTER=0x28,
    ESC=0x29,
    BACKSPACE=0x2A,
    TAB=0x2B,
    SPACE=0x2C,
    MINUS=0x2D,
    EQUAL=0x2E,
    LEFTBRACE=0x2F,
    RIGHTBRACE=0x30,
    BACKSLASH=0x31,
    HASHTILDE=0x32,
    SEMICOLON=0x33,
    APOSTROPHE=0x34,
    GRAVE=0x35,
    COMMA=0x36,
    DOT=0x37,
    SLASH=0x38,
    CAPSLOCK=0x39,
    F1=0x3A,
    F2=0x3B,
    F3=0x3C,
    F4=0x3D,
    F5=0x3E,
    F6=0x3F,
    F7=0x40,
    F8=0x41,
    F9=0x42,
    F10=0x43,
    F11=0x44,
    F12=0x45,
    SYSRQ=0x46,
    SCROLLLOCK=0x47,
    PAUSE=0x48,
    INSERT=0x49,
    HOME=0x4A,
    PAGEUP=0x4B,
    DELETE=0x4C,
    END=0x4D,
    PAGEDOWN=0x4E,
    RIGHT=0x4F,
    LEFT=0x50,
    DOWN=0x51,
    UP=0x52,
    NUMLOCK=0x53,
    KPSLASH=0x54,
    KPASTERISK=0x55,
    KPMINUS=0x56,
    KPPLUS=0x57,
    KPENTER=0x58,
    KP1=0x59,
    KP2=0x5A,
    KP3=0x5B,
    KP4=0x5C,
    KP5=0x5D,
    KP6=0x5E,
    KP7=0x5F,
    KP8=0x60,
    KP9=0x61,
    KP0=0x62,
    KPDOT=0x63,
    COMPOSE=0x65,
    POWER=0x66,
    KPEQUAL=0x67,
    F13=0x68,
    F14=0x69,
    F15=0x6A,
    F16=0x6B,
    F17=0x6C,
    F18=0x6D,
    F19=0x6E,
    F20=0x6F,
    F21=0x70,
    F22=0x71,
    F23=0x72,
    F24=0x73,
    OPEN=0x74,
    HELP=0x75,
    PROPS=0x76,
    FRONT=0x77,
    STOP=0x78,
    AGAIN=0x79,
    UNDO=0x7A,
    CUT=0x7B,
    COPY=0x7C,
    PASTE=0x7D,
    FIND=0x7E,
    MUTE=0x7F,
    VOLUMEUP=0x80,
    VOLUMEDOWN=0x81,
    KPCOMMA=0x85,
    RO=0x87,
    KATAKANAHIRAGANA=0x88,
    YEN=0x89,
    HENKAN=0x8A,
    MUHENKAN=0x8B,
    KPJPCOMMA=0x8C,
    HANGEUL=0x90,
    HANJA=0x91,
    KATAKANA=0x92,
    HIRAGANA=0x93,
    ZENKAKUHANKAKU=0x94,
    KPLEFTPAREN=0xB6,
    KPRIGHTPAREN=0xB7,
    LEFTCTRL=0xE0,
    LEFTSHIFT=0xE1,
    LEFTALT=0xE2,
    LEFTWINDOWS=0xE3,
    RIGHTCTRL=0xE4,
    RIGHTSHIFT=0xE5,
    RIGHTALT=0xE6,
    RIGHTMETA=0xE7,
    MEDIA_PLAYPAUSE=0xE8,
    MEDIA_STOPCD=0xE9,
    MEDIA_PREVIOUSSONG=0xEA,
    MEDIA_NEXTSONG=0xEB,
    MEDIA_EJECTCD=0xEC,
    MEDIA_VOLUMEUP=0xED,
    MEDIA_VOLUMEDOWN=0xEE,
    MEDIA_MUTE=0xEF,
    MEDIA_WWW=0xF0,
    MEDIA_BACK=0xF1,
    MEDIA_FORWARD=0xF2,
    MEDIA_STOP=0xF3,
    MEDIA_FIND=0xF4,
    MEDIA_SCROLLUP=0xF5,
    MEDIA_SCROLLDOWN=0xF6,
    MEDIA_EDIT=0xF7,
    MEDIA_SLEEP=0xF8,
    MEDIA_COFFEE=0xF9,
    MEDIA_REFRESH=0xFA,
    MEDIA_CALC=0xFB,
)
USB_HID_KEYCODES[0] = "No Output"
USB_HID_KEYCODES[0x1E] = "1"
USB_HID_KEYCODES[0x1F] = "2"
USB_HID_KEYCODES[0x20] = "3"
USB_HID_KEYCODES[0x21] = "4"
USB_HID_KEYCODES[0x22] = "5"
USB_HID_KEYCODES[0x23] = "6"
USB_HID_KEYCODES[0x24] = "7"
USB_HID_KEYCODES[0x25] = "8"
USB_HID_KEYCODES[0x26] = "9"
USB_HID_KEYCODES[0x27] = "0"
USB_HID_KEYCODES[0x64] = "102ND"

HID_CONSUMERCODES = NamedInts(
    {
        #    Unassigned=0x00,
        #    Consumer_Control=0x01,
        #    Numeric_Key_Pad=0x02,
        #    Programmable_Buttons=0x03,
        #    Microphone=0x04,
        #    Headphone=0x05,
        #    Graphic_Equalizer=0x06,
        #    AM__PM=0x22,
        "Power": 0x30,
        "Reset": 0x31,
        "Sleep": 0x32,
        "Sleep_After": 0x33,
        "Sleep_Mode": 0x34,
        "Illumination": 0x35,
        "Function_Buttons": 0x36,
        "Menu": 0x40,
        "Menu__Pick": 0x41,
        "Menu_Up": 0x42,
        "Menu_Down": 0x43,
        "Menu_Left": 0x44,
        "Menu_Right": 0x45,
        "Menu_Escape": 0x46,
        "Menu_Value_Increase": 0x47,
        "Menu_Value_Decrease": 0x48,
        "Data_On_Screen": 0x60,
        "Closed_Caption": 0x61,
        #    Closed_Caption_Select=0x62,
        "VCR__TV": 0x63,
        #    Broadcast_Mode=0x64,
        "Snapshot": 0x65,
        #    Still=0x66,
        "Red": 0x69,
        "Green": 0x6A,
        "Blue": 0x6B,
        "Yellow": 0x6C,
        "Aspect_Ratio": 0x6D,
        "Brightness_Up": 0x6F,
        "Brightness_Down": 0x70,
        "Brightness_Toggle": 0x72,
        "Brightness_Min": 0x73,
        "Brightness_Max": 0x74,
        "Brightness_Auto": 0x75,
        "Keyboard_Illumination_Up": 0x79,
        "Keyboard_Illumination_Down": 0x7A,
        "Keyboard_Illumination_Toggle": 0x7C,
        #    Selection=0x80,
        #    Assign_Selection=0x81,
        "Mode_Step": 0x82,
        "Recall_Last": 0x83,
        "Enter_Channel": 0x84,
        #    Order_Movie=0x85,
        #    Channel=0x86,
        #    Media_Selection=0x87,
        "Media_Select_Computer": 0x88,
        "Media_Select_TV": 0x89,
        "Media_Select_WWW": 0x8A,
        "Media_Select_DVD": 0x8B,
        "Media_Select_Telephone": 0x8C,
        "Media_Select_Program_Guide": 0x8D,
        "Media_Select_Video_Phone": 0x8E,
        "Media_Select_Games": 0x8F,
        "Media_Select_Messages": 0x90,
        "Media_Select_CD": 0x91,
        "Media_Select_VCR": 0x92,
        "Media_Select_Tuner": 0x93,
        "Quit": 0x94,
        "Help": 0x95,
        "Media_Select_Tape": 0x96,
        "Media_Select_Cable": 0x97,
        "Media_Select_Satellite": 0x98,
        "Media_Select_Security": 0x99,
        "Media_Select_Home": 0x9A,
        #    Media_Select_Call=0x9B,
        "Channel_Increment": 0x9C,
        "Channel_Decrement": 0x9D,
        #    Media_Select_SAP=0x9E,
        "VCR_Plus": 0xA0,
        #    Once=0xA1,
        #    Daily=0xA2,
        #    Weekly=0xA3,
        #    Monthly=0xA4,
        "Play": 0xB0,
        "Pause": 0xB1,
        "Record": 0xB2,
        "Fast_Forward": 0xB3,
        "Rewind": 0xB4,
        "Scan_Next_Track": 0xB5,
        "Scan_Previous_Track": 0xB6,
        "Stop": 0xB7,
        "Eject": 0xB8,
        "Random_Play": 0xB9,
        "Select_DisC": 0xBA,
        "Enter_Disc": 0xBB,
        "Repeat": 0xBC,
        "Tracking": 0xBD,
        "Track_Normal": 0xBE,
        "Slow_Tracking": 0xBF,
        #    Frame_Forward=0xC0,
        #    Frame_Back=0xC1,
        #    Mark=0xC2,
        #    Clear_Mark=0xC3,
        #    Repeat_From_Mark=0xC4,
        #    Return_To_Mark=0xC5,
        #    Search_Mark_Forward=0xC6,
        #    Search_Mark_Backwards=0xC7,
        #    Counter_Reset=0xC8,
        #    Show_Counter=0xC9,
        #    Tracking_Increment=0xCA,
        #    Tracking_Decrement=0xCB,
        #    Stop__Eject=0xCC,
        "Play__Pause": 0xCD,
        #    Play__Skip=0xCE,
        "Volume": 0xE0,
        #    Balance=0xE1,
        "Mute": 0xE2,
        #    Bass=0xE3,
        #    Treble=0xE4,
        "Bass_Boost": 0xE5,
        #    Surround_Mode=0xE6,
        #    Loudness=0xE7,
        #    MPX=0xE8,
        "Volume_Up": 0xE9,
        "Volume_Down": 0xEA,
        #    Speed_Select=0xF0,
        #    Playback_Speed=0xF1,
        #    Standard_Play=0xF2,
        #    Long_Play=0xF3,
        #    Extended_Play=0xF4,
        "Slow": 0xF5,
        "Fan_Enable": 0x100,
        "Fan_Speed": 0x101,
        "Light": 0x102,
        "Light_Illumination_Level": 0x103,
        "Climate_Control_Enable": 0x104,
        "Room_Temperature": 0x105,
        "Security_Enable": 0x106,
        "Fire_Alarm": 0x107,
        "Police_Alarm": 0x108,
        "Proximity": 0x109,
        "Motion": 0x10A,
        "Duress_Alarm": 0x10B,
        "Holdup_Alarm": 0x10C,
        "Medical_Alarm": 0x10D,
        "Balance_Right": 0x150,
        "Balance_Left": 0x151,
        "Bass_Increment": 0x152,
        "Bass_Decrement": 0x153,
        "Treble_Increment": 0x154,
        "Treble_Decrement": 0x155,
        "Speaker_System": 0x160,
        "Channel_Left": 0x161,
        "Channel_Right": 0x162,
        "Channel_Center": 0x163,
        "Channel_Front": 0x164,
        "Channel_Center_Front": 0x165,
        "Channel_Side": 0x166,
        "Channel_Surround": 0x167,
        "Channel_Low_Frequency_Enhancement": 0x168,
        "Channel_Top": 0x169,
        "Channel_Unknown": 0x16A,
        "Subchannel": 0x170,
        "Subchannel_Increment": 0x171,
        "Subchannel_Decrement": 0x172,
        "Alternate_Audio_Increment": 0x173,
        "Alternate_Audio_Decrement": 0x174,
        "Application_Launch_Buttons": 0x180,
        "AL_Launch_Button_Configuration_Tool": 0x181,
        "AL_Programmable_Button_Configuration": 0x182,
        "AL_Consumer_Control_Configuration": 0x183,
        "AL_Word_Processor": 0x184,
        "AL_Text_Editor": 0x185,
        "AL_Spreadsheet": 0x186,
        "AL_Graphics_Editor": 0x187,
        "AL_Presentation_App": 0x188,
        "AL_Database_App": 0x189,
        "AL_Email_Reader": 0x18A,
        "AL_Newsreader": 0x18B,
        "AL_Voicemail": 0x18C,
        "AL_Contacts__Address_Book": 0x18D,
        "AL_Calendar__Schedule": 0x18E,
        "AL_Task__Project_Manager": 0x18F,
        "AL_Log__Journal__Timecard": 0x190,
        "AL_Checkbook__Finance": 0x191,
        "AL_Calculator": 0x192,
        "AL_A__V_Capture__Playback": 0x193,
        "AL_Local_Machine_Browser": 0x194,
        "AL_LAN__WAN_Browser": 0x195,
        "AL_Internet_Browser": 0x196,
        "AL_Remote_Networking__ISP_Connect": 0x197,
        "AL_Network_Conference": 0x198,
        "AL_Network_Chat": 0x199,
        "AL_Telephony__Dialer": 0x19A,
        "AL_Logon": 0x19B,
        "AL_Logoff": 0x19C,
        "AL_Logon__Logoff": 0x19D,
        "AL_Terminal_Lock__Screensaver": 0x19E,
        "AL_Control_Panel": 0x19F,
        "AL_Command_Line_Processor__Run": 0x1A0,
        "AL_Process__Task_Manager": 0x1A1,
        "AL_Select_Tast__Application": 0x1A2,
        "AL_Next_Task__Application": 0x1A3,
        "AL_Previous_Task__Application": 0x1A4,
        "AL_Preemptive_Halt_Task__Application": 0x1A5,
        "AL_Integrated_Help_Center": 0x1A6,
        "AL_Documents": 0x1A7,
        "AL_Thesaurus": 0x1A8,
        "AL_Dictionary": 0x1A9,
        "AL_Desktop": 0x1AA,
        "AL_Spell_Check": 0x1AB,
        "AL_Grammar_Check": 0x1AC,
        "AL_Wireless_Status": 0x1AD,
        "AL_Keyboard_Layout": 0x1AE,
        "AL_Virus_Protection": 0x1AF,
        "AL_Encryption": 0x1B0,
        "AL_Screen_Saver": 0x1B1,
        "AL_Alarms": 0x1B2,
        "AL_Clock": 0x1B3,
        "AL_File_Browser": 0x1B4,
        "AL_Power_Status": 0x1B5,
        "AL_Image_Browser": 0x1B6,
        "AL_Audio_Browser": 0x1B7,
        "AL_Movie_Browser": 0x1B8,
        "AL_Digital_Rights_Manager": 0x1B9,
        "AL_Digital_Wallet": 0x1BA,
        "AL_Instant_Messaging": 0x1BC,
        "AL_OEM_Features___Tips__Tutorial_Browser": 0x1BD,
        "AL_OEM_Help": 0x1BE,
        "AL_Online_Community": 0x1BF,
        "AL_Entertainment_Content_Browser": 0x1C0,
        "AL_Online_Shopping_Browser": 0x1C1,
        "AL_SmartCard_Information__Help": 0x1C2,
        "AL_Market_Monitor__Finance_Browser": 0x1C3,
        "AL_Customized_Corporate_News_Browser": 0x1C4,
        "AL_Online_Activity_Browser": 0x1C5,
        "AL_Research__Search_Browser": 0x1C6,
        "AL_Audio_Player": 0x1C7,
        "Generic_GUI_Application_Controls": 0x200,
        "AC_New": 0x201,
        "AC_Open": 0x202,
        "AC_Close": 0x203,
        "AC_Exit": 0x204,
        "AC_Maximize": 0x205,
        "AC_Minimize": 0x206,
        "AC_Save": 0x207,
        "AC_Print": 0x208,
        "AC_Properties": 0x209,
        "AC_Undo": 0x21A,
        "AC_Copy": 0x21B,
        "AC_Cut": 0x21C,
        "AC_Paste": 0x21D,
        "AC_Select_All": 0x21E,
        "AC_Find": 0x21F,
        "AC_Find_and_Replace": 0x220,
        "AC_Search": 0x221,
        "AC_Go_To": 0x222,
        "AC_Home": 0x223,
        "AC_Back": 0x224,
        "AC_Forward": 0x225,
        "AC_Stop": 0x226,
        "AC_Refresh": 0x227,
        "AC_Previous_Link": 0x228,
        "AC_Next_Link": 0x229,
        "AC_Bookmarks": 0x22A,
        "AC_History": 0x22B,
        "AC_Subscriptions": 0x22C,
        "AC_Zoom_In": 0x22D,
        "AC_Zoom_Out": 0x22E,
        "AC_Zoom": 0x22F,
        "AC_Full_Screen_View": 0x230,
        "AC_Normal_View": 0x231,
        "AC_View_Toggle": 0x232,
        "AC_Scroll_Up": 0x233,
        "AC_Scroll_Down": 0x234,
        "AC_Scroll": 0x235,
        "AC_Pan_Left": 0x236,
        "AC_Pan_Right": 0x237,
        "AC_Pan": 0x238,
        "AC_New_Window": 0x239,
        "AC_Tile_Horizontally": 0x23A,
        "AC_Tile_Vertically": 0x23B,
        "AC_Format": 0x23C,
        "AC_Edit": 0x23D,
        "AC_Bold": 0x23E,
        "AC_Italics": 0x23F,
        "AC_Underline": 0x240,
        "AC_Strikethrough": 0x241,
        "AC_Subscript": 0x242,
        "AC_Superscript": 0x243,
        "AC_All_Caps": 0x244,
        "AC_Rotate": 0x245,
        "AC_Resize": 0x246,
        "AC_Flip_horizontal": 0x247,
        "AC_Flip_Vertical": 0x248,
        "AC_Mirror_Horizontal": 0x249,
        "AC_Mirror_Vertical": 0x24A,
        "AC_Font_Select": 0x24B,
        "AC_Font_Color": 0x24C,
        "AC_Font_Size": 0x24D,
        "AC_Justify_Left": 0x24E,
        "AC_Justify_Center_H": 0x24F,
        "AC_Justify_Right": 0x250,
        "AC_Justify_Block_H": 0x251,
        "AC_Justify_Top": 0x252,
        "AC_Justify_Center_V": 0x253,
        "AC_Justify_Bottom": 0x254,
        "AC_Justify_Block_V": 0x255,
        "AC_Indent_Decrease": 0x256,
        "AC_Indent_Increase": 0x257,
        "AC_Numbered_List": 0x258,
        "AC_Restart_Numbering": 0x259,
        "AC_Bulleted_List": 0x25A,
        "AC_Promote": 0x25B,
        "AC_Demote": 0x25C,
        "AC_Yes": 0x25D,
        "AC_No": 0x25E,
        "AC_Cancel": 0x25F,
        "AC_Catalog": 0x260,
        "AC_Buy__Checkout": 0x261,
        "AC_Add_to_Cart": 0x262,
        "AC_Expand": 0x263,
        "AC_Expand_All": 0x264,
        "AC_Collapse": 0x265,
        "AC_Collapse_All": 0x266,
        "AC_Print_Preview": 0x267,
        "AC_Paste_Special": 0x268,
        "AC_Insert_Mode": 0x269,
        "AC_Delete": 0x26A,
        "AC_Lock": 0x26B,
        "AC_Unlock": 0x26C,
        "AC_Protect": 0x26D,
        "AC_Unprotect": 0x26E,
        "AC_Attach_Comment": 0x26F,
        "AC_Delete_Comment": 0x270,
        "AC_View_Comment": 0x271,
        "AC_Select_Word": 0x272,
        "AC_Select_Sentence": 0x273,
        "AC_Select_Paragraph": 0x274,
        "AC_Select_Column": 0x275,
        "AC_Select_Row": 0x276,
        "AC_Select_Table": 0x277,
        "AC_Select_Object": 0x278,
        "AC_Redo__Repeat": 0x279,
        "AC_Sort": 0x27A,
        "AC_Sort_Ascending": 0x27B,
        "AC_Sort_Descending": 0x27C,
        "AC_Filter": 0x27D,
        "AC_Set_Clock": 0x27E,
        "AC_View_Clock": 0x27F,
        "AC_Select_Time_Zone": 0x280,
        "AC_Edit_Time_Zones": 0x281,
        "AC_Set_Alarm": 0x282,
        "AC_Clear_Alarm": 0x283,
        "AC_Snooze_Alarm": 0x284,
        "AC_Reset_Alarm": 0x285,
        "AC_Synchronize": 0x286,
        "AC_Send__Receive": 0x287,
        "AC_Send_To": 0x288,
        "AC_Reply": 0x289,
        "AC_Reply_All": 0x28A,
        "AC_Forward_Msg": 0x28B,
        "AC_Send": 0x28C,
        "AC_Attach_File": 0x28D,
        "AC_Upload": 0x28E,
        "AC_Download_Save_Target_As": 0x28F,
        "AC_Set_Borders": 0x290,
        "AC_Insert_Row": 0x291,
        "AC_Insert_Column": 0x292,
        "AC_Insert_File": 0x293,
        "AC_Insert_Picture": 0x294,
        "AC_Insert_Object": 0x295,
        "AC_Insert_Symbol": 0x296,
        "AC_Save_and_Close": 0x297,
        "AC_Rename": 0x298,
        "AC_Merge": 0x299,
        "AC_Split": 0x29A,
        "AC_Distribute_Horizontally": 0x29B,
        "AC_Distribute_Vertically": 0x29C,
    }
)
HID_CONSUMERCODES[0x20] = "+10"
HID_CONSUMERCODES[0x21] = "+100"
HID_CONSUMERCODES._fallback = lambda x: f"unknown:{x:04X}"

## Information for x1c00 Persistent from https://drive.google.com/drive/folders/0BxbRzx7vEV7eWmgwazJ3NUFfQ28

KEYMOD = NamedInts(CTRL=0x01, SHIFT=0x02, ALT=0x04, META=0x08, RCTRL=0x10, RSHIFT=0x20, RALT=0x40, RMETA=0x80)

ACTIONID = NamedInts(
    Empty=0x00,
    Key=0x01,
    Mouse=0x02,
    Xdisp=0x03,
    Ydisp=0x04,
    Vscroll=0x05,
    Hscroll=0x06,
    Consumer=0x07,
    Internal=0x08,
    Power=0x09,
)

MOUSE_BUTTONS = NamedInts(
    Mouse_Button_Left=0x0001,
    Mouse_Button_Right=0x0002,
    Mouse_Button_Middle=0x0004,
    Mouse_Button_Back=0x0008,
    Mouse_Button_Forward=0x0010,
    Mouse_Button_6=0x0020,
    Mouse_Button_Scroll_Left=0x0040,
    Mouse_Button_Scroll_Right=0x0080,
    Mouse_Button_9=0x0100,
    Mouse_Button_10=0x0200,
    Mouse_Button_11=0x0400,
    Mouse_Button_12=0x0800,
    Mouse_Button_13=0x1000,
    Mouse_Button_DPI=0x2000,
    Mouse_Button_15=0x4000,
    Mouse_Button_16=0x8000,
)
MOUSE_BUTTONS._fallback = lambda x: f"unknown mouse button:{x:04X}"


class HorizontalScroll(IntEnum):
    Left = 0x4000
    Right = 0x8000


# Construct universe for Persistent Remappable Keys setting (only for supported values)
KEYS = UnsortedNamedInts()
KEYS_Default = 0x7FFFFFFF  # Special value to reset key to default - has to be different from all others
KEYS[KEYS_Default] = "Default"  # Value to reset to default
KEYS[0] = "None"  # Value for no output

# Add HID keys plus modifiers
modifiers = {
    0x00: "",
    0x01: "Cntrl+",
    0x02: "Shift+",
    0x04: "Alt+",
    0x08: "Meta+",
    0x03: "Cntrl+Shift+",
    0x05: "Alt+Cntrl+",
    0x09: "Meta+Cntrl+",
    0x06: "Alt+Shift+",
    0x0A: "Meta+Shift+",
    0x0C: "Meta+Alt+",
}
for val, name in modifiers.items():
    for key in USB_HID_KEYCODES:
        KEYS[(ACTIONID.Key << 24) + (int(key) << 8) + val] = name + str(key)

# Add HID Consumer Codes
for code in HID_CONSUMERCODES:
    KEYS[(ACTIONID.Consumer << 24) + (int(code) << 8)] = str(code)

# Add Mouse Buttons
for code in MOUSE_BUTTONS:
    KEYS[(ACTIONID.Mouse << 24) + (int(code) << 8)] = str(code)

# Add Horizontal Scroll
for code in HorizontalScroll:
    KEYS[(ACTIONID.Hscroll << 24) + (int(code) << 8)] = str(code)


# Construct subsets for known devices
def persistent_keys(action_ids):
    keys = UnsortedNamedInts()
    keys[KEYS_Default] = "Default"  # Value to reset to default
    keys[0] = "No Output (only as default)"
    for key in KEYS:
        if (int(key) >> 24) in action_ids:
            keys[int(key)] = str(key)
    return keys


KEYS_KEYS_CONSUMER = persistent_keys([ACTIONID.Key, ACTIONID.Consumer])
KEYS_KEYS_MOUSE_HSCROLL = persistent_keys([ACTIONID.Key, ACTIONID.Mouse, ACTIONID.Hscroll])

COLORS = UnsortedNamedInts(
    {
        # from Xorg rgb.txt,v 1.3 2000/08/17
        "red": 0xFF0000,
        "orange": 0xFFA500,
        "yellow": 0xFFFF00,
        "green": 0x00FF00,
        "blue": 0x0000FF,
        "purple": 0xA020F0,
        "violet": 0xEE82EE,
        "black": 0x000000,
        "white": 0xFFFFFF,
        "gray": 0xBEBEBE,
        "brown": 0xA52A2A,
        "cyan": 0x00FFFF,
        "magenta": 0xFF00FF,
        "pink": 0xFFC0CB,
        "maroon": 0xB03060,
        "turquoise": 0x40E0D0,
        "gold": 0xFFD700,
        "tan": 0xD2B48C,
        "snow": 0xFFFAFA,
        "ghost white": 0xF8F8FF,
        "white smoke": 0xF5F5F5,
        "gainsboro": 0xDCDCDC,
        "floral white": 0xFFFAF0,
        "old lace": 0xFDF5E6,
        "linen": 0xFAF0E6,
        "antique white": 0xFAEBD7,
        "papaya whip": 0xFFEFD5,
        "blanched almond": 0xFFEBCD,
        "bisque": 0xFFE4C4,
        "peach puff": 0xFFDAB9,
        "navajo white": 0xFFDEAD,
        "moccasin": 0xFFE4B5,
        "cornsilk": 0xFFF8DC,
        "ivory": 0xFFFFF0,
        "lemon chiffon": 0xFFFACD,
        "seashell": 0xFFF5EE,
        "honeydew": 0xF0FFF0,
        "mint cream": 0xF5FFFA,
        "azure": 0xF0FFFF,
        "alice blue": 0xF0F8FF,
        "lavender": 0xE6E6FA,
        "lavender blush": 0xFFF0F5,
        "misty rose": 0xFFE4E1,
        "dark slate gray": 0x2F4F4F,
        "dim gray": 0x696969,
        "slate gray": 0x708090,
        "light slate gray": 0x778899,
        "light gray": 0xD3D3D3,
        "midnight blue": 0x191970,
        "navy blue": 0x000080,
        "cornflower blue": 0x6495ED,
        "dark slate blue": 0x483D8B,
        "slate blue": 0x6A5ACD,
        "medium slate blue": 0x7B68EE,
        "light slate blue": 0x8470FF,
        "medium blue": 0x0000CD,
        "royal blue": 0x4169E1,
        "dodger blue": 0x1E90FF,
        "deep sky blue": 0x00BFFF,
        "sky blue": 0x87CEEB,
        "light sky blue": 0x87CEFA,
        "steel blue": 0x4682B4,
        "light steel blue": 0xB0C4DE,
        "light blue": 0xADD8E6,
        "powder blue": 0xB0E0E6,
        "pale turquoise": 0xAFEEEE,
        "dark turquoise": 0x00CED1,
        "medium turquoise": 0x48D1CC,
        "light cyan": 0xE0FFFF,
        "cadet blue": 0x5F9EA0,
        "medium aquamarine": 0x66CDAA,
        "aquamarine": 0x7FFFD4,
        "dark green": 0x006400,
        "dark olive green": 0x556B2F,
        "dark sea green": 0x8FBC8F,
        "sea green": 0x2E8B57,
        "medium sea green": 0x3CB371,
        "light sea green": 0x20B2AA,
        "pale green": 0x98FB98,
        "spring green": 0x00FF7F,
        "lawn green": 0x7CFC00,
        "chartreuse": 0x7FFF00,
        "medium spring green": 0x00FA9A,
        "green yellow": 0xADFF2F,
        "lime green": 0x32CD32,
        "yellow green": 0x9ACD32,
        "forest green": 0x228B22,
        "olive drab": 0x6B8E23,
        "dark khaki": 0xBDB76B,
        "khaki": 0xF0E68C,
        "pale goldenrod": 0xEEE8AA,
        "light goldenrod yellow": 0xFAFAD2,
        "light yellow": 0xFFFFE0,
        "light goldenrod": 0xEEDD82,
        "goldenrod": 0xDAA520,
        "dark goldenrod": 0xB8860B,
        "rosy brown": 0xBC8F8F,
        "indian red": 0xCD5C5C,
        "saddle brown": 0x8B4513,
        "sienna": 0xA0522D,
        "peru": 0xCD853F,
        "burlywood": 0xDEB887,
        "beige": 0xF5F5DC,
        "wheat": 0xF5DEB3,
        "sandy brown": 0xF4A460,
        "chocolate": 0xD2691E,
        "firebrick": 0xB22222,
        "dark salmon": 0xE9967A,
        "salmon": 0xFA8072,
        "light salmon": 0xFFA07A,
        "dark orange": 0xFF8C00,
        "coral": 0xFF7F50,
        "light coral": 0xF08080,
        "tomato": 0xFF6347,
        "orange red": 0xFF4500,
        "hot pink": 0xFF69B4,
        "deep pink": 0xFF1493,
        "light pink": 0xFFB6C1,
        "pale violet red": 0xDB7093,
        "medium violet red": 0xC71585,
        "violet red": 0xD02090,
        "plum": 0xDDA0DD,
        "orchid": 0xDA70D6,
        "medium orchid": 0xBA55D3,
        "dark orchid": 0x9932CC,
        "dark violet": 0x9400D3,
        "blue violet": 0x8A2BE2,
        "medium purple": 0x9370DB,
        "thistle": 0xD8BFD8,
        "dark gray": 0xA9A9A9,
        "dark blue": 0x00008B,
        "dark cyan": 0x008B8B,
        "dark magenta": 0x8B008B,
        "dark red": 0x8B0000,
        "light green": 0x90EE90,
    }
)

COLORSPLUS = UnsortedNamedInts({"No change": -1})
for i in COLORS:
    COLORSPLUS[int(i)] = str(i)

KEYCODES = NamedInts(
    {
        "A": 1,
        "B": 2,
        "C": 3,
        "D": 4,
        "E": 5,
        "F": 6,
        "G": 7,
        "H": 8,
        "I": 9,
        "J": 10,
        "K": 11,
        "L": 12,
        "M": 13,
        "N": 14,
        "O": 15,
        "P": 16,
        "Q": 17,
        "R": 18,
        "S": 19,
        "T": 20,
        "U": 21,
        "V": 22,
        "W": 23,
        "X": 24,
        "Y": 25,
        "Z": 26,
        "1": 27,
        "2": 28,
        "3": 29,
        "4": 30,
        "5": 31,
        "6": 32,
        "7": 33,
        "8": 34,
        "9": 35,
        "0": 36,
        "ENTER": 37,
        "ESC": 38,
        "BACKSPACE": 39,
        "TAB": 40,
        "SPACE": 41,
        "-": 42,
        "=": 43,
        "[": 44,
        "]": 45,
        "\\": 45,
        "~": 47,
        ";": 48,
        "'": 49,
        "`": 50,
        ",": 51,
        ".": 52,
        "/": 53,
        "CAPS LOCK": 54,
        "F1": 55,
        "F2": 56,
        "F3": 57,
        "F4": 58,
        "F5": 59,
        "F6": 60,
        "F7": 61,
        "F8": 62,
        "F9": 63,
        "F10": 64,
        "F11": 65,
        "F12": 66,
        "PRINT": 67,
        "SCROLL LOCK": 68,
        "PASTE": 69,
        "INSERT": 70,
        "HOME": 71,
        "PAGE UP": 72,
        "DELETE": 73,
        "END": 74,
        "PAGE DOWN": 75,
        "RIGHT": 76,
        "LEFT": 77,
        "DOWN": 78,
        "UP": 79,
        "NUMLOCK": 80,
        "KEYPAD /": 81,
        "KEYPAD *": 82,
        "KEYPAD -": 83,
        "KEYPAD +": 84,
        "KEYPAD ENTER": 85,
        "KEYPAD 1": 86,
        "KEYPAD 2": 87,
        "KEYPAD 3": 88,
        "KEYPAD 4": 89,
        "KEYPAD 5": 90,
        "KEYPAD 6": 91,
        "KEYPAD 7": 92,
        "KEYPAD 8": 93,
        "KEYPAD 9": 94,
        "KEYPAD 0": 95,
        "KEYPAD .": 96,
        "COMPOSE": 98,
        "POWER": 99,
        "LEFT CTRL": 104,
        "LEFT SHIFT": 105,
        "LEFT ALT": 106,
        "LEFT WINDOWS": 107,
        "RIGHT CTRL": 108,
        "RIGHT SHIFT": 109,
        "RIGHT ALTGR": 110,
        "RIGHT WINDOWS": 111,
        "BRIGHTNESS": 153,
        "PAUSE": 155,
        "MUTE": 156,
        "NEXT": 157,
        "PREVIOUS": 158,
        "G1": 180,
        "G2": 181,
        "G3": 182,
        "G4": 183,
        "G5": 184,
        "LOGO": 210,
    }
)


# load in override dictionary for KEYCODES
try:
    if os.path.isfile(_keys_file_path):
        with open(_keys_file_path) as keys_file:
            keys = yaml.safe_load(keys_file)
            if isinstance(keys, dict):
                keys = NamedInts(**keys)
                for k in KEYCODES:
                    if int(k) not in keys and str(k) not in keys:
                        keys[int(k)] = str(k)
                KEYCODES = keys
except Exception as e:
    print(e)
