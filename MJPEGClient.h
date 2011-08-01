//
//  MJPEGClient.h
//  MJPEGSocketDesktop
//
//  Created by Hao Hu on 29.07.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AsyncSocket.h"
#import "Base64.h"

//#define MJPEG_DEBUG_MODE
#define BUFFER_SIZE             512

#define READ_TAG_HEADERS        -1
#define READ_TAG_SOI            0
#define READ_TAG_EOI            1
#define READ_TAG_IMAGE          2


#define WRITE_TAG_GET           0
#define WRITE_TAG_HEADERS       1


#define CR 0x0d
#define LF 0x0a



@class MJPEGClient;



@protocol MJPEGClientDelegate <NSObject>

- (void) mjpegClient:(MJPEGClient*) client didReceiveImage:(UIImage*) image;


- (void) mjpegClient:(MJPEGClient*) client didReceiveError:(NSError*) error;

@end

@interface MJPEGClient : NSObject {


    NSMutableData *buffer;
    NSMutableData *imgBuffer;
    NSString * _clientId;
    NSString *_userName;
    NSString *_password;
    id<MJPEGClientDelegate> _delegate;
    NSTimeInterval _timeout;
    AsyncSocket *socket;
    //-----HTTP URL related data----
    
    NSString *_host;
    UInt16 _port;
    NSString *_path;
    //------------------------------
}
@property (retain) NSString* clientId;
@property (retain) NSString *userName;
@property (retain) NSString *password;
@property (retain) NSString *host;
@property (retain) NSString *path;
@property (assign) UInt16 port;

- (void) start;
- (void) stop;
- (id) initWithURL:(NSString*) url delegate:(id<MJPEGClientDelegate>) delegate timeout:(NSTimeInterval) timeout;


@end
