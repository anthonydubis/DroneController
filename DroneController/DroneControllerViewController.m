//
//  ViewController.m
//  DroneController
//
//  Created by Anthony Dubis on 4/24/15.
//  Copyright (c) 2015 Anthony Dubis. All rights reserved.
//

#import "DroneControllerViewController.h"
#import "BButton.h"
#import "AFHTTPRequestOperationManager.h"
#import <AVFoundation/AVFoundation.h>

@interface DroneControllerViewController ()
{
    BOOL shouldTurnLeft;
    BOOL shouldTurnRight;
    BOOL isMovingThrottle;
    BOOL isMovingJoystick;
    BOOL canSendMessage;
}

@property (nonatomic, assign) CGPoint jsOrigin;
@property (nonatomic, assign) CGFloat jsRadius;
@property (nonatomic, assign) CGRect throttleTrackRect;
@property (nonatomic, strong) AVAudioPlayer *beep;

@end

@implementation DroneControllerViewController

#define RESET_ANIMATION_DURATION 0.20

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupButtons];
    canSendMessage = YES;
    
    // Setup beep sound
    NSString *path = [[NSBundle mainBundle] pathForResource:@"beep-07" ofType:@"wav"];
    NSURL *url = [NSURL fileURLWithPath:path];
    self.beep = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:nil];
}

/*
 * Called whenever the user touches the screen.
 * Check to see if they are touching the head of the joystick before acting.
 */
-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    for (UITouch *touch in touches) {
        CGPoint location = [touch locationInView:touch.view];
        
        if (CGRectContainsPoint(self.joystickHead.frame, location)) {
            isMovingJoystick = YES;
            self.joystickHead.center = location;
            [self sendCurrentParameters];
        } else if (CGRectContainsPoint(self.throttleHead.frame, location)) {
            isMovingThrottle = YES;
            self.throttleHead.center = [self moveThrottleToLocation:location];
            [self sendCurrentParameters];
        }
    }
}

/*
 * Called as the user draggs the head around.
 */
-(void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    // Ignore irrelavent touches
    if (!isMovingThrottle && !isMovingJoystick) return;
    
    for (UITouch *touch in touches) {
        CGPoint location = [touch locationInView:self.view];
        if ([self touchPointPertainsToJoystick:location]) {
            self.joystickHead.center = [self moveJoystickToLocation:location];
            [self sendCurrentParameters];
        } else if ([self touchPointPertainsToThrottle:location]) {
            self.throttleHead.center = [self moveThrottleToLocation:location];
            [self sendCurrentParameters];
        }
    }
}

/*
 * Called when the user stops touching the screen
 */
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    // Ignore irrelavent touches
    if (!isMovingThrottle && !isMovingJoystick) return;
    
    for (UITouch *touch in touches) {
        CGPoint location = [touch locationInView:self.view];
        if ([self touchPointPertainsToJoystick:location]) {
            [self resetJoystick];
            [self sendCurrentParameters];
        } else if ([self touchPointPertainsToThrottle:location]) {
            isMovingThrottle = NO;
            [self sendCurrentParameters];
        }
    }
}

// Must be currently moving the joystick and the pt should be in the left half of the screen
- (BOOL)touchPointPertainsToJoystick:(CGPoint)pt
{
    return (isMovingJoystick && pt.x < self.view.frame.size.width / 2);
}

// Must be currently moving the throttle and pt should be in the right half of the screen
- (BOOL)touchPointPertainsToThrottle:(CGPoint)pt
{
    return (isMovingThrottle && pt.x > self.view.frame.size.width / 2);
}

/*
 * Called when something interrupts the touch, like a phone call or low memory warning
 */
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [self touchesEnded:touches withEvent:event];
}

/*
 * Sets the joystick back to the center and turns off the movingJoystick flag.
 */
