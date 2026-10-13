#ifndef _ISS_H
#define _ISS_H

#include <stdbool.h>
#include <CoreFoundation/CoreFoundation.h>

/** @brief Initialize resources
 * @return true on success, false on failure
 */
bool iss_init(void);

/** @brief Clean up resources */
void iss_destroy(void);

/** @brief The direction to switch spaces towards */
typedef enum {
    ISSDirectionLeft = 0,
    ISSDirectionRight = 1
} ISSDirection;

/**
 * @brief Describes the current space state for the active display.
 */
typedef struct {
    unsigned int currentIndex; /**< Zero-based index of the active space */
    unsigned int spaceCount;   /**< Total number of user-visible spaces */
    char displayID[128];       /**< UUID string of the display */
} ISSSpaceInfo;

/**
 * @brief Performs the space switch if the requested move is within bounds.
 * @param direction The direction to switch spaces towards
 * @return true if the switch was posted, false if blocked by bounds or errors
 */
bool iss_switch(ISSDirection direction);

/**
 * @brief Retrieves the current space info for the display where the cursor is located.
 * @param info Output pointer that receives the info struct.
 * @return true on success, false if unavailable (e.g. API failure)
 */
bool iss_get_space_info(ISSSpaceInfo *info);

/**
 * @brief Retrieves the current space info for the active menu-bar display.
 * @param info Output pointer that receives the info struct.
 * @return true on success, false if unavailable (e.g. API failure)
 */
bool iss_get_menubar_space_info(ISSSpaceInfo *info);

/**
 * @brief Determines if a move in the given direction is allowed for the info.
 * @param info Space info snapshot.
 * @param direction Desired direction to move.
 * @return true if the move is permissible.
 */
bool iss_can_move(ISSSpaceInfo info, ISSDirection direction);

/**
 * @brief Attempts to switch directly to the provided space index.
 * @param targetIndex Zero-based index for the desired space.
 * @return true if the request succeeded (already on target or switches posted)
 */
bool iss_switch_to_index(unsigned int targetIndex);

/**
 * @brief Enables or disables interception of trackpad horizontal swipe gestures.
 *
 * When enabled, native horizontal dock-swipe gestures are suppressed and
 * replaced with instant space switches (no sliding animation).
 * @param enabled true to intercept, false to pass gestures through normally.
 */
void iss_set_swipe_override(bool enabled);

/**
 * @brief Callback invoked after any successful space switch.
 * @param newSpaceIndex Zero-based index of the space that was switched to.
 */
typedef void (*ISSSwitchCallback)(unsigned int newSpaceIndex);

/**
 * @brief Registers a callback invoked after each successful space switch.
 * @param callback Function pointer, or NULL to clear.
 */
void iss_set_switch_callback(ISSSwitchCallback callback);

/**
 * @brief Resets the predicted space indices so the next bounds check falls back
 * to live CGS data. Call this whenever the active space changes externally
 * (e.g. from activeSpaceDidChangeNotification).
 */
void iss_reset_predictions(void);

// MARK: - Public API

/**
 * @brief Returns true when App Exposé is currently active.
 * Detects a Dock layer-18 overlay combined with 1-2 layer-20 windows.
 */
bool iss_is_expose_active(void);

/**
 * @brief Returns true when Mission Control is currently active.
 * Detects a Dock layer-18 overlay combined with 3+ layer-20 windows.
 */
bool iss_is_mission_control_active(void);

/**
 * @brief Enables or disables experimental overlay detection.
 * When disabled, iss_is_expose_active() and iss_is_mission_control_active() always return false.
 * @param enabled true to enable detection, false to disable.
 */
void iss_set_overlay_detection_enabled(bool enabled);

/**
 * @brief Sets the gesture speed for swipe override
 * @param speed The velocity value for the gesture
 */
void iss_set_gesture_speed(double speed);

#endif /* _ISS_H */
