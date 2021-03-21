//
// --------------------------------------------------------------------------
// ButtonInputParser.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "ButtonTriggerGenerator.h"
#import "Actions.h"
#import "ModifiedDrag.h"
#import "Utility_Transformation.h"
#import "Utility_Helper.h"
#import "ConfigFileInterface_Helper.h"
#import "GestureScrollSimulator.h"
#import "TransformationManager.h"
#import "ModifierManager.h"
#import "SharedUtility.h"
#import "ButtonTriggerHandler.h"
#import "ButtonLandscapeAssessor.h"

#pragma mark - Definition of private helper class `Button State`

// Instaces of this helper class describe the state of a single button on an input device
// The `_state` class variable of `ButtonInputParser` (renamed to ButtonTriggerGenerator) is a collection of `ButtonState` instances
@interface ButtonState : NSObject
- (instancetype)init NS_UNAVAILABLE;
@property NSTimer *holdTimer;
@property NSTimer *levelTimer;
@property BOOL isZombified;
@property int64_t clickLevel; // TODO: Making this nonatomic might lead to problems, should think about this again (But it's necessary to override setters)
@property BOOL isPressed; // NSEvent.pressedMouseButtons doesn't react fast enought (led to problems in `getActiveButtonModifiersForDevice`), so we're keeping track of pressed mouse buttons manually
@property (readonly) CFTimeInterval pressedAtTimeStamp; // Keep track of when a button's been pressed to obtain press order in `getActiveButtonModifiersForDevice`
@property (readonly) MFDevice *device;
@end
@implementation ButtonState
@synthesize clickLevel = _clickLevel, isPressed = _isPressed, pressedAtTimeStamp = _pressedAtTimeStamp;
#pragma mark Init
- (instancetype)initWithDevice:(MFDevice *)device {
    self = [super init];
    if (self) {
        _device = device;
    }
    return self;
}
#pragma mark clickLevel accessors
- (int64_t)clickLevel {
    @synchronized (self) {
        return _clickLevel;
    }
}
- (void)setClickLevel:(int64_t)clickLevel {
#if DEBUG
    NSLog(@"Setting clickLevel to: %lld", clickLevel);
#endif
    @synchronized (self) {
        _clickLevel = clickLevel;
    }
    [ModifierManager handleButtonModifiersMightHaveChangedWithDevice:self.device];
}
#pragma mark isPressed accessors
- (BOOL)isPressed {
    @synchronized (self) {
        return _isPressed;
    }
}
- (void)setIsPressed:(BOOL)isPressed {
    @synchronized (self) {
        _pressedAtTimeStamp = CACurrentMediaTime();
        _isPressed = isPressed;
    }
    if (!isPressed) { // Whenever isPressed becomes true, clickLevel is also modified, so we don't need to notify for modifier change in that case
        [ModifierManager handleButtonModifiersMightHaveChangedWithDevice:self.device];
    }
}
#pragma mark pressedAtTimeStamp accessor
- (CFTimeInterval)pressedAtTimeStamp {
    @synchronized (self) {
        return _pressedAtTimeStamp;
    }
}
@end

#pragma mark - Implementation of `ButtonInputParser`

@implementation ButtonTriggerGenerator

#pragma mark - Class vars

/*
 deviceID:
    buttonNumber:
        ButtonState instance
 */
static NSMutableDictionary *_state;

#pragma mark - Load

+ (void)load {
    _state = [NSMutableDictionary dictionary];
}

#pragma mark - Input parsing