- (void)resetJoystick
{
    isMovingJoystick = NO;
    
    // [UIView beginAnimations:nil context:nil];
    // [UIView setAnimationDuration:RESET_ANIMATION_DURATION];
    self.joystickHead.center = self.jsOrigin;
    // [UIView commitAnimations];
}

/*
 * Reset the throttle to the bottom of the track.
 * Reset before arming and disarming the drone.
 */
- (void)resetThrottle
{
    CGPoint home = CGPointMake(self.throttleHead.center.x,
                               self.throttleTrackRect.origin.y + self.throttleTrackRect.size.height);
    self.throttleHead.center = home;
}

/*
 * Returns the center location the head of the joystick should be moved to based on the selected location.
 * If the selected location is within the D-Pad background, then move to that location.
 * If the selected location is outside of the D-Pad, move to the closest point on the edge of the D-Pad.
 */
- (CGPoint)moveJoystickToLocation:(CGPoint)pt
{
    if (CGRectContainsPoint(self.joystickBackground.frame, pt)) {
        return pt;
    } else {
        return [self locationOnSquareDPadNearestToPoint:pt];
    }
    /* This was for when you were bounding the joystick to the circular background
    if ([self getDistanceFromJoystickOriginToPoint:selected] > self.jsRadius) {
        return [self locationOnDPadNearestToPoint:selected];
    } else {
        return selected;
    }
     */
}

- (CGPoint)moveThrottleToLocation:(CGPoint)loc
{
    CGPoint center = self.throttleHead.center;
    CGRect throttleTrackRect = self.throttleTrackRect;
    if (loc.y < throttleTrackRect.origin.y) {
        // The loc is above the track
        return CGPointMake(center.x, throttleTrackRect.origin.y);
    } else if (loc.y > (throttleTrackRect.origin.y + throttleTrackRect.size.height)) {
        // The loc is below the track
        return CGPointMake(center.x, throttleTrackRect.origin.y + throttleTrackRect.size.height);
    } else {
        // Within bounds of the track
        return CGPointMake(center.x, loc.y);
    }
}

- (CGPoint)locationOnSquareDPadNearestToPoint:(CGPoint)pt
{
    CGRect rect = self.joystickBackground.frame;
    CGFloat x = [self nearestValueOfFloat:pt.x inRangeWithStart:rect.origin.x andEnd:(rect.origin.x + rect.size.width)];
    CGFloat y = [self nearestValueOfFloat:pt.y inRangeWithStart:rect.origin.y andEnd:(rect.origin.y + rect.size.height)];
    return CGPointMake(x, y);
}

- (CGFloat)nearestValueOfFloat:(CGFloat)val inRangeWithStart:(CGFloat)start andEnd:(CGFloat)end
{
    if (val < start)
        return start;
    else if (val > end)
        return end;
    else
        return val;
}

/*
 * Returns the point on the D-Pad closest to the given point.
 * It is assumed that the given point is outside of the D-Pad.
 */
- (CGPoint)locationOnDPadNearestToPoint:(CGPoint)pt
{
    CGPoint c = self.jsOrigin;
    CGFloat r = self.jsRadius;
    
    double vX = pt.x - c.x;
    double vY = pt.y - c.y;
    double magV = sqrt(vX*vX + vY*vY);
    double aX = c.x + vX / magV * r;
    double aY = c.y + vY / magV * r;
    
    return CGPointMake(aX, aY);
}

- (CGFloat)getDistanceFromJoystickOriginToPoint:(CGPoint)pt
{
    return hypot(pt.x - self.jsOrigin.x, pt.y - self.jsOrigin.y);
}

- (void)sendCurrentParameters {
    NSArray *params = [self getCurrentParameters];
    [self postParameters:params];
}

