//
//  MJPEGWithSocketAppDelegate.h
//  MJPEGWithSocket
//
//  Created by Hao Hu on 29.07.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MJPEGClient.h"

@interface MJPEGWithSocketAppDelegate : NSObject <UIApplicationDelegate,MJPEGClientDelegate> {

    IBOutlet UIImageView *imgView;
    MJPEGClient *client;
    
}

@property (nonatomic, retain) IBOutlet UIWindow *window;

- (IBAction) sendClicked;
- (IBAction) stopClicked;
- (IBAction) btnReleaseClicked;
- (IBAction) btnCreateClicked;

@end
