//
//  SwipeINteractionController.h
//  ILoveCatz
//
//  Created by Colin Eberhardt on 22/08/2013.
//  Copyright (c) 2013 com.razeware. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SwipeInteractionController : UIPercentDrivenInteractiveTransition

- (void)wireToViewController:(UIViewController*)viewController;

@property (nonatomic, assign) BOOL interactionInProgress;

@end