// Params should be ordered Throttle, Pitch, Yaw, Roll
- (void)postParameters:(NSArray *)params {
    if (canSendMessage) {
        NSLog(@"Throttle: %@, Pitch: %@, Yaw: %@, Roll: %@", params[0], params[1], params[2], params[3]);
        canSendMessage = NO;
        AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
        NSDictionary *parameters = @{@"access_token": @"bb91440f1d9607b0eedec4565bc81356a1ff3137",
                                     @"args": [self getStringForParameters:params]};
        [manager POST:@"https://api.spark.io/v1/devices/50ff6d065067545656300487/setTPYR/"
           parameters:parameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
               NSLog(@"Received response");
               AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
               canSendMessage = YES;
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            NSLog(@"Error: %@", error);
        }];
    }
}

- (NSString *)getStringForParameters:(NSArray *)params
{
    NSString *str = [NSString stringWithFormat:@"%@,%@,%@,%@", [params objectAtIndex:0], [params objectAtIndex:1],
                     [params objectAtIndex:2], [params objectAtIndex:3]];
    return str;
}

- (NSArray *)getCurrentParameters
{
    NSArray *array = [NSArray arrayWithObjects:[self getCurrentThrottle], [self getCurrentPitch],
                      [self getCurrentYaw], [self getCurrentRoll], nil];
    return array;
}

/*
 * Gets the current throttle based on where the shield is in the track
 * The top of the track is 2000 - the bottom is 1000
 */
- (NSNumber *)getCurrentThrottle
{
    CGRect trackRect = self.throttleTrackRect;
    CGPoint throttlePoint = self.throttleHead.center;
    CGFloat pos = throttlePoint.y - trackRect.origin.y;
    CGFloat percentage = 1 - (pos / trackRect.size.height);
    int val = 1000 * percentage;
    
    return [NSNumber numberWithInt:1000 + val];
}

/*
 * The yaw is determined by whether the left or right button is pushed down.
 * Let's try a fixed yaw so the drone turns at a constant/smooth speed
 */
- (NSNumber *)getCurrentYaw
{
    if (shouldTurnRight)
        return [NSNumber numberWithInt:1750];
    else if (shouldTurnLeft)
        return [NSNumber numberWithInt:1250];
    else
        return [NSNumber numberWithInt:1500];
}

/*
 * Roll is based on the how far left/right the joystick is from the center.
 */
- (NSNumber *)getCurrentRoll
{
    // This check removes issues with rounding when we know the value should be 1500
    if (CGPointEqualToPoint(self.joystickHead.center, self.joystickBackground.center))
        return [NSNumber numberWithInt:1500];
    
    int joystickX = self.joystickHead.center.x;
    double pct = (joystickX - self.jsOrigin.x + self.jsRadius) / (self.jsRadius * 2);
    return [NSNumber numberWithInt:(1000 + 1000*pct)];
}

/*
 * Pitch is based on how far above/below the joystick is from the center
 */
- (NSNumber *)getCurrentPitch
{
    // This check removes issues with rounding when we know the value should be 1500
    if (CGPointEqualToPoint(self.joystickHead.center, self.joystickBackground.center))
        return [NSNumber numberWithInt:1500];
    
    int joystickY = self.joystickHead.center.y;
    double pct = (joystickY - self.jsOrigin.y + self.jsRadius) / (self.jsRadius * 2);
    // Reverse direction of pitch
    int adj = 1000 - 1000*pct;
    return [NSNumber numberWithInt:(1000 + adj)];
}

- (CGPoint)jsOrigin {
    return self.joystickBackground.center;
}

- (CGFloat)jsRadius {
    return self.joystickBackground.frame.size.width / 2.0;
}

#define TRACK_W 16.0

// Returns the rect for the black track that the throttle head travels along
- (CGRect)throttleTrackRect {
    CGRect rect = self.throttleBackground.frame;
    return CGRectMake(rect.origin.x + (rect.size.width - TRACK_W) / 2,
                      rect.origin.y, TRACK_W, rect.size.height);
}

#pragma mark - Setting up the buttons