+ (MFEventPassThroughEvaluation)parseInputWithButton:(NSNumber *)btn triggerType:(MFButtonInputType)triggerType inputDevice:(MFDevice *)device {
    
#if DEBUG
    NSLog(@"PARSING BUTTON INPUT - btn: %@, trigger %@", btn, @(triggerType));
#endif
    
    // Declare passThroughEval (return value)
    MFEventPassThroughEvaluation passThroughEval;
    
    // Gather info from params
    NSNumber *devID = device.uniqueID;
    ButtonState *bs = _state[devID][btn];
    
    // If no entry exists in _state for the incoming device and button, create one
    if (bs == nil) {
        if (_state[devID] == nil) {
            _state[devID] = [NSMutableDictionary dictionary];
        }
        bs = [[ButtonState alloc] initWithDevice:device];
        _state[devID][btn] = bs;
    }
    
    if (triggerType == kMFButtonInputTypeButtonDown && bs.clickLevel == 0) {
        // The button might have switched -> Neuter all other buttons of current device
        neuterAllButtonsOnDeviceExcept(devID, btn);
    }
    
    if (triggerType == kMFButtonInputTypeButtonDown) {
        
        // Mouse down
        
        // Restart Timers
        NSDictionary *timerInfo = @{
            @"devID": devID,
            @"btn": btn
        };
        [bs.holdTimer invalidate]; // Probs unnecessary cause it gets killed by mouse up anyways
        [bs.levelTimer invalidate];
        bs.holdTimer = [NSTimer scheduledTimerWithTimeInterval:0.25
                                                        target:self
                                                      selector:@selector(holdTimerCallback:)
                                                      userInfo:timerInfo
                                                       repeats:NO];
        bs.levelTimer = [NSTimer scheduledTimerWithTimeInterval:0.25 //NSEvent.doubleClickInterval // The possible doubleClickIntervall
                         // values (configurable in System Preferences) are either too long or too short. I prefer 0.25
                                                         target:self
                                                       selector:@selector(levelTimerCallback:)
                                                       userInfo:timerInfo
                                                        repeats:NO];
        
        // Check if zombified
        // Zombification should only occur during mouse down state, and then be removed with the consequent mouse up event
        if (bs.isZombified) {
            NSDictionary *debugInfo = @{
                @"devID": devID,
                @"btn": btn,
                @"lvl": @(bs.clickLevel),
                @"trigger": @(triggerType),
                @"holdTimer": bs.holdTimer,
                @"levelTimer": bs.levelTimer,
            };
            NSString *exceptionString = [NSString stringWithFormat:@"Button was found to be zombified when mouse down event occured: %@", debugInfo];
            @throw [NSException exceptionWithName:@"ZombifiedDuringMouseUpStateException" reason:exceptionString userInfo:nil];
        }
        
        // Update bs
        bs.isPressed = YES;
        bs.clickLevel += 1;
        
        // If new clickLevel and any following clickLevels can't lead to any effects, cycle back to the first click level
        if (![ButtonLandscapeAssessor buttonCouldStillBeUsedThisClickCycle:devID button:btn level:@(bs.clickLevel)]) {
            bs.clickLevel = 1;
        }
        
        // Send trigger
        passThroughEval = [ButtonTriggerHandler handleButtonTriggerWithButton:btn triggerType:kMFActionTriggerTypeButtonDown clickLevel:@(bs.clickLevel) device:devID];
        
    } else {
        
        // Mouse up
        
        // Reset button state if zombified
        if (bs.isZombified) {
            resetStateWithDevice(devID, btn);
        }
        
        // Send trigger
        passThroughEval = [ButtonTriggerHandler handleButtonTriggerWithButton:btn triggerType:kMFActionTriggerTypeButtonUp clickLevel:@(bs.clickLevel) device:devID];
        
        // Update bs
        bs.isPressed = NO;
        
        // Kill hold timer. This is only necessary if the hold timer zombified I think.
        [bs.holdTimer invalidate];

    }
    
    // Return
    return passThroughEval;
}

#pragma mark - Timer callbacks

+ (void)holdTimerCallback:(NSTimer *)timer {
    NSNumber *devID;
    NSNumber *btn;
    NSNumber *lvl;
    getTimerCallbackInfo(timer.userInfo, &devID, &btn, &lvl);
    
    zombifyWithDevice(devID, btn);
    [ButtonTriggerHandler handleButtonTriggerWithButton:btn triggerType:kMFActionTriggerTypeHoldTimerExpired clickLevel:lvl device:devID];
}

+ (void)levelTimerCallback:(NSTimer *)timer {
    NSNumber *devID;
    NSNumber *btn;
    NSNumber *lvl;
    getTimerCallbackInfo(timer.userInfo, &devID, &btn, &lvl);
    
    resetStateWithDevice(devID, btn);
    [ButtonTriggerHandler handleButtonTriggerWithButton:btn triggerType:kMFActionTriggerTypeLevelTimerExpired clickLevel:lvl device:devID];
}
static void getTimerCallbackInfo(NSDictionary *info, NSNumber **devID, NSNumber **btn,NSNumber **lvl) {
    
    *devID = (NSNumber *)info[@"devID"];
    *btn = (NSNumber *)info[@"btn"];
    
    ButtonState *bs = _state[*devID][*btn];
    *lvl = @(bs.clickLevel);
}

