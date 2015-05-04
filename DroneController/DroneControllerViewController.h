//
//  ViewController.h
//  DroneController
//
//  Created by Anthony Dubis on 4/24/15.
//  Copyright (c) 2015 Anthony Dubis. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BButton.h"

@interface DroneControllerViewController : UIViewController

@property (weak, nonatomic) IBOutlet UIImageView *joystickHead;
@property (weak, nonatomic) IBOutlet UIImageView *joystickBackground;
@property (weak, nonatomic) IBOutlet UIView *throttleBackground;
@property (weak, nonatomic) IBOutlet UIImageView *throttleHead;
@property (strong, nonatomic) IBOutlet BButton *rightButton;
@property (strong, nonatomic) IBOutlet BButton *leftButton;
@property (strong, nonatomic) IBOutlet BButton *armButton;
@property (strong, nonatomic) IBOutlet BButton *disarmButton;

@end