- (void)setupButtons
{
    // Setup the "Arm" button
    CGRect r1 = self.armButton.frame;
    [self.armButton removeFromSuperview];
    BButton *armButton = [[BButton alloc] initWithFrame:r1 type:BButtonTypeDanger style:BButtonStyleBootstrapV3];
    [armButton setTitle:@"Arm" forState:UIControlStateNormal];
    [armButton addTarget:self action:@selector(armDrone:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:armButton];
    
    // Add the "Disarm" button
    CGRect r2 = self.disarmButton.frame;
    [self.disarmButton removeFromSuperview];
    BButton *disarmButton = [[BButton alloc] initWithFrame:r2 type:BButtonTypeDanger style:BButtonStyleBootstrapV3];
    [disarmButton setTitle:@"Disarm" forState:UIControlStateNormal];
    [disarmButton addTarget:self action:@selector(disarmDrone:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:disarmButton];
    
    // Setup "Right" button
    CGRect r3 = self.rightButton.frame;
    [self.rightButton removeFromSuperview];
    self.rightButton = [[BButton alloc] initWithFrame:r3 type:BButtonTypePrimary style:BButtonStyleBootstrapV3];
    [self.rightButton setTitle:@"Right" forState:UIControlStateNormal];
    [self setTargetsForYawButton:self.rightButton];
    [self.view addSubview:self.rightButton];
    
    // Setup "Left" button
    CGRect r4 = self.leftButton.frame;
    [self.leftButton removeFromSuperview];
    self.leftButton = [[BButton alloc] initWithFrame:r4 type:BButtonTypePrimary style:BButtonStyleBootstrapV3];
    [self.leftButton setTitle:@"Left" forState:UIControlStateNormal];
    [self setTargetsForYawButton:self.leftButton];
    [self.view addSubview:self.leftButton];
}

// Params sent should be ordered: TPYR
- (void)armDrone:(BButton *)sender
{
    NSLog(@"Arming drone...");
    [self.beep play];
    [self resetJoystick];
    [self resetThrottle];
    NSArray *params = [NSArray arrayWithObjects:[NSNumber numberWithInt:1000], [NSNumber numberWithInt:1500],
                       [NSNumber numberWithInt:2000], [NSNumber numberWithInt:1500], nil];
    [self postParameters:params];
}

// Params sent should be ordered: TPYR
- (void)disarmDrone:(BButton *)sender
{
    NSLog(@"Disarming drone...");
    [self.beep play];
    [self resetJoystick];
    [self resetThrottle];
    NSArray *params = [NSArray arrayWithObjects:[NSNumber numberWithInt:1000], [NSNumber numberWithInt:1500],
                       [NSNumber numberWithInt:1000], [NSNumber numberWithInt:1500], nil];
    [self postParameters:params];
}

// Set the targets for the left and right yaw buttons
- (void)setTargetsForYawButton:(BButton *)button
{
    [button addTarget:self action:@selector(pressedDownOnButton:) forControlEvents:UIControlEventTouchDown];
    [button addTarget:self action:@selector(liftedUpOnButton:) forControlEvents:UIControlEventTouchUpInside];
    [button addTarget:self action:@selector(liftedUpOnButton:) forControlEvents:UIControlEventTouchUpOutside];
}

- (void)pressedDownOnButton:(BButton *)sender
{
    [self.beep play];
    if (sender == self.rightButton) {
        shouldTurnRight = YES;
        NSLog(@"Turning right...");
    } else if (sender == self.leftButton) {
        shouldTurnLeft = YES;
        NSLog(@"Turning left...");
    }
    [self sendCurrentParameters];
}

- (void)liftedUpOnButton:(BButton *)sender
{
    if (sender == self.rightButton) {
        shouldTurnRight = NO;
        NSLog(@"Stopped turning right.");
    } else if (sender == self.leftButton) {
        shouldTurnLeft = NO;
        NSLog(@"Stopped turning left.");
    }
    [self sendCurrentParameters];
}

- (void)giveFeedback
{
    [self.beep play];
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
}

@end