#pragma mark - State control

#pragma mark Reset state

static void resetStateWithDevice(NSNumber *devID, NSNumber *btn) {
    
#if DEBUG
//    NSLog(@"RESETTING STATE - devID: %@, btn: %@", devID, btn);
//    [SharedUtility printInfoOnCaller];
#endif
    
    ButtonState *bs = _state[devID][btn];
    
    [bs.holdTimer invalidate];
    [bs.levelTimer invalidate];
    bs.clickLevel = 0;
    bs.isZombified = NO;
    
}
// Don't think we'll need this
static void resetAllState() {
    for (NSNumber *devKey in _state) {
        NSDictionary *dev = _state[devKey];
        for (NSNumber *btnKey in dev) {
            resetStateWithDevice(devKey, btnKey);
        }
    }
}

#pragma mark Zombify

// Zombification is kinda like a frozen mouse down state. No more triggers are sent and on the next mouse up event, state will be fully reset. But clickLevel won't be reset when zombifying.
// With the click level not being reset the button can still be used as a modifier for other triggers while it's held down.
static void zombifyWithDevice(NSNumber *devID, NSNumber *btn) {
    
#if DEBUG
//    NSLog(@"ZOMBIFYING - devID: %@, btn: %@", devID, btn);
//    [SharedUtility printInfoOnCaller];
#endif
    
    ButtonState *bs = _state[devID][btn];
    
    [bs.holdTimer invalidate];
    [bs.levelTimer invalidate];
    bs.isZombified = YES;
    
}

static void neuterAllButtonsOnDeviceExcept(NSNumber *devID, NSNumber *exceptedBtn) {
    for (NSNumber *btn in _state[devID]) {
        if ([btn isEqualToNumber:exceptedBtn]) continue;
        if (buttonIsPressed(devID, btn)) {
            zombifyWithDevice(devID, btn);
        } else {
            resetStateWithDevice(devID, btn);
        }
    }
}

#pragma mark Interface

+ (void)handleButtonHasHadDirectEffectWithDevice:(NSNumber *)devID button:(NSNumber *)btn {
    resetStateWithDevice(devID, btn);
}

+ (void)handleButtonHasHadEffectAsModifierWithDevice:(NSNumber *)devID button:(NSNumber *)btn {
    zombifyWithDevice(devID, btn);
}

+ (NSArray *)getActiveButtonModifiersForDevice:(NSNumber *)devID {
    // NSUInteger pressedButtons = NSEvent.pressedMouseButtons; // This only updates after we use it here, which led to problems, so were keeping track of mouse down state ourselves with `bs.isPressed`
    
    // Get state and order by press time
    NSDictionary *devState = _state[devID];
    NSArray *buttonsOrderedByPressTime = [devState keysSortedByValueUsingComparator:^NSComparisonResult(ButtonState *_Nonnull bs1, ButtonState *_Nonnull bs2) {
        return [@(bs1.pressedAtTimeStamp) compare:@(bs2.pressedAtTimeStamp)];
    }];
    
    // Fill out array
    NSMutableArray *outArray = [NSMutableArray array];
    for (NSNumber *buttonNumber in buttonsOrderedByPressTime) {
        ButtonState *bs = devState[buttonNumber];
        BOOL isActive = bs.isPressed && (bs.clickLevel != 0);
        if (isActive) {
            [outArray addObject:@{
                kMFButtonModificationPreconditionKeyButtonNumber: buttonNumber,
                kMFButtonModificationPreconditionKeyClickLevel: @(bs.clickLevel)
            }];
        }
    }
    return outArray;
}

#pragma mark - Helper

static BOOL buttonIsPressed(NSNumber *devID, NSNumber *btn) {
    //return [bs.holdTimer isValid] || bs.isZombified;
    ButtonState *bs = _state[devID][btn];
    return bs.isPressed;
}


@end
