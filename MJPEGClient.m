//
//  MJPEGClient.m
//  MJPEGSocketDesktop
//
//  Created by Hao Hu on 29.07.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "MJPEGClient.h"


@implementation MJPEGClient
@synthesize clientId = _clientId;
@synthesize userName = _userName;
@synthesize password = _password;
@synthesize host = _host;
@synthesize path = _path;
@synthesize port = _port;

//**************************MJPEG Client constants list********************************
NSString* const HTTP_GET_PATTERN = @"GET %@ HTTP/1.1\r\n";
NSString * const HEADER_USER_AGENT = @"User-Agent: mediola MJPEG Client 1.0\r\n";
NSString * const HEADER_CONNECTION = @"Connection: keep-alive\r\n";
NSString * const HEADER_HOST = @"Host: %@\r\n";
NSString * const HEADER_AUTH= @"Authorization: %@\r\n";

NSString * const HEADER_CONTENT_TYPE= @"Content-Type:";
NSString * const HEADER_CONTENT_LENGTH = @"Content-Length";

const UInt8 CRLF_CRLF[] = {0X0d,0x0a,0X0d,0x0a};
const UInt8 SOI[] = {0xff,0xd8};

//**************************************************************************************

-(void) doGet
{
    //1. Write the first GET Line
    NSString *getLine = [[NSString alloc] initWithFormat:HTTP_GET_PATTERN, _path];
    [socket writeData:[getLine dataUsingEncoding:NSUTF8StringEncoding] withTimeout:_timeout tag:0];
    [getLine release];
    //2. Write Headers one by one
    NSString *hostHeader = [[NSString alloc] initWithFormat:HEADER_HOST,_host];
    NSString *authHeader = nil;
    
    if (_userName != nil && _password != nil)
    {
        NSString *authString = [[NSString alloc] initWithFormat:@"%@:%@",_userName,_password];
        NSString *authedString = [Base64 encodePlaintText:authString];
        [authString release];
        NSString *value = [[NSString alloc] initWithFormat:@"Basic %@",authedString];
        authHeader = [[NSString alloc] initWithFormat:HEADER_AUTH,value];
        [value release];
    }
    
    NSString *allHeaders = nil;
    if (authHeader)
    {
        allHeaders = [[NSString alloc] initWithFormat:@"%@%@%@%@\r\n\r\n", hostHeader,HEADER_USER_AGENT,authHeader,HEADER_CONNECTION];
    }
    else
    {
        allHeaders = [[NSString alloc] initWithFormat:@"%@%@%@\r\n\r\n", hostHeader,HEADER_USER_AGENT,HEADER_CONNECTION];
    }
    
    [socket writeData:[allHeaders dataUsingEncoding:NSUTF8StringEncoding] withTimeout:_timeout tag:1];
    [authHeader release];
    [hostHeader release];
    [allHeaders release];
}

- (id) initWithURL:(NSString *)url delegate:(id<MJPEGClientDelegate>)delegate timeout:(NSTimeInterval)timeout
{
    if ((self = [super init]))
    {
        _timeout = timeout;
        _delegate = delegate;
        NSURL *nsUrl = [[NSURL alloc] initWithString:url];
        self.host = [nsUrl host] ;
        self.path = [nsUrl path] ;
        
        NSNumber * httpPort = [nsUrl port];
        _port = [httpPort unsignedIntValue];
        [nsUrl release];
        
        buffer = [[NSMutableData alloc] initWithLength:BUFFER_SIZE];
        imgBuffer = [[NSMutableData alloc] initWithLength:(BUFFER_SIZE * 10)];
    }
    return self;
}


- (void) start
{
    NSError *error = nil;
    if (socket)
    {
        [self stop];
    }
    
    socket = [[AsyncSocket alloc] initWithDelegate:self];
    
    
    if ( ![socket connectToHost:_host onPort:_port withTimeout:_timeout error:&error])
    {
        NSLog(@"Error to connect. The reason is %@", [error localizedDescription]);
        [_delegate mjpegClient:self didReceiveError:error];
        return;
    }
    
}




- (void) stop
{
    if (socket)
    {
        if ([socket isConnected])
            [socket disconnect];
       
    }
}



- (void)dealloc
{
    
    [buffer release];
    [imgBuffer release];
    [super dealloc];
}

/*
 Get the length of Header, in fact, it tries to get the position of 
 CRLF,CRLF
 */
