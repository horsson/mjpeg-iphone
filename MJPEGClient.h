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
#define BUFFER_SIZE             1024
#define BUFFER_SIZE_FOR_HEADER  64 * 10 * 5
#define MAX_FRAME_SIZE          BUFFER_SIZE * 2 * 10
#define MAX_TIMEOUT_TIMES           3


#define READ_TAG_HTTP_HEADERS        0
#define READ_TAG_SOI                 1
#define READ_TAG_IMAGE               2


#define WRITE_TAG_GET           0
#define WRITE_TAG_HEADERS       1


#define CR 0x0d
#define LF 0x0a
#define CRLF @"\r\n"

typedef enum
{
    ERROR_AUTH,
    ERROR_TIMEOUT,
    ERROR_UNKNOWN
    
} MJPEGClientError;

@class MJPEGClient;



@protocol MJPEGClientDelegate <NSObject>

- (void) mjpegClient:(MJPEGClient*) client didReceiveImage:(UIImage*) image;


- (void) mjpegClient:(MJPEGClient*) client didReceiveError:(NSError*) error;

@end

@interface MJPEGClient : NSObject {
@private
    NSMutableData *imgBuffer;
    NSString * _clientId;
    NSString *_userName;
    NSString *_password;
    id<MJPEGClientDelegate> _delegate;
    NSTimeInterval _timeout;
    AsyncSocket *socket;
    //**************HTTP URL related data******************
    
    NSString *_host;
    UInt16 _port;
    NSString *_path;
    NSString* _query;
    //******************************************************
    
    BOOL _isStopped;
}
@property (nonatomic, copy) NSString* clientId;
@property (nonatomic, copy) NSString *userName;
@property (nonatomic, copy) NSString *password;
@property (nonatomic, copy) NSString *host;
@property (nonatomic, copy) NSString *path;
@property (nonatomic, copy) NSString *query;
@property (assign) UInt16 port;
@property (assign) BOOL isStopped;

- (void) start;
- (void) stop;
- (id) initWithURL:(NSString*) url delegate:(id<MJPEGClientDelegate>) delegate timeout:(NSTimeInterval) timeout;


@end