-(NSUInteger) findHeaderLength:(NSData*) data
{
    const UInt8 *buf = [data bytes];
    int index = 0;
    for (int i = 0; i < [data length]; i++) {
        if (buf[i] == CRLF_CRLF[index])
        {
            index++;
            if (index > 4)
                return i;
        }
        else
        {
            index = 0;
        }
    }
    
    return  -1;
}

/*
 Get the position of SOI
 */
- (NSUInteger) findSOIPos:(NSData*) data
{
   
    
    const UInt8* buf = [data bytes];
    int index = 0;
    for (int i=0; i < [data length];i++)
    {
        
        if (SOI[index] != buf[i])
        {
            continue;
        }
        else if (SOI[++index] == buf[++i])
        {
            return i-1;
        }
        else
        {
            index = 0;
        }
    }

    return  -1;
}


/*
 Get the Content-Length header from the response.
 */
- (UInt32) getContentLength:(NSData*) data
{
    NSString *strHeaders = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSArray* headers = [strHeaders componentsSeparatedByString:@"\r\n"];
    [strHeaders release];
    for (NSString *header in headers)
    {
       // NSLog(@"%@",header);
        NSArray* headerComp = [header componentsSeparatedByString:@":"];
        if ([HEADER_CONTENT_LENGTH isEqualToString:[headerComp objectAtIndex:0]])
        {
            return [[headerComp objectAtIndex:1] intValue];
        }
    }
    
    return -1;
}

/*
 DEBUG helper!
 */
-(BOOL) isValidImage:(NSData*) imageData
{
    const UInt8* tmpData = [imageData bytes];
    NSUInteger length = [imageData length];
    UInt8 b1 =tmpData[0];
    UInt8 b2 =tmpData[1];
    UInt8 blast =tmpData[length-1];
    UInt8 blast2 =tmpData[length-2];
    NSString * output= [NSString stringWithFormat:@"1st %x, 2nd %x, last %x, last2 %x",b1,b2,blast,blast2];
    NSLog(@"%@",output);
    
    if (tmpData[0] == 0xff && tmpData[1] == 0xd8 && tmpData[length-1] == 0xd9 && tmpData[length-2] == 0xff)
    {
        return YES;
    }
    else
    {
        return NO;
    }
}
//********************************asyncsocket callback delegate********************************
- (void)onSocket:(AsyncSocket *)sock didWriteDataWithTag:(long)tag
{
    switch (tag) {
        case 0:
            NSLog(@"GET Line written.");
            break;
        case 1:
            NSLog(@"Headers written.");
            //As all HTTP headers are written successfully, ok, read the response now.

            [sock readDataToLength:BUFFER_SIZE withTimeout:_timeout tag:READ_TAG_SOI];
            break;
    }
}

- (void)onSocket:(AsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    
    if (READ_TAG_SOI == tag )
    {
        NSUInteger pos ;
    
            pos = [self findSOIPos:data];
            if (pos != -1)
            {
               // NSLog(@"Pos is %d. Tag is %ld.",pos,tag);
                NSRange range = NSMakeRange(pos, BUFFER_SIZE - pos);
                NSData * headers = [data subdataWithRange:NSMakeRange(0, pos)];
                UInt32 length = [self getContentLength:headers];
                UInt32 lengthToRead = length - (BUFFER_SIZE - pos);
                [imgBuffer setLength:0];
                [imgBuffer appendData:[data subdataWithRange:range]]; 
                [sock readDataToLength:lengthToRead withTimeout:_timeout tag:READ_TAG_IMAGE];
                
            }
            else
            {
                [sock readDataToLength:BUFFER_SIZE withTimeout:_timeout tag:READ_TAG_SOI];
            }
      
    }
    
    else if (READ_TAG_IMAGE == tag)
    {

        [imgBuffer appendData:data];
        //NSUInteger lengthOfData = [imgBuffer length];
        //NSLog(@"The image data length is %lu.",lengthOfData);
        
        if (_delegate)
        {
            NSData *imgDataToGen = [NSData dataWithData:imgBuffer];
            UIImage *img = [[[UIImage alloc] initWithData:imgDataToGen] autorelease];
            
            [_delegate mjpegClient:self didReceiveImage:img];
        } 
              
        //Read the next picture.
        [sock readDataToLength:BUFFER_SIZE withTimeout:_timeout tag:READ_TAG_SOI];
    }
   
}


- (void)onSocket:(AsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port
{
     NSLog(@"Connected to %@ on port %d", host, port);
    //After successfully connected to the host, send the GET request.
     [self doGet];
}

- (void)onSocketDidDisconnect:(AsyncSocket *)sock
{
    [sock release];
     socket = nil;
}

//************************************************************************************************
@end
